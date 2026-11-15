export class AdsRepository {
  constructor(private readonly db: D1Database) {}

  async isTransactionRecorded(
    installationId: string,
    transactionId?: string,
    rewardId?: string,
    nonce?: string
  ): Promise<boolean> {
    if (!transactionId && !rewardId && !nonce) return false;

    // 1. If nonce provided, check if it was marked used by the SSV callback
    if (nonce) {
      const consumedNonce = await this.db
        .prepare('SELECT nonce FROM ad_nonces WHERE nonce = ? AND installation_id = ? AND used_at IS NOT NULL')
        .bind(nonce, installationId)
        .first();
      if (consumedNonce) return true;
    }

    // 2. Check if transaction_id or reward_id is recorded in admob_ssv_transactions
    if (transactionId || rewardId) {
      const tx = await this.db
        .prepare(
          'SELECT transaction_id FROM admob_ssv_transactions WHERE installation_id = ? AND ((? != \'\' AND transaction_id = ?) OR (? != \'\' AND reward_id = ?))'
        )
        .bind(installationId, transactionId || '', transactionId || '', rewardId || '', rewardId || '')
        .first();
      if (tx) return true;
    }

    return false;
  }

  async recordSsvTransaction(params: {
    transactionId: string;
    installationId: string;
    rewardId?: string;
    keyId: number;
    adNetwork?: string;
  }): Promise<void> {
    const nowIso = new Date().toISOString();
    await this.db
      .prepare(
        `INSERT INTO admob_ssv_transactions (transaction_id, installation_id, reward_id, key_id, verified_at, ad_network)
         VALUES (?, ?, ?, ?, ?, ?)`
      )
      .bind(
        params.transactionId,
        params.installationId,
        params.rewardId || null,
        params.keyId,
        nowIso,
        params.adNetwork || 'admob'
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
