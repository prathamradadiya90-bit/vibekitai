import { InstallationRecord } from '../types';

export class InstallationsRepository {
  constructor(private db?: D1Database) {}

  async upsertInstallation(id: string): Promise<InstallationRecord> {
    const nowIso = new Date().toISOString();

    if (!this.db) {
      return {
        id,
        created_at: nowIso,
        last_active_at: nowIso,
        is_pro: 0,
        pro_expires_at: null,
      };
    }

    // Insert or update last_active_at atomically
    await this.db
      .prepare(
        `INSERT INTO installations (id, created_at, last_active_at, is_pro, pro_expires_at)
         VALUES (?, ?, ?, 0, NULL)
         ON CONFLICT(id) DO UPDATE SET
           last_active_at = excluded.last_active_at`
      )
      .bind(id, nowIso, nowIso)
      .run();

    const record = await this.db
      .prepare('SELECT id, created_at, last_active_at, is_pro, pro_expires_at FROM installations WHERE id = ?')
      .bind(id)
      .first<InstallationRecord>();

    return (
      record || {
        id,
        created_at: nowIso,
        last_active_at: nowIso,
        is_pro: 0,
        pro_expires_at: null,
      }
    );
  }

  async getInstallation(id: string): Promise<InstallationRecord | null> {
    if (!this.db) return null;
    return this.db
      .prepare('SELECT id, created_at, last_active_at, is_pro, pro_expires_at FROM installations WHERE id = ?')
      .bind(id)
      .first<InstallationRecord>();
  }

  async updateProStatus(id: string, isPro: boolean, expiresAt: string | null): Promise<void> {
    if (!this.db) return;
    const nowIso = new Date().toISOString();
    await this.db
      .prepare(
        `INSERT INTO installations (id, created_at, last_active_at, is_pro, pro_expires_at)
         VALUES (?, ?, ?, ?, ?)
         ON CONFLICT(id) DO UPDATE SET
           is_pro = excluded.is_pro,
           pro_expires_at = excluded.pro_expires_at,
           last_active_at = excluded.last_active_at`
      )
      .bind(id, nowIso, nowIso, isPro ? 1 : 0, expiresAt)
      .run();
  }
}
