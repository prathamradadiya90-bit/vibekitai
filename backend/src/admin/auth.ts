import { MiddlewareHandler } from 'hono';
import { AppHonoEnv, AdminRole, AdminUser } from '../types';
import { AuthError, ForbiddenError } from '../errors/app_error';
import { timingSafeEqual } from '../security/crypto_timing';

/**
 * Parses payload from a JWT without external heavy libraries
 */
function parseJwtPayload(token: string): Record<string, unknown> | null {
  try {
    const parts = token.split('.');
    if (parts.length < 2) return null;
    const base64Url = parts[1];
    if (!base64Url) return null;
    const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
    const jsonPayload = decodeURIComponent(
      atob(base64)
        .split('')
        .map((c) => '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2))
        .join('')
    );
    return JSON.parse(jsonPayload);
  } catch {
    return null;
  }
}

/**
 * Resolves role from configuration or environment
 */
function resolveRole(email: string, env: AppHonoEnv['Bindings']): AdminRole | null {
  // 1. Check ADMIN_USERS_JSON: {"admin@vibekit.ai": "admin", "analyst@vibekit.ai": "viewer"}
  if (env.ADMIN_USERS_JSON) {
    try {
      const mapping = JSON.parse(env.ADMIN_USERS_JSON) as Record<string, string>;
      const matched = mapping[email.toLowerCase()];
      if (matched === 'admin' || matched === 'viewer') {
        return matched as AdminRole;
      }
    } catch {
      // Ignore parse failure and fall through
    }
  }

  // 2. Check ADMIN_ALLOWED_EMAILS: "admin@vibekit.ai:admin,viewer@vibekit.ai:viewer"
  if (env.ADMIN_ALLOWED_EMAILS) {
    const entries = env.ADMIN_ALLOWED_EMAILS.split(',');
    for (const entry of entries) {
      const [entryEmail, entryRole] = entry.trim().split(':');
      if (entryEmail && entryEmail.toLowerCase() === email.toLowerCase()) {
        return entryRole === 'viewer' ? 'viewer' : 'admin';
      }
    }
  }

  // 3. Fallback in development or testing environments
  if (env.ENVIRONMENT === 'development' || env.ENVIRONMENT === 'test') {
    if (email.includes('viewer')) return 'viewer';
    return 'admin';
  }

  return null;
}

/**
 * Admin Authentication & RBAC Middleware
 */
export const adminAuthMiddleware = (): MiddlewareHandler<AppHonoEnv> => {
  return async (c, next) => {
    // 1. Add strict security headers
    c.header('X-Robots-Tag', 'noindex, nofollow');
    c.header('X-Frame-Options', 'DENY');
    c.header('X-Content-Type-Options', 'nosniff');
    c.header(
      'Content-Security-Policy',
      "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self'"
    );

    // 2. Extract Identity: Check Cloudflare Access Assertion Header
    const cfAssertion = c.req.header('Cf-Access-Jwt-Assertion') || c.req.header('cf-access-jwt-assertion');
    let adminUser: AdminUser | null = null;
    const isDevOrTest = c.env.ENVIRONMENT === 'development' || c.env.ENVIRONMENT === 'test';

    if (cfAssertion) {
      const payload = parseJwtPayload(cfAssertion);
      const nowSec = Math.floor(Date.now() / 1000);
      const isExpired = typeof payload?.['exp'] === 'number' && (payload['exp'] as number) < nowSec;

      // Validate AUD claim in production
      const audMatches = !c.env.CF_ACCESS_AUD || (
        Array.isArray(payload?.['aud'])
          ? (payload['aud'] as string[]).includes(c.env.CF_ACCESS_AUD)
          : payload?.['aud'] === c.env.CF_ACCESS_AUD
      );

      // In production, require unexpired assertion with matching AUD and recognized email
      if (!isExpired && audMatches && payload && typeof payload['email'] === 'string') {
        const email = payload['email'];
        const role = resolveRole(email, c.env);
        if (role) {
          adminUser = {
            email,
            role,
            source: 'cf_access',
          };
        }
      }
    }

    // 3. Fallback: Check Signed Session / Secret Token
    if (!adminUser) {
      const authHeader = c.req.header('Authorization');
      const token = authHeader?.startsWith('Bearer ') ? authHeader.substring(7).trim() : null;
      const cookieHeader = c.req.header('Cookie');
      const cookieToken = cookieHeader
        ?.split(';')
        .map((s) => s.trim())
        .find((s) => s.startsWith('vibekit_admin_session='))
        ?.split('=')[1];

      const providedToken = token || cookieToken;
      // In production, fallback dev secret is prohibited
      const adminSecret = c.env.ADMIN_SECRET || (isDevOrTest ? 'dev_admin_secret_key_change_in_prod' : '');

      if (providedToken && adminSecret) {
        // If providedToken contains email:secret or is a valid token matching ADMIN_SECRET
        const isSuperAdmin = await timingSafeEqual(providedToken, adminSecret);
        if (isSuperAdmin) {
          adminUser = {
            email: 'superadmin@vibekit.ai',
            role: 'admin',
            source: 'session_token',
          };
        } else if (providedToken.includes(':')) {
          const [emailPart, secretPart] = providedToken.split(':');
          if (emailPart && secretPart && (await timingSafeEqual(secretPart, adminSecret))) {
            const role = resolveRole(emailPart, c.env) || 'viewer';
            adminUser = {
              email: emailPart,
              role,
              source: 'session_token',
            };
          }
        }
      }
    }

    if (!adminUser) {
      throw new AuthError('Access denied. Valid Cloudflare Access assertion or Admin token required.');
    }

    // 4. Role Enforcement: Viewer cannot execute mutating actions
    const method = c.req.method.toUpperCase();
    const isMutation = ['POST', 'PUT', 'DELETE', 'PATCH'].includes(method);

    if (isMutation && adminUser.role !== 'admin') {
      throw new ForbiddenError('Action denied. Read-only viewer role cannot perform mutating operations.');
    }

    // 5. CSRF protection on mutating requests
    if (isMutation) {
      const csrfHeader = c.req.header('X-Admin-Action');
      const contentType = c.req.header('Content-Type');
      if (!csrfHeader && (!contentType || !contentType.includes('application/json'))) {
        throw new ForbiddenError('CSRF protection: Missing X-Admin-Action header on mutating request.');
      }
    }

    c.set('adminUser', adminUser);
    await next();
  };
};
