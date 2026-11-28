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

  async getOrCreateReferralCode(installationId: string): Promise<string> {
    const existing = await this.db
      .prepare('SELECT referral_code FROM installations WHERE id = ?')
      .bind(installationId)
      .first<{ referral_code?: string | null }>();

    if (existing?.referral_code) {
      return existing.referral_code;
    }

    const randomCode = `RV${crypto.randomUUID().replace(/-/g, '').slice(0, 10).toUpperCase()}`;
    const now = new Date().toISOString();

    await this.db
      .prepare(
        `INSERT INTO installations (id, created_at, last_active_at, referral_code)
         VALUES (?, ?, ?, ?)
         ON CONFLICT(id) DO UPDATE SET
           referral_code = COALESCE(installations.referral_code, excluded.referral_code)`
      )
      .bind(installationId, now, now, randomCode)
      .run();

    const refreshed = await this.db
      .prepare('SELECT referral_code FROM installations WHERE id = ?')
      .bind(installationId)
      .first<{ referral_code?: string | null }>();

    return refreshed?.referral_code || randomCode;
  }

  async resolveReferrerInstallationId(referrerCode: string): Promise<string | null> {
    if (!referrerCode || referrerCode === 'anonymous_default') return null;
    const res = await this.db
      .prepare('SELECT id FROM installations WHERE referral_code = ? OR id = ? LIMIT 1')
      .bind(referrerCode, referrerCode)
      .first<{ id: string }>();
    return res?.id ?? null;
  }

  async isReferrerValid(referrerCode: string): Promise<boolean> {
    return (await this.resolveReferrerInstallationId(referrerCode)) !== null;
  }

  async hasReferredInstallationClaimed(referredInstallationId: string): Promise<boolean> {
    const res = await this.db
      .prepare('SELECT id FROM referrals WHERE referred_installation_id = ?')
      .bind(referredInstallationId)
      .first<{ id: string }>();
    return !!res;
  }

  async getRewardedReferralsCount(referrerInstallationId: string): Promise<number> {
    const res = await this.db
      .prepare(
        "SELECT COUNT(*) as count FROM referrals WHERE referrer_installation_id = ? AND status = 'REWARDED'"
      )
      .bind(referrerInstallationId)
      .first<{ count: number }>();
    return res?.count ?? 0;
  }

  async recordReferralAndAwardCredits(
    referrerInstallationId: string,
    referredInstallationId: string,
    creditsToAward = 2
  ): Promise<'rewarded' | 'already_claimed' | 'limit_reached'> {
    const referralId = `ref_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
    const now = new Date().toISOString();
    const today = now.slice(0, 10);

    try {
      // Ensure referred installation exists before FK insert
      await this.db
        .prepare(
          `INSERT INTO installations (id, created_at, last_active_at)
           VALUES (?, ?, ?)
           ON CONFLICT(id) DO UPDATE SET last_active_at = excluded.last_active_at`
        )
        .bind(referredInstallationId, now, now)
        .run();

      // Enforce 10-referral cap atomically at SQL INSERT time
      const insertRefRes = await this.db
        .prepare(
          `INSERT INTO referrals (id, referrer_installation_id, referred_installation_id, credits_awarded, status, created_at)
           SELECT ?, ?, ?, ?, 'REWARDED', ?
           WHERE (SELECT COUNT(*) FROM referrals WHERE referrer_installation_id = ? AND status = 'REWARDED') < 10`
        )
        .bind(
          referralId,
          referrerInstallationId,
          referredInstallationId,
          creditsToAward,
          now,
          referrerInstallationId
        )
        .run();

      if ((insertRefRes.meta?.changes ?? 0) === 0) {
        return 'limit_reached';
      }

      await this.db.batch([
        this.db
          .prepare(
            `INSERT INTO daily_usage (id, installation_id, usage_date, free_credits_used, rewarded_credits_earned, updated_at)
             VALUES (?, ?, ?, 0, ?, ?)
             ON CONFLICT(installation_id, usage_date) DO UPDATE SET
               rewarded_credits_earned = rewarded_credits_earned + excluded.rewarded_credits_earned,
               updated_at = excluded.updated_at`
          )
          .bind(`${referredInstallationId}_${today}`, referredInstallationId, today, creditsToAward, now),

        this.db
          .prepare(
            `INSERT INTO daily_usage (id, installation_id, usage_date, free_credits_used, rewarded_credits_earned, updated_at)
             VALUES (?, ?, ?, 0, ?, ?)
             ON CONFLICT(installation_id, usage_date) DO UPDATE SET
               rewarded_credits_earned = rewarded_credits_earned + excluded.rewarded_credits_earned,
               updated_at = excluded.updated_at`
          )
          .bind(`${referrerInstallationId}_${today}`, referrerInstallationId, today, creditsToAward, now),
      ]);

      return 'rewarded';
    } catch (err: any) {
      const msg = String(err?.message || err).toLowerCase();
      if (msg.includes('unique') || msg.includes('constraint')) {
        return 'already_claimed';
      }
      throw err;
    }
  }
}
