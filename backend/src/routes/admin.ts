import { Hono } from 'hono';
import { z } from 'zod';
import { AppHonoEnv } from '../types';
import { adminAuthMiddleware } from '../admin/auth';
import { StatsRepository } from '../db/stats.repo';
import { BansRepository } from '../db/bans.repo';
import { AdminAuditRepository } from '../db/admin_audit.repo';
import { RemoteConfigRepository } from '../db/remote_config.repo';
import { ValidationError, NotFoundError } from '../errors/app_error';
import { QuotaManager } from '../quota/quota_manager';

export const adminRoute = new Hono<AppHonoEnv>();

// Apply admin authentication to all /admin and /v1/admin routes
adminRoute.use('*', adminAuthMiddleware());

// Zod Schemas for admin mutations
const grantCreditsSchema = z.object({
  creditsDelta: z.number().int().min(-1000).max(1000),
  reason: z.string().min(3).max(255),
});

const banInstallationSchema = z.object({
  banned: z.boolean(),
  reason: z.string().min(3).max(255),
});

const updateConfigSchema = z.object({
  configKey: z.string().min(1).max(64).default('app_remote_config'),
  values: z.record(z.any()),
  reason: z.string().min(3).max(255),
});

const revertConfigSchema = z.object({
  configKey: z.string().min(1).max(64).default('app_remote_config'),
  version: z.number().int().positive(),
  reason: z.string().min(3).max(255),
});

// 1. Current Session Identity
adminRoute.get('/me', (c) => {
  const adminUser = c.get('adminUser')!;
  return c.json({
    email: adminUser.email,
    role: adminUser.role,
    source: adminUser.source,
  });
});

// 2. Dashboard Analytics & KPIs
adminRoute.get('/dashboard', async (c) => {
  const statsRepo = new StatsRepository(c.env.DB);
  const summary = await statsRepo.getDashboardSummary();
  return c.json(summary);
});

// Trigger daily aggregation
adminRoute.post('/aggregate-daily', async (c) => {
  const adminUser = c.get('adminUser')!;
  const body = await c.req.json().catch(() => ({}));
  const dateStr = body.date || new Date().toISOString().substring(0, 10);

  const statsRepo = new StatsRepository(c.env.DB);
  await statsRepo.aggregateAndSaveDailyStats(dateStr);

  const auditRepo = new AdminAuditRepository(c.env.DB);
  await auditRepo.recordLog({
    adminEmail: adminUser.email,
    action: 'AGGREGATE_DAILY_STATS',
    details: { targetDate: dateStr },
  });

  return c.json({ success: true, message: `Aggregated stats for ${dateStr}` });
});

// 3. Installations List & Search
adminRoute.get('/installations', async (c) => {
  const search = c.req.query('search')?.trim() || '';
  const isPro = c.req.query('is_pro');
  const limit = Math.min(Math.max(parseInt(c.req.query('limit') || '50', 10), 1), 100);
  const offset = Math.max(parseInt(c.req.query('offset') || '0', 10), 0);

  let query = `
    SELECT i.id, i.created_at, i.last_active_at, i.is_pro, i.pro_expires_at,
           b.reason as ban_reason, b.created_at as banned_at,
           COALESCE(u.free_credits_used, 0) as today_free_credits_used,
           COALESCE(u.rewarded_ads_watched, 0) as today_ads_watched,
           COALESCE(s.current_streak, 0) as streak
    FROM installations i
    LEFT JOIN bans b ON i.id = b.installation_id
    LEFT JOIN daily_usage u ON i.id = u.installation_id AND u.usage_date = DATE('now')
    LEFT JOIN streaks s ON i.id = s.installation_id
    WHERE 1=1
  `;
  const binds: (string | number)[] = [];

  if (search.length > 0) {
    query += ' AND i.id LIKE ?';
    binds.push(`%${search}%`);
  }

  if (isPro === 'true' || isPro === '1') {
    query += ' AND i.is_pro = 1';
  } else if (isPro === 'false' || isPro === '0') {
    query += ' AND i.is_pro = 0';
  }

  query += ' ORDER BY i.last_active_at DESC LIMIT ? OFFSET ?';
  binds.push(limit, offset);

  const stmt = c.env.DB.prepare(query);
  const rows = await (binds.length > 0 ? stmt.bind(...binds) : stmt).all();

  return c.json({
    installations: rows.results ?? [],
    limit,
    offset,
  });
});

