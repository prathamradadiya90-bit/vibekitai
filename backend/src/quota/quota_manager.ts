import { Env } from '../types';

export interface QuotaStatus {
  free_credits_remaining: number;
  rewarded_credits_remaining: number;
  total_credits_remaining: number;
  is_pro: boolean;
  pro_credits_remaining: number;
  pro_cycle_resets_at: string | null;
  rewarded_ads_watched_today: number;
  max_rewarded_ads_per_day: number;
  reset_at_utc: string;
}

interface MemoryQuotaEntry {
  date: string;
  freeUsed: number;
  rewardedEarned: number;
  rewardedAdsWatched: number;
}

const memoryUsageStore = new Map<string, MemoryQuotaEntry>();
const MAX_MEMORY_ENTRIES = 2000;

export type CreditBucket = 'free' | 'rewarded' | 'pro';

function pruneMemoryUsageStore(today: string): void {
  if (memoryUsageStore.size <= MAX_MEMORY_ENTRIES) return;
  for (const [k, v] of memoryUsageStore.entries()) {
    if (v.date !== today) memoryUsageStore.delete(k);
    if (memoryUsageStore.size <= MAX_MEMORY_ENTRIES) return;
  }
  for (const k of memoryUsageStore.keys()) {
    memoryUsageStore.delete(k);
    if (memoryUsageStore.size <= MAX_MEMORY_ENTRIES / 2) break;
  }
}

export class QuotaManager {
  private db?: D1Database;
  private maxDailyFree: number;
  private maxDailyRewards: number;
  private creditsPerReward: number;
  private monthlyProCredits: number;

  constructor(env: Env) {
    this.db = env.DB;
    const rawFree = parseInt(env.MAX_DAILY_FREE_CREDITS ?? '3', 10);
    const rawRewards = parseInt(env.MAX_DAILY_REWARDS ?? '2', 10);
    const rawPerAd = parseInt(env.REWARD_CREDITS_PER_AD ?? '3', 10);
    const rawPro = parseInt(env.MONTHLY_PRO_CREDITS ?? '200', 10);
    this.maxDailyFree = Number.isFinite(rawFree) ? Math.max(0, rawFree) : 3;
    this.maxDailyRewards = Number.isFinite(rawRewards) ? Math.max(0, rawRewards) : 2;
    this.creditsPerReward = Number.isFinite(rawPerAd) ? Math.max(0, rawPerAd) : 3;
    this.monthlyProCredits = Number.isFinite(rawPro) ? Math.max(0, rawPro) : 200;
  }

  private getTodayUtcString(): string {
    return new Date().toISOString().split('T')[0] ?? '';
  }

  private getTomorrowMidnightUtcString(): string {
    const tomorrow = new Date();
    tomorrow.setUTCDate(tomorrow.getUTCDate() + 1);
    tomorrow.setUTCHours(0, 0, 0, 0);
    return tomorrow.toISOString();
  }

