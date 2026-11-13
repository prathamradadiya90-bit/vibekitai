export interface ReferralRecord {
  id: string;
  referrer_installation_id: string;
  referred_installation_id: string;
  credits_awarded: number;
  status: string;
  created_at: string;
}

export class ReferralsRepository {
  constructor(private readonly db: D1Database) {}

  async isReferrerValid(referrerCode: string): Promise<boolean> {
    const res = await this.db
      .prepare('SELECT id FROM installations WHERE id = ?')
      .bind(referrerCode)
      .first<{ id: string }>();
    return !!res;
  }

  async hasReferredInstallationClaimed(referredInstallationId: string): Promise<boolean> {
    const res = await this.db
      .prepare('SELECT id FROM referrals WHERE referred_installation_id = ?')
      .bind(referredInstallationId)
      .first<{ id: string }>();
    return !!res;
  }

  async getRewardedReferralsCount(referrerCode: string): Promise<number> {
    const res = await this.db
      .prepare(
        "SELECT COUNT(*) as count FROM referrals WHERE referrer_installation_id = ? AND status = 'REWARDED'"
      )
      .bind(referrerCode)
      .first<{ count: number }>();
    return res?.count ?? 0;
  }

  async recordReferralAndAwardCredits(
    referrerCode: string,
    referredInstallationId: string,
    creditsToAward = 2
  ): Promise<void> {
    const referralId = `ref_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
    const now = new Date().toISOString();
    const today = now.slice(0, 10);

    await this.db.batch([
      // 1. Insert referral record
      this.db
        .prepare(
          `INSERT INTO referrals (id, referrer_installation_id, referred_installation_id, credits_awarded, status, created_at)
           VALUES (?, ?, ?, ?, 'REWARDED', ?)`
        )
        .bind(referralId, referrerCode, referredInstallationId, creditsToAward, now),

      // 2. Credit referred user
      this.db
        .prepare(
          `INSERT INTO daily_usage (id, installation_id, usage_date, free_credits_used, rewarded_credits_earned, updated_at)
           VALUES (?, ?, ?, 0, ?, ?)
           ON CONFLICT(installation_id, usage_date) DO UPDATE SET
             rewarded_credits_earned = rewarded_credits_earned + excluded.rewarded_credits_earned,
             updated_at = excluded.updated_at`
        )
        .bind(`${referredInstallationId}_${today}`, referredInstallationId, today, creditsToAward, now),

      // 3. Credit referrer
      this.db
        .prepare(
          `INSERT INTO daily_usage (id, installation_id, usage_date, free_credits_used, rewarded_credits_earned, updated_at)
           VALUES (?, ?, ?, 0, ?, ?)
           ON CONFLICT(installation_id, usage_date) DO UPDATE SET
             rewarded_credits_earned = rewarded_credits_earned + excluded.rewarded_credits_earned,
             updated_at = excluded.updated_at`
        )
        .bind(`${referrerCode}_${today}`, referrerCode, today, creditsToAward, now),
    ]);
  }
}