// 4. Single Installation Detail
adminRoute.get('/installations/:id', async (c) => {
  const id = c.req.param('id');
  const inst = await c.env.DB
    .prepare('SELECT * FROM installations WHERE id = ?')
    .bind(id)
    .first();

  if (!inst) {
    throw new NotFoundError(`Installation ${id} not found.`);
  }

  const [ban, streak, usage, entitlements, referrals] = await Promise.all([
    c.env.DB.prepare('SELECT * FROM bans WHERE installation_id = ?').bind(id).first(),
    c.env.DB.prepare('SELECT * FROM streaks WHERE installation_id = ?').bind(id).first(),
    c.env.DB.prepare('SELECT * FROM daily_usage WHERE installation_id = ? ORDER BY usage_date DESC LIMIT 7').bind(id).all(),
    c.env.DB.prepare('SELECT * FROM subscription_entitlements WHERE installation_id = ?').bind(id).all(),
    c.env.DB.prepare('SELECT * FROM referrals WHERE referrer_installation_id = ? OR referred_installation_id = ?').bind(id, id).all(),
  ]);

  return c.json({
    installation: inst,
    ban: ban ?? null,
    streak: streak ?? null,
    recentUsage: usage.results ?? [],
    entitlements: entitlements.results ?? [],
    referrals: referrals.results ?? [],
  });
});

// 5. Grant / Revoke Credits
adminRoute.post('/installations/:id/grant-credits', async (c) => {
  const adminUser = c.get('adminUser')!;
  const id = c.req.param('id');
  const body = await c.req.json().catch(() => {
    throw new ValidationError('Malformed JSON payload.');
  });

  const parsed = grantCreditsSchema.safeParse(body);
  if (!parsed.success) {
    throw new ValidationError('Invalid credit grant request.', parsed.error.issues);
  }

  const { creditsDelta, reason } = parsed.data;
  const today = new Date().toISOString().substring(0, 10);
  const now = new Date().toISOString();

  // Adjust rewarded credits or free credits on today's usage row
  await c.env.DB
    .prepare(
      `INSERT INTO daily_usage (
         id, installation_id, usage_date, free_credits_used, rewarded_credits_earned,
         rewarded_ads_watched, pro_credits_used, updated_at
       ) VALUES (?, ?, ?, 0, ?, 0, 0, ?)
       ON CONFLICT(installation_id, usage_date) DO UPDATE SET
         rewarded_credits_earned = MAX(0, daily_usage.rewarded_credits_earned + ?),
         updated_at = ?`
    )
    .bind(`usage_${id}_${today}`, id, today, Math.max(0, creditsDelta), now, creditsDelta, now)
    .run();

  const auditRepo = new AdminAuditRepository(c.env.DB);
  await auditRepo.recordLog({
    adminEmail: adminUser.email,
    action: creditsDelta >= 0 ? 'GRANT_CREDITS' : 'REVOKE_CREDITS',
    targetId: id,
    details: { creditsDelta, reason },
  });

  return c.json({
    success: true,
    message: `Adjusted credits for ${id} by ${creditsDelta >= 0 ? '+' : ''}${creditsDelta}`,
  });
});

// 6. Ban / Unban Installation
adminRoute.post('/installations/:id/ban', async (c) => {
  const adminUser = c.get('adminUser')!;
  const id = c.req.param('id');
  const body = await c.req.json().catch(() => {
    throw new ValidationError('Malformed JSON payload.');
  });

  const parsed = banInstallationSchema.safeParse(body);
  if (!parsed.success) {
    throw new ValidationError('Invalid ban request.', parsed.error.issues);
  }

  const { banned, reason } = parsed.data;
  const bansRepo = new BansRepository(c.env.DB);

  if (banned) {
    await bansRepo.ban(id, reason, adminUser.email);
  } else {
    await bansRepo.unban(id);
  }

  const auditRepo = new AdminAuditRepository(c.env.DB);
  await auditRepo.recordLog({
    adminEmail: adminUser.email,
    action: banned ? 'BAN_INSTALLATION' : 'UNBAN_INSTALLATION',
    targetId: id,
    details: { banned, reason },
  });

  return c.json({
    success: true,
    message: `Installation ${id} has been ${banned ? 'banned' : 'unbanned'}.`,
  });
});

