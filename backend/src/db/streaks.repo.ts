export interface StreakRecord {
  installation_id: string;
  current_streak: number;
  longest_streak: number;
  last_checkin_date: string;
  freeze_count: number;
  pro_freeze_refilled_at?: string | null;
  last_freeze_used_date?: string | null;
  created_at: string;
  updated_at: string;
}

export class StreaksRepository {
  constructor(private readonly db: D1Database) {}

  async getStreak(installationId: string): Promise<StreakRecord | null> {
    return await this.db
      .prepare('SELECT * FROM streaks WHERE installation_id = ?')
      .bind(installationId)
      .first<StreakRecord>();
  }

  async getOrCreateStreak(installationId: string, isPro: boolean): Promise<StreakRecord> {
    const existing = await this.getStreak(installationId);
    if (existing) {
      return existing;
    }

    const nowIso = new Date().toISOString();
    const initialFreezes = isPro ? 1 : 0;
    await this.db
      .prepare(
        `INSERT INTO streaks (installation_id, current_streak, longest_streak, last_checkin_date, freeze_count, pro_freeze_refilled_at, created_at, updated_at)
         VALUES (?, 0, 0, '', ?, ?, ?, ?)
         ON CONFLICT(installation_id) DO NOTHING`
      )
      .bind(installationId, initialFreezes, isPro ? nowIso : null, nowIso, nowIso)
      .run();

    return (
      (await this.getStreak(installationId)) ?? {
        installation_id: installationId,
        current_streak: 0,
        longest_streak: 0,
        last_checkin_date: '',
        freeze_count: initialFreezes,
        created_at: nowIso,
        updated_at: nowIso,
      }
    );
  }

  async refillProFreeze(installationId: string, nowIso: string): Promise<void> {
    await this.db
      .prepare(
        'UPDATE streaks SET freeze_count = freeze_count + 1, pro_freeze_refilled_at = ?, updated_at = ? WHERE installation_id = ?'
      )
      .bind(nowIso, nowIso, installationId)
      .run();
  }

  async getTotalXp(installationId: string): Promise<number> {
    const res = await this.db
      .prepare('SELECT COALESCE(SUM(xp_points), 0) AS total_xp FROM xp_events WHERE installation_id = ?')
      .bind(installationId)
      .first<{ total_xp: number }>();
    return res?.total_xp ?? 0;
  }

  async getClaimedMilestones(installationId: string): Promise<number[]> {
    const rows = await this.db
      .prepare('SELECT milestone_day FROM milestone_claims WHERE installation_id = ?')
      .bind(installationId)
      .all<{ milestone_day: number }>();
    return (rows.results || []).map((m) => m.milestone_day);
  }

  async updateStreakAndRecordXp(params: {
    installationId: string;
    newStreak: number;
    newLongest: number;
    todayLocal: string;
    freezeCount: number;
    freezeUsed: boolean;
    nowIso: string;
    action: string;
    xpAwarded: number;
  }): Promise<void> {
    const xpId = `xp_${Date.now()}_${Math.random().toString(36).substring(7)}`;

    await this.db.batch([
      this.db
        .prepare(
          `UPDATE streaks
           SET current_streak = ?,
               longest_streak = ?,
               last_checkin_date = ?,
               freeze_count = ?,
               last_freeze_used_date = CASE WHEN ? THEN ? ELSE last_freeze_used_date END,
               updated_at = ?
           WHERE installation_id = ?`
        )
        .bind(
          params.newStreak,
          params.newLongest,
          params.todayLocal,
          params.freezeCount,
          params.freezeUsed ? 1 : 0,
          params.todayLocal,
          params.nowIso,
          params.installationId
        ),

      this.db
        .prepare(
          `INSERT INTO xp_events (id, installation_id, action_type, xp_points, created_at)
           VALUES (?, ?, ?, ?, ?)`
        )
        .bind(xpId, params.installationId, params.action, params.xpAwarded, params.nowIso),
    ]);
  }

  async claimMilestone(params: {
    installationId: string;
    milestoneDay: number;
    rewardType: string;
    bonusCredits: number;
    nowIso: string;
    todayIso: string;
  }): Promise<void> {
    const claimId = `mc_${Date.now()}_${Math.random().toString(36).substring(7)}`;

    const statements: D1PreparedStatement[] = [
      this.db
        .prepare(
          `INSERT INTO milestone_claims (id, installation_id, milestone_day, reward_type, bonus_credits, claimed_at)
           VALUES (?, ?, ?, ?, ?, ?)`
        )
        .bind(
          claimId,
          params.installationId,
          params.milestoneDay,
          params.rewardType,
          params.bonusCredits,
          params.nowIso
        ),
    ];

    if (params.bonusCredits > 0) {
      statements.push(
        this.db
          .prepare(
            `INSERT INTO daily_usage (id, installation_id, usage_date, rewarded_credits_earned, updated_at)
             VALUES (?, ?, ?, ?, ?)
             ON CONFLICT(installation_id, usage_date) DO UPDATE SET
               rewarded_credits_earned = rewarded_credits_earned + excluded.rewarded_credits_earned,
               updated_at = excluded.updated_at`
          )
          .bind(
            `${params.installationId}_${params.todayIso}`,
            params.installationId,
            params.todayIso,
            params.bonusCredits,
            params.nowIso
          )
      );
    }

    await this.db.batch(statements);
  }

  async earnFreeze(installationId: string, nowIso: string): Promise<number> {
    await this.db
      .prepare(
        `INSERT INTO streaks (installation_id, current_streak, longest_streak, last_checkin_date, freeze_count, created_at, updated_at)
         VALUES (?, 0, 0, '', 1, ?, ?)
         ON CONFLICT(installation_id) DO UPDATE SET
           freeze_count = freeze_count + 1,
           updated_at = excluded.updated_at`
      )
      .bind(installationId, nowIso, nowIso)
      .run();

    const updated = await this.getStreak(installationId);
    return updated?.freeze_count ?? 1;
  }
}