  async getQuotaStatus(installationId: string): Promise<QuotaStatus> {
    const today = this.getTodayUtcString();
    const resetAtUtc = this.getTomorrowMidnightUtcString();

    if (!this.db) {
      pruneMemoryUsageStore(today);
      let entry = memoryUsageStore.get(installationId);
      if (!entry || entry.date !== today) {
        entry = { date: today, freeUsed: 0, rewardedEarned: 0, rewardedAdsWatched: 0 };
        memoryUsageStore.set(installationId, entry);
      }
      const freeRemaining = Math.max(0, this.maxDailyFree - entry.freeUsed);
      const totalRemaining = freeRemaining + entry.rewardedEarned;
      return {
        free_credits_remaining: freeRemaining,
        rewarded_credits_remaining: entry.rewardedEarned,
        total_credits_remaining: totalRemaining,
        is_pro: false,
        pro_credits_remaining: 0,
        pro_cycle_resets_at: null,
        rewarded_ads_watched_today: entry.rewardedAdsWatched,
        max_rewarded_ads_per_day: this.maxDailyRewards,
        reset_at_utc: resetAtUtc,
      };
    }

    await this.db
      .prepare(
        `INSERT INTO installations (id, created_at, last_active_at)
         VALUES (?, ?, ?)
         ON CONFLICT(id) DO UPDATE SET last_active_at = excluded.last_active_at`
      )
      .bind(installationId, new Date().toISOString(), new Date().toISOString())
      .run();

    const inst = await this.db
      .prepare('SELECT is_pro, pro_expires_at FROM installations WHERE id = ?')
      .bind(installationId)
      .first<{ is_pro: number; pro_expires_at: string | null }>();

    let isPro = inst?.is_pro === 1;
    let proCycleResetsAt: string | null = null;
    let proRemaining = 0;

    if (isPro && inst?.pro_expires_at && new Date(inst.pro_expires_at) < new Date()) {
      // Expire timed rows but preserve active Lifetime passes if one exists
      await this.db
        .prepare(
          `UPDATE subscription_entitlements
           SET status = 'EXPIRED'
           WHERE installation_id = ?
             AND status IN ('ACTIVE', 'IN_GRACE_PERIOD', 'CANCELED')
             AND expires_at IS NOT NULL
             AND product_id NOT IN ('vibekit_pro_lifetime', 'vibekit_lifetime')`
        )
        .bind(installationId)
        .run();

      const activeLifetime = await this.db
        .prepare(
          `SELECT id FROM subscription_entitlements
           WHERE installation_id = ?
             AND (product_id IN ('vibekit_pro_lifetime', 'vibekit_lifetime') OR expires_at IS NULL)
             AND status NOT IN ('REVOKED', 'EXPIRED', 'ON_HOLD', 'PAUSED')
           LIMIT 1`
        )
        .bind(installationId)
        .first<{ id: string }>();

      if (activeLifetime) {
        await this.db
          .prepare('UPDATE installations SET is_pro = 1, pro_expires_at = NULL WHERE id = ?')
          .bind(installationId)
          .run();
      } else {
        isPro = false;
        await this.db
          .prepare('UPDATE installations SET is_pro = 0 WHERE id = ?')
          .bind(installationId)
          .run();
      }
    } else if (isPro && inst?.pro_expires_at) {
      proCycleResetsAt = inst.pro_expires_at;
    }

    if (isPro) {
      const cycle = await this.ensureActiveProCycle(installationId, inst?.pro_expires_at ?? null);
      if (cycle) {
        proCycleResetsAt = cycle.cycle_end;
        proRemaining = Math.max(0, this.monthlyProCredits - cycle.credits_used);
      }
    }

    const usage = await this.db
      .prepare(
        'SELECT free_credits_used, rewarded_ads_watched FROM daily_usage WHERE installation_id = ? AND usage_date = ?'
      )
      .bind(installationId, today)
      .first<{
        free_credits_used: number;
        rewarded_ads_watched: number;
      }>();

    const rewardedRow = await this.db
      .prepare(
        'SELECT COALESCE(SUM(rewarded_credits_earned), 0) AS remaining_rewarded FROM daily_usage WHERE installation_id = ?'
      )
      .bind(installationId)
      .first<{ remaining_rewarded: number }>();

    const freeUsed = usage?.free_credits_used ?? 0;
    const adsWatched = usage?.rewarded_ads_watched ?? 0;
    const rewardedRemaining = Math.max(0, rewardedRow?.remaining_rewarded ?? 0);

    const freeRemaining = Math.max(0, this.maxDailyFree - freeUsed);
    // Keep free+rewarded total populated accurately; Pro users with exhausted cycle also retain rewarded credits
    const totalRemaining = freeRemaining + rewardedRemaining;

    return {
      free_credits_remaining: freeRemaining,
      rewarded_credits_remaining: rewardedRemaining,
      total_credits_remaining: totalRemaining,
      is_pro: isPro,
      pro_credits_remaining: isPro ? proRemaining : 0,
      pro_cycle_resets_at: proCycleResetsAt,
      rewarded_ads_watched_today: adsWatched,
      max_rewarded_ads_per_day: this.maxDailyRewards,
      reset_at_utc: resetAtUtc,
    };
  }

