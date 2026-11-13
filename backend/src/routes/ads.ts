import { Hono } from 'hono';
import { Env } from '../types';
import { AdMobSsvQuerySchema, RewardVerifySchema } from '../schemas/validation';
import { QuotaManager } from '../quota/quota_manager';
import { verifyAdMobSsvSignature } from '../security/admob_ssv';
import { AdsRepository } from '../db/ads.repo';

export const adsRoute = new Hono<{ Bindings: Env }>();

// 1. Issue a cryptographically fresh single-use nonce for the client to pass in AdMob custom_data
adsRoute.post('/ads/request-nonce', async (c) => {
  const installationId = c.req.header('X-App-Instance-Id') || 'anonymous_default';
  const quotaManager = new QuotaManager(c.env);
  const nonce = await quotaManager.createAdNonce(installationId);

  return c.json({
    nonce,
    installation_id: installationId,
    expires_in_seconds: 600,
  });
});

// 2. Official Google AdMob Server-Side Verification (SSV) callback endpoint
adsRoute.get('/ads/ssv', async (c) => {
  const url = new URL(c.req.url);
  const queryResult = AdMobSsvQuerySchema.safeParse(Object.fromEntries(url.searchParams.entries()));

  if (!queryResult.success) {
    return c.text('Invalid SSV query parameters', 400);
  }

  const {
    user_id: installationId,
    transaction_id: transactionId,
    key_id: keyId,
    signature,
    custom_data: customData,
    ad_network: adNetwork,
  } = queryResult.data;

  // Verify signature (or skip if dev flag explicitly set)
  let isSignatureValid = false;
  if (c.env.SKIP_SSV_VERIFY_FOR_DEV === 'true' || c.env.ENVIRONMENT === 'test') {
    isSignatureValid = true;
  } else {
    isSignatureValid = await verifyAdMobSsvSignature(
      url.search.slice(1),
      keyId,
      signature,
      c.env.ADMOB_SSV_KEY_URL
    );
  }

  if (!isSignatureValid) {
    console.warn(`AdMob SSV signature rejected for transaction ${transactionId}`);
    return c.text('Signature verification failed', 403);
  }

  // Extract nonce, rewardId, and installationId if encoded in custom_data
  let nonce: string | undefined;
  let rewardId: string | undefined;
  let targetInstallationId = installationId;

  if (customData) {
    try {
      const parsed = JSON.parse(customData);
      nonce = parsed.nonce;
      rewardId = parsed.reward_id || parsed.rewardId;
      if (!targetInstallationId && (parsed.userId || parsed.installationId || parsed.user_id)) {
        targetInstallationId = parsed.userId || parsed.installationId || parsed.user_id;
      }
    } catch {
      if (customData.startsWith('nonce_')) {
        nonce = customData;
      }
    }
  }

  if (!targetInstallationId) {
    return c.text('Missing installation ID in SSV request', 400);
  }

  const quotaManager = new QuotaManager(c.env);
  const recordResult = await quotaManager.recordSsvReward({
    installationId: targetInstallationId,
    transactionId,
    rewardId,
    keyId: parseInt(keyId, 10) || 0,
    adNetwork: adNetwork || 'admob',
    nonce,
  });

  if (!recordResult.success) {
    if (recordResult.reason === 'DUPLICATE_TRANSACTION') {
      // Return 200 to AdMob so it stops retrying already processed callbacks
      return c.text('OK: Duplicate transaction ignored');
    }
    return c.text(`Reward rejected: ${recordResult.reason}`, 400);
  }

  return c.text('OK');
});

// 3. Client polling / verification endpoint: checks if reward was recorded by SSV
adsRoute.post('/ads/verify-reward', async (c) => {
  const installationId = c.req.header('X-App-Instance-Id') || 'anonymous_default';
  const bodyResult = RewardVerifySchema.safeParse(await c.req.json().catch(() => ({})));

  const quotaManager = new QuotaManager(c.env);
  const quota = await quotaManager.getQuotaStatus(installationId);

  // If testing or dev mode without SSV server callback, allow dev credit grant
  if (c.env.SKIP_SSV_VERIFY_FOR_DEV === 'true' || c.env.ENVIRONMENT === 'test') {
    const rewardId = bodyResult.success && bodyResult.data.reward_id ? bodyResult.data.reward_id : `dev_reward_${Date.now()}`;
    const recordResult = await quotaManager.recordSsvReward({
      installationId,
      transactionId: `tx_${Date.now()}_${Math.random().toString(36).substring(7)}`,
      rewardId,
      keyId: 1,
      adNetwork: 'admob_dev',
    });
    const updatedQuota = await quotaManager.getQuotaStatus(installationId);
    if (!recordResult.success) {
      return c.json(
        {
          verified: false,
          error: {
            code: 'DAILY_REWARD_LIMIT_REACHED',
            message: 'Daily rewarded ads limit reached. Upgrade to Pro for unlimited credits.',
          },
          credits_remaining: updatedQuota.total_credits_remaining,
          rewarded_ads_watched_today: updatedQuota.rewarded_ads_watched_today,
          max_rewarded_ads_per_day: updatedQuota.max_rewarded_ads_per_day,
        },
        429
      );
    }

    return c.json({
      verified: true,
      credits_added: parseInt(c.env.REWARD_CREDITS_PER_AD || '3', 10),
      credits_remaining: updatedQuota.total_credits_remaining,
      rewarded_ads_watched_today: updatedQuota.rewarded_ads_watched_today,
      max_rewarded_ads_per_day: updatedQuota.max_rewarded_ads_per_day,
    });
  }

  // Production check: reward credits are only verified if granted via SSV
  let isVerified = false;
  if (c.env.DB && bodyResult.success && (bodyResult.data.transaction_id || bodyResult.data.reward_id)) {
    const adsRepo = new AdsRepository(c.env.DB);
    isVerified = await adsRepo.isTransactionRecorded(
      installationId,
      bodyResult.data.transaction_id,
      bodyResult.data.reward_id
    );
  }

  return c.json({
    verified: isVerified,
    credits_remaining: quota.total_credits_remaining,
    rewarded_ads_watched_today: quota.rewarded_ads_watched_today,
    max_rewarded_ads_per_day: quota.max_rewarded_ads_per_day,
  });
});
