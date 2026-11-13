export class PurchasesRepository {
  constructor(private readonly db: D1Database) {}

  async isRtdnEventOutdated(purchaseToken: string, eventTimeMillis: number): Promise<boolean> {
    const newer = await this.db
      .prepare('SELECT event_time_millis FROM rtdn_event_log WHERE purchase_token = ? AND event_time_millis > ?')
      .bind(purchaseToken, eventTimeMillis)
      .first<{ event_time_millis: number }>();
    return !!newer;
  }

  async recordRtdnEvent(params: {
    eventId: string;
    purchaseToken: string;
    notificationType: number;
    eventTimeMillis: number;
    status: string;
  }): Promise<void> {
    await this.db
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
  }

  async isCreditPackProcessed(orderId: string, purchaseToken: string): Promise<boolean> {
    const existing = await this.db
      .prepare('SELECT order_id FROM credit_pack_purchases WHERE order_id = ? OR purchase_token = ?')
      .bind(orderId, purchaseToken)
      .first();
    return !!existing;
  }

  async recordCreditPackAndGrantCredits(params: {
    orderId: string;
    installationId: string;
    productId: string;
    creditsGranted: number;
    purchaseToken: string;
  }): Promise<void> {
    const now = new Date().toISOString();
    const today = now.slice(0, 10);

    await this.db.batch([
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
  }
}
