import { Hono } from 'hono';
import { AppHonoEnv } from '../types';
import { getAppConfig } from '../config/app_config';
import { RemoteConfigRepository } from '../db/remote_config.repo';

export const configRoute = new Hono<AppHonoEnv>();

configRoute.get('/config', async (c) => {
  const cfg = getAppConfig(c.env);

  // Short edge cache TTL for performance
  c.header('Cache-Control', 'public, max-age=300, s-maxage=300');

  const baseConfig = {
    app_name: 'VibeKit AI',
    version: '1.1.0',
    model: cfg.geminiModel,
    daily_free_credits: cfg.maxDailyFreeCredits,
    reward_credits_per_ad: cfg.rewardCreditsPerAd,
    max_daily_rewards: cfg.maxDailyRewards,
    monthly_pro_credits: cfg.monthlyProCredits,
    pricing: {
      weekly: { id: 'vibekit_pro_weekly', default_inr: 49 },
      monthly: { id: 'vibekit_pro_monthly', default_inr: 99 },
      yearly: { id: 'vibekit_pro_yearly', default_inr: 699, trial_days: 3 },
    },
    feature_flags: {
      bio_lab: true,
      streaks_and_rewards: true,
      interstitial_ads: true,
      referrals: true,
      credit_packs: c.env.ENABLE_CREDIT_PACKS === 'true',
    },
    ad_settings: {
      interstitial_min_interval_seconds: 180, // 3-minute gap
      interstitial_max_per_day: 3,
      rewarded_max_per_day: cfg.maxDailyRewards,
    },
    paywall: {
      variant: 'default', // A/B test variant
      max_full_screens_per_session: 1,
    },
    privacy_policy_url: 'https://vibekit.ai/privacy',
    terms_of_service_url: 'https://vibekit.ai/terms',
  };

  try {
    const remoteRepo = new RemoteConfigRepository(c.env.DB);
    const dynamicOverrides = await remoteRepo.getLatestConfig<Record<string, any>>('app_remote_config');
    if (dynamicOverrides?.value) {
      return c.json({
        ...baseConfig,
        ...dynamicOverrides.value,
        feature_flags: {
          ...baseConfig.feature_flags,
          ...(dynamicOverrides.value.feature_flags ?? {}),
        },
        ad_settings: {
          ...baseConfig.ad_settings,
          ...(dynamicOverrides.value.ad_settings ?? {}),
        },
      });
    }
  } catch {
    // Fall back to base config if DB read fails
  }

  return c.json(baseConfig);
});
