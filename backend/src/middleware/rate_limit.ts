import { MiddlewareHandler } from 'hono';
import { AppHonoEnv } from '../types';

export function rateLimiterMiddleware(options?: {
  generalLimit?: number;
  generationLimit?: number;
  windowSeconds?: number;
}): MiddlewareHandler<AppHonoEnv> {
  const generalLimit = options?.generalLimit ?? 60;
  const generationLimit = options?.generationLimit ?? 15;
  const windowSeconds = options?.windowSeconds ?? 60;

  // In-memory fallback map for dev / test environments
  const memoryCounts = new Map<string, { count: number; windowStart: number }>();

  return async (c, next) => {
    // Exempt health check endpoints from rate limiting overhead
    if (c.req.path === '/v1/health' || c.req.path === '/health') {
      return await next();
    }

    // Determine client identifier: canonical sanitized installation ID + CF-Connecting-IP
    const clientIp = c.req.header('CF-Connecting-IP') || c.req.header('X-Forwarded-For') || 'unknown_ip';
    const rawHeaderId = c.req.header('X-App-Instance-Id') || c.req.header('X-Installation-Id');
    const installId = c.get('installationId') || (rawHeaderId ? rawHeaderId.slice(0, 64).replace(/[^a-zA-Z0-9_\-\.]/g, '') : '') || 'anon';
    const isGeneration = c.req.path.includes('/generations/');
    const limit = isGeneration ? generationLimit : generalLimit;

    const nowSec = Math.floor(Date.now() / 1000);
    const windowStart = nowSec - (nowSec % windowSeconds);

    // Prune stale in-memory counters to prevent memory leaks in long-running isolates
    if (memoryCounts.size > 500) {
      const cutoff = nowSec - windowSeconds * 2;
      for (const [k, v] of memoryCounts.entries()) {
        if (v.windowStart < cutoff) {
          memoryCounts.delete(k);
        }
      }
    }

    const firstIp = (clientIp.split(',')[0] ?? clientIp).trim();
    const key = `${installId}_${firstIp}_${isGeneration ? 'gen' : 'all'}_${windowStart}`;

    if (c.env?.DB) {
      try {
        // Atomic upsert with RETURNING count to eliminate extra SELECT roundtrip
        const row = await c.env.DB.prepare(
          `INSERT INTO rate_limit_counters (key, count, window_start, expires_at)
           VALUES (?, 1, ?, ?)
           ON CONFLICT(key) DO UPDATE SET count = count + 1
           RETURNING count`
        )
          .bind(key, windowStart, windowStart + windowSeconds * 2)
          .first<{ count: number }>();

        if (row && row.count > limit) {
          return c.json(
            {
              error: {
                code: 'RATE_LIMIT_EXCEEDED',
                message: 'Too many requests. Please slow down and try again shortly.',
              },
            },
            429
          );
        }
      } catch (err) {
        // Graceful fallback to memory on DB hiccup so requests are never dropped
        const entry = memoryCounts.get(key) || { count: 0, windowStart };
        entry.count += 1;
        memoryCounts.set(key, entry);
        if (entry.count > limit) {
          return c.json(
            {
              error: {
                code: 'RATE_LIMIT_EXCEEDED',
                message: 'Too many requests. Please slow down.',
              },
            },
            429
          );
        }
      }
    } else {
      const entry = memoryCounts.get(key) || { count: 0, windowStart };
      entry.count += 1;
      memoryCounts.set(key, entry);
      if (entry.count > limit) {
        return c.json(
          {
            error: {
              code: 'RATE_LIMIT_EXCEEDED',
              message: 'Rate limit exceeded.',
            },
          },
          429
        );
      }
    }

    await next();
  };
}
