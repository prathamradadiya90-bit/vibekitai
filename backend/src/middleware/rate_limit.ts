import { MiddlewareHandler } from 'hono';
import { Env } from '../types';

export function rateLimiterMiddleware(options?: {
  generalLimit?: number;
  generationLimit?: number;
  windowSeconds?: number;
}): MiddlewareHandler<{ Bindings: Env }> {
  const generalLimit = options?.generalLimit ?? 60;
  const generationLimit = options?.generationLimit ?? 15;
  const windowSeconds = options?.windowSeconds ?? 60;

  // In-memory fallback map for dev / test environments
  const memoryCounts = new Map<string, { count: number; windowStart: number }>();

  return async (c, next) => {
    // Determine client identifier: installation ID or CF-Connecting-IP
    const clientIp = c.req.header('CF-Connecting-IP') || c.req.header('X-Forwarded-For') || 'unknown_ip';
    const installId = c.req.header('X-App-Instance-Id') || 'anon';
    const isGeneration = c.req.path.includes('/generations/');
    const limit = isGeneration ? generationLimit : generalLimit;

    const nowSec = Math.floor(Date.now() / 1000);
    const windowStart = nowSec - (nowSec % windowSeconds);
    const firstIp = (clientIp.split(',')[0] ?? clientIp).trim();
    const key = `${installId}_${firstIp}_${isGeneration ? 'gen' : 'all'}_${windowStart}`;

    if (c.env.DB) {
      try {
        // Upsert counter in rate_limit_counters table
        await c.env.DB.prepare(
          `INSERT INTO rate_limit_counters (key, count, window_start, expires_at)
           VALUES (?, 1, ?, ?)
           ON CONFLICT(key) DO UPDATE SET count = count + 1`
        )
          .bind(key, windowStart, windowStart + windowSeconds * 2)
          .run();

        const row = await c.env.DB.prepare('SELECT count FROM rate_limit_counters WHERE key = ?')
          .bind(key)
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