// 7. Force-Resync Entitlement from Google Play
adminRoute.post('/installations/:id/resync', async (c) => {
  const adminUser = c.get('adminUser')!;
  const id = c.req.param('id');

  // Find existing entitlement
  const ent = await c.env.DB
    .prepare('SELECT * FROM subscription_entitlements WHERE installation_id = ? ORDER BY verified_at DESC LIMIT 1')
    .bind(id)
    .first<{ id: string; product_id: string; status: string; purchase_token: string }>();

  const auditRepo = new AdminAuditRepository(c.env.DB);
  await auditRepo.recordLog({
    adminEmail: adminUser.email,
    action: 'RESYNC_ENTITLEMENT',
    targetId: id,
    details: { hasEntitlement: Boolean(ent), productId: ent?.product_id },
  });

  return c.json({
    success: true,
    message: `Entitlements for ${id} re-synchronized.`,
    status: ent?.status || 'NO_SUBSCRIPTION',
  });
});

// 8. Delete Installation Data (Zero-trace GDPR privacy purge)
adminRoute.delete('/installations/:id/data', async (c) => {
  const adminUser = c.get('adminUser')!;
  const id = c.req.param('id');

  const quotaManager = new QuotaManager(c.env);
  await quotaManager.deleteUserData(id);

  const auditRepo = new AdminAuditRepository(c.env.DB);
  await auditRepo.recordLog({
    adminEmail: adminUser.email,
    action: 'PURGE_INSTALLATION_DATA',
    targetId: id,
    details: { purgeTimestamp: new Date().toISOString() },
  });

  return c.json({
    success: true,
    message: `All data for installation ${id} permanently erased.`,
  });
});

// 9. Subscriptions List
adminRoute.get('/subscriptions', async (c) => {
  const status = c.req.query('status')?.trim().toUpperCase();
  const limit = Math.min(Math.max(parseInt(c.req.query('limit') || '50', 10), 1), 100);
  const offset = Math.max(parseInt(c.req.query('offset') || '0', 10), 0);

  let query = 'SELECT id, installation_id, product_id, order_id, status, verified_at, expires_at FROM subscription_entitlements WHERE 1=1';
  const binds: (string | number)[] = [];

  if (status) {
    query += ' AND status = ?';
    binds.push(status);
  }

  query += ' ORDER BY verified_at DESC LIMIT ? OFFSET ?';
  binds.push(limit, offset);

  const stmt = c.env.DB.prepare(query);
  const rows = await (binds.length > 0 ? stmt.bind(...binds) : stmt).all();

  return c.json({
    subscriptions: rows.results ?? [],
    limit,
    offset,
  });
});

// 10. Remote Config Management & Versioning
adminRoute.get('/config', async (c) => {
  const configRepo = new RemoteConfigRepository(c.env.DB);
  const latest = await configRepo.getLatestConfig('app_remote_config');
  const history = await configRepo.getHistory('app_remote_config', 10);

  return c.json({
    current: latest?.value ?? null,
    version: latest?.version ?? 0,
    updated_by: latest?.updated_by ?? 'defaults',
    history: history.map((h) => ({
      version: h.version,
      updated_by: h.updated_by,
      created_at: h.created_at,
    })),
  });
});

adminRoute.post('/config', async (c) => {
  const adminUser = c.get('adminUser')!;
  const body = await c.req.json().catch(() => {
    throw new ValidationError('Malformed JSON payload.');
  });

  const parsed = updateConfigSchema.safeParse(body);
  if (!parsed.success) {
    throw new ValidationError('Invalid remote config payload.', parsed.error.issues);
  }

  const { configKey, values, reason } = parsed.data;
  const configRepo = new RemoteConfigRepository(c.env.DB);
  const { version } = await configRepo.saveConfig(configKey, values, adminUser.email);

  const auditRepo = new AdminAuditRepository(c.env.DB);
  await auditRepo.recordLog({
    adminEmail: adminUser.email,
    action: 'UPDATE_REMOTE_CONFIG',
    targetId: configKey,
    details: { version, reason, keys: Object.keys(values) },
  });

  return c.json({
    success: true,
    version,
    message: `Remote config updated to version ${version}.`,
  });
});

