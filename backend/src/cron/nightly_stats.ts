import { Env } from '../types';
import { StatsRepository } from '../db/stats.repo';
import { QuotaManager } from '../quota/quota_manager';

export async function handleScheduledTask(
  controller: ScheduledController,
  env: Env,
  ctx: ExecutionContext
): Promise<void> {
  if (!env.DB) return;
  const statsRepo = new StatsRepository(env.DB);
  const quotaManager = new QuotaManager(env);

  const yesterday = new Date(Date.now() - 86400000).toISOString().substring(0, 10);
  const today = new Date().toISOString().substring(0, 10);

  ctx.waitUntil(
    (async () => {
      try {
        // Reconcile expired entitlements BEFORE saving today's active Pro snapshot
        await quotaManager.reconcileEntitlementsNightly();
        await statsRepo.aggregateAndSaveDailyStats(yesterday);
        await statsRepo.aggregateAndSaveDailyStats(today);

        const oneHourAgoSec = Math.floor(Date.now() / 1000) - 3600;
        await env.DB.prepare('DELETE FROM rate_limit_counters WHERE expires_at < ?')
          .bind(oneHourAgoSec)
          .run()
          .catch((err) => console.warn('Failed to purge expired rate_limit_counters:', err));

        const nowIso = new Date().toISOString();
        await env.DB.prepare('DELETE FROM idempotency_keys WHERE expires_at <= ?')
          .bind(nowIso)
          .run()
          .catch((err) => console.warn('Failed to purge expired idempotency_keys:', err));
      } catch (err) {
        console.error('Failed nightly scheduled task:', err);
      }
    })()
  );
}
