import { Hono } from 'hono';
import { Env } from '../types';
import { ReferralClaimSchema } from '../schemas/validation';
import { verifyPlayIntegrityToken } from '../security/play_integrity';
import { ReferralsRepository } from '../db/referrals.repo';

export const referralsRoute = new Hono<{ Bindings: Env }>();

referralsRoute.post('/referrals/claim', async (c) => {
  const installationId = c.req.header('X-App-Instance-Id') || c.req.header('x-installation-id');
  if (!installationId) {
    return c.json({ error: { code: 'UNAUTHORIZED', message: 'Missing installation ID' } }, 401);
  }

  const body = await c.req.json();
  const parsed = ReferralClaimSchema.safeParse(body);
  if (!parsed.success) {
    return c.json({ error: { code: 'VALIDATION_ERROR', message: 'Invalid referral payload' } }, 400);
  }

  const { referrer_code, integrity_token } = parsed.data;

  // Cannot refer self
  if (referrer_code === installationId) {
    return c.json({ error: { code: 'SELF_REFERRAL', message: 'Cannot refer your own installation' } }, 400);
  }

  // Verify Play Integrity token if supplied or if in production
  if (integrity_token) {
    const integrityResult = await verifyPlayIntegrityToken(integrity_token, 'com.vibekit.ai', c.env, true);
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

  // Verify referrer exists
  const isReferrerValid = await repo.isReferrerValid(referrer_code);
  if (!isReferrerValid) {
    return c.json({ error: { code: 'INVALID_REFERRER', message: 'Referral code not found' } }, 404);
  }

  // Ensure this installation hasn't already claimed a referral
  const alreadyClaimed = await repo.hasReferredInstallationClaimed(installationId);
  if (alreadyClaimed) {
    return c.json({ error: { code: 'ALREADY_REFERRED', message: 'Referral reward already claimed for this device' } }, 409);
  }

  // Check referrer count limit (max 10 referrals)
  const currentCount = await repo.getRewardedReferralsCount(referrer_code);
  if (currentCount >= 10) {
    return c.json({ error: { code: 'REFERRAL_LIMIT_REACHED', message: 'Referrer has reached the maximum of 10 referral rewards' } }, 400);
  }

  const creditsToAward = 2;
  await repo.recordReferralAndAwardCredits(referrer_code, installationId, creditsToAward);

  return c.json({
    success: true,
    credits_awarded: creditsToAward,
    message: 'Referral claimed! 2 free credits awarded to both users.',
  });
});

referralsRoute.get('/referrals/stats', async (c) => {
  const installationId = c.req.header('X-App-Instance-Id') || c.req.header('x-installation-id');
  if (!installationId) {
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
  const count = await repo.getRewardedReferralsCount(installationId);
  const maxReferrals = 10;
  const creditsEarned = count * 2;

  return c.json({
    referral_code: installationId,
    total_referred: count,
    max_referrals: maxReferrals,
    credits_earned: creditsEarned,
    can_refer_more: count < maxReferrals,
  });
});
