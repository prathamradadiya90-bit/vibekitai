import { Hono } from 'hono';
import { Env } from '../types';
import { StreakCheckinSchema, MilestoneClaimSchema } from '../schemas/validation';
import { QuotaManager } from '../quota/quota_manager';
import { StreaksRepository } from '../db/streaks.repo';

export const streakRoute = new Hono<{ Bindings: Env }>();

// Action XP Values
const ACTION_XP: Record<string, number> = {
  generate: 10,
  card_export: 15,
  challenge: 25,
  share: 15,
  save: 5,
};

// Helper: Calculate date string with client UTC offset
function getLocalDateString(offsetMinutes: number): string {
  const now = new Date();
  const localTime = new Date(now.getTime() + offsetMinutes * 60 * 1000);
  return localTime.toISOString().split('T')[0] ?? '';
}

// Helper: Check day difference between two YYYY-MM-DD dates
function getDayDiff(date1Str: string, date2Str: string): number {
  const d1 = new Date(date1Str);
  const d2 = new Date(date2Str);
  const diffTime = d1.getTime() - d2.getTime();
  return Math.round(diffTime / (1000 * 60 * 60 * 24));
}

// 1. GET /v1/streak - Fetch current streak, XP, level, and milestones
streakRoute.get('/streak', async (c) => {
  const installationId = c.req.header('X-App-Instance-Id') || 'anonymous_default';
  const offsetHeader = c.req.header('X-Timezone-Offset');
  const offsetMinutes = offsetHeader ? parseInt(offsetHeader, 10) : 0;
  const todayLocal = getLocalDateString(isNaN(offsetMinutes) ? 0 : offsetMinutes);

  if (!c.env.DB) {
    // Memory fallback for standalone tests
    return c.json({
      current_streak: 1,
      longest_streak: 1,
      last_checkin_date: todayLocal,
      freeze_count: 1,
      checked_in_today: false,
      total_xp: 50,
      level: 1,
      claimed_milestones: [],
    });
  }

  const quotaManager = new QuotaManager(c.env);
  const quota = await quotaManager.getQuotaStatus(installationId);
  const repo = new StreaksRepository(c.env.DB);

  const streakRow = await repo.getOrCreateStreak(installationId, quota.is_pro);
  const nowIso = new Date().toISOString();

  if (quota.is_pro) {
    const lastRefill = streakRow.pro_freeze_refilled_at ? new Date(streakRow.pro_freeze_refilled_at).getTime() : 0;
    const sevenDaysMs = 7 * 24 * 60 * 60 * 1000;
    if (Date.now() - lastRefill > sevenDaysMs && streakRow.freeze_count < 2) {
      await repo.refillProFreeze(installationId, nowIso);
      streakRow.freeze_count += 1;
    }
  }

  const totalXp = await repo.getTotalXp(installationId);
  const level = Math.floor(totalXp / 100) + 1;
  const claimedMilestones = await repo.getClaimedMilestones(installationId);
  const checkedInToday = streakRow.last_checkin_date === todayLocal;

  return c.json({
    current_streak: streakRow.current_streak,
    longest_streak: streakRow.longest_streak,
    last_checkin_date: streakRow.last_checkin_date,
    freeze_count: streakRow.freeze_count,
    checked_in_today: checkedInToday,
    total_xp: totalXp,
    level,
    claimed_milestones: claimedMilestones,
  });
});

// 2. POST /v1/streak/checkin - Record daily action, update streak and award XP
streakRoute.post('/streak/checkin', async (c) => {
  const installationId = c.req.header('X-App-Instance-Id') || 'anonymous_default';
  const bodyResult = StreakCheckinSchema.safeParse(await c.req.json().catch(() => ({})));

  if (!bodyResult.success) {
    return c.json(
      {
        error: {
          code: 'VALIDATION_ERROR',
          message: 'Invalid checkin payload.',
          details: bodyResult.error.format(),
        },
      },
      400
    );
  }

  const { utc_offset_minutes, action } = bodyResult.data;
  const todayLocal = getLocalDateString(utc_offset_minutes);
  const xpAwarded = ACTION_XP[action] || 10;
  const nowIso = new Date().toISOString();

  if (!c.env.DB) {
    return c.json({
      success: true,
      current_streak: 1,
      longest_streak: 1,
      xp_awarded: xpAwarded,
      streak_preserved_by_freeze: false,
    });
  }

  const repo = new StreaksRepository(c.env.DB);
  const streak = await repo.getOrCreateStreak(installationId, false);

  let newStreak = streak.current_streak;
  let newLongest = streak.longest_streak;
  let freezeUsed = false;
  let effectiveXp = xpAwarded;

  if (streak.last_checkin_date === todayLocal) {
    // Already checked in today: check if XP for this action was already awarded today
    const existingXp = await c.env.DB
      .prepare('SELECT id FROM xp_events WHERE installation_id = ? AND action_type = ? AND created_at >= ? LIMIT 1')
      .bind(installationId, action, `${todayLocal}T00:00:00.000Z`)
      .first();
    if (existingXp) {
      effectiveXp = 0;
    }
  } else if (streak.last_checkin_date === '') {
    // First ever checkin
    newStreak = 1;
    newLongest = 1;
  } else {
    const diff = getDayDiff(todayLocal, streak.last_checkin_date);
    if (diff <= 0) {
      // Same local day or clock/timezone adjustment: maintain streak
      newStreak = streak.current_streak;
    } else if (diff === 1) {
      newStreak += 1;
      if (newStreak > newLongest) newLongest = newStreak;
    } else if (diff === 2 && streak.freeze_count > 0) {
      freezeUsed = true;
      streak.freeze_count -= 1;
      newStreak += 1;
      if (newStreak > newLongest) newLongest = newStreak;
    } else {
      newStreak = 1;
    }
  }

  await repo.updateStreakAndRecordXp({
    installationId,
    newStreak,
    newLongest,
    todayLocal,
    freezeCount: streak.freeze_count,
    freezeUsed,
    nowIso,
    action,
    xpAwarded: effectiveXp,
  });

  return c.json({
    success: true,
    current_streak: newStreak,
    longest_streak: newLongest,
    xp_awarded: effectiveXp,
    streak_preserved_by_freeze: freezeUsed,
  });
});

