export interface FeedbackRecord {
  id: string;
  installation_id: string;
  message: string;
  created_at: string;
  status?: string;
  resolved_by?: string | null;
  resolved_at?: string | null;
}

export class FeedbackRepository {
  constructor(private readonly db: D1Database) {}

  async create(installationId: string, message: string): Promise<string> {
    const id = `fb_${Date.now()}_${Math.random().toString(36).substring(7)}`;
    const now = new Date().toISOString();

    await this.db
      .prepare(
        `INSERT INTO feedback_records (id, installation_id, message, created_at, status)
         VALUES (?, ?, ?, ?, 'open')`
      )
      .bind(id, installationId, message, now)
      .run();

    return id;
  }

  async list(limit = 20, offset = 0): Promise<FeedbackRecord[]> {
    const rows = await this.db
      .prepare(
        `SELECT id, installation_id, message, created_at, status, resolved_by, resolved_at
         FROM feedback_records
         ORDER BY created_at DESC
         LIMIT ? OFFSET ?`
      )
      .bind(limit, offset)
      .all<FeedbackRecord>();

    return rows.results ?? [];
  }

  async resolve(id: string, resolvedBy: string): Promise<boolean> {
    const now = new Date().toISOString();
    const res = await this.db
      .prepare(
        `UPDATE feedback_records
         SET status = 'resolved', resolved_by = ?, resolved_at = ?
         WHERE id = ?`
      )
      .bind(resolvedBy, now, id)
      .run();

    return (res.meta.changes ?? 0) > 0;
  }
}
