import { describe, it, expect } from 'vitest';
import app from '../src/index';
import { timingSafeEqual } from '../src/security/crypto_timing';
import { validateOutboundUrl, SecuritySSRFError } from '../src/security/safe_fetch';
import { ReplyRequestSchema, CaptionRequestSchema, BioRequestSchema } from '../src/schemas/validation';

describe('Phase 3: Security Hardening Test Suite (ASVS L2 / MASVS L1+L2)', () => {
  describe('1. Constant-Time Secret Comparison (timingSafeEqual)', () => {
    it('returns true for identical secret strings', async () => {
      const match = await timingSafeEqual('super_secret_admin_token_123', 'super_secret_admin_token_123');
      expect(match).toBe(true);
    });

    it('returns false for mismatched secrets of equal length', async () => {
      const match = await timingSafeEqual('super_secret_admin_token_123', 'super_secret_admin_token_124');
      expect(match).toBe(false);
    });

    it('returns false for mismatched secrets of different lengths without throwing', async () => {
      const match1 = await timingSafeEqual('short', 'much_longer_token_value_abc');
      expect(match1).toBe(false);

      const match2 = await timingSafeEqual('', 'token');
      expect(match2).toBe(false);
    });
  });

  describe('2. SSRF Outbound Destination Defense (validateOutboundUrl)', () => {
    it('approves legitimate upstream AI provider domains', () => {
      expect(() =>
        validateOutboundUrl('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5:generateContent')
      ).not.toThrow();

      expect(() => validateOutboundUrl('https://api.groq.com/openai/v1/chat/completions')).not.toThrow();
      expect(() => validateOutboundUrl('https://api.openai.com/v1/chat/completions')).not.toThrow();
      expect(() => validateOutboundUrl('https://gstatic.com/admob/reward/verifier-keys.json')).not.toThrow();
      expect(() => validateOutboundUrl('https://admob.googleapis.com/v1/publicKeys')).not.toThrow();
    });

    it('rejects arbitrary external domains not in allowlist', () => {
      expect(() => validateOutboundUrl('https://evil-attacker.com/steal-data')).toThrow(SecuritySSRFError);
      expect(() => validateOutboundUrl('https://webhook.site/test')).toThrow(SecuritySSRFError);
    });

    it('strictly blocks cloud metadata endpoints and private IP ranges', () => {
      // AWS/GCP/Azure instance metadata endpoint
      expect(() => validateOutboundUrl('https://169.254.169.254/latest/meta-data/')).toThrow(SecuritySSRFError);
      // Localhost & loopback
      expect(() => validateOutboundUrl('http://127.0.0.1:8080/admin')).toThrow(SecuritySSRFError);
      expect(() => validateOutboundUrl('https://localhost:3000/')).toThrow(SecuritySSRFError);
      // Private Class A, B, C networks
      expect(() => validateOutboundUrl('https://10.0.0.5/internal-db')).toThrow(SecuritySSRFError);
      expect(() => validateOutboundUrl('https://172.16.0.1/secrets')).toThrow(SecuritySSRFError);
      expect(() => validateOutboundUrl('https://192.168.1.1/router')).toThrow(SecuritySSRFError);
    });

    it('strictly rejects cleartext HTTP in production', () => {
      expect(() =>
        validateOutboundUrl('http://generativelanguage.googleapis.com/test')
      ).toThrow(SecuritySSRFError);
    });
  });

  describe('3. Strict Zod Schema Enforcement (.strict())', () => {
    it('rejects unexpected additional properties in ReplyRequestSchema', () => {
      const valid = {
        message: 'Hello there',
        tone: 'Friendly',
        language: 'English',
        length: 'short',
        count: 3,
      };
      expect(ReplyRequestSchema.safeParse(valid).success).toBe(true);

      const injected = {
        ...valid,
        __proto_injection: 'malicious_polluted_property',
        role: 'admin',
      };
      expect(ReplyRequestSchema.safeParse(injected).success).toBe(false);
    });

    it('rejects unexpected additional properties in CaptionRequestSchema', () => {
      const valid = {
        topic: 'Coffee vibes',
        platform: 'Instagram Reels',
        tone: 'Trendy',
        language: 'English',
        length: 'medium',
      };
      expect(CaptionRequestSchema.safeParse(valid).success).toBe(true);

      const injected = {
        ...valid,
        extra_credit_grant: 100,
      };
      expect(CaptionRequestSchema.safeParse(injected).success).toBe(false);
    });

    it('rejects unexpected additional properties in BioRequestSchema', () => {
      const valid = {
        interests: 'Design & Code',
        platform: 'Instagram',
        vibe: 'Aesthetic',
        language: 'English',
      };
      expect(BioRequestSchema.safeParse(valid).success).toBe(true);

      const injected = {
        ...valid,
        is_pro_override: true,
      };
      expect(BioRequestSchema.safeParse(injected).success).toBe(false);
    });
  });

  describe('4. Strict Security Response Headers', () => {
    it('emits ASVS L2 security headers on API responses', async () => {
      const res = await app.request('/health');
      expect(res.headers.get('X-Content-Type-Options')).toBe('nosniff');
      expect(res.headers.get('X-Frame-Options')).toBe('DENY');
      expect(res.headers.get('Strict-Transport-Security')).toContain('max-age=31536000');
      expect(res.headers.get('Referrer-Policy')).toBe('strict-origin-when-cross-origin');
      expect(res.headers.get('Permissions-Policy')).toContain('camera=()');
      expect(res.headers.get('Content-Security-Policy')).toContain("frame-ancestors 'none'");
    });
  });
});
