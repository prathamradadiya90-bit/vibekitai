import { MiddlewareHandler } from 'hono';
import { AppHonoEnv, InstallationRecord } from '../types';
import { InstallationsRepository } from '../db/installations.repo';
import { BansRepository } from '../db/bans.repo';
import { AccountBannedError, AuthError } from '../errors/app_error';
import { verifySessionToken } from '../security/session_tokens';

export const installationMiddleware = (): MiddlewareHandler<AppHonoEnv> => {
  return async (c, next) => {
    if (
      c.req.path.startsWith('/v1/admin') ||
      c.req.path === '/v1/health' ||
      c.req.path === '/health' ||
      c.req.path === '/v1/ads/ssv' ||
      c.req.path === '/v1/purchases/rtdn'
    ) {
      return await next();
    }

    const rawInstanceId =
      c.req.header('X-App-Instance-Id')?.trim() ||
      c.req.header('X-Installation-Id')?.trim();
    const sanitizedId = rawInstanceId
      ? rawInstanceId.slice(0, 64).replace(/[^a-zA-Z0-9_\-\.]/g, '')
      : '';
    const installationId = sanitizedId.length > 0 ? sanitizedId : 'anonymous_default';
    const requestId =
      c.get('requestId') ||
      c.req.header('X-Request-Id')?.trim() ||
      `req_${Date.now()}_${Math.random().toString(36).substring(7)}`;

    c.header('X-Request-Id', requestId);
    c.set('requestId', requestId);

    // If caller presents X-Session-Token, verify HMAC signature and installation binding
    const sessionToken = c.req.header('X-Session-Token')?.trim();
    if (sessionToken) {
      const isDevOrTest = c.env?.ENVIRONMENT === 'development' || c.env?.ENVIRONMENT === 'test';
      const secret =
        c.env?.SESSION_SECRET ||
        c.env?.ADMIN_SECRET ||
        (isDevOrTest ? 'vibekit_default_session_secret_rotate_in_prod' : '');
      const payload = await verifySessionToken(sessionToken, secret);
      if (!payload || payload.sub !== installationId) {
        throw new AuthError('Invalid or mismatched session token.');
      }
    }

    // Fast cached ban verification (exempt privacy data erasure)
    if (c.env?.DB && c.req.path !== '/v1/privacy/delete-data') {
      try {
        const bansRepo = new BansRepository(c.env.DB);
        const isBanned = await bansRepo.isBanned(installationId);
        if (isBanned) {
          throw new AccountBannedError('This installation has been suspended for policy violations.');
        }
      } catch (err) {
        if (err instanceof AccountBannedError) throw err;
        // Fail closed in production so transient DB errors don't bypass bans
        if (c.env.ENVIRONMENT === 'production') {
          throw err;
        }
      }
    }

    let installation: InstallationRecord;
    if (c.env?.DB) {
      const repo = new InstallationsRepository(c.env.DB);
      try {
        installation = await repo.upsertInstallation(installationId);
      } catch {
        installation = {
          id: installationId,
          created_at: new Date().toISOString(),
          last_active_at: new Date().toISOString(),
          is_pro: 0,
          pro_expires_at: null,
        };
      }
    } else {
      installation = {
        id: installationId,
        created_at: new Date().toISOString(),
        last_active_at: new Date().toISOString(),
        is_pro: 0,
        pro_expires_at: null,
      };
    }

    c.set('installation', installation);
    c.set('installationId', installationId);
    await next();
  };
};