  private async ensureActiveProCycle(
    installationId: string,
    proExpiresAt: string | null
  ): Promise<{ id: string; credits_used: number; cycle_start: string; cycle_end: string } | null> {
    if (!this.db) return null;
    const nowIso = new Date().toISOString();

    let cycle = await this.db
      .prepare(
        `SELECT id, credits_used, cycle_start, cycle_end
         FROM pro_cycle_usage
         WHERE installation_id = ? AND cycle_end > ?
         ORDER BY cycle_end ASC LIMIT 1`
      )
      .bind(installationId, nowIso)
      .first<{ id: string; credits_used: number; cycle_start: string; cycle_end: string }>();

    if (!cycle) {
      const monthEnd = new Date(Date.now() + 30 * 86400000);
      const entitlementEnd = proExpiresAt ? new Date(proExpiresAt) : null;
      if (entitlementEnd && entitlementEnd.getTime() <= Date.now()) {
        return null;
      }
      const cycleStart = nowIso;
      const cycleEnd = (entitlementEnd && entitlementEnd < monthEnd ? entitlementEnd : monthEnd).toISOString();
      // Deterministic minute-bucket ID + ON CONFLICT DO NOTHING eliminates concurrent PK 500s
      const minuteBucket = Math.floor(Date.now() / 60000);
      const cycleId = `pcu_${installationId}_${minuteBucket}`;

      await this.db
        .prepare(
          `INSERT INTO pro_cycle_usage (id, installation_id, cycle_start, cycle_end, credits_used, updated_at)
           VALUES (?, ?, ?, ?, 0, ?)
           ON CONFLICT(id) DO NOTHING`
        )
        .bind(cycleId, installationId, cycleStart, cycleEnd, nowIso)
        .run();

      cycle =
        (await this.db
          .prepare(
            `SELECT id, credits_used, cycle_start, cycle_end
             FROM pro_cycle_usage
             WHERE installation_id = ? AND cycle_end > ?
             ORDER BY cycle_end ASC LIMIT 1`
          )
          .bind(installationId, nowIso)
          .first<{ id: string; credits_used: number; cycle_start: string; cycle_end: string }>()) ??
        { id: cycleId, credits_used: 0, cycle_start: cycleStart, cycle_end: cycleEnd };
    }

    return cycle;
  }

  async hasAvailableCredits(installationId: string): Promise<boolean> {
    const quota = await this.getQuotaStatus(installationId);
    if (quota.is_pro) {
      return quota.pro_credits_remaining > 0 || quota.rewarded_credits_remaining > 0;
    }
    return quota.total_credits_remaining > 0;
  }

  async deductCredit(installationId: string): Promise<boolean> {
    return (await this.reserveCredit(installationId)) !== null;
  }

  async reserveCredit(installationId: string): Promise<CreditBucket | null> {
    const reserved = await this.reserveCreditWithDate(installationId);
    return reserved ? reserved.bucket : null;
  }

