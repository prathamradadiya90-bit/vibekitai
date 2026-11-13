import { Env } from '../types';

export interface AppConfig {
  environment: string;
  geminiModel: string;
  maxDailyFreeCredits: number;
  rewardCreditsPerAd: number;
  maxDailyRewards: number;
  monthlyProCredits: number;
  maxInputLengthReply: number;
  maxInputLengthCaption: number;
  maxInputLengthBio: number;
}

export function getAppConfig(env: Env): AppConfig {
  return {
    environment: env.ENVIRONMENT || 'development',
    geminiModel: env.GEMINI_MODEL || 'gemini-1.5-flash',
    maxDailyFreeCredits: parseInt(env.MAX_DAILY_FREE_CREDITS || '3', 10),
    rewardCreditsPerAd: parseInt(env.REWARD_CREDITS_PER_AD || '3', 10),
    maxDailyRewards: parseInt(env.MAX_DAILY_REWARDS || '2', 10),
    monthlyProCredits: parseInt(env.MONTHLY_PRO_CREDITS || '200', 10),
    maxInputLengthReply: 500,
    maxInputLengthCaption: 400,
    maxInputLengthBio: 300,
  };
}
