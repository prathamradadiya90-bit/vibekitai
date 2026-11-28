/**
 * SSRF-Safe Outbound HTTP Client
 * Enforces strict domain allowlisting, blocks private IP ranges/metadata endpoints,
 * and re-validates targets across HTTP redirects.
 */

const ALLOWED_HOSTS = new Set([
  'generativelanguage.googleapis.com',
  'api.groq.com',
  'api.openai.com',
  'openrouter.ai',
  'api.together.xyz',
  'api.deepseek.com',
  'api.mistral.ai',
  'admob.googleapis.com',
  'gstatic.com',
  'www.gstatic.com',
  'playintegrity.googleapis.com',
  'androidpublisher.googleapis.com',
  'oauth2.googleapis.com',
  'accounts.google.com',
]);

const BLOCKED_IP_PATTERNS = [
  /^127\./, // Loopback
  /^10\./, // Private Class A
  /^172\.(1[6-9]|2[0-9]|3[0-1])\./, // Private Class B
  /^192\.168\./, // Private Class C
  /^169\.254\./, // Link-local / Cloud metadata (AWS/GCP/Azure)
  /^0\./, // Broadcast
  /^localhost$/i,
  /^\[::\]$/, // IPv6 unspecified
  /^\[::1\]$/, // IPv6 loopback
  /^\[::ffff:/i, // IPv4-mapped IPv6
  /^\[fe80:/i, // IPv6 link-local
  /^\[fc00:/i, // IPv6 unique local fc00::/7
  /^\[fd[0-9a-f]{2}:/i, // IPv6 unique local fd00::/8
];

export class SecuritySSRFError extends Error {
  constructor(message: string) {
    super(`SSRF Violation: ${message}`);
    this.name = 'SecuritySSRFError';
  }
}

/**
 * Validates that an outbound target URL strictly belongs to allowlisted domains.
 */
export function validateOutboundUrl(rawUrl: string, allowLocalhostInDev = false): URL {
  let url: URL;
  try {
    url = new URL(rawUrl);
  } catch {
    throw new SecuritySSRFError('Malformed URL');
  }

  // Also allow Cloudflare Access JWKS domains dynamically validated at admin auth time?
  // Note: Cloudflare Access team domains end with `.cloudflareaccess.com`.
  const isCfAccessHost =
    url.protocol === 'https:' &&
    /^[a-z0-9-]+\.cloudflareaccess\.com$/i.test(url.hostname);

  // 1. Enforce HTTPS (allow HTTP on localhost only in development/testing)
  if (url.protocol !== 'https:') {
    const isLocalhost = url.hostname === 'localhost' || url.hostname === '127.0.0.1';
    if (!allowLocalhostInDev || !isLocalhost) {
      throw new SecuritySSRFError('Insecure protocol: only HTTPS is permitted for outbound requests');
    }
  }

  // 2. Reject private network ranges and metadata IPs
  for (const pattern of BLOCKED_IP_PATTERNS) {
    if (pattern.test(url.hostname)) {
      if (allowLocalhostInDev && (url.hostname === 'localhost' || url.hostname === '127.0.0.1')) {
        continue;
      }
      throw new SecuritySSRFError(`Prohibited internal or metadata destination: ${url.hostname}`);
    }
  }

  // 3. Allowlist validation for production hosts
  if (!ALLOWED_HOSTS.has(url.hostname) && !isCfAccessHost) {
    if (allowLocalhostInDev && (url.hostname === 'localhost' || url.hostname === '127.0.0.1')) {
      return url;
    }
    throw new SecuritySSRFError(`Host not in approved outbound allowlist: ${url.hostname}`);
  }

  return url;
}

const MAX_REDIRECT_HOPS = 3;

/**
 * SSRF-Safe fetch wrapper that validates every redirect Location before following it.
 */
export async function safeFetch(
  rawUrl: string,
  init?: RequestInit,
  allowLocalhostInDev = false
): Promise<Response> {
  let currentUrl = validateOutboundUrl(rawUrl, allowLocalhostInDev);
  let currentInit: RequestInit = { ...init, redirect: 'manual' };

  for (let hop = 0; hop <= MAX_REDIRECT_HOPS; hop++) {
    const response = await fetch(currentUrl.toString(), currentInit);
    const isRedirect = response.status >= 300 && response.status < 400;
    const location = response.headers.get('location');

    if (!isRedirect || !location) {
      return response;
    }

    if (hop === MAX_REDIRECT_HOPS) {
      throw new SecuritySSRFError('Exceeded maximum safe redirect hops');
    }

    const nextRaw = new URL(location, currentUrl).toString();
    currentUrl = validateOutboundUrl(nextRaw, allowLocalhostInDev);

    // Strip Authorization header on cross-origin redirect and downgrade 301/302/303 to GET
    const nextHeaders = new Headers(currentInit.headers);
    if (currentUrl.origin !== new URL(rawUrl).origin) {
      nextHeaders.delete('Authorization');
    }
    const method =
      response.status === 307 || response.status === 308
        ? currentInit.method
        : 'GET';
    currentInit = {
      ...currentInit,
      method,
      headers: nextHeaders,
      ...(method === 'GET' ? { body: undefined } : {}),
    };
  }

  throw new SecuritySSRFError('Unexpected redirect termination');
}