  /**
   * Atomically reserves 1 credit before expensive AI generation and records the UTC date
   * reserved so cross-midnight failures refund accurately to the debited day.
   */
  async reserveCreditWithDate(
    installationId: string
  ): Promise<{ bucket: CreditBucket; usageDate: string } | null> {
    const today = this.getTodayUtcString();
    const nowIso = new Date().toISOString();

    if (!this.db) {
      pruneMemoryUsageStore(today);
      let entry = memoryUsageStore.get(installationId);
      if (!entry || entry.date !== today) {
        entry = { date: today, freeUsed: 0, rewardedEarned: 0, rewardedAdsWatched: 0 };
        memoryUsageStore.set(installationId, entry);
      }
      if (entry.freeUsed < this.maxDailyFree) {
        entry.freeUsed += 1;
        return { bucket: 'free', usageDate: today };
      }
      if (entry.rewardedEarned > 0) {
        entry.rewardedEarned -= 1;
        return { bucket: 'rewarded', usageDate: today };
      }
      return null;
    }

    // 1. Check if user is Pro
    const inst = await this.db
      .prepare('SELECT is_pro, pro_expires_at FROM installations WHERE id = ?')
      .bind(installationId)
      .first<{ is_pro: number; pro_expires_at: string | null }>();

    const isPro = Boolean(inst?.is_pro) && (!inst?.pro_expires_at || new Date(inst.pro_expires_at) > new Date());

    if (isPro) {
      const cycle = await this.ensureActiveProCycle(installationId, inst?.pro_expires_at ?? null);
      if (cycle && this.monthlyProCredits > 0) {
        const proNowIso = new Date().toISOString();
        const proResult = await this.db
          .prepare(
            `UPDATE pro_cycle_usage
             SET credits_used = credits_used + 1, updated_at = ?
             WHERE id = ? AND credits_used < ?`
          )
          .bind(proNowIso, cycle.id, this.monthlyProCredits)
          .run();

        if ((proResult.meta?.changes ?? 0) > 0) {
          await this.db
            .prepare(
              `INSERT INTO daily_usage (id, installation_id, usage_date, pro_credits_used, updated_at)
               VALUES (?, ?, ?, 1, ?)
               ON CONFLICT(installation_id, usage_date) DO UPDATE SET
                 pro_credits_used = pro_credits_used + 1,
                 updated_at = excluded.updated_at`
            )
            .bind(`${installationId}_${today}`, installationId, today, proNowIso)
            .run();
          return { bucket: 'pro', usageDate: today };
        }
      }
      // Pro monthly allowance exhausted: fall through to purchased credit packs / rewarded credits
    } else if (this.maxDailyFree > 0) {
      // 2. Free user: try atomic deduction from free credits first
      const freeUpdate = await this.db
        .prepare(
          `UPDATE daily_usage
           SET free_credits_used = free_credits_used + 1, updated_at = ?
           WHERE installation_id = ? AND usage_date = ? AND free_credits_used < ?`
        )
        .bind(nowIso, installationId, today, this.maxDailyFree)
        .run();

      if ((freeUpdate.meta?.changes ?? 0) > 0) {
        return { bucket: 'free', usageDate: today };
      }

      // First credit of the day attempt
      try {
        const insertResult = await this.db
          .prepare(
            `INSERT INTO daily_usage (id, installation_id, usage_date, free_credits_used, updated_at)
             VALUES (?, ?, ?, 1, ?)`
          )
          .bind(`${installationId}_${today}`, installationId, today, nowIso)
          .run();
        if ((insertResult.meta?.changes ?? 0) > 0) {
          return { bucket: 'free', usageDate: today };
        }
      } catch {
        const retryUpdate = await this.db
          .prepare(
            `UPDATE daily_usage
             SET free_credits_used = free_credits_used + 1, updated_at = ?
             WHERE installation_id = ? AND usage_date = ? AND free_credits_used < ?`
          )
          .bind(nowIso, installationId, today, this.maxDailyFree)
          .run();
        if ((retryUpdate.meta?.changes ?? 0) > 0) {
          return { bucket: 'free', usageDate: today };
        }
      }
    }

    // 3. Deduct from persistent rewarded / credit-pack / referral credits across dates
    const candidateRows = await this.db
      .prepare(
        'SELECT usage_date FROM daily_usage WHERE installation_id = ? AND rewarded_credits_earned > 0 ORDER BY usage_date ASC LIMIT 10'
      )
      .bind(installationId)
      .all<{ usage_date: string }>();

    for (const candidateRow of candidateRows.results ?? []) {
      const rewardedUpdate = await this.db
        .prepare(
          `UPDATE daily_usage
           SET rewarded_credits_earned = rewarded_credits_earned - 1, updated_at = ?
           WHERE installation_id = ? AND usage_date = ? AND rewarded_credits_earned > 0`
        )
        .bind(nowIso, installationId, candidateRow.usage_date)
        .run();

      if ((rewardedUpdate.meta?.changes ?? 0) > 0) {
        return { bucket: 'rewarded', usageDate: candidateRow.usage_date };
      }
    }

    return null;
  }

