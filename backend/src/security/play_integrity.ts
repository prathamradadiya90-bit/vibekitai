// Google Play Integrity API Helper & Anonymous Abuse Signal Accounting
// Zero raw IP addresses or device serials are ever persisted.

import { Env } from '../types';
import { getGoogleAccessToken } from './google_play';

export interface IntegrityVerdict {
  isValid: boolean;
  appLicensingVerdict?: string; // 'LICENSED' | 'UNLICENSED' | 'UNEVALUATED'
  deviceRecognitionVerdict?: string[]; // e.g. ['MEETS_BASIC_INTEGRITY', 'MEETS_STRONG_INTEGRITY']
  appRecognitionVerdict?: string;
  error?: string;
}

// SHA-256 hash helper for anonymous fingerprinting
export async function sha256Hex(input: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(input);
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, '0')).join('');
}

export async function verifyPlayIntegrityToken(
  token: string | undefined,
  packageName: string,
  env: Env,
  isCreditGrant = false
): Promise<IntegrityVerdict> {
  const isProd = env.ENVIRONMENT === 'production';

  if (!env.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON) {
    if (isProd) {
      return {
        isValid: !isCreditGrant,
        error: token ? 'PLAY_INTEGRITY_NOT_CONFIGURED' : 'MISSING_INTEGRITY_TOKEN',
      };
    }
    return {
      isValid: true,
      appLicensingVerdict: 'LICENSED',
      deviceRecognitionVerdict: ['MEETS_STRONG_INTEGRITY'],
      appRecognitionVerdict: 'PLAY_RECOGNIZED',
    };
  }

  if (env.ENVIRONMENT === 'test') {
    return {
      isValid: true,
      appLicensingVerdict: 'LICENSED',
      deviceRecognitionVerdict: ['MEETS_STRONG_INTEGRITY'],
      appRecognitionVerdict: 'PLAY_RECOGNIZED',
    };
  }

  if (!token) {
    return {
      isValid: !isCreditGrant,
      error: 'NO_TOKEN_PROVIDED',
    };
  }

  try {
    const response = await fetch(
      `https://playintegrity.googleapis.com/v1/${encodeURIComponent(packageName)}:decodeIntegrityToken`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${await getGoogleAccessToken(env.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON)}`,
        },
        body: JSON.stringify({ integrityToken: token }),
      }
    );

    if (!response.ok) {
      console.warn('Play Integrity API call failed with status:', response.status);
      return { isValid: !isCreditGrant, error: `API_HTTP_${response.status}` };
    }

    const payload = (await response.json()) as any;
    const tokenPayload = payload.tokenPayloadExternal || {};

    const licensing: string | undefined =
      tokenPayload.accountDetails?.appLicensingVerdict ??
      tokenPayload.appLicensingVerdict?.licensingStatus;
    const device: string[] = tokenPayload.deviceIntegrity?.deviceRecognitionVerdict || [];
    const app: string | undefined = tokenPayload.appIntegrity?.appRecognitionVerdict;
    const reqPkg: string | undefined = tokenPayload.requestDetails?.requestPackageName;

    const meetsDevice =
      device.includes('MEETS_BASIC_INTEGRITY') ||
      device.includes('MEETS_STRONG_INTEGRITY') ||
      device.includes('MEETS_DEVICE_INTEGRITY');
    const pkgValid = !reqPkg || reqPkg === packageName;
    const appValid = !isCreditGrant ? app !== 'UNRECOGNIZED_VERSION' : app === 'PLAY_RECOGNIZED';
    const licensingValid = !isCreditGrant || !licensing || licensing === 'LICENSED';

    return {
      isValid: meetsDevice && pkgValid && appValid && licensingValid,
      appLicensingVerdict: licensing,
      deviceRecognitionVerdict: device,
      appRecognitionVerdict: app,
    };
  } catch (err: any) {
    console.error('Play Integrity evaluation error:', err);
    return { isValid: !isCreditGrant, error: err.message || 'INTEGRITY_VERIFICATION_EXCEPTION' };
  }
}

// Log an anonymous abuse signal (hashed IP only, zero raw IP)
export async function recordAbuseSignal(params: {
  db?: D1Database;
  clientIp: string;
  deviceToken?: string;
}): Promise<void> {
  if (!params.db) return;

  const ipHash = await sha256Hex(params.clientIp || 'unknown');
  const deviceHash = params.deviceToken ? await sha256Hex(params.deviceToken) : null;
  const now = new Date();
  const windowStart = new Date(now.getFullYear(), now.getMonth(), now.getDate(), now.getHours()).toISOString();
  const id = `ab_${ipHash.substring(0, 16)}_${windowStart.substring(0, 13)}`;

  try {
    await params.db
      .prepare(
        `INSERT INTO abuse_signals (id, ip_hash, device_integrity_hash, request_count, window_start, updated_at)
         VALUES (?, ?, ?, 1, ?, ?)
         ON CONFLICT(id) DO UPDATE SET
           request_count = request_count + 1,
           updated_at = excluded.updated_at`
      )
      .bind(id, ipHash, deviceHash, windowStart, now.toISOString())
      .run();
  } catch (err) {
    console.warn('Could not persist abuse signal:', err);
  }
}
