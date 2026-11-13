/**
 * Ephemeral HMAC-SHA256 Session Token Generator & Verifier
 * Pure Web Crypto API (supported natively across Cloudflare Workers isolates)
 */

interface SessionPayload {
  sub: string; // installation_id
  dev: string; // device integrity hash
  iat: number;
  exp: number;
}

function base64UrlEncode(str: string): string {
  return btoa(str).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function base64UrlDecode(str: string): string {
  let base64 = str.replace(/-/g, '+').replace(/_/g, '/');
  while (base64.length % 4) {
    base64 += '=';
  }
  return atob(base64);
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
  const iat = Math.floor(Date.now() / 1000);
  const exp = iat + ttlSeconds;

  const header = { alg: 'HS256', typ: 'JWT' };
  const payload: SessionPayload = {
    sub: installationId,
    dev: deviceHash,
    iat,
    exp,
  };

  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));
  const message = `${encodedHeader}.${encodedPayload}`;

  const key = await getHmacKey(secret);
  const enc = new TextEncoder();
  const signatureBuffer = await crypto.subtle.sign('HMAC', key, enc.encode(message));
  const signatureBytes = Array.from(new Uint8Array(signatureBuffer));
  const signature = base64UrlEncode(String.fromCharCode(...signatureBytes));

  return `${message}.${signature}`;
}

export async function verifySessionToken(
  token: string,
  secret: string = 'vibekit_default_session_secret_rotate_in_prod'
): Promise<SessionPayload | null> {
  try {
    const parts = token.split('.');
    if (parts.length !== 3) return null;

    const [encodedHeader, encodedPayload, signature] = parts;
    if (!encodedHeader || !encodedPayload || !signature) return null;

    const message = `${encodedHeader}.${encodedPayload}`;
    const key = await getHmacKey(secret);

    // Decode signature
    const sigBinary = base64UrlDecode(signature);
    const sigBytes = new Uint8Array(sigBinary.length);
    for (let i = 0; i < sigBinary.length; i++) {
      sigBytes[i] = sigBinary.charCodeAt(i);
    }

    const enc = new TextEncoder();
    const isValid = await crypto.subtle.verify('HMAC', key, sigBytes, enc.encode(message));
    if (!isValid) return null;

    const payload = JSON.parse(base64UrlDecode(encodedPayload)) as SessionPayload;
    const now = Math.floor(Date.now() / 1000);
    if (payload.exp < now) {
      return null; // Expired
    }

    return payload;
  } catch {
    return null;
  }
}