  /**
   * Refunds a previously reserved credit to the exact UTC date debited when AI generation fails.
   */
  async refundCredit(installationId: string, bucket: CreditBucket, reservedUsageDate?: string): Promise<void> {
    const targetDate = reservedUsageDate || this.getTodayUtcString();
    const nowIso = new Date().toISOString();

    if (!this.db) {
      const entry = memoryUsageStore.get(installationId);
      if (!entry || entry.date !== targetDate) return;
      if (bucket === 'free' && entry.freeUsed > 0) {
        entry.freeUsed -= 1;
      } else if (bucket === 'rewarded') {
        entry.rewardedEarned += 1;
      }
      return;
    }

    try {
      if (bucket === 'pro') {
        await this.db
          .prepare(
            `UPDATE pro_cycle_usage
             SET credits_used = MAX(0, credits_used - 1), updated_at = ?
             WHERE id = (
               SELECT id FROM pro_cycle_usage
               WHERE installation_id = ? AND cycle_start <= ? AND cycle_end > ?
               ORDER BY cycle_end ASC LIMIT 1
             )`
          )
          .bind(nowIso, installationId, nowIso, nowIso)
          .run();
        await this.db
          .prepare(
            `UPDATE daily_usage
             SET pro_credits_used = MAX(0, pro_credits_used - 1), updated_at = ?
             WHERE installation_id = ? AND usage_date = ?`
          )
          .bind(nowIso, installationId, targetDate)
          .run();
      } else if (bucket === 'free') {
        await this.db
          .prepare(
            `UPDATE daily_usage
             SET free_credits_used = MAX(0, free_credits_used - 1), updated_at = ?
             WHERE installation_id = ? AND usage_date = ?`
          )
          .bind(nowIso, installationId, targetDate)
          .run();
      } else if (bucket === 'rewarded') {
        await this.db
          .prepare(
            `INSERT INTO daily_usage (id, installation_id, usage_date, rewarded_credits_earned, updated_at)
             VALUES (?, ?, ?, 1, ?)
             ON CONFLICT(installation_id, usage_date) DO UPDATE SET
               rewarded_credits_earned = rewarded_credits_earned + 1,
               updated_at = excluded.updated_at`
          )
          .bind(`${installationId}_${targetDate}`, installationId, targetDate, nowIso)
          .run();
      }
    } catch (err) {
      console.warn('Credit refund failed (non-fatal):', err);
    }
  }

  async grantBonusCredits(installationId: string, credits: number): Promise<void> {
    if (credits <= 0) return;
    const today = this.getTodayUtcString();
    const nowIso = new Date().toISOString();
    if (!this.db) {
      pruneMemoryUsageStore(today);
      let entry = memoryUsageStore.get(installationId);
      if (!entry || entry.date !== today) {
        entry = { date: today, freeUsed: 0, rewardedEarned: 0, rewardedAdsWatched: 0 };
        memoryUsageStore.set(installationId, entry);
      }
      entry.rewardedEarned += credits;
      return;
    }

    await this.db
      .prepare(
        `INSERT INTO daily_usage (id, installation_id, usage_date, rewarded_credits_earned, updated_at)
         VALUES (?, ?, ?, ?, ?)
         ON CONFLICT(installation_id, usage_date) DO UPDATE SET
           rewarded_credits_earned = rewarded_credits_earned + excluded.rewarded_credits_earned,
           updated_at = excluded.updated_at`
      )
      .bind(`${installationId}_${today}`, installationId, today, credits, nowIso)
      .run();
  }

  async createAdNonce(installationId: string): Promise<string> {
    const nonce = `nonce_${Date.now()}_${Math.random().toString(36).substring(2, 12)}`;
    const now = new Date();
    const expiresAt = new Date(now.getTime() + 10 * 60 * 1000);

    if (this.db) {
      await this.db
        .prepare(
          `INSERT INTO installations (id, created_at, last_active_at)
           VALUES (?, ?, ?)
           ON CONFLICT(id) DO UPDATE SET last_active_at = excluded.last_active_at`
        )
        .bind(installationId, now.toISOString(), now.toISOString())
        .run();

      await this.db
        .prepare(
          `INSERT INTO ad_nonces (nonce, installation_id, created_at, expires_at)
           VALUES (?, ?, ?, ?)`
        )
        .bind(nonce, installationId, now.toISOString(), expiresAt.toISOString())
        .run();
    }

    return nonce;
  }

