import { describe, it, expect, vi, beforeEach } from 'vitest';
import { app } from '../src/index';
import { createMockEnv } from './fixtures';
import { AppHonoEnv } from '../src/types';

describe('Phase 8: Chaos Engineering & Resilience Tests', () => {
  let env: AppHonoEnv['Bindings'];

  beforeEach(() => {
    env = createMockEnv();
    vi.restoreAllMocks();
  });

  describe('1. Payload Fuzzing & Body Limit Defense', () => {
    it('rejects oversized JSON bodies > 16KB with HTTP 400 VALIDATION_ERROR', async () => {
      // 20 KB payload
      const hugeString = 'A'.repeat(20 * 1024);
      const req = new Request('http://localhost/v1/generations/reply', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Installation-Id': 'inst_chaos_user',
          'Content-Length': String(hugeString.length),
        },
        body: JSON.stringify({
          message: hugeString,
          tone: 'Witty',
          language: 'English',
        }),
      });

      const res = await app.fetch(req, env);
      expect(res.status).toBe(400);
      const data = await res.json() as any;
      expect(data.error.code).toBe('VALIDATION_ERROR');
      expect(data.error.message).toContain('exceeds maximum allowed size');
      expect(data.error.requestId).toBeDefined();
    });

    it('rejects unknown injected fields due to Zod .strict() schema validation', async () => {
      const req = new Request('http://localhost/v1/generations/reply', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Installation-Id': 'inst_chaos_user',
        },
        body: JSON.stringify({
          message: 'Hey what are you doing tonight?',
          tone: 'Witty',
          language: 'English',
          injected_admin_role: 'superadmin',
          __proto__: { backdoor: true },
        }),
      });

      const res = await app.fetch(req, env);
      expect(res.status).toBe(400);
      const data = await res.json() as any;
      expect(data.error.code).toBe('VALIDATION_ERROR');
    });

    it('gracefully handles unicode emojis and multilingual text', async () => {
      const validMultilingual = '🔥🚀 नमस्ते வணக்கம் مرحبا';
      const req = new Request('http://localhost/v1/generations/reply', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Installation-Id': 'inst_chaos_user',
        },
        body: JSON.stringify({
          message: validMultilingual,
          tone: 'Witty',
          language: 'English',
        }),
      });

      const res = await app.fetch(req, env);
      expect([200, 429]).toContain(res.status);
    });
  });

  describe('2. AI Provider Outage & Failover', () => {
    it('transparently falls back to secondary provider when primary throws 503', async () => {
      let callCount = 0;
      const originalFetch = globalThis.fetch;
      globalThis.fetch = vi.fn().mockImplementation(async (url: string, init?: any) => {
        callCount++;
        if (callCount === 1) {
          // Primary provider fails with 503
          return new Response(JSON.stringify({ error: 'Service Unavailable' }), {
            status: 503,
            headers: { 'Content-Type': 'application/json' },
          });
        }
        // Fallback returns valid schema
        return new Response(
          JSON.stringify({
            candidates: [
              {
                content: {
                  parts: [
                    {
                      text: JSON.stringify({
                        suggestions: ['Fallback witty reply 1', 'Fallback witty reply 2'],
                      }),
                    },
                  ],
                },
              },
            ],
          }),
          { status: 200, headers: { 'Content-Type': 'application/json' } }
        );
      });

      try {
        const req = new Request('http://localhost/v1/generations/reply', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-Installation-Id': 'inst_failover_test',
          },
          body: JSON.stringify({
            message: 'Test message for failover',
            tone: 'Witty',
            language: 'English',
          }),
        });

        const res = await app.fetch(req, env);
        expect(res.status).toBe(200);
        const data = await res.json() as any;
        const suggestions = data.suggestions ?? data.data?.suggestions;
        expect(suggestions.length).toBeGreaterThanOrEqual(2);
      } finally {
        globalThis.fetch = originalFetch;
      }
    });
  });

  describe('3. Spend Circuit Breaker Burst Defense', () => {
    it('blocks all AI generations when daily spend cap is reached', async () => {
      // Mock D1 database with tripped budget status
      const mockDb = {
        prepare: vi.fn().mockReturnValue({
          bind: vi.fn().mockReturnThis(),
          first: vi.fn().mockResolvedValue({
            total_spend_usd: 30.0,
            max_budget_usd: 25.0,
            is_tripped: 1,
          }),
        }),
      } as any;

      const trippedEnv = createMockEnv({ DB: mockDb });

      const req = new Request('http://localhost/v1/generations/reply', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Installation-Id': 'inst_circuit_user',
        },
        body: JSON.stringify({
          message: 'Will this be blocked by circuit breaker?',
          tone: 'Witty',
          language: 'English',
        }),
      });

      const res = await app.fetch(req, trippedEnv);
      expect(res.status).toBe(503);
      const data = await res.json() as any;
      expect(data.error.code).toBe('RATE_LIMIT_EXCEEDED');
      expect(data.error.message).toContain('budget limit reached');
    });
  });
});
