import { Hono } from 'hono';
import { z } from 'zod';
import { AppHonoEnv } from '../types';
import { verifyPlayIntegrityToken, sha256Hex } from '../security/play_integrity';
import { mintSessionToken } from '../security/session_tokens';
import { ValidationError, AuthError } from '../errors/app_error';

export const authRoute = new Hono<AppHonoEnv>();

const attestSchema = z.object({
  integrityToken: z.string().optional(),
});

authRoute.post('/auth/attest', async (c) => {
  const installation = c.get('installation');
  const body = await c.req.json().catch(() => ({}));
  const parsed = attestSchema.safeParse(body);

  if (!parsed.success) {
    throw new ValidationError('Invalid attestation payload.', parsed.error.format());
  }

  const packageName = c.env.GOOGLE_PLAY_PACKAGE_NAME || 'com.vibekit.ai';
  const verdict = await verifyPlayIntegrityToken(
    parsed.data.integrityToken,
    packageName,
    c.env,
    true // isCreditGrant
  );

  if (!verdict.isValid && c.env.ENVIRONMENT === 'production') {
    throw new AuthError(`Hardware integrity attestation failed: ${verdict.error || 'INVALID_DEVICE'}`);
  }

  const deviceHash = await sha256Hex(parsed.data.integrityToken || installation.id);
  const secret = c.env.ADMIN_SECRET || 'vibekit_default_session_secret_rotate_in_prod';
  const sessionToken = await mintSessionToken(installation.id, deviceHash, secret, 900);

  return c.json({
    success: true,
    sessionToken,
    expiresIn: 900,
    integrityVerdict: verdict.isValid ? 'PASS' : 'TEST_BYPASS',
  });
});
