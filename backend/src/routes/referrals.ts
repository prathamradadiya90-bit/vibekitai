import { Hono } from 'hono';
import { AppHonoEnv } from '../types';
import { ReferralClaimSchema } from '../schemas/validation';
import { verifyPlayIntegrityToken } from '../security/play_integrity';
import { ReferralsRepository } from '../db/referrals.repo';

export const referralsRoute = new Hono<AppHonoEnv>();

referralsRoute.post('/referrals/claim', async (c) => {
  const rawHeader = c.req.header('X-App-Instance-Id') || c.req.header('x-installation-id');
  const installationId = c.get('installationId');
  if (!rawHeader || !installationId || installationId === 'anonymous_default') {
    return c.json({ error: { code: 'UNAUTHORIZED', message: 'Missing installation ID' } }, 401);
  }

  const body = await c.req.json();
  const parsed = ReferralClaimSchema.safeParse(body);
  if (!parsed.success) {
    return c.json({ error: { code: 'VALIDATION_ERROR', message: 'Invalid referral payload' } }, 400);
  }

  const { referrer_code, integrity_token } = parsed.data;

  if (referrer_code === 'anonymous_default') {
    return c.json({ error: { code: 'INVALID_REFERRER', message: 'Referral code not found' } }, 404);
  }

  if (referrer_code === installationId) {
    return c.json({ error: { code: 'SELF_REFERRAL', message: 'Cannot refer your own installation' } }, 400);
  }

  // Always enforce Play Integrity in production even if integrity_token was omitted
  const isProd = c.env.ENVIRONMENT === 'production';
  if (isProd || integrity_token) {
    const packageName = c.env.GOOGLE_PLAY_PACKAGE_NAME || 'com.vibekit.vibekit_ai';
    const integrityResult = await verifyPlayIntegrityToken(integrity_token, packageName, c.env, true);
    if (!integrityResult.isValid) {
      return c.json({ error: { code: 'INTEGRITY_CHECK_FAILED', message: 'Device integrity verdict rejected' } }, 403);
    }
  }

  const db = c.env.DB;
  if (!db) {
    return c.json({
      success: true,
      credits_awarded: 2,
      message: 'Referral claimed! 2 free credits awarded to both users.',
    });
  }

  const repo = new ReferralsRepository(db);
  const referrerInstallationId = await repo.resolveReferrerInstallationId(referrer_code);
  if (!referrerInstallationId) {
    return c.json({ error: { code: 'INVALID_REFERRER', message: 'Referral code not found' } }, 404);
  }

  if (referrerInstallationId === installationId) {
    return c.json({ error: { code: 'SELF_REFERRAL', message: 'Cannot refer your own installation' } }, 400);
  }

  const alreadyClaimed = await repo.hasReferredInstallationClaimed(installationId);
  if (alreadyClaimed) {
    return c.json({ error: { code: 'ALREADY_REFERRED', message: 'Referral reward already claimed for this device' } }, 409);
  }

  const creditsToAward = 2;
  const result = await repo.recordReferralAndAwardCredits(
    referrerInstallationId,
    installationId,
    creditsToAward
  );

  if (result === 'already_claimed') {
    return c.json({ error: { code: 'ALREADY_REFERRED', message: 'Referral reward already claimed for this device' } }, 409);
  }
  if (result === 'limit_reached') {
    return c.json(
      { error: { code: 'REFERRAL_LIMIT_REACHED', message: 'Referrer has reached the maximum of 10 referral rewards' } },
      400
    );
  }

  return c.json({
    success: true,
    credits_awarded: creditsToAward,
    message: 'Referral claimed! 2 free credits awarded to both users.',
  });
});

referralsRoute.get('/referrals/stats', async (c) => {
  const rawHeader = c.req.header('X-App-Instance-Id') || c.req.header('x-installation-id');
  const installationId = c.get('installationId');
  if (!rawHeader || !installationId || installationId === 'anonymous_default') {
    return c.json({ error: { code: 'UNAUTHORIZED', message: 'Missing installation ID' } }, 401);
  }

  const db = c.env.DB;
  if (!db) {
    return c.json({
      referral_code: installationId,
      total_referred: 0,
      max_referrals: 10,
      credits_earned: 0,
      can_refer_more: true,
    });
  }

  const repo = new ReferralsRepository(db);
  const [referralCode, count] = await Promise.all([
    repo.getOrCreateReferralCode(installationId),
    repo.getRewardedReferralsCount(installationId),
  ]);
  const maxReferrals = 10;
  const creditsEarned = count * 2;

  return c.json({
    referral_code: referralCode,
    total_referred: count,
    max_referrals: maxReferrals,
    credits_earned: creditsEarned,
    can_refer_more: count < maxReferrals,
  });
});
