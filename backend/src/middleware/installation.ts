import { MiddlewareHandler } from 'hono';
import { AppHonoEnv, InstallationRecord } from '../types';
import { InstallationsRepository } from '../db/installations.repo';
import { BansRepository } from '../db/bans.repo';
import { AccountBannedError } from '../errors/app_error';

export const installationMiddleware = (): MiddlewareHandler<AppHonoEnv> => {
  return async (c, next) => {
    // Exempt admin routes from mobile installation tracking
    if (c.req.path.startsWith('/v1/admin')) {
      return await next();
    }

    const rawInstanceId = c.req.header('X-App-Instance-Id')?.trim();
    const installationId = rawInstanceId && rawInstanceId.length > 0 ? rawInstanceId : 'anonymous_default';
    const requestId =
      c.req.header('X-Request-Id')?.trim() ||
      `req_${Date.now()}_${Math.random().toString(36).substring(7)}`;

    c.header('X-Request-Id', requestId);
    c.set('requestId', requestId);

    // Fast cached ban verification (exempt privacy data erasure)
    if (c.env.DB && c.req.path !== '/v1/privacy/delete-data') {
      try {
        const bansRepo = new BansRepository(c.env.DB);
        const isBanned = await bansRepo.isBanned(installationId);
        if (isBanned) {
          throw new AccountBannedError('This installation has been suspended for policy violations.');
        }
      } catch (err) {
        if (err instanceof AccountBannedError) throw err;
      }
    }

    const repo = new InstallationsRepository(c.env.DB);
    let installation: InstallationRecord;

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

    c.set('installation', installation);
    await next();
  };
};
