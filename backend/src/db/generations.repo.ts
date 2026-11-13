export interface GenerationMetadataRecord {
  id: string;
  requestId: string;
  installationId: string;
  category: string;
  tone?: string;
  language?: string;
  status: 'success' | 'failed' | 'safety_rejected';
  latencyMs: number;
}

export class GenerationsRepository {
  constructor(private db?: D1Database) {}

  async insertMetadata(record: GenerationMetadataRecord): Promise<void> {
    if (!this.db) return;
    const nowIso = new Date().toISOString();

    await this.db
      .prepare(
        `INSERT INTO generation_metadata (id, request_id, installation_id, category, tone, language, status, latency_ms, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`
      )
      .bind(
        record.id,
        record.requestId,
        record.installationId,
        record.category,
        record.tone || null,
        record.language || null,
        record.status,
        record.latencyMs,
        nowIso
      )
      .run();
  }
}
