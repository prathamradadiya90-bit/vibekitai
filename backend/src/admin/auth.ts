import { MiddlewareHandler } from 'hono';
import { AppHonoEnv, AdminRole, AdminUser } from '../types';
import { AuthError, ForbiddenError } from '../errors/app_error';
import { timingSafeEqual } from '../security/crypto_timing';
import { safeFetch } from '../security/safe_fetch';

interface CfJwk {
  kid: string;
  kty: string;
  alg?: string;
  use?: string;
  n?: string;
  e?: string;
}

const jwksCache = new Map<string, { keys: CfJwk[]; fetchedAtMs: number }>();
const JWKS_CACHE_TTL_MS = 60 * 60 * 1000; // 1 hour

function base64UrlToUint8Array(base64Url: string): Uint8Array {
  let base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
  while (base64.length % 4) base64 += '=';
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

function decodeJwtPart(part: string): Record<string, unknown> | null {
  try {
    const bytes = base64UrlToUint8Array(part);
    const jsonPayload = new TextDecoder().decode(bytes);
    return JSON.parse(jsonPayload) as Record<string, unknown>;
  } catch {
    return null;
  }
}

async function fetchCfAccessKeys(teamName: string, forceRefresh = false): Promise<CfJwk[]> {
  const sanitizedTeam = teamName.trim().toLowerCase().replace(/[^a-z0-9-]/g, '');
  if (!sanitizedTeam) return [];

  const now = Date.now();
  const cached = jwksCache.get(sanitizedTeam);
  if (!forceRefresh && cached && now - cached.fetchedAtMs < JWKS_CACHE_TTL_MS) {
    return cached.keys;
  }

  const certsUrl = `https://${sanitizedTeam}.cloudflareaccess.com/cdn-cgi/access/certs`;
  try {
    const res = await safeFetch(certsUrl, { headers: { Accept: 'application/json' } }, false);
    if (!res.ok) return cached?.keys || [];
    const data = (await res.json()) as { keys?: CfJwk[] };
    const keys = Array.isArray(data?.keys) ? data.keys : [];
    if (keys.length > 0) {
      jwksCache.set(sanitizedTeam, { keys, fetchedAtMs: now });
      return keys;
    }
    return cached?.keys || [];
  } catch {
    return cached?.keys || [];
  }
}

async function verifyCfAccessJwtSignature(
  token: string,
  teamName: string
): Promise<Record<string, unknown> | null> {
  const parts = token.split('.');
  if (parts.length !== 3) return null;
  const [headerPart, payloadPart, sigPart] = parts;
  if (!headerPart || !payloadPart || !sigPart) return null;

  const header = decodeJwtPart(headerPart);
  const payload = decodeJwtPart(payloadPart);
  if (!header || !payload) return null;
  if (header['alg'] !== 'RS256' || typeof header['kid'] !== 'string') return null;

  const expectedIss = `https://${teamName.trim().toLowerCase()}.cloudflareaccess.com`;
  if (payload['iss'] !== expectedIss) return null;

  let keys = await fetchCfAccessKeys(teamName, false);
  let jwk = keys.find((k) => k.kid === header['kid'] && k.kty === 'RSA');
  if (!jwk) {
    keys = await fetchCfAccessKeys(teamName, true);
    jwk = keys.find((k) => k.kid === header['kid'] && k.kty === 'RSA');
  }
  if (!jwk) return null;

  try {
    const cryptoKey = await crypto.subtle.importKey(
      'jwk',
      jwk as unknown as JsonWebKey,
      { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
      false,
      ['verify']
    );
    const sigBytes = base64UrlToUint8Array(sigPart);
    const msgBytes = new TextEncoder().encode(`${headerPart}.${payloadPart}`);
    const valid = await crypto.subtle.verify('RSASSA-PKCS1-v1_5', cryptoKey, sigBytes, msgBytes);
    return valid ? payload : null;
  } catch {
    return null;
  }
}

/**
 * Resolves role from configuration or environment
 */
function resolveRole(email: string, env: AppHonoEnv['Bindings']): AdminRole | null {
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

  if (env.ADMIN_ALLOWED_EMAILS) {
    const entries = env.ADMIN_ALLOWED_EMAILS.split(',');
    for (const entry of entries) {
      const colonIdx = entry.indexOf(':');
      const rawEmail = colonIdx === -1 ? entry : entry.slice(0, colonIdx);
      const rawRole = colonIdx === -1 ? '' : entry.slice(colonIdx + 1);
      const entryEmail = rawEmail.trim();
      const entryRole = rawRole.trim().toLowerCase();
      if (entryEmail && entryEmail.toLowerCase() === email.toLowerCase()) {
        if (entryRole === 'viewer') return 'viewer';
        if (entryRole === 'admin') return 'admin';
        return null;
      }
    }
  }

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
    c.header('X-Robots-Tag', 'noindex, nofollow');
    c.header('X-Frame-Options', 'DENY');
    c.header('X-Content-Type-Options', 'nosniff');
    c.header(
      'Content-Security-Policy',
      "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self'"
    );

    const cfAssertion = c.req.header('Cf-Access-Jwt-Assertion') || c.req.header('cf-access-jwt-assertion');
    let adminUser: AdminUser | null = null;
    const isDevOrTest = c.env.ENVIRONMENT === 'development' || c.env.ENVIRONMENT === 'test';

    if (cfAssertion) {
      let payload: Record<string, unknown> | null = null;
      if (c.env.CF_ACCESS_TEAM_NAME) {
        // Production / configured team: strict cryptographic RS256 JWKS verification
        payload = await verifyCfAccessJwtSignature(cfAssertion, c.env.CF_ACCESS_TEAM_NAME);
      } else if (isDevOrTest) {
        // Local dev / unit tests without live Access team: decode payload only in dev/test
        const parts = cfAssertion.split('.');
        if (parts.length >= 2 && parts[1]) {
          payload = decodeJwtPart(parts[1]);
        }
      }

      const nowSec = Math.floor(Date.now() / 1000);
      const hasValidExp =
        typeof payload?.['exp'] === 'number' &&
        Number.isFinite(payload['exp'] as number) &&
        (payload['exp'] as number) > nowSec;

      const audMatches = c.env.CF_ACCESS_AUD
        ? Array.isArray(payload?.['aud'])
          ? (payload['aud'] as string[]).includes(c.env.CF_ACCESS_AUD)
          : payload?.['aud'] === c.env.CF_ACCESS_AUD
        : isDevOrTest;

      if (hasValidExp && audMatches && payload && typeof payload['email'] === 'string') {
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

    if (!adminUser) {
      const authHeader = c.req.header('Authorization');
      const token = authHeader?.startsWith('Bearer ') ? authHeader.substring(7).trim() : null;
      const cookieHeader = c.req.header('Cookie');
      const cookiePair = cookieHeader
        ?.split(';')
        .map((s) => s.trim())
        .find((s) => s.startsWith('vibekit_admin_session='));
      const cookieToken = cookiePair ? cookiePair.slice('vibekit_admin_session='.length) : undefined;

      const providedToken = token || cookieToken;
      const adminSecret = c.env.ADMIN_SECRET || (isDevOrTest ? 'dev_admin_secret_key_change_in_prod' : '');

      if (providedToken && adminSecret) {
        const isSuperAdmin = await timingSafeEqual(providedToken, adminSecret);
        if (isSuperAdmin) {
          adminUser = {
            email: 'superadmin@vibekit.ai',
            role: 'admin',
            source: 'session_token',
          };
        } else {
          const colonIdx = providedToken.indexOf(':');
          if (colonIdx > 0) {
            const emailPart = providedToken.slice(0, colonIdx);
            const secretPart = providedToken.slice(colonIdx + 1);
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
    }

    if (!adminUser) {
      throw new AuthError('Access denied. Valid Cloudflare Access assertion or Admin token required.');
    }

    c.set('adminUser', adminUser);

    if (c.req.method !== 'GET' && c.req.method !== 'HEAD' && c.req.method !== 'OPTIONS') {
      if (adminUser.role !== 'admin') {
        throw new ForbiddenError('Viewer accounts are prohibited from performing mutating operations.');
      }
      if (!c.req.header('X-Admin-Action')) {
        throw new ForbiddenError('Mutating admin actions require the X-Admin-Action confirmation header.');
      }
    }

    await next();
  };
};
