// Authoritative Google Play Developer API verification (subscriptions v2 + one-time products).
// Fails closed: without a service account, purchases are rejected unless running the
// test suite (ENVIRONMENT=test) or explicitly opted in for local dev (ALLOW_UNVERIFIED_PURCHASES=true).

import { Env } from '../types';

export const SUBSCRIPTION_PRODUCTS = new Set([
  'vibekit_pro_weekly',
  'vibekit_pro_monthly',
  'vibekit_pro_yearly',
]);
export const LIFETIME_PRODUCTS = new Set(['vibekit_pro_lifetime']);
export const CREDIT_PACK_PRODUCTS: Record<string, number> = {
  vibekit_credits_50: 50,
  vibekit_credits_25: 25,
};

export type EntitlementStatus =
  | 'ACTIVE'
  | 'IN_GRACE_PERIOD'
  | 'ON_HOLD'
  | 'PAUSED'
  | 'CANCELED'
  | 'EXPIRED'
  | 'REVOKED';

export type SubscriptionVerification =
  | {
      ok: true;
      productId: string;
      orderId: string | null;
      status: EntitlementStatus;
      expiresAt: string | null;
      entitled: boolean;
    }
  | { ok: false; reason: string; retryable: boolean };

export type ProductVerification =
  | { ok: true; productId: string; orderId: string | null; purchased: boolean; quantity: number }
  | { ok: false; reason: string; retryable: boolean };

const API_BASE = 'https://androidpublisher.googleapis.com/androidpublisher/v3/applications';

export function isUnverifiedBillingAllowed(env: Env): boolean {
  return (
    !env.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON &&
    (env.ENVIRONMENT === 'test' || env.ALLOW_UNVERIFIED_PURCHASES === 'true')
  );
}

function packageNameOf(env: Env): string {
  return env.GOOGLE_PLAY_PACKAGE_NAME || 'com.vibekit.ai';
}

function mockPeriodDays(productId: string): number {
  return productId.includes('yearly') ? 365 : productId.includes('weekly') ? 7 : 30;
}

// ---------------------------------------------------------------------------
// OAuth2 service-account access token (RS256 JWT bearer grant), cached per isolate
// ---------------------------------------------------------------------------
let cachedToken: { token: string; expiresAtMs: number } | null = null;

function base64UrlEncode(data: ArrayBuffer | Uint8Array | string): string {
  const bytes =
    typeof data === 'string'
      ? new TextEncoder().encode(data)
      : data instanceof Uint8Array
      ? data
      : new Uint8Array(data);
  let binary = '';
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function pemToDer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN [^-]+-----/, '')
    .replace(/-----END [^-]+-----/, '')
    .replace(/\\n/g, '')
    .replace(/\s+/g, '');
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

