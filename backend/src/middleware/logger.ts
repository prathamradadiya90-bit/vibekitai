import { MiddlewareHandler } from 'hono';
import { AppHonoEnv } from '../types';

export interface StructuredLogRecord {
  level: 'info' | 'warn' | 'error';
  timestamp: string;
  requestId: string;
  installationId: string;
  method: string;
  path: string;
  status: number;
  durationMs: number;
  outcome: 'success' | 'quota_exceeded' | 'client_error' | 'server_error';
  userAgent?: string;
  country?: string;
}

/**
 * Structured Logging Middleware with Invariant Zero-Prompt Retention Redaction.
 * Assigns requestId early so downstream rate-limiter/installation rejections also log cleanly.
 */
export const structuredLoggerMiddleware = (): MiddlewareHandler<AppHonoEnv> => {
  return async (c, next) => {
    const startTime = Date.now();
    const requestId =
      c.get('requestId') ||
      c.req.header('X-Request-Id')?.trim() ||
      `req_${Date.now()}_${Math.random().toString(36).substring(7)}`;
    c.set('requestId', requestId);
    c.header('X-Request-Id', requestId);

    await next();

    const durationMs = Date.now() - startTime;
    const status = c.res.status;
    const installationId =
      c.get('installationId') ||
      c.get('installation')?.id ||
      c.req.header('X-App-Instance-Id')?.trim().slice(0, 64) ||
      'anonymous';

    let outcome: StructuredLogRecord['outcome'] = 'success';
    if (status === 429) {
      outcome = 'quota_exceeded';
    } else if (status >= 400 && status < 500) {
      outcome = 'client_error';
    } else if (status >= 500) {
      outcome = 'server_error';
    }

    const logRecord: StructuredLogRecord = {
      level: status >= 500 ? 'error' : status >= 400 ? 'warn' : 'info',
      timestamp: new Date().toISOString(),
      requestId,
      installationId,
      method: c.req.method,
      path: c.req.path,
      status,
      durationMs,
      outcome,
      userAgent: c.req.header('User-Agent')?.slice(0, 100),
      country: (c.req.raw as any)?.cf?.country,
    };

    console.log(JSON.stringify(logRecord));
  };
};