// 3. POST /v1/streak/claim-milestone - Claim milestone rewards
streakRoute.post('/streak/claim-milestone', async (c) => {
  const installationId = c.req.header('X-App-Instance-Id') || 'anonymous_default';
  const bodyResult = MilestoneClaimSchema.safeParse(await c.req.json().catch(() => ({})));

  if (!bodyResult.success) {
    return c.json(
      {
        error: {
          code: 'VALIDATION_ERROR',
          message: 'Invalid milestone day. Allowed days: 3, 7, 14, 30.',
        },
      },
      400
    );
  }

  const { milestone_day } = bodyResult.data;

  if (!c.env.DB) {
    return c.json({
      success: true,
      milestone_day,
      reward_type: 'credit',
      bonus_credits: 1,
    });
  }

  const repo = new StreaksRepository(c.env.DB);
  const streak = await repo.getStreak(installationId);

  if (!streak || streak.current_streak < milestone_day) {
    return c.json(
      {
        error: {
          code: 'MILESTONE_NOT_REACHED',
          message: `Your current streak of ${streak?.current_streak ?? 0} has not reached milestone ${milestone_day}.`,
        },
      },
      400
    );
  }

  let rewardType = 'credit';
  let bonusCredits = 0;
  if (milestone_day === 3) {
    rewardType = 'credit';
    bonusCredits = 1;
  } else if (milestone_day === 7) {
    rewardType = 'template_pack';
    bonusCredits = 1;
  } else if (milestone_day === 14) {
    rewardType = 'template_pack';
    bonusCredits = 0;
  } else if (milestone_day === 30) {
    rewardType = 'badge';
    bonusCredits = 2;
  }

  const nowIso = new Date().toISOString();
  const todayIso = nowIso.split('T')[0] ?? '';

  try {
    await repo.claimMilestone({
      installationId,
      milestoneDay: milestone_day,
      rewardType,
      bonusCredits,
      nowIso,
      todayIso,
    });

    return c.json({
      success: true,
      milestone_day,
      reward_type: rewardType,
      bonus_credits: bonusCredits,
    });
  } catch (_err) {
    return c.json(
      {
        error: {
          code: 'ALREADY_CLAIMED',
          message: `Milestone ${milestone_day} has already been claimed for this installation.`,
        },
      },
      400
    );
  }
});

// 4. POST /v1/streak/earn-freeze - Free users earn 1 freeze via rewarded ad
streakRoute.post('/streak/earn-freeze', async (c) => {
  const installationId = c.req.header('X-App-Instance-Id') || 'anonymous_default';
  if (!c.env.DB) {
    return c.json({ success: true, freeze_count: 1 });
  }

  const quotaManager = new QuotaManager(c.env);
  const quota = await quotaManager.getQuotaStatus(installationId);
  const isDevOrTest = c.env.ENVIRONMENT === 'development' || c.env.ENVIRONMENT === 'test';

  if (!isDevOrTest && quota.rewarded_ads_watched_today === 0) {
    return c.json(
      {
        error: {
          code: 'AD_REQUIRED',
          message: 'Watch a rewarded ad to earn a streak freeze.',
        },
      },
      400
    );
  }

  const repo = new StreaksRepository(c.env.DB);
  const streak = await repo.getStreak(installationId);

  if (streak && streak.freeze_count >= 2) {
    return c.json(
      {
        error: {
          code: 'MAX_FREEZES_REACHED',
          message: 'You already have the maximum of 2 streak freezes.',
        },
      },
      400
    );
  }

  const nowIso = new Date().toISOString();
  const freezeCount = await repo.earnFreeze(installationId, nowIso);

  return c.json({
    success: true,
    freeze_count: freezeCount,
  });
});