  // Verified AdMob SSV Reward Granting (only persists transaction & consumes nonce when credit slot succeeds)
  async recordSsvReward(params: {
    installationId: string;
    transactionId: string;
    rewardId?: string;
    keyId: number;
    adNetwork?: string;
    nonce?: string;
  }): Promise<{ success: boolean; reason?: string }> {
    if (this.maxDailyRewards <= 0) {
      return { success: false, reason: 'DAILY_REWARD_LIMIT_REACHED' };
    }

    if (!this.db) {
      const today = this.getTodayUtcString();
      pruneMemoryUsageStore(today);
      let entry = memoryUsageStore.get(params.installationId);
      if (!entry || entry.date !== today) {
        entry = { date: today, freeUsed: 0, rewardedEarned: 0, rewardedAdsWatched: 0 };
        memoryUsageStore.set(params.installationId, entry);
      }
      if (entry.rewardedAdsWatched >= this.maxDailyRewards) {
        return { success: false, reason: 'DAILY_REWARD_LIMIT_REACHED' };
      }
      entry.rewardedAdsWatched += 1;
      entry.rewardedEarned += this.creditsPerReward;
      return { success: true };
    }

    const { installationId, transactionId, rewardId, keyId, adNetwork, nonce } = params;
    const today = this.getTodayUtcString();
    const nowIso = new Date().toISOString();

    // 1. Check transaction_id or reward_id idempotency before touching nonces or daily caps
    const existingTx = await this.db
      .prepare(
        `SELECT transaction_id FROM admob_ssv_transactions
         WHERE transaction_id = ? OR (installation_id = ? AND ? IS NOT NULL AND reward_id = ?)`
      )
      .bind(transactionId, installationId, rewardId || null, rewardId || null)
      .first<{ transaction_id: string }>();

    if (existingTx) {
      return { success: false, reason: 'DUPLICATE_TRANSACTION' };
    }

    // 2. Enforce cap early
    const quota = await this.getQuotaStatus(installationId);
    if (quota.rewarded_ads_watched_today >= this.maxDailyRewards) {
      return { success: false, reason: 'DAILY_REWARD_LIMIT_REACHED' };
    }

    // 3. Verify & consume nonce before granting
    if (nonce) {
      const consumeRes = await this.db
        .prepare(
          `UPDATE ad_nonces
           SET used_at = ?
           WHERE nonce = ? AND installation_id = ? AND used_at IS NULL AND expires_at >= ?`
        )
        .bind(nowIso, nonce, installationId, nowIso)
        .run();

      if ((consumeRes.meta?.changes ?? 0) === 0) {
        return { success: false, reason: 'INVALID_OR_EXPIRED_NONCE' };
      }
    }

    // 4. Atomically reserve daily ad reward slot BEFORE persisting SSV transaction
    const creditRes = await this.db
      .prepare(
        `INSERT INTO daily_usage (id, installation_id, usage_date, rewarded_credits_earned, rewarded_ads_watched, updated_at)
         VALUES (?, ?, ?, ?, 1, ?)
         ON CONFLICT(installation_id, usage_date) DO UPDATE SET
           rewarded_credits_earned = rewarded_credits_earned + excluded.rewarded_credits_earned,
           rewarded_ads_watched = rewarded_ads_watched + 1,
           updated_at = excluded.updated_at
         WHERE daily_usage.rewarded_ads_watched < ?`
      )
      .bind(`${installationId}_${today}`, installationId, today, this.creditsPerReward, nowIso, this.maxDailyRewards)
      .run();

    if ((creditRes.meta?.changes ?? 0) === 0) {
      if (nonce) {
        await this.db
          .prepare('UPDATE ad_nonces SET used_at = NULL WHERE nonce = ? AND installation_id = ?')
          .bind(nonce, installationId)
          .run()
          .catch(() => {});
      }
      return { success: false, reason: 'DAILY_REWARD_LIMIT_REACHED' };
    }

    // 5. Persist SSV transaction; roll back daily reward increment if concurrent duplicate wins PK/unique constraint
    try {
      await this.db
        .prepare(
          `INSERT INTO admob_ssv_transactions (transaction_id, installation_id, reward_id, key_id, verified_at, ad_network)
           VALUES (?, ?, ?, ?, ?, ?)`
        )
        .bind(transactionId, installationId, rewardId || null, keyId, nowIso, adNetwork || 'admob')
        .run();
    } catch {
      await this.db
        .prepare(
          `UPDATE daily_usage
           SET rewarded_credits_earned = MAX(0, rewarded_credits_earned - ?),
               rewarded_ads_watched = MAX(0, rewarded_ads_watched - 1),
               updated_at = ?
           WHERE installation_id = ? AND usage_date = ?`
        )
        .bind(this.creditsPerReward, nowIso, installationId, today)
        .run()
        .catch(() => {});
      return { success: false, reason: 'DUPLICATE_TRANSACTION' };
    }

    return { success: true };
  }

