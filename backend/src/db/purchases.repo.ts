export interface CreditPackRecord {
  order_id: string;
  installation_id: string;
  product_id: string;
  credits_granted: number;
  purchase_token: string;
  revoked_at?: string | null;
}

export class PurchasesRepository {
  constructor(private readonly db: D1Database) {}

  async isRtdnEventOutdated(purchaseToken: string, eventTimeMillis: number): Promise<boolean> {
    const newer = await this.db
      .prepare('SELECT event_time_millis FROM rtdn_event_log WHERE purchase_token = ? AND event_time_millis > ?')
      .bind(purchaseToken, eventTimeMillis)
      .first<{ event_time_millis: number }>();
    return !!newer;
  }

  /**
   * Inserts RTDN event_id idempotently; returns false when the exact messageId was already processed.
   */
  async recordRtdnEvent(params: {
    eventId: string;
    purchaseToken: string;
    notificationType: number;
    eventTimeMillis: number;
    status: string;
  }): Promise<boolean> {
    const res = await this.db
      .prepare(
        `INSERT INTO rtdn_event_log (event_id, purchase_token, notification_type, event_time_millis, status, processed_at)
         VALUES (?, ?, ?, ?, ?, ?)
         ON CONFLICT(event_id) DO NOTHING`
      )
      .bind(
        params.eventId,
        params.purchaseToken,
        params.notificationType,
        params.eventTimeMillis,
        params.status,
        new Date().toISOString()
      )
      .run();
    return (res.meta?.changes ?? 1) > 0;
  }

  async isCreditPackProcessed(orderId: string, purchaseToken: string): Promise<boolean> {
    const existing = await this.db
      .prepare('SELECT order_id FROM credit_pack_purchases WHERE order_id = ? OR purchase_token = ?')
      .bind(orderId, purchaseToken)
      .first();
    return !!existing;
  }

  async findCreditPackByToken(purchaseToken: string): Promise<CreditPackRecord | null> {
    return await this.db
      .prepare(
        'SELECT order_id, installation_id, product_id, credits_granted, purchase_token, revoked_at FROM credit_pack_purchases WHERE purchase_token = ?'
      )
      .bind(purchaseToken)
      .first<CreditPackRecord>();
  }

  async revokeCreditPackAndClawBack(pack: CreditPackRecord): Promise<boolean> {
    if (pack.revoked_at) return false;
    const now = new Date().toISOString();

    const markRes = await this.db
      .prepare('UPDATE credit_pack_purchases SET revoked_at = ? WHERE order_id = ? AND revoked_at IS NULL')
      .bind(now, pack.order_id)
      .run();

    if ((markRes.meta?.changes ?? 0) === 0) return false;

    let remainingToClawBack = pack.credits_granted;
    const usageRows = await this.db
      .prepare(
        `SELECT id, rewarded_credits_earned
         FROM daily_usage
         WHERE installation_id = ? AND rewarded_credits_earned > 0
         ORDER BY usage_date DESC`
      )
      .bind(pack.installation_id)
      .all<{ id: string; rewarded_credits_earned: number }>();

    for (const row of usageRows.results ?? []) {
      if (remainingToClawBack <= 0) break;
      const deduct = Math.min(remainingToClawBack, row.rewarded_credits_earned);
      await this.db
        .prepare(
          'UPDATE daily_usage SET rewarded_credits_earned = MAX(0, rewarded_credits_earned - ?), updated_at = ? WHERE id = ?'
        )
        .bind(deduct, now, row.id)
        .run();
      remainingToClawBack -= deduct;
    }

    return true;
  }

  async recordCreditPackAndGrantCredits(params: {
    orderId: string;
    installationId: string;
    productId: string;
    creditsGranted: number;
    purchaseToken: string;
  }): Promise<'granted' | 'already_processed'> {
    const now = new Date().toISOString();
    const today = now.slice(0, 10);

    try {
      await this.db.batch([
        this.db
          .prepare(
            `INSERT INTO installations (id, created_at, last_active_at)
             VALUES (?, ?, ?)
             ON CONFLICT(id) DO UPDATE SET last_active_at = excluded.last_active_at`
          )
          .bind(params.installationId, now, now),

        this.db
          .prepare(
            `INSERT INTO credit_pack_purchases (order_id, installation_id, product_id, credits_granted, purchase_token, purchased_at)
             VALUES (?, ?, ?, ?, ?, ?)`
          )
          .bind(
            params.orderId,
            params.installationId,
            params.productId,
            params.creditsGranted,
            params.purchaseToken,
            now
          ),

        this.db
          .prepare(
            `INSERT INTO daily_usage (id, installation_id, usage_date, free_credits_used, rewarded_credits_earned, updated_at)
             VALUES (?, ?, ?, 0, ?, ?)
             ON CONFLICT(installation_id, usage_date) DO UPDATE SET
               rewarded_credits_earned = rewarded_credits_earned + excluded.rewarded_credits_earned,
               updated_at = excluded.updated_at`
          )
          .bind(
            `${params.installationId}_${today}`,
            params.installationId,
            today,
            params.creditsGranted,
            now
          ),
      ]);
      return 'granted';
    } catch (err: any) {
      const msg = String(err?.message || err).toLowerCase();
      if (msg.includes('unique') || msg.includes('constraint')) {
        return 'already_processed';
      }
      throw err;
    }
  }
}
