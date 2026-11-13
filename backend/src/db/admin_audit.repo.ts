export interface AdminAuditEntry {
  id: string;
  admin_email: string;
  action: string;
  target_id: string | null;
  details_json: string;
  ip_hash: string | null;
  created_at: string;
}

export class AdminAuditRepository {
  constructor(private db: D1Database) {}

  public async recordLog(entry: {
    adminEmail: string;
    action: string;
    targetId?: string | null;
    details: Record<string, unknown>;
    ipHash?: string | null;
  }): Promise<string> {
    const id = `audit_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
    const now = new Date().toISOString();
    const detailsJson = JSON.stringify(entry.details);

    await this.db
      .prepare(
        `INSERT INTO admin_audit_log (id, admin_email, action, target_id, details_json, ip_hash, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?)`
      )
      .bind(
        id,
        entry.adminEmail,
        entry.action,
        entry.targetId ?? null,
        detailsJson,
        entry.ipHash ?? null,
        now
      )
      .run();

    return id;
  }

  public async listLogs(limit: number = 50, offset: number = 0): Promise<AdminAuditEntry[]> {
    const rows = await this.db
      .prepare(
        `SELECT id, admin_email, action, target_id, details_json, ip_hash, created_at
         FROM admin_audit_log
         ORDER BY created_at DESC
         LIMIT ? OFFSET ?`
      )
      .bind(limit, offset)
      .all<AdminAuditEntry>();

    return rows.results ?? [];
  }
}