  /**
   * Records a Google-verified entitlement while protecting active Lifetime passes
   * from having their `pro_expires_at = NULL` overwritten by an older timed sub.
   */
  async activatePro(
    installationId: string,
    productId: string,
    purchaseToken: string,
    orderId: string | null,
    expiresAt: string | null,
    status: 'ACTIVE' | 'IN_GRACE_PERIOD' | 'CANCELED' = 'ACTIVE'
  ): Promise<void> {
    if (!this.db) return;

    const nowIso = new Date().toISOString();

    const previous = await this.db
      .prepare('SELECT installation_id FROM subscription_entitlements WHERE purchase_token = ?')
      .bind(purchaseToken)
      .first<{ installation_id: string }>();

    const existingLifetime = await this.db
      .prepare(
        `SELECT id FROM subscription_entitlements
         WHERE installation_id = ?
           AND (product_id IN ('vibekit_pro_lifetime', 'vibekit_lifetime') OR expires_at IS NULL)
           AND status NOT IN ('REVOKED', 'EXPIRED', 'ON_HOLD', 'PAUSED')
         LIMIT 1`
      )
      .bind(installationId)
      .first<{ id: string }>();

    const isLifetimePurchase =
      expiresAt === null || productId === 'vibekit_pro_lifetime' || productId === 'vibekit_lifetime';
    const effectiveExpiresAt = existingLifetime || isLifetimePurchase ? null : expiresAt;

    await this.db
      .prepare(
        `INSERT INTO installations (id, created_at, last_active_at, is_pro, pro_expires_at)
         VALUES (?, ?, ?, 1, ?)
         ON CONFLICT(id) DO UPDATE SET
           is_pro = 1,
           pro_expires_at = CASE WHEN excluded.pro_expires_at IS NULL THEN NULL ELSE COALESCE(excluded.pro_expires_at, installations.pro_expires_at) END,
           last_active_at = excluded.last_active_at`
      )
      .bind(installationId, nowIso, nowIso, effectiveExpiresAt)
      .run();

    await this.db
      .prepare(
        `INSERT INTO subscription_entitlements (id, installation_id, product_id, purchase_token, order_id, status, verified_at, expires_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)
         ON CONFLICT(purchase_token) DO UPDATE SET
           installation_id = excluded.installation_id,
           product_id = excluded.product_id,
           order_id = COALESCE(excluded.order_id, order_id),
           status = excluded.status,
           expires_at = excluded.expires_at,
           verified_at = excluded.verified_at`
      )
      .bind(
        `sub_${Date.now()}_${Math.random().toString(36).substring(7)}`,
        installationId,
        productId,
        purchaseToken,
        orderId,
        status,
        nowIso,
        expiresAt
      )
      .run();

    if (previous && previous.installation_id !== installationId) {
      await this.db
        .prepare(
          `UPDATE installations SET is_pro = 0
           WHERE id = ? AND NOT EXISTS (
             SELECT 1 FROM subscription_entitlements
             WHERE installation_id = ?
               AND status NOT IN ('REVOKED', 'EXPIRED', 'ON_HOLD', 'PAUSED')
               AND (
                 product_id IN ('vibekit_pro_lifetime', 'vibekit_lifetime')
                 OR expires_at IS NULL
                 OR expires_at > ?
               )
           )`
        )
        .bind(previous.installation_id, previous.installation_id, nowIso)
        .run();
    }
  }

