export interface RemoteConfigVersionRecord {
  id: string;
  config_key: string;
  value_json: string;
  version: number;
  updated_by: string;
  created_at: string;
}

// In-memory cache across worker isolate requests
const configCache = new Map<string, { data: any; version: number; expiresAt: number }>();
const CONFIG_CACHE_TTL_MS = 60_000; // 60s

export class RemoteConfigRepository {
  constructor(private db: D1Database) {}

  public async getLatestConfig<T = any>(key: string): Promise<{ value: T; version: number; updated_by: string } | null> {
    const cached = configCache.get(key);
    const now = Date.now();
    if (cached && cached.expiresAt > now) {
      return { value: cached.data as T, version: cached.version, updated_by: 'cache' };
    }

    const row = await this.db
      .prepare(
        `SELECT config_key, value_json, version, updated_by
         FROM remote_config_versions
         WHERE config_key = ?
         ORDER BY version DESC
         LIMIT 1`
      )
      .bind(key)
      .first<RemoteConfigVersionRecord>();

    if (!row) return null;

    try {
      const parsed = JSON.parse(row.value_json) as T;
      configCache.set(key, { data: parsed, version: row.version, expiresAt: now + CONFIG_CACHE_TTL_MS });
      return { value: parsed, version: row.version, updated_by: row.updated_by };
    } catch {
      return null;
    }
  }

  public async saveConfig(key: string, value: any, updatedBy: string): Promise<{ version: number }> {
    // Find highest version
    const latest = await this.db
      .prepare('SELECT MAX(version) as max_version FROM remote_config_versions WHERE config_key = ?')
      .bind(key)
      .first<{ max_version: number | null }>();

    const nextVersion = (latest?.max_version ?? 0) + 1;
    const id = `cfg_${Date.now()}_v${nextVersion}`;
    const valueJson = JSON.stringify(value);
    const now = new Date().toISOString();

    await this.db
      .prepare(
        `INSERT INTO remote_config_versions (id, config_key, value_json, version, updated_by, created_at)
         VALUES (?, ?, ?, ?, ?, ?)`
      )
      .bind(id, key, valueJson, nextVersion, updatedBy, now)
      .run();

    configCache.set(key, { data: value, version: nextVersion, expiresAt: Date.now() + CONFIG_CACHE_TTL_MS });
    return { version: nextVersion };
  }

  public async revertToVersion(key: string, targetVersion: number, revertedBy: string): Promise<{ version: number }> {
    const targetRow = await this.db
      .prepare('SELECT value_json FROM remote_config_versions WHERE config_key = ? AND version = ?')
      .bind(key, targetVersion)
      .first<{ value_json: string }>();

    if (!targetRow) {
      throw new Error(`Target version ${targetVersion} not found for config key ${key}`);
    }

    const parsedValue = JSON.parse(targetRow.value_json);
    return await this.saveConfig(key, parsedValue, `${revertedBy} (reverted to v${targetVersion})`);
  }

  public async getHistory(key: string, limit: number = 20): Promise<RemoteConfigVersionRecord[]> {
    const rows = await this.db
      .prepare(
        `SELECT id, config_key, value_json, version, updated_by, created_at
         FROM remote_config_versions
         WHERE config_key = ?
         ORDER BY version DESC
         LIMIT ?`
      )
      .bind(key, limit)
      .all<RemoteConfigVersionRecord>();

    return rows.results ?? [];
  }

  public static clearCache(): void {
    configCache.clear();
  }
}
