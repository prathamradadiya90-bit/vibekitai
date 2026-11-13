export class AdsRepository {
  constructor(private readonly db: D1Database) {}

  async isTransactionRecorded(
    installationId: string,
    transactionId?: string,
    rewardId?: string
  ): Promise<boolean> {
    if (!transactionId && !rewardId) return false;

    const tx = await this.db
      .prepare(
        'SELECT transaction_id FROM admob_ssv_transactions WHERE installation_id = ? AND (transaction_id = ? OR reward_id = ?)'
      )
      .bind(installationId, transactionId || '', rewardId || '')
      .first();

    return tx !== null;
  }

  async recordSsvTransaction(params: {
    transactionId: string;
    installationId: string;
    rewardAmount: number;
    rawQuery: string;
    customData: string;
  }): Promise<void> {
    const nowIso = new Date().toISOString();
    await this.db
      .prepare(
        `INSERT INTO admob_ssv_transactions (transaction_id, installation_id, reward_amount, raw_query, custom_data, verified_at)
         VALUES (?, ?, ?, ?, ?, ?)`
      )
      .bind(
        params.transactionId,
        params.installationId,
        params.rewardAmount,
        params.rawQuery,
        params.customData,
        nowIso
      )
      .run();
  }

  async createNonce(nonce: string, installationId: string, expiresAt: string): Promise<void> {
    const nowIso = new Date().toISOString();
    await this.db
      .prepare(
        `INSERT INTO ad_nonces (nonce, installation_id, created_at, expires_at)
         VALUES (?, ?, ?, ?)`
      )
      .bind(nonce, installationId, nowIso, expiresAt)
      .run();
  }

  async validateAndConsumeNonce(nonce: string, installationId: string): Promise<boolean> {
    const nowIso = new Date().toISOString();
    const existing = await this.db
      .prepare(
        'SELECT nonce FROM ad_nonces WHERE nonce = ? AND installation_id = ? AND expires_at > ?'
      )
      .bind(nonce, installationId, nowIso)
      .first();

    if (!existing) return false;

    // Immediately purge or consume to prevent replay
    await this.db
      .prepare('DELETE FROM ad_nonces WHERE nonce = ?')
      .bind(nonce)
      .run();

    return true;
  }
}
