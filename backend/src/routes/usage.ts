import { Hono } from 'hono';
import { Env } from '../types';
import { QuotaManager } from '../quota/quota_manager';

export const usageRoute = new Hono<{ Bindings: Env }>();

usageRoute.get('/usage', async (c) => {
  const installationId = c.req.header('X-App-Instance-Id') || 'anonymous_default';
  const quotaManager = new QuotaManager(c.env);
  const status = await quotaManager.getQuotaStatus(installationId);
  return c.json(status);
});
