import { describe, it, expect, beforeEach } from 'vitest';
import app from '../src/index';
import { Env } from '../src/types';
import { BansRepository } from '../src/db/bans.repo';

function createMockD1DatabaseWithTables(): D1Database {
  const store = new Map<string, any[]>();
  store.set('bans', []);
  store.set('admin_audit_log', []);
  store.set('remote_config_versions', []);
  store.set('daily_usage', []);
  store.set('feedback_records', []);
  store.set('subscription_entitlements', []);
  store.set('generation_metadata', []);
  store.set('installations', []);

  return {
    prepare: (query: string) => {
      let boundArgs: any[] = [];
      const stmt: any = {
        bind: (...args: any[]) => {
          boundArgs = args;
          return stmt;
        },
        first: async <T>() => {
          const lower = query.toLowerCase();
          if (lower.includes('from bans where installation_id = ?')) {
            const id = boundArgs[0];
            const found = store.get('bans')?.find((b) => b.installation_id === id);
            return (found || null) as T | null;
          }
          if (lower.includes('from remote_config_versions')) {
            const versions = store.get('remote_config_versions') || [];
            if (lower.includes('max(version)')) {
              const max = versions.reduce((m, v) => Math.max(m, v.version), 0);
              return { max_version: max } as any;
            }
            if (lower.includes('where config_key = ? and version = ?')) {
              const key = boundArgs[0];
              const ver = boundArgs[1];
              return (versions.find((v) => v.config_key === key && v.version === ver) || null) as any;
            }
            return (versions[versions.length - 1] || null) as any;
          }
          if (lower.includes('from installations where id = ?')) {
            return { id: boundArgs[0], is_pro: 0, created_at: new Date().toISOString(), last_active_at: new Date().toISOString() } as any;
          }
          return null as T | null;
        },
        all: async <T>() => {
          const lower = query.toLowerCase();
          if (lower.includes('from admin_audit_log')) {
            return { results: (store.get('admin_audit_log') || []) as T[], success: true };
          }
          if (lower.includes('from remote_config_versions')) {
            return { results: (store.get('remote_config_versions') || []) as T[], success: true };
          }
          if (lower.includes('from feedback_records')) {
            return { results: (store.get('feedback_records') || []) as T[], success: true };
          }
          if (lower.includes('from subscription_entitlements')) {
            return { results: (store.get('subscription_entitlements') || []) as T[], success: true };
          }
          return { results: [] as T[], success: true };
        },
        run: async () => {
          const lower = query.toLowerCase();
          if (lower.includes('insert into bans') || lower.includes('replace into bans')) {
            const [id, reason, bannedBy, createdAt] = boundArgs;
            const bans = store.get('bans') || [];
            bans.push({ installation_id: id, reason, banned_by: bannedBy, created_at: createdAt });
            store.set('bans', bans);
          } else if (lower.includes('delete from bans where installation_id = ?')) {
            const id = boundArgs[0];
            const bans = (store.get('bans') || []).filter((b) => b.installation_id !== id);
            store.set('bans', bans);
          } else if (lower.includes('insert into admin_audit_log')) {
            const [id, adminEmail, action, targetId, detailsJson, ipHash, createdAt] = boundArgs;
            const logs = store.get('admin_audit_log') || [];
            logs.push({ id, admin_email: adminEmail, action, target_id: targetId, details_json: detailsJson, ip_hash: ipHash, created_at: createdAt });
            store.set('admin_audit_log', logs);
          } else if (lower.includes('insert into remote_config_versions')) {
            const [id, configKey, valueJson, version, updatedBy, createdAt] = boundArgs;
            const configs = store.get('remote_config_versions') || [];
            configs.push({ id, config_key: configKey, value_json: valueJson, version, updated_by: updatedBy, created_at: createdAt });
            store.set('remote_config_versions', configs);
          }
          return { success: true, meta: { changes: 1 } };
        },
      };
      return stmt;
    },
    batch: async (statements: any[]) => {
      return statements.map(() => ({ success: true, meta: { changes: 1 } }));
    },
    exec: async () => ({ count: 0, duration: 0 }),
    dump: async () => new ArrayBuffer(0),
  } as unknown as D1Database;
}

