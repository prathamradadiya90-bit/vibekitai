import { safeFetch } from './safe_fetch';

interface GoogleKey {
  keyId: number | string;
  base64: string;
}

const DEFAULT_KEY_URL = 'https://gstatic.com/admob/reward/verifier-keys.json';
const CACHE_TTL_MS = 24 * 60 * 60 * 1000; // 24 hours
const keyCacheByUrl = new Map<string, { keys: GoogleKey[]; fetchedAt: number }>();

export async function getAdMobPublicKeys(
  keyUrl?: string,
  allowLocalhostInDev: boolean = false,
  forceRefresh: boolean = false
): Promise<GoogleKey[]> {
  const url = keyUrl || DEFAULT_KEY_URL;
  const now = Date.now();
  const cached = keyCacheByUrl.get(url);

  if (!forceRefresh && cached && now - cached.fetchedAt < CACHE_TTL_MS && cached.keys.length > 0) {
    return cached.keys;
  }

  try {
    const res = await safeFetch(
      url,
      { headers: { Accept: 'application/json' } },
      allowLocalhostInDev
    );
    if (!res.ok) {
      throw new Error(`Failed to fetch AdMob public keys: HTTP ${res.status}`);
    }
    const data = (await res.json()) as { keys?: GoogleKey[] };
    const keys = Array.isArray(data?.keys) ? data.keys : [];
    if (keys.length > 0) {
      keyCacheByUrl.set(url, { keys, fetchedAt: now });
      return keys;
    }
    return cached?.keys || [];
  } catch (err) {
    console.warn('Could not fetch remote AdMob public keys, using cached or fallback:', err);
    return cached?.keys || [];
  }
}

function base64ToUint8Array(base64: string): Uint8Array {
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

function derToP1363(der: Uint8Array): Uint8Array {
  if (der[0] !== 0x30) {
    return der;
  }
  let offset = 2;
  if (der[offset] !== 0x02) throw new Error('Invalid DER signature');
  const rLen = der[offset + 1];
  if (rLen === undefined) throw new Error('Invalid DER signature length');
  offset += 2;
  let r = der.slice(offset, offset + rLen);
  offset += rLen;

  if (der[offset] !== 0x02) throw new Error('Invalid DER signature');
  const sLen = der[offset + 1];
  if (sLen === undefined) throw new Error('Invalid DER signature length');
  offset += 2;
  let s = der.slice(offset, offset + sLen);

  if (r.length === 33 && r[0] === 0x00) r = r.slice(1);
  if (s.length === 33 && s[0] === 0x00) s = s.slice(1);

  const p1363 = new Uint8Array(64);
  p1363.set(r, 32 - r.length);
  p1363.set(s, 64 - s.length);
  return p1363;
}

export async function verifyAdMobSsvSignature(
  queryString: string,
  keyId: string,
  signature: string,
  keyUrl?: string,
  allowLocalhostInDev: boolean = false
): Promise<boolean> {
  let keys = await getAdMobPublicKeys(keyUrl, allowLocalhostInDev, false);
  let matchedKey = keys.find((k) => String(k.keyId) === String(keyId));

  if (!matchedKey) {
    // Handle Google key rotation inside 24h TTL with a single forced refresh
    keys = await getAdMobPublicKeys(keyUrl, allowLocalhostInDev, true);
    matchedKey = keys.find((k) => String(k.keyId) === String(keyId));
  }

  if (!matchedKey) {
    console.warn(`AdMob key_id ${keyId} not found in key set`);
    return false;
  }

  try {
    let messageToVerify: string;
    const sigParamIdx = queryString.indexOf('&signature=');
    if (sigParamIdx !== -1 && queryString.indexOf('&key_id=') > sigParamIdx === false) {
      // Standard AdMob suffix placement: signed payload is everything prior to &signature=
      messageToVerify = queryString.substring(0, sigParamIdx);
    } else {
      // Reordered query params (including leading signature=...): strip signature safely
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

    const sigBytes = base64ToUint8Array(decodeURIComponent(signature));
    const p1363Sig = derToP1363(sigBytes);

    return await crypto.subtle.verify(
      { name: 'ECDSA', hash: 'SHA-256' },
      cryptoKey,
      p1363Sig,
      dataBytes
    );
  } catch (err) {
    console.error('AdMob SSV ECDSA verification exception:', err);
    return false;
  }
}