export async function getGoogleAccessToken(serviceAccountJson: string): Promise<string> {
  if (cachedToken && cachedToken.expiresAtMs - 60_000 > Date.now()) {
    return cachedToken.token;
  }

  const creds = JSON.parse(serviceAccountJson) as { client_email: string; private_key: string };
  const iat = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', typ: 'JWT' };
  const claim = {
    iss: creds.client_email,
    scope: 'https://www.googleapis.com/auth/androidpublisher',
    aud: 'https://oauth2.googleapis.com/token',
    iat,
    exp: iat + 3600,
  };

  const unsigned = `${base64UrlEncode(JSON.stringify(header))}.${base64UrlEncode(JSON.stringify(claim))}`;
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToDer(creds.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign']
  );
  const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(unsigned));
  const assertion = `${unsigned}.${base64UrlEncode(signature)}`;

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=${encodeURIComponent('urn:ietf:params:oauth:grant-type:jwt-bearer')}&assertion=${assertion}`,
  });
  if (!res.ok) {
    throw new Error(`Google OAuth token exchange failed: HTTP ${res.status}`);
  }
  const json = (await res.json()) as { access_token: string; expires_in: number };
  cachedToken = { token: json.access_token, expiresAtMs: Date.now() + json.expires_in * 1000 };
  return json.access_token;
}

async function playApi(env: Env, path: string, method: 'GET' | 'POST' = 'GET'): Promise<Response> {
  const accessToken = await getGoogleAccessToken(env.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON!);
  return fetch(`${API_BASE}/${encodeURIComponent(packageNameOf(env))}${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${accessToken}`,
      ...(method === 'POST' ? { 'Content-Type': 'application/json' } : {}),
    },
    body: method === 'POST' ? '{}' : undefined,
  });
}

function failureFromStatus(status: number): { ok: false; reason: string; retryable: boolean } {
  // 400/404/410: token unknown/invalid for this app -> permanent rejection
  const retryable = status === 429 || status >= 500 || status === 401 || status === 403;
  return { ok: false, reason: `PLAY_API_HTTP_${status}`, retryable };
}

const SUB_STATE_MAP: Record<string, EntitlementStatus | undefined> = {
  SUBSCRIPTION_STATE_ACTIVE: 'ACTIVE',
  SUBSCRIPTION_STATE_IN_GRACE_PERIOD: 'IN_GRACE_PERIOD',
  SUBSCRIPTION_STATE_ON_HOLD: 'ON_HOLD',
  SUBSCRIPTION_STATE_PAUSED: 'PAUSED',
  SUBSCRIPTION_STATE_CANCELED: 'CANCELED',
  SUBSCRIPTION_STATE_EXPIRED: 'EXPIRED',
};

/**
 * Verifies a subscription purchase token with purchases.subscriptionsv2.get and
 * acknowledges it if needed. Expiry always comes from Google, never from the client.
 */
export async function verifySubscriptionPurchase(
  env: Env,
  expectedProductId: string,
  purchaseToken: string
): Promise<SubscriptionVerification> {
  if (!env.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON) {
    if (!isUnverifiedBillingAllowed(env)) {
      return { ok: false, reason: 'BILLING_VERIFICATION_UNAVAILABLE', retryable: true };
    }
    return {
      ok: true,
      productId: expectedProductId,
      orderId: null,
      status: 'ACTIVE',
      expiresAt: new Date(Date.now() + mockPeriodDays(expectedProductId) * 86400000).toISOString(),
      entitled: true,
    };
  }

  try {
    const res = await playApi(env, `/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`);
    if (!res.ok) return failureFromStatus(res.status);

    const data = (await res.json()) as {
      subscriptionState?: string;
      latestOrderId?: string;
      acknowledgementState?: string;
      lineItems?: { productId: string; expiryTime?: string }[];
    };

    const lineItem = (data.lineItems || []).find((li) => li.productId === expectedProductId);
    if (!lineItem) {
      return { ok: false, reason: 'PRODUCT_MISMATCH', retryable: false };
    }

    const status = SUB_STATE_MAP[data.subscriptionState || ''];
    if (!status) {
      // PENDING / UNSPECIFIED / PENDING_PURCHASE_CANCELED
      return { ok: false, reason: `SUBSCRIPTION_NOT_ACTIVE_${data.subscriptionState}`, retryable: false };
    }

    const expiresAt = lineItem.expiryTime ? new Date(lineItem.expiryTime).toISOString() : null;
    const notExpired = !!expiresAt && new Date(expiresAt) > new Date();
    // CANCELED = auto-renew off; user keeps access until expiry
    const entitled =
      notExpired && (status === 'ACTIVE' || status === 'IN_GRACE_PERIOD' || status === 'CANCELED');

    if (entitled && data.acknowledgementState === 'ACKNOWLEDGEMENT_STATE_PENDING') {
      const ack = await playApi(
        env,
        `/purchases/subscriptions/${encodeURIComponent(expectedProductId)}/tokens/${encodeURIComponent(purchaseToken)}:acknowledge`,
        'POST'
      );
      if (!ack.ok) console.warn('Subscription acknowledge failed:', ack.status);
    }

    return {
      ok: true,
      productId: expectedProductId,
      orderId: data.latestOrderId || null,
      status,
      expiresAt,
      entitled,
    };
  } catch (err: any) {
    console.error('Play subscription verification error:', err);
    return { ok: false, reason: 'PLAY_API_EXCEPTION', retryable: true };
  }
}

/**
 * Verifies a one-time product (lifetime pass or consumable credit pack) with
 * purchases.products.get. Acknowledges non-consumables; consumables are consumed by the client.
 */
export async function verifyProductPurchase(
  env: Env,
  productId: string,
  purchaseToken: string,
  opts: { acknowledge: boolean; mockOrderId?: string }
): Promise<ProductVerification> {
  if (!env.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON) {
    if (!isUnverifiedBillingAllowed(env)) {
      return { ok: false, reason: 'BILLING_VERIFICATION_UNAVAILABLE', retryable: true };
    }
    return { ok: true, productId, orderId: opts.mockOrderId || null, purchased: true, quantity: 1 };
  }

  try {
    const res = await playApi(
      env,
      `/purchases/products/${encodeURIComponent(productId)}/tokens/${encodeURIComponent(purchaseToken)}`
    );
    if (!res.ok) return failureFromStatus(res.status);

    const data = (await res.json()) as {
      purchaseState?: number; // 0 purchased, 1 canceled, 2 pending
      acknowledgementState?: number; // 0 pending, 1 acknowledged
      orderId?: string;
      quantity?: number;
    };

    const purchased = data.purchaseState === 0;
    if (purchased && opts.acknowledge && data.acknowledgementState === 0) {
      const ack = await playApi(
        env,
        `/purchases/products/${encodeURIComponent(productId)}/tokens/${encodeURIComponent(purchaseToken)}:acknowledge`,
        'POST'
      );
      if (!ack.ok) console.warn('Product acknowledge failed:', ack.status);
    }

    return {
      ok: true,
      productId,
      orderId: data.orderId || null,
      purchased,
      quantity: Math.max(1, data.quantity ?? 1),
    };
  } catch (err: any) {
    console.error('Play product verification error:', err);
    return { ok: false, reason: 'PLAY_API_EXCEPTION', retryable: true };
  }
}
