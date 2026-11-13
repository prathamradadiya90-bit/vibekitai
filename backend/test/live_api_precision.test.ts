import { describe, it, expect } from 'vitest';

const BASE_URL = 'http://127.0.0.1:8787';

function getFreshUserId(prefix = 'user'): string {
  return `${prefix}_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
}

describe('Exhaustive Live API Precision & Quality Audit', { timeout: 15000 }, () => {

  // Helper fetcher
  async function api(path: string, options: RequestInit = {}, userId?: string) {
    const headers = new Headers(options.headers || {});
    if (!headers.has('X-App-Instance-Id')) {
      headers.set('X-App-Instance-Id', userId || getFreshUserId());
    }
    if (!headers.has('Content-Type') && options.method && options.method !== 'GET') {
      headers.set('Content-Type', 'application/json');
    }

    const res = await fetch(`${BASE_URL}${path}`, {
      ...options,
      headers,
    });

    const contentType = res.headers.get('content-type') || '';
    let body: any = null;
    if (contentType.includes('application/json')) {
      body = await res.json();
    } else {
      body = await res.text();
    }

    return { status: res.status, headers: res.headers, body };
  }

  // 1. Health & Root Endpoints
  describe('1. Health & Root Service Verification', () => {
    it('GET /health returns healthy status', async () => {
      const { status, body } = await api('/v1/health');
      expect(status).toBe(200);
      expect(body.status).toBe('healthy');
      expect(body.version).toBe('1.0.0');
      expect(typeof body.timestamp).toBe('string');
    });

    it('GET / returns root fallback status', async () => {
      const { status, body } = await api('/');
      expect(status).toBe(200);
      expect(body).toContain('VibeKit AI Edge API');
    });
  });

  // 2. Configuration & Remote Feature Flags
  describe('2. Remote Config & Pricing Precision', () => {
    it('GET /v1/config returns complete remote configuration and pricing', async () => {
      const { status, body } = await api('/v1/config');
      expect(status).toBe(200);
      expect(body.app_name).toBe('VibeKit AI');
      expect(body.version).toBeDefined();
      expect(body.daily_free_credits).toBeGreaterThanOrEqual(1);
      expect(body.reward_credits_per_ad).toBeGreaterThanOrEqual(1);
      expect(body.pricing.weekly.id).toBe('vibekit_pro_weekly');
      expect(body.pricing.monthly.id).toBe('vibekit_pro_monthly');
      expect(body.pricing.yearly.id).toBe('vibekit_pro_yearly');
      expect(body.feature_flags.bio_lab).toBe(true);
      expect(body.feature_flags.streaks_and_rewards).toBe(true);
    });
  });

  // 3. User Quota & Usage
  describe('3. Usage & Quota Accounting', () => {
    it('GET /v1/usage returns initial credits balance', async () => {
      const testUser = getFreshUserId('quota');
      const { status, body } = await api('/v1/usage', {}, testUser);
      expect(status).toBe(200);
      expect(body.free_credits_remaining).toBeGreaterThanOrEqual(1);
      expect(body.total_credits_remaining).toBeGreaterThanOrEqual(1);
      expect(typeof body.is_pro).toBe('boolean');
      expect(body.rewarded_ads_watched_today).toBe(0);
      expect(body.max_rewarded_ads_per_day).toBe(2);
    });
  });

  // 4. Streaks & Gamification
  describe('4. Streaks & Gamification System', () => {
    it('GET /v1/streak returns streak and level status', async () => {
      const testUser = getFreshUserId('streak');
      const { status, body } = await api('/v1/streak', {}, testUser);
      expect(status).toBe(200);
      expect(body.current_streak).toBeGreaterThanOrEqual(0);
      expect(body.total_xp).toBeGreaterThanOrEqual(0);
      expect(body.level).toBeGreaterThanOrEqual(1);
      expect(Array.isArray(body.claimed_milestones)).toBe(true);
    });

    it('POST /v1/streak/checkin awards XP and records activity', async () => {
      const testUser = getFreshUserId('checkin');
      const { status, body } = await api('/v1/streak/checkin', {
        method: 'POST',
        body: JSON.stringify({ action: 'generate' }),
      }, testUser);
      expect(status).toBe(200);
      expect(body.success).toBe(true);
      expect(body.xp_awarded).toBeGreaterThanOrEqual(5);
      expect(body.current_streak).toBeGreaterThanOrEqual(1);
    });
  });

  // 5. AI Generations - Reply Studio (Accuracy, Tone, Multilingual)
  describe('5. Reply Studio Generation Accuracy', () => {
    it('generates 3 accurate Funny replies in English', async () => {
      const user = getFreshUserId('reply_en_funny');
      const { status, body } = await api('/v1/generations/reply', {
        method: 'POST',
        body: JSON.stringify({
          message: 'Are you free tonight?',
          tone: 'Funny',
          language: 'English',
          length: 'medium',
          count: 3,
        }),
      }, user);

      expect(status).toBe(200);
      expect(body.suggestions).toHaveLength(3);
      expect(body.tone).toBe('Funny');
      expect(body.language).toBe('English');
      expect(typeof body.credits_remaining).toBe('number');

      for (const s of body.suggestions) {
        expect(typeof s).toBe('string');
        expect(s.trim().length).toBeGreaterThan(5);
      }
    });

    it('generates 3 accurate Professional replies in English', async () => {
      const user = getFreshUserId('reply_en_prof');
      const { status, body } = await api('/v1/generations/reply', {
        method: 'POST',
        body: JSON.stringify({
          message: 'Can we push our sync to tomorrow morning?',
          tone: 'Professional',
          language: 'English',
          length: 'short',
          count: 3,
        }),
      }, user);

      expect(status).toBe(200);
      expect(body.suggestions).toHaveLength(3);
      expect(body.tone).toBe('Professional');
      for (const s of body.suggestions) {
        expect(s.trim().length).toBeGreaterThan(5);
      }
    });

    it('generates accurate Hinglish replies', async () => {
      const user = getFreshUserId('reply_hinglish');
      const { status, body } = await api('/v1/generations/reply', {
        method: 'POST',
        body: JSON.stringify({
          message: 'Chai peene chalte hain?',
          tone: 'Witty',
          language: 'Hinglish',
          length: 'medium',
          count: 3,
        }),
      }, user);

      expect(status).toBe(200);
      expect(body.suggestions).toHaveLength(3);
      expect(body.language).toBe('Hinglish');
    });

    it('generates accurate Hindi replies', async () => {
      const user = getFreshUserId('reply_hindi');
      const { status, body } = await api('/v1/generations/reply', {
        method: 'POST',
        body: JSON.stringify({
          message: 'Kya hum kal mil sakte hain?',
          tone: 'Polite',
          language: 'Hindi',
          length: 'medium',
          count: 3,
        }),
      }, user);

      expect(status).toBe(200);
      expect(body.suggestions).toHaveLength(3);
      expect(body.language).toBe('Hindi');
    });
  });

  // 6. AI Generations - Caption Lab (Hooks, CTAs, Hashtags)
  describe('6. Caption Lab Generation Accuracy & Precision', () => {
    it('generates structured captions, hooks, CTAs, and formatted hashtags for Instagram Post', async () => {
      const user = getFreshUserId('caption_ig');
      const { status, body } = await api('/v1/generations/caption', {
        method: 'POST',
        body: JSON.stringify({
          topic: 'Late night coding session with artisan coffee',
          platform: 'Instagram Post',
          tone: 'Aesthetic',
          language: 'English',
          length: 'medium',
          include_hooks: true,
          include_hashtags: true,
        }),
      }, user);

      expect(status).toBe(200);
      expect(Array.isArray(body.captions)).toBe(true);
      expect(body.captions.length).toBeGreaterThanOrEqual(1);

      expect(Array.isArray(body.hooks)).toBe(true);
      expect(body.hooks.length).toBeGreaterThanOrEqual(1);

      expect(Array.isArray(body.call_to_actions)).toBe(true);
      expect(body.call_to_actions.length).toBeGreaterThanOrEqual(1);

      expect(Array.isArray(body.hashtags)).toBe(true);
      expect(body.hashtags.length).toBeGreaterThanOrEqual(3);
      for (const tag of body.hashtags) {
        expect(tag.startsWith('#')).toBe(true);
      }
    });

    it('generates Trendy YouTube Shorts captions with relevant hooks', async () => {
      const user = getFreshUserId('caption_yt');
      const { status, body } = await api('/v1/generations/caption', {
        method: 'POST',
        body: JSON.stringify({
          topic: 'Morning routine before 6 AM',
          platform: 'YouTube Shorts',
          tone: 'Trendy',
          language: 'English',
          include_hooks: true,
          include_hashtags: true,
        }),
      }, user);

      expect(status).toBe(200);
      expect(body.captions.length).toBeGreaterThanOrEqual(1);
      expect(body.platform).toBe('YouTube Shorts');
    });
  });

  // 7. AI Generations - Bio Lab (Bios and Usernames)
  describe('7. Bio Lab Generation Accuracy', () => {
    it('generates aesthetic bios and handles for Instagram', async () => {
      const user = getFreshUserId('bio_ig');
      const { status, body } = await api('/v1/generations/bio', {
        method: 'POST',
        body: JSON.stringify({
          interests: 'Coffee, architecture, vintage film cameras, travel',
          platform: 'Instagram',
          vibe: 'Aesthetic',
          language: 'English',
          include_usernames: true,
        }),
      }, user);

      expect(status).toBe(200);
      expect(Array.isArray(body.bios)).toBe(true);
      expect(body.bios.length).toBeGreaterThanOrEqual(2);

      expect(Array.isArray(body.usernames)).toBe(true);
      expect(body.usernames.length).toBeGreaterThanOrEqual(2);
      for (const u of body.usernames) {
        expect(typeof u).toBe('string');
        expect(u.length).toBeGreaterThan(2);
      }
    });

    it('generates professional bios for LinkedIn', async () => {
      const user = getFreshUserId('bio_li');
      const { status, body } = await api('/v1/generations/bio', {
        method: 'POST',
        body: JSON.stringify({
          interests: 'Software engineer, open source, cloud architecture',
          platform: 'LinkedIn',
          vibe: 'Professional',
          language: 'English',
          include_usernames: false,
        }),
      }, user);

      expect(status).toBe(200);
      expect(body.bios.length).toBeGreaterThanOrEqual(2);
      expect(body.platform).toBe('LinkedIn');
    });
  });

  // 8. AI Generations - Vibe Check & Roaster
  describe('8. Vibe Check & Roaster Precision', () => {
    it('rates and roasts low-effort draft message with score, tags, and rewrites', async () => {
      const user = getFreshUserId('vibe_roast');
      const { status, body } = await api('/v1/generations/vibe-check', {
        method: 'POST',
        body: JSON.stringify({
          text: 'Hey are you free tonight? Just wondering what you are doing lol',
          mode: 'roast',
          language: 'English',
        }),
      }, user);

      expect(status).toBe(200);
      expect(typeof body.score).toBe('number');
      expect(body.score).toBeGreaterThanOrEqual(0);
      expect(body.score).toBeLessThanOrEqual(100);

      expect(typeof body.title).toBe('string');
      expect(body.title.length).toBeGreaterThan(2);

      expect(typeof body.verdict).toBe('string');
      expect(body.verdict.length).toBeGreaterThan(5);

      expect(Array.isArray(body.tags)).toBe(true);
      expect(body.tags.length).toBeGreaterThanOrEqual(1);

      expect(Array.isArray(body.rewrites)).toBe(true);
      expect(body.rewrites.length).toBe(3);
      for (const rw of body.rewrites) {
        expect(typeof rw).toBe('string');
        expect(rw.length).toBeGreaterThan(5);
      }
    });

    it('executes Vibe Polish mode to enhance draft tone warmly', async () => {
      const user = getFreshUserId('vibe_polish');
      const { status, body } = await api('/v1/generations/vibe-check', {
        method: 'POST',
        body: JSON.stringify({
          text: 'Can we reschedule our call? Something came up.',
          mode: 'polish',
          language: 'English',
        }),
      }, user);

      expect(status).toBe(200);
      expect(body.score).toBeGreaterThanOrEqual(50);
      expect(body.rewrites.length).toBe(3);
    });

    it('executes Boss Mode for assertive workplace communications', async () => {
      const user = getFreshUserId('vibe_boss');
      const { status, body } = await api('/v1/generations/vibe-check', {
        method: 'POST',
        body: JSON.stringify({
          text: 'Hey I think I should be paid more for the extra hours I do.',
          mode: 'work',
          language: 'English',
        }),
      }, user);

      expect(status).toBe(200);
      expect(body.rewrites.length).toBe(3);
    });
  });

  // 9. Idempotency Key Guarantees
  describe('9. Idempotency Deduplication', () => {
    it('returns cached identical result without double credit decrement', async () => {
      const idempotencyKey = `idem_${Date.now()}_test`;
      const user = getFreshUserId('idem_user');

      const res1 = await api('/v1/generations/reply', {
        method: 'POST',
        headers: {
          'X-App-Instance-Id': user,
          'X-Idempotency-Key': idempotencyKey,
        },
        body: JSON.stringify({
          message: 'Coffee tomorrow?',
          tone: 'Friendly',
          language: 'English',
        }),
      }, user);

      expect(res1.status).toBe(200);
      const creditsAfterFirst = res1.body.credits_remaining;

      // Second call with identical key
      const res2 = await api('/v1/generations/reply', {
        method: 'POST',
        headers: {
          'X-App-Instance-Id': user,
          'X-Idempotency-Key': idempotencyKey,
        },
        body: JSON.stringify({
          message: 'Coffee tomorrow?',
          tone: 'Friendly',
          language: 'English',
        }),
      }, user);

      expect(res2.status).toBe(200);
      expect(res2.body.suggestions).toEqual(res1.body.suggestions);
      expect(res2.body.credits_remaining).toBe(creditsAfterFirst);
    });
  });

  // 10. User Feedback & Support
  describe('10. Feedback & Customer Inquiries', () => {
    it('POST /v1/feedback accepts valid feedback submission', async () => {
      const { status, body } = await api('/v1/feedback', {
        method: 'POST',
        body: JSON.stringify({
          message: 'The new Vibe Check mode is incredible! Really loving the UI.',
        }),
      });

      expect(status).toBe(200);
      expect(body.success).toBe(true);
      expect(body.message).toContain('Thank you');
    });

    it('rejects feedback that is too short', async () => {
      const { status, body } = await api('/v1/feedback', {
        method: 'POST',
        body: JSON.stringify({ message: 'hi' }),
      });

      expect(status).toBe(400);
      expect(body.error.code).toBe('VALIDATION_ERROR');
    });
  });

  // 11. Referrals Program
  describe('11. Referrals System', () => {
    it('GET /v1/referrals/stats returns referral quota metrics', async () => {
      const user = getFreshUserId('ref_stats');
      const { status, body } = await api('/v1/referrals/stats', {}, user);
      expect(status).toBe(200);
      expect(body.referral_code).toBe(user);
      expect(body.max_referrals).toBe(10);
      expect(typeof body.total_referred).toBe('number');
      expect(typeof body.can_refer_more).toBe('boolean');
    });

    it('rejects self-referral attempts', async () => {
      const user = getFreshUserId('self_ref');
      const { status, body } = await api('/v1/referrals/claim', {
        method: 'POST',
        body: JSON.stringify({ referrer_code: user }),
      }, user);

      expect(status).toBe(400);
      expect(body.error.code).toBe('SELF_REFERRAL');
    });
  });

  // 12. AdMob SSV & Rewarded Ads
  describe('12. Rewarded Video Ads & SSV Nonce', () => {
    it('POST /v1/ads/request-nonce issues a valid cryptographic nonce', async () => {
      const { status, body } = await api('/v1/ads/request-nonce', {
        method: 'POST',
        body: JSON.stringify({ ad_unit_id: 'test_ad_unit' }),
      });

      expect(status).toBe(200);
      expect(typeof body.nonce).toBe('string');
      expect(body.nonce.length).toBeGreaterThan(10);
      expect(body.expires_in_seconds).toBe(600);
    });
  });

  // 13. Privacy & Right to be Forgotten (GDPR)
  describe('13. Privacy & Data Deletion', () => {
    it('POST /v1/privacy/delete-data permanently purges user cloud records', async () => {
      const deleteUser = getFreshUserId('del_user');
      const { status, body } = await api('/v1/privacy/delete-data', {
        method: 'POST',
      }, deleteUser);

      expect(status).toBe(200);
      expect(body.success).toBe(true);
      expect(body.message).toContain('permanently purged');
    });
  });

  // 14. Input Validation & Security Hardening
  describe('14. Security Boundaries & Input Schema Defense', () => {
    it('rejects malformed requests with missing required fields', async () => {
      const { status, body } = await api('/v1/generations/reply', {
        method: 'POST',
        body: JSON.stringify({ tone: 'Funny' }), // missing 'message'
      });

      expect(status).toBe(400);
      expect(body.error.code).toBe('VALIDATION_ERROR');
    });

    it('rejects requests with body exceeding 16KB limit', async () => {
      const largePayload = 'a'.repeat(20000);
      const { status, body } = await api('/v1/generations/reply', {
        method: 'POST',
        body: JSON.stringify({
          message: largePayload,
          tone: 'Funny',
        }),
      });

      expect([400, 413]).toContain(status);
    });
  });
});
