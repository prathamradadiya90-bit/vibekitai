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

  // Bounded in-memory fallback map for dev / test / DB hiccups
  const memoryCounts = new Map<string, { count: number; windowStart: number }>();

  const incrementMemory = (key: string, windowStart: number, nowSec: number): number => {
    if (memoryCounts.size > 500) {
      const cutoff = nowSec - windowSeconds * 2;
      for (const [k, v] of memoryCounts.entries()) {
        if (v.windowStart < cutoff) {
          memoryCounts.delete(k);
        }
      }
      // Hard eviction cap if flooded within a single window
      if (memoryCounts.size > 1000) {
        let deleted = 0;
        for (const k of memoryCounts.keys()) {
          memoryCounts.delete(k);
          deleted++;
          if (deleted >= 250) break;
        }
      }
    }
    const entry = memoryCounts.get(key) || { count: 0, windowStart };
    entry.count += 1;
    memoryCounts.set(key, entry);
    return entry.count;
  };

  return async (c, next) => {
    if (c.req.path === '/v1/health' || c.req.path === '/health') {
      return await next();
    }

    // Prefer Cloudflare Worker cf object when available; sanitize headers safely
    const rawCfConnectingIp = (c.req.raw as any)?.cf ? c.req.header('CF-Connecting-IP') : undefined;
    const rawIpHeader =
      rawCfConnectingIp ||
      c.req.header('CF-Connecting-IP') ||
      c.req.header('X-Real-IP') ||
      c.req.header('X-Forwarded-For') ||
      'unknown_ip';
    const firstIp = (rawIpHeader.split(',')[0] ?? rawIpHeader).trim().slice(0, 64);

    const rawHeaderId = c.req.header('X-App-Instance-Id') || c.req.header('X-Installation-Id');
    const installId =
      c.get('installationId') ||
      (rawHeaderId ? rawHeaderId.slice(0, 64).replace(/[^a-zA-Z0-9_\-\.]/g, '') : '') ||
      'anon';

    const isGeneration = c.req.path.includes('/generations/');
    const isAdmin = c.req.path.startsWith('/v1/admin');
    const bucket = isGeneration ? 'gen' : isAdmin ? 'adm' : 'all';
    const limit = isGeneration ? generationLimit : generalLimit;
    // Per-IP cap defeats X-App-Instance-Id rotation while permitting multiple users behind one NAT
    const ipCap = isAdmin ? Math.min(generalLimit, 30) : Math.max(limit * 3, limit + 10);

    const nowSec = Math.floor(Date.now() / 1000);
    const windowStart = nowSec - (nowSec % windowSeconds);
    const expiresAt = windowStart + windowSeconds * 2;

    const installKey = `${installId}_${firstIp}_${bucket}_${windowStart}`;
    const ipKey = `ip_${firstIp}_${bucket}_${windowStart}`;

    if (c.env?.DB) {
      try {
        const [instRow, ipRow] = await Promise.all([
          c.env.DB.prepare(
            `INSERT INTO rate_limit_counters (key, count, window_start, expires_at)
             VALUES (?, 1, ?, ?)
             ON CONFLICT(key) DO UPDATE SET count = count + 1
             RETURNING count`
          )
            .bind(installKey, windowStart, expiresAt)
            .first<{ count: number }>(),
          c.env.DB.prepare(
            `INSERT INTO rate_limit_counters (key, count, window_start, expires_at)
             VALUES (?, 1, ?, ?)
             ON CONFLICT(key) DO UPDATE SET count = count + 1
             RETURNING count`
          )
            .bind(ipKey, windowStart, expiresAt)
            .first<{ count: number }>(),
        ]);

        if ((instRow && instRow.count > limit) || (ipRow && ipRow.count > ipCap)) {
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
      } catch {
        const instCount = incrementMemory(installKey, windowStart, nowSec);
        const ipCount = incrementMemory(ipKey, windowStart, nowSec);
        if (instCount > limit || ipCount > ipCap) {
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
      const instCount = incrementMemory(installKey, windowStart, nowSec);
      const ipCount = incrementMemory(ipKey, windowStart, nowSec);
      if (instCount > limit || ipCount > ipCap) {
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
};
