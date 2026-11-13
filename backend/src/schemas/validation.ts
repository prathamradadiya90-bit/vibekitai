import { z } from 'zod';

export const ReplyRequestSchema = z
  .object({
    message: z.string().min(1, 'Message cannot be empty').max(500, 'Message cannot exceed 500 characters'),
    tone: z.enum(['Funny', 'Friendly', 'Flirty', 'Confident', 'Professional', 'Polite', 'Supportive', 'Witty', 'Rizz', 'Savage']),
    language: z.enum(['English', 'Hindi', 'Hinglish', 'Gujarati']),
    length: z.enum(['short', 'medium', 'detailed']).default('medium'),
    count: z.number().int().min(1).max(5).default(3),
    challenge_id: z.string().optional(),
  })
  .strict();

export const ReplyOutputSchema = z
  .object({
    suggestions: z.array(z.string()).min(1),
  })
  .strict();

export const CaptionRequestSchema = z
  .object({
    topic: z.string().min(1, 'Topic cannot be empty').max(400, 'Topic cannot exceed 400 characters'),
    platform: z.enum(['Instagram Reels', 'Instagram Post', 'WhatsApp Status', 'YouTube Shorts', 'General Social Media']),
    tone: z.enum(['Trendy', 'Witty', 'Aesthetic', 'Confident', 'Professional', 'Inspirational', 'Humorous']),
    language: z.enum(['English', 'Hindi', 'Hinglish', 'Gujarati']),
    length: z.enum(['short', 'medium', 'detailed']).default('medium'),
    include_hooks: z.boolean().default(true),
    include_hashtags: z.boolean().default(true),
    challenge_id: z.string().optional(),
  })
  .strict();

export const CaptionOutputSchema = z
  .object({
    captions: z.array(z.string()).min(1),
    hooks: z.array(z.string()).default([]),
    call_to_actions: z.array(z.string()).default([]),
    hashtags: z.array(z.string()).default([]),
  })
  .strict();

export const BioRequestSchema = z
  .object({
    interests: z.string().min(1, 'Interests cannot be empty').max(300, 'Interests cannot exceed 300 characters'),
    platform: z.enum(['Instagram', 'WhatsApp', 'LinkedIn', 'Twitter/X', 'General Profile']),
    vibe: z.enum(['Aesthetic', 'Witty', 'Professional', 'Minimalist', 'Creative', 'Bold']),
    language: z.enum(['English', 'Hindi', 'Hinglish', 'Gujarati']),
    include_usernames: z.boolean().default(true),
  })
  .strict();

export const BioOutputSchema = z
  .object({
    bios: z.array(z.string()).min(1),
    usernames: z.array(z.string()).default([]),
  })
  .strict();

export const VibeCheckRequestSchema = z
  .object({
    text: z.string().min(1, 'Text cannot be empty').max(500, 'Text cannot exceed 500 characters'),
    mode: z.enum(['roast', 'polish', 'dating', 'work', 'decoder', 'excuse']).default('roast'),
    language: z.enum(['English', 'Hindi', 'Hinglish', 'Gujarati']).default('English'),
    challenge_id: z.string().optional(),
  })
  .strict();

export const VibeCheckOutputSchema = z
  .object({
    score: z.number().int().min(0).max(100),
    title: z.string().min(1),
    verdict: z.string().min(1),
    tags: z.array(z.string()).default([]),
    rewrites: z.array(z.string()).min(1),
  })
  .strict();

export type VibeCheckRequest = z.infer<typeof VibeCheckRequestSchema>;
export type VibeCheckOutput = z.infer<typeof VibeCheckOutputSchema>;

export const PurchaseVerifySchema = z
  .object({
    product_id: z.enum([
      'vibekit_pro_weekly',
      'vibekit_pro_monthly',
      'vibekit_pro_yearly',
      'vibekit_pro_lifetime',
      'vibekit_credits_50',
      'vibekit_credits_25',
    ]),
    purchase_token: z.string().min(5),
    order_id: z.string().optional(),
  })
  .strict();

export const RewardVerifySchema = z
  .object({
    reward_id: z.string().optional(),
    transaction_id: z.string().optional(),
    nonce: z.string().optional(),
    ad_network: z.string().optional(),
  })
  .strict();

export const AdMobSsvQuerySchema = z
  .object({
    ad_network: z.string().optional(),
    ad_unit: z.string().optional(),
    custom_data: z.string().optional(),
    key_id: z.string().min(1),
    reward_amount: z.string().optional(),
    reward_item: z.string().optional(),
    timestamp: z.string().min(1),
    transaction_id: z.string().min(1),
    user_id: z.string().optional(),
    signature: z.string().min(10),
  });

export const RtdnNotificationSchema = z
  .object({
    message: z.object({
      data: z.string().min(1),
      messageId: z.string().optional(),
      publishTime: z.string().optional(),
    }),
    subscription: z.string().optional(),
  });

export const StreakCheckinSchema = z
  .object({
    utc_offset_minutes: z.number().int().min(-840).max(840).default(0),
    action: z.enum(['generate', 'card_export', 'challenge', 'share', 'save']),
  })
  .strict();

export const MilestoneClaimSchema = z
  .object({
    milestone_day: z.union([z.literal(3), z.literal(7), z.literal(14), z.literal(30)]),
  })
  .strict();

export const ReferralClaimSchema = z
  .object({
    referrer_code: z.string().min(1).max(64),
    integrity_token: z.string().optional(),
  })
  .strict();

export const FeedbackSchema = z
  .object({
    message: z.string().min(3).max(1000),
  })
  .strict();

// Inferred TypeScript types (no manual duplication)
export type ReplyRequest = z.infer<typeof ReplyRequestSchema>;
export type ReplyOutput = z.infer<typeof ReplyOutputSchema>;
export type CaptionRequest = z.infer<typeof CaptionRequestSchema>;
export type CaptionOutput = z.infer<typeof CaptionOutputSchema>;
export type BioRequest = z.infer<typeof BioRequestSchema>;
export type BioOutput = z.infer<typeof BioOutputSchema>;
export type PurchaseVerifyRequest = z.infer<typeof PurchaseVerifySchema>;
export type RewardVerifyRequest = z.infer<typeof RewardVerifySchema>;
export type AdMobSsvQuery = z.infer<typeof AdMobSsvQuerySchema>;
export type RtdnNotification = z.infer<typeof RtdnNotificationSchema>;
export type StreakCheckinRequest = z.infer<typeof StreakCheckinSchema>;
export type MilestoneClaimRequest = z.infer<typeof MilestoneClaimSchema>;
export type ReferralClaimRequest = z.infer<typeof ReferralClaimSchema>;
export type FeedbackRequest = z.infer<typeof FeedbackSchema>;
