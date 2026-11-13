export interface IdempotencyRecord {
  idempotency_key: string;
  installation_id: string;
  endpoint: string;
  request_hash: string;
  response_json: string;
  status_code: number;
  created_at: string;
  expires_at: string;
}

export class IdempotencyRepository {
  constructor(private db: D1Database) {}

  public async getValidResponse(
    key: string,
    installationId: string,
    endpoint: string
  ): Promise<{ statusCode: number; data: unknown } | null> {
    const now = new Date().toISOString();
    const row = await this.db
      .prepare(
        `SELECT response_json, status_code
         FROM idempotency_keys
         WHERE idempotency_key = ? AND installation_id = ? AND endpoint = ? AND expires_at > ?`
      )
      .bind(key, installationId, endpoint, now)
      .first<{ response_json: string; status_code: number }>();

    if (!row) return null;

    try {
      return {
        statusCode: row.status_code,
        data: JSON.parse(row.response_json),
      };
    } catch {
      return null;
    }
  }

  public async storeResponse(params: {
    key: string;
    installationId: string;
    endpoint: string;
    requestHash: string;
    responseJson: string;
    statusCode: number;
    ttlHours?: number;
  }): Promise<void> {
    const now = new Date();
    const ttl = params.ttlHours ?? 24;
    const expiresAt = new Date(now.getTime() + ttl * 3600 * 1000).toISOString();

    await this.db
      .prepare(
        `INSERT INTO idempotency_keys (
           idempotency_key, installation_id, endpoint, request_hash, response_json, status_code, created_at, expires_at
         ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
         ON CONFLICT(installation_id, endpoint, idempotency_key) DO UPDATE SET
           request_hash = excluded.request_hash,
           response_json = excluded.response_json,
           status_code = excluded.status_code,
           expires_at = excluded.expires_at`
      )
      .bind(
        params.key,
        params.installationId,
        params.endpoint,
        params.requestHash,
        params.responseJson,
        params.statusCode,
        now.toISOString(),
        expiresAt
      )
      .run();
  }
}
