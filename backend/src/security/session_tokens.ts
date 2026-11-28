/**
 * Ephemeral HMAC-SHA256 Session Token Generator & Verifier
 * Pure Web Crypto API (supported natively across Cloudflare Workers isolates)
 */

export interface SessionPayload {
  sub: string; // installation_id
  dev: string; // device integrity hash
  iat: number;
  exp: number;
}

function bytesToBase64Url(bytes: Uint8Array): string {
  let binary = '';
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]!);
  }
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function utf8ToBase64Url(str: string): string {
  return bytesToBase64Url(new TextEncoder().encode(str));
}

function base64UrlToBytes(str: string): Uint8Array {
  let base64 = str.replace(/-/g, '+').replace(/_/g, '/');
  while (base64.length % 4) {
    base64 += '=';
  }
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

function base64UrlDecodeUtf8(str: string): string {
  return new TextDecoder().decode(base64UrlToBytes(str));
}

async function getHmacKey(secret: string): Promise<CryptoKey> {
  const enc = new TextEncoder();
  return await crypto.subtle.importKey(
    'raw',
    enc.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign', 'verify']
  );
}

export async function mintSessionToken(
  installationId: string,
  deviceHash: string,
  secret: string = 'vibekit_default_session_secret_rotate_in_prod',
  ttlSeconds: number = 900 // 15 minutes
): Promise<string> {
  if (!secret) {
    throw new Error('Session signing secret must be non-empty.');
  }
  const iat = Math.floor(Date.now() / 1000);
  const exp = iat + ttlSeconds;

  const header = { alg: 'HS256', typ: 'JWT' };
  const payload: SessionPayload = {
    sub: installationId,
    dev: deviceHash,
    iat,
    exp,
  };

  const encodedHeader = utf8ToBase64Url(JSON.stringify(header));
  const encodedPayload = utf8ToBase64Url(JSON.stringify(payload));
  const message = `${encodedHeader}.${encodedPayload}`;

  const key = await getHmacKey(secret);
  const signatureBuffer = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(message));
  const signature = bytesToBase64Url(new Uint8Array(signatureBuffer));

  return `${message}.${signature}`;
}

export async function verifySessionToken(
  token: string,
  secret: string
): Promise<SessionPayload | null> {
  try {
    if (!secret) return null;
    const parts = token.split('.');
    if (parts.length !== 3) return null;

    const [encodedHeader, encodedPayload, signature] = parts;
    if (!encodedHeader || !encodedPayload || !signature) return null;

    const message = `${encodedHeader}.${encodedPayload}`;
    const key = await getHmacKey(secret);
    const sigBytes = base64UrlToBytes(signature);

    const isValid = await crypto.subtle.verify('HMAC', key, sigBytes, new TextEncoder().encode(message));
    if (!isValid) return null;

    const payload = JSON.parse(base64UrlDecodeUtf8(encodedPayload)) as SessionPayload;
    const now = Math.floor(Date.now() / 1000);
    if (
      typeof payload?.sub !== 'string' ||
      payload.sub.length === 0 ||
      typeof payload?.dev !== 'string' ||
      typeof payload?.iat !== 'number' ||
      !Number.isFinite(payload.iat) ||
      payload.iat > now + 60 ||
      typeof payload?.exp !== 'number' ||
      !Number.isFinite(payload.exp) ||
      payload.exp < now
    ) {
      return null;
    }

    return payload;
  } catch {
    return null;
  }
}