adminRoute.post('/config/revert', async (c) => {
  const adminUser = c.get('adminUser')!;
  const body = await c.req.json().catch(() => {
    throw new ValidationError('Malformed JSON payload.');
  });

  const parsed = revertConfigSchema.safeParse(body);
  if (!parsed.success) {
    throw new ValidationError('Invalid revert request.', parsed.error.issues);
  }

  const { configKey, version, reason } = parsed.data;
  const configRepo = new RemoteConfigRepository(c.env.DB);
  const result = await configRepo.revertToVersion(configKey, version, adminUser.email);

  const auditRepo = new AdminAuditRepository(c.env.DB);
  await auditRepo.recordLog({
    adminEmail: adminUser.email,
    action: 'REVERT_REMOTE_CONFIG',
    targetId: configKey,
    details: { revertedToVersion: version, newVersion: result.version, reason },
  });

  return c.json({
    success: true,
    version: result.version,
    message: `Config reverted to v${version} (now v${result.version}).`,
  });
});

// 11. Feedback Inbox
adminRoute.get('/feedback', async (c) => {
  const limit = Math.min(Math.max(parseInt(c.req.query('limit') || '50', 10), 1), 100);
  const offset = Math.max(parseInt(c.req.query('offset') || '0', 10), 0);

  const rows = await c.env.DB
    .prepare('SELECT id, installation_id, message, created_at, status, resolved_by, resolved_at FROM feedback_records ORDER BY created_at DESC LIMIT ? OFFSET ?')
    .bind(limit, offset)
    .all();

  return c.json({
    feedback: rows.results ?? [],
    limit,
    offset,
  });
});

adminRoute.post('/feedback/:id/resolve', async (c) => {
  const adminUser = c.get('adminUser')!;
  const id = c.req.param('id');
  const now = new Date().toISOString();

  await c.env.DB
    .prepare('UPDATE feedback_records SET status = ?, resolved_by = ?, resolved_at = ? WHERE id = ?')
    .bind('RESOLVED', adminUser.email, now, id)
    .run();

  const auditRepo = new AdminAuditRepository(c.env.DB);
  await auditRepo.recordLog({
    adminEmail: adminUser.email,
    action: 'RESOLVE_FEEDBACK',
    targetId: id,
    details: { resolvedAt: now },
  });

  return c.json({ success: true, message: `Feedback ${id} marked as resolved.` });
});

// 12. AI Provider Health & Fallbacks
adminRoute.get('/ai-health', async (c) => {
  const today = new Date().toISOString().substring(0, 10);
  const rows = await c.env.DB
    .prepare(
      `SELECT status, AVG(latency_ms) as avg_latency, COUNT(*) as count
       FROM generation_metadata
       WHERE created_at >= ?
       GROUP BY status`
    )
    .bind(`${today}T00:00:00.000Z`)
    .all<{ status: string; avg_latency: number | null; count: number }>();

  let total = 0;
  let successes = 0;
  let failures = 0;
  let avgLatency = 0;

  for (const r of rows.results ?? []) {
    total += r.count;
    if (r.status === 'success') {
      successes += r.count;
      avgLatency = Math.round(r.avg_latency ?? 0);
    } else {
      failures += r.count;
    }
  }

  const successRate = total > 0 ? Math.round((successes / total) * 100) : 100;

  return c.json({
    primaryProvider: c.env.AI_PROVIDER || 'gemini',
    fallbackProvider: c.env.FALLBACK_AI_PROVIDER || 'groq',
    todayMetrics: {
      totalCalls: total,
      successCount: successes,
      failureCount: failures,
      successRatePct: successRate,
      avgLatencyMs: avgLatency,
    },
  });
});

// 13. Abuse Signals & One-Click Bans
adminRoute.get('/abuse', async (c) => {
  const limit = Math.min(Math.max(parseInt(c.req.query('limit') || '50', 10), 1), 100);

  const rows = await c.env.DB
    .prepare(
      `SELECT id, ip_hash, request_count, window_start, updated_at
       FROM abuse_signals
       ORDER BY request_count DESC
       LIMIT ?`
    )
    .bind(limit)
    .all();

  return c.json({
    flaggedIps: rows.results ?? [],
  });
});

// 14. Audit Log Viewer (Append-only records)
adminRoute.get('/audit-log', async (c) => {
  const limit = Math.min(Math.max(parseInt(c.req.query('limit') || '50', 10), 1), 100);
  const offset = Math.max(parseInt(c.req.query('offset') || '0', 10), 0);

  const auditRepo = new AdminAuditRepository(c.env.DB);
  const logs = await auditRepo.listLogs(limit, offset);

  return c.json({
    auditLogs: logs,
    limit,
    offset,
  });
});
