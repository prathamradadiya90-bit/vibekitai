export interface BanRecord {
  installation_id: string;
  reason: string;
  banned_by: string;
  created_at: string;
}

// In-isolate TTL cache for ultra-fast ban checks without hitting D1 on every single request
const bannedCache = new Map<string, { banned: boolean; expiresAt: number }>();
const CACHE_TTL_MS = 60_000; // 60 seconds

export class BansRepository {
  constructor(private db: D1Database) {}

  public async isBanned(installationId: string): Promise<boolean> {
    const cached = bannedCache.get(installationId);
    const now = Date.now();
    if (cached && cached.expiresAt > now) {
      return cached.banned;
    }

    const row = await this.db
      .prepare('SELECT installation_id FROM bans WHERE installation_id = ?')
      .bind(installationId)
      .first<{ installation_id: string }>();

    const isBanned = Boolean(row?.installation_id);
    bannedCache.set(installationId, { banned: isBanned, expiresAt: now + CACHE_TTL_MS });
    return isBanned;
  }

  public async ban(installationId: string, reason: string, bannedBy: string): Promise<void> {
    const now = new Date().toISOString();
    await this.db
      .prepare(
        `INSERT INTO bans (installation_id, reason, banned_by, created_at)
         VALUES (?, ?, ?, ?)
         ON CONFLICT(installation_id) DO UPDATE SET
           reason = excluded.reason,
           banned_by = excluded.banned_by,
           created_at = excluded.created_at`
      )
      .bind(installationId, reason, bannedBy, now)
      .run();

    bannedCache.set(installationId, { banned: true, expiresAt: Date.now() + CACHE_TTL_MS });
  }

  public async unban(installationId: string): Promise<void> {
    await this.db
      .prepare('DELETE FROM bans WHERE installation_id = ?')
      .bind(installationId)
      .run();

    bannedCache.set(installationId, { banned: false, expiresAt: Date.now() + CACHE_TTL_MS });
  }

  public async listBanned(limit: number = 50, offset: number = 0): Promise<BanRecord[]> {
    const rows = await this.db
      .prepare('SELECT installation_id, reason, banned_by, created_at FROM bans ORDER BY created_at DESC LIMIT ? OFFSET ?')
      .bind(limit, offset)
      .all<BanRecord>();

    return rows.results ?? [];
  }

  public static clearCache(): void {
    bannedCache.clear();
  }
}
