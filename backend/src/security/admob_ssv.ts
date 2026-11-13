import { safeFetch } from './safe_fetch';

interface GoogleKey {
  keyId: number | string;
  base64: string;
}

let cachedKeys: GoogleKey[] | null = null;
let keysFetchedAt = 0;
const CACHE_TTL_MS = 24 * 60 * 60 * 1000; // 24 hours

export async function getAdMobPublicKeys(keyUrl?: string): Promise<GoogleKey[]> {
  const now = Date.now();
  if (cachedKeys && now - keysFetchedAt < CACHE_TTL_MS) {
    return cachedKeys;
  }

  const url = keyUrl || 'https://gstatic.com/admob/reward/verifier-keys.json';
  try {
    const res = await safeFetch(url, {
      headers: { Accept: 'application/json' },
    }, true);
    if (!res.ok) {
      throw new Error(`Failed to fetch AdMob public keys: HTTP ${res.status}`);
    }
    const data = (await res.json()) as { keys: GoogleKey[] };
    cachedKeys = data.keys || [];
    keysFetchedAt = now;
    return cachedKeys;
  } catch (err) {
    console.warn('Could not fetch remote AdMob public keys, using cached or fallback:', err);
    return cachedKeys || [];
  }
}

// Convert base64 / base64url string to Uint8Array
function base64ToUint8Array(base64: string): Uint8Array {
  // Normalize base64url to standard base64
  let normalized = base64.replace(/-/g, '+').replace(/_/g, '/');
  while (normalized.length % 4 !== 0) {
    normalized += '=';
  }
  const binary = atob(normalized);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

// Convert DER-encoded ECDSA signature to IEEE P1363 (r || s) format required by Web Crypto
function derToP1363(der: Uint8Array): Uint8Array {
  if (der[0] !== 0x30) {
    // Already in raw r||s format
    return der;
  }
  let offset = 2;
  // Read r
  if (der[offset] !== 0x02) throw new Error('Invalid DER signature');
  const rLen = der[offset + 1];
  if (rLen === undefined) throw new Error('Invalid DER signature length');
  offset += 2;
  let r = der.slice(offset, offset + rLen);
  offset += rLen;

  // Read s
  if (der[offset] !== 0x02) throw new Error('Invalid DER signature');
  const sLen = der[offset + 1];
  if (sLen === undefined) throw new Error('Invalid DER signature length');
  offset += 2;
  let s = der.slice(offset, offset + sLen);

  // Strip leading zero padding if 33 bytes
  if (r.length === 33 && r[0] === 0x00) r = r.slice(1);
  if (s.length === 33 && s[0] === 0x00) s = s.slice(1);

  // Pad to 32 bytes if less
  const p1363 = new Uint8Array(64);
  p1363.set(r, 32 - r.length);
  p1363.set(s, 64 - s.length);
  return p1363;
}

export async function verifyAdMobSsvSignature(
  queryString: string,
  keyId: string,
  signature: string,
  keyUrl?: string
): Promise<boolean> {
  const keys = await getAdMobPublicKeys(keyUrl);
  const matchedKey = keys.find((k) => String(k.keyId) === String(keyId));

  if (!matchedKey) {
    console.warn(`AdMob key_id ${keyId} not found in key set`);
    return false;
  }

  try {
    // Official Google specification:
    // Message to verify is the raw query string prior to &signature= (or signature=)
    let messageToVerify: string;
    const sigParamIdx = queryString.indexOf('&signature=');
    if (sigParamIdx !== -1) {
      messageToVerify = queryString.substring(0, sigParamIdx);
    } else if (queryString.startsWith('signature=')) {
      messageToVerify = '';
    } else {
      // Fallback: strip signature parameter if placed elsewhere
      const params = new URLSearchParams(queryString);
      params.delete('signature');
      messageToVerify = params.toString();
    }
    const encoder = new TextEncoder();
    const dataBytes = encoder.encode(messageToVerify);

    const keyBytes = base64ToUint8Array(matchedKey.base64);
    const cryptoKey = await crypto.subtle.importKey(
      'spki',
      keyBytes,
      { name: 'ECDSA', namedCurve: 'P-256' },
      false,
      ['verify']
    );

    const rawSig = base64ToUint8Array(signature);
    const p1363Sig = derToP1363(rawSig);

    return await crypto.subtle.verify(
      { name: 'ECDSA', hash: 'SHA-256' },
      cryptoKey,
      p1363Sig,
      dataBytes
    );
  } catch (err) {
    console.error('AdMob SSV signature verification error:', err);
    return false;
  }
}
