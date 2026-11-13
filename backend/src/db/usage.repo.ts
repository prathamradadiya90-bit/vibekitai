export interface DailyUsageRecord {
  id: string;
  installation_id: string;
  usage_date: string;
  free_credits_used: number;
  rewarded_credits_earned: number;
  rewarded_ads_watched: number;
  pro_credits_used: number;
  updated_at: string;
}

export class UsageRepository {
  constructor(private db?: D1Database) {}

  async getDailyUsage(installationId: string, usageDate: string): Promise<DailyUsageRecord | null> {
    if (!this.db) return null;
    return this.db
      .prepare(
        'SELECT id, installation_id, usage_date, free_credits_used, rewarded_credits_earned, rewarded_ads_watched, pro_credits_used, updated_at FROM daily_usage WHERE installation_id = ? AND usage_date = ?'
      )
      .bind(installationId, usageDate)
      .first<DailyUsageRecord>();
  }

  async getRewardedCreditsBalance(installationId: string): Promise<number> {
    if (!this.db) return 0;
    const row = await this.db
      .prepare('SELECT COALESCE(SUM(rewarded_credits_earned), 0) AS balance FROM daily_usage WHERE installation_id = ?')
      .bind(installationId)
      .first<{ balance: number }>();
    return Math.max(0, row?.balance ?? 0);
  }

  async deductFreeCreditAtomic(
    installationId: string,
    usageDate: string,
    maxDailyFree: number
  ): Promise<boolean> {
    if (!this.db) return true;
    const nowIso = new Date().toISOString();
    const id = `${installationId}_${usageDate}`;

    // First attempt update if row exists with guard
    const updateResult = await this.db
      .prepare(
        `UPDATE daily_usage
         SET free_credits_used = free_credits_used + 1, updated_at = ?
         WHERE installation_id = ? AND usage_date = ? AND free_credits_used < ?`
      )
      .bind(nowIso, installationId, usageDate, maxDailyFree)
      .run();

    if ((updateResult.meta.changes ?? 0) > 0) {
      return true;
    }

    // If no row updated, try inserting the first usage if below maxDailyFree
    if (maxDailyFree > 0) {
      try {
        const insertResult = await this.db
          .prepare(
            `INSERT INTO daily_usage (id, installation_id, usage_date, free_credits_used, updated_at)
             VALUES (?, ?, ?, 1, ?)
             ON CONFLICT(installation_id, usage_date) DO UPDATE SET
               free_credits_used = daily_usage.free_credits_used + 1,
               updated_at = excluded.updated_at
             WHERE daily_usage.free_credits_used < ?`
          )
          .bind(id, installationId, usageDate, nowIso, maxDailyFree)
          .run();

        return (insertResult.meta.changes ?? 0) > 0;
      } catch {
        return false;
      }
    }

    return false;
  }

  async deductRewardedCreditAtomic(installationId: string): Promise<boolean> {
    if (!this.db) return true;
    const nowIso = new Date().toISOString();

    const result = await this.db
      .prepare(
        `UPDATE daily_usage
         SET rewarded_credits_earned = rewarded_credits_earned - 1, updated_at = ?
         WHERE id = (
           SELECT id FROM daily_usage
           WHERE installation_id = ? AND rewarded_credits_earned > 0
           ORDER BY usage_date DESC LIMIT 1
         )`
      )
      .bind(nowIso, installationId, installationId)
      .run();

    return (result.meta.changes ?? 0) > 0;
  }

  async deductProCreditAtomic(
    installationId: string,
    maxProCredits: number
  ): Promise<boolean> {
    if (!this.db) return true;
    const nowIso = new Date().toISOString();
    const today = nowIso.split('T')[0] ?? '';

    const updateResult = await this.db
      .prepare(
        `UPDATE pro_cycle_usage
         SET credits_used = credits_used + 1, updated_at = ?
         WHERE id = (
           SELECT id FROM pro_cycle_usage
           WHERE installation_id = ? AND cycle_end > ? AND credits_used < ?
           ORDER BY cycle_end DESC LIMIT 1
         )`
      )
      .bind(nowIso, installationId, nowIso, maxProCredits)
      .run();

    if ((updateResult.meta.changes ?? 0) > 0) {
      // Record analytics row via batch or upsert
      await this.db
        .prepare(
          `INSERT INTO daily_usage (id, installation_id, usage_date, pro_credits_used, updated_at)
           VALUES (?, ?, ?, 1, ?)
           ON CONFLICT(installation_id, usage_date) DO UPDATE SET
             pro_credits_used = daily_usage.pro_credits_used + 1,
             updated_at = excluded.updated_at`
        )
        .bind(`${installationId}_${today}`, installationId, today, nowIso)
        .run();

      return true;
    }

    return false;
  }
}