  async handleSubscriptionLifecycleUpdate(params: {
    purchaseToken: string;
    status: 'ACTIVE' | 'IN_GRACE_PERIOD' | 'ON_HOLD' | 'PAUSED' | 'CANCELED' | 'EXPIRED' | 'REVOKED';
    expiresAt?: string;
  }): Promise<void> {
    if (!this.db) return;

    const sub = await this.db
      .prepare('SELECT installation_id, product_id FROM subscription_entitlements WHERE purchase_token = ?')
      .bind(params.purchaseToken)
      .first<{ installation_id: string; product_id: string }>();

    if (!sub) return;

    const isPro =
      params.status === 'ACTIVE' || params.status === 'IN_GRACE_PERIOD' || params.status === 'CANCELED';

    await this.db
      .prepare(
        `UPDATE subscription_entitlements
         SET status = ?, expires_at = COALESCE(?, expires_at)
         WHERE purchase_token = ?`
      )
      .bind(params.status, params.expiresAt || null, params.purchaseToken)
      .run();

    if (isPro) {
      const activeLifetime = await this.db
        .prepare(
          `SELECT id FROM subscription_entitlements
           WHERE installation_id = ?
             AND (product_id IN ('vibekit_pro_lifetime', 'vibekit_lifetime') OR expires_at IS NULL)
             AND status NOT IN ('REVOKED', 'EXPIRED', 'ON_HOLD', 'PAUSED')
           LIMIT 1`
        )
        .bind(sub.installation_id)
        .first<{ id: string }>();

      const nextExpires = activeLifetime ? null : params.expiresAt || null;
      await this.db
        .prepare(
          `UPDATE installations
           SET is_pro = 1,
               pro_expires_at = CASE WHEN ? IS NOT NULL THEN pro_expires_at ELSE COALESCE(?, pro_expires_at) END
           WHERE id = ?`
        )
        .bind(activeLifetime ? 1 : null, nextExpires, sub.installation_id)
        .run();
    } else {
      await this.db
        .prepare(
          `UPDATE installations SET is_pro = 0
           WHERE id = ? AND NOT EXISTS (
             SELECT 1 FROM subscription_entitlements
             WHERE installation_id = ?
               AND purchase_token != ?
               AND status NOT IN ('REVOKED', 'EXPIRED', 'ON_HOLD', 'PAUSED')
               AND (
                 product_id IN ('vibekit_pro_lifetime', 'vibekit_lifetime')
                 OR expires_at IS NULL
                 OR expires_at > ?
               )
           )`
        )
        .bind(sub.installation_id, sub.installation_id, params.purchaseToken, new Date().toISOString())
        .run();
    }
  }

  async deleteUserData(installationId: string): Promise<void> {
    memoryUsageStore.delete(installationId);
    if (!this.db) return;
    await this.db.batch([
      this.db.prepare('DELETE FROM idempotency_keys WHERE installation_id = ?').bind(installationId),
      this.db.prepare('DELETE FROM pro_cycle_usage WHERE installation_id = ?').bind(installationId),
      this.db.prepare('DELETE FROM admob_ssv_transactions WHERE installation_id = ?').bind(installationId),
      this.db.prepare('DELETE FROM ad_nonces WHERE installation_id = ?').bind(installationId),
      this.db.prepare('DELETE FROM daily_usage WHERE installation_id = ?').bind(installationId),
      this.db.prepare('DELETE FROM generation_metadata WHERE installation_id = ?').bind(installationId),
      this.db.prepare('DELETE FROM reward_events WHERE installation_id = ?').bind(installationId),
      this.db.prepare('DELETE FROM subscription_entitlements WHERE installation_id = ?').bind(installationId),
      this.db.prepare('DELETE FROM credit_pack_purchases WHERE installation_id = ?').bind(installationId),
      this.db.prepare('DELETE FROM streaks WHERE installation_id = ?').bind(installationId),
      this.db.prepare('DELETE FROM xp_events WHERE installation_id = ?').bind(installationId),
      this.db.prepare('DELETE FROM milestone_claims WHERE installation_id = ?').bind(installationId),
      this.db
        .prepare('DELETE FROM referrals WHERE referrer_installation_id = ? OR referred_installation_id = ?')
        .bind(installationId, installationId),
      this.db.prepare('DELETE FROM feedback_records WHERE installation_id = ?').bind(installationId),
      this.db.prepare('DELETE FROM installations WHERE id = ?').bind(installationId),
    ]);
  }

  async reconcileEntitlementsNightly(): Promise<{ checked: number; expired: number }> {
    if (!this.db) return { checked: 0, expired: 0 };

    const rows = await this.db
      .prepare(
        `SELECT id, installation_id, product_id, purchase_token, status, expires_at
         FROM subscription_entitlements
         WHERE status IN ('ACTIVE', 'IN_GRACE_PERIOD', 'CANCELED')
           AND expires_at IS NOT NULL
           AND product_id NOT IN ('vibekit_pro_lifetime', 'vibekit_lifetime')`
      )
      .all<{
        id: string;
        installation_id: string;
        product_id: string;
        purchase_token: string;
        status: string;
        expires_at: string | null;
      }>();

    const activeList = rows.results ?? [];
    let expiredCount = 0;

    for (const sub of activeList) {
      if (sub.expires_at && new Date(sub.expires_at) < new Date()) {
        await this.handleSubscriptionLifecycleUpdate({
          purchaseToken: sub.purchase_token,
          status: 'EXPIRED',
          expiresAt: sub.expires_at,
        });
        expiredCount++;
      }
    }

    return { checked: activeList.length, expired: expiredCount };
  }
}
