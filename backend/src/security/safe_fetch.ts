/**
 * SSRF-Safe Outbound HTTP Client
 * Enforces strict domain allowlisting and blocks private IP ranges/metadata endpoints.
 */

const ALLOWED_HOSTS = new Set([
  'generativelanguage.googleapis.com',
  'api.groq.com',
  'api.openai.com',
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
  /^\[::1\]$/, // IPv6 loopback
  /^\[fe80:/i, // IPv6 link-local
  /^\[fc00:/i, // IPv6 unique local
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
  if (!ALLOWED_HOSTS.has(url.hostname)) {
    if (allowLocalhostInDev && (url.hostname === 'localhost' || url.hostname === '127.0.0.1')) {
      return url;
    }
    throw new SecuritySSRFError(`Host not in approved outbound allowlist: ${url.hostname}`);
  }

  return url;
}

/**
 * SSRF-Safe fetch wrapper
 */
export async function safeFetch(
  rawUrl: string,
  init?: RequestInit,
  allowLocalhostInDev = false
): Promise<Response> {
  const validatedUrl = validateOutboundUrl(rawUrl, allowLocalhostInDev);
  return await fetch(validatedUrl.toString(), init);
}