function createFakeCfAccessJwt(email: string): string {
  const header = btoa(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const payload = btoa(JSON.stringify({
    email,
    sub: 'cf_sub_' + email,
    iss: 'https://vibekit.cloudflareaccess.com',
    aud: ['vibekit_admin_aud'],
    exp: Math.floor(Date.now() / 1000) + 3600,
  }));
  return `${header}.${payload}.fake_signature`;
}

describe('Phase 9: Admin Panel Security, RBAC & Endpoints', () => {
  let mockEnv: Env;
  let mockDb: D1Database;

  beforeEach(() => {
    BansRepository.clearCache();
    mockDb = createMockD1DatabaseWithTables();
    mockEnv = {
      DB: mockDb,
      ENVIRONMENT: 'test',
      ADMIN_SECRET: 'test_admin_supersecret',
      ADMIN_USERS_JSON: JSON.stringify({
        'admin@vibekit.ai': 'admin',
        'viewer@vibekit.ai': 'viewer',
      }),
      GEMINI_MODEL: 'gemini-1.5-flash',
      MAX_DAILY_FREE_CREDITS: '3',
      REWARD_CREDITS_PER_AD: '3',
      MAX_DAILY_REWARDS: '2',
      MONTHLY_PRO_CREDITS: '200',
    };
  });

  it('rejects unauthenticated requests to /v1/admin/me with 401 UNAUTHORIZED', async () => {
    const res = await app.request('/v1/admin/me', { method: 'GET' }, mockEnv);
    expect(res.status).toBe(401);
    const json = (await res.json()) as any;
    expect(json.error.code).toBe('UNAUTHORIZED');
  });

  it('rejects expired Cloudflare Access JWT assertions', async () => {
    const header = btoa(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
    const payload = btoa(JSON.stringify({
      email: 'admin@vibekit.ai',
      exp: Math.floor(Date.now() / 1000) - 300, // expired 5 minutes ago
    }));
    const expiredJwt = `${header}.${payload}.sig`;
    const res = await app.request(
      '/v1/admin/me',
      {
        method: 'GET',
        headers: { 'Cf-Access-Jwt-Assertion': expiredJwt },
      },
      mockEnv
    );
    expect(res.status).toBe(401);
  });

  it('authenticates admin with valid Cloudflare Access JWT header', async () => {
    const jwt = createFakeCfAccessJwt('admin@vibekit.ai');
    const res = await app.request(
      '/v1/admin/me',
      {
        method: 'GET',
        headers: { 'Cf-Access-Jwt-Assertion': jwt },
      },
      mockEnv
    );

    expect(res.status).toBe(200);
    const json = (await res.json()) as any;
    expect(json.email).toBe('admin@vibekit.ai');
    expect(json.role).toBe('admin');
    expect(json.source).toBe('cf_access');
  });

  it('authenticates viewer with valid Cloudflare Access JWT header', async () => {
    const jwt = createFakeCfAccessJwt('viewer@vibekit.ai');
    const res = await app.request(
      '/v1/admin/me',
      {
        method: 'GET',
        headers: { 'Cf-Access-Jwt-Assertion': jwt },
      },
      mockEnv
    );

    expect(res.status).toBe(200);
    const json = (await res.json()) as any;
    expect(json.email).toBe('viewer@vibekit.ai');
    expect(json.role).toBe('viewer');
  });

  it('allows viewer to read dashboard metrics', async () => {
    const jwt = createFakeCfAccessJwt('viewer@vibekit.ai');
    const res = await app.request(
      '/v1/admin/dashboard',
      {
        method: 'GET',
        headers: { 'Cf-Access-Jwt-Assertion': jwt },
      },
      mockEnv
    );

    expect(res.status).toBe(200);
    const json = (await res.json()) as any;
    expect(json.dau).toBeDefined();
    expect(json.generations).toBeDefined();
  });

  it('blocks viewer from mutating operations with 403 FORBIDDEN', async () => {
    const jwt = createFakeCfAccessJwt('viewer@vibekit.ai');
    const res = await app.request(
      '/v1/admin/installations/inst_test_123/ban',
      {
        method: 'POST',
        headers: {
          'Cf-Access-Jwt-Assertion': jwt,
          'Content-Type': 'application/json',
          'X-Admin-Action': '1',
        },
        body: JSON.stringify({ banned: true, reason: 'Test ban by viewer' }),
      },
      mockEnv
    );

    expect(res.status).toBe(403);
    const json = (await res.json()) as any;
    expect(json.error.code).toBe('FORBIDDEN');
  });

  it('allows admin to ban installation and records audit log', async () => {
    const jwt = createFakeCfAccessJwt('admin@vibekit.ai');
    const res = await app.request(
      '/v1/admin/installations/inst_bad_device/ban',
      {
        method: 'POST',
        headers: {
          'Cf-Access-Jwt-Assertion': jwt,
          'Content-Type': 'application/json',
          'X-Admin-Action': '1',
        },
        body: JSON.stringify({ banned: true, reason: 'Violation of Terms' }),
      },
      mockEnv
    );

    expect(res.status).toBe(200);
    const json = (await res.json()) as any;
    expect(json.success).toBe(true);

    // Verify audit log has the entry
    const auditRes = await app.request(
      '/v1/admin/audit-log',
      {
        method: 'GET',
        headers: { 'Cf-Access-Jwt-Assertion': jwt },
      },
      mockEnv
    );
    expect(auditRes.status).toBe(200);
    const auditJson = (await auditRes.json()) as any;
    expect(auditJson.auditLogs.length).toBeGreaterThanOrEqual(1);
    expect(auditJson.auditLogs[0].action).toBe('BAN_INSTALLATION');
    expect(auditJson.auditLogs[0].target_id).toBe('inst_bad_device');
  });

  it('enforces ban in shared installation middleware on generation route', async () => {
    // 1. Ban device in repository
    const bansRepo = new BansRepository(mockDb);
    await bansRepo.ban('inst_banned_user', 'Fraudulent activity', 'admin@vibekit.ai');

    // 2. Request generation with banned instance ID
    const res = await app.request(
      '/v1/generations/reply',
      {
        method: 'POST',
        headers: {
          'X-App-Instance-Id': 'inst_banned_user',
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: 'Hey there',
          tone: 'Friendly',
          language: 'English',
        }),
      },
      mockEnv
    );

    expect(res.status).toBe(403);
    const json = (await res.json()) as any;
    expect(json.error.code).toBe('ACCOUNT_BANNED');
  });

  it('updates and versions remote config with rollback capability', async () => {
    const jwt = createFakeCfAccessJwt('admin@vibekit.ai');

    // 1. Update remote config
    const updateRes = await app.request(
      '/v1/admin/config',
      {
        method: 'POST',
        headers: {
          'Cf-Access-Jwt-Assertion': jwt,
          'Content-Type': 'application/json',
          'X-Admin-Action': '1',
        },
        body: JSON.stringify({
          configKey: 'app_remote_config',
          reason: 'Adjusting free limits',
          values: { daily_free_credits: 5, reward_credits_per_ad: 4 },
        }),
      },
      mockEnv
    );

    expect(updateRes.status).toBe(200);
    const updateJson = (await updateRes.json()) as any;
    expect(updateJson.success).toBe(true);
    expect(updateJson.version).toBe(1);

    // 2. Query config history
    const historyRes = await app.request(
      '/v1/admin/config',
      {
        method: 'GET',
        headers: { 'Cf-Access-Jwt-Assertion': jwt },
      },
      mockEnv
    );

    expect(historyRes.status).toBe(200);
    const historyJson = (await historyRes.json()) as any;
    expect(historyJson.version).toBe(1);
    expect(historyJson.current.daily_free_credits).toBe(5);
  });

  it('renders admin HTML single page application at /admin', async () => {
    const res = await app.request('/admin', { method: 'GET' }, mockEnv);
    expect(res.status).toBe(200);
    const html = await res.text();
    expect(html).toContain('VibeKit AI - Admin Console');
    expect(html).toContain('Dashboard');
  });
});
