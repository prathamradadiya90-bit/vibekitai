import { describe, it, expect, beforeEach, vi } from 'vitest';
import { Hono } from 'hono';
import { OpenAICompatibleProvider } from '../src/ai/openai_compatible';
import { handleScheduledTask } from '../src/cron/nightly_stats';
import { AdsRepository } from '../src/db/ads.repo';
import { PurchasesRepository } from '../src/db/purchases.repo';
import { ReferralsRepository } from '../src/db/referrals.repo';
import { StreaksRepository } from '../src/db/streaks.repo';
import { QuotaManager } from '../src/quota/quota_manager';
import { validateOutboundUrl } from '../src/security/safe_fetch';
import { installationMiddleware } from '../src/middleware/installation';
import { bodyLimitMiddleware } from '../src/middleware/body_limit';
import { rateLimiterMiddleware } from '../src/middleware/rate_limit';
import { FallbackChainAIProvider, resetFallbackCircuitBreaker } from '../src/ai/fallback_chain';
import type { AIProvider } from '../src/ai/factory';
import { UsageRepository } from '../src/db/usage.repo';
import { mintSessionToken, verifySessionToken } from '../src/security/session_tokens';
import { adminAuthMiddleware } from '../src/admin/auth';
import { verifyAdMobSsvSignature } from '../src/security/admob_ssv';
import { globalErrorHandler } from '../src/middleware/error_handler';

// Mock in-memory SQLite D1Database for isolated unit testing
class MockD1Statement {
  constructor(private sql: string, private params: any[] = [], private dbState: any) {}

  bind(...params: any[]) {
    return new MockD1Statement(this.sql, params, this.dbState);
  }

  async first<T = unknown>(): Promise<T | null> {
    const s = this.sql.toLowerCase();
    if (s.includes('from ad_nonces') && s.includes('used_at is not null')) {
      const [nonce, instId] = this.params;
      const found = this.dbState.nonces.find((n: any) => n.nonce === nonce && n.installation_id === instId && n.used_at !== null);
      return (found || null) as T | null;
    }
    if (s.includes('from admob_ssv_transactions')) {
      const [instId, tx1, tx2, rew1, rew2] = this.params;
      const found = this.dbState.ssvTxs.find((t: any) => t.installation_id === instId && ((tx1 && t.transaction_id === tx2) || (rew1 && t.reward_id === rew2)));
      return (found || null) as T | null;
    }
    if (s.includes('from credit_pack_purchases')) {
      const [orderId, token] = this.params;
      const found = this.dbState.creditPacks.find((cp: any) => cp.order_id === orderId || cp.purchase_token === token);
      return (found || null) as T | null;
    }
    if (s.includes('from installations where id = ?')) {
      const [instId] = this.params;
      const found = this.dbState.installations.find((i: any) => i.id === instId);
      return (found || null) as T | null;
    }
    if (s.includes('from streaks where installation_id = ?')) {
      const [instId] = this.params;
      const found = this.dbState.streaks.find((st: any) => st.installation_id === instId);
      return (found || null) as T | null;
    }
    if (s.includes('from subscription_entitlements where purchase_token = ?')) {
      const [token] = this.params;
      const found = this.dbState.subscriptions.find((sub: any) => sub.purchase_token === token);
      return (found || null) as T | null;
    }
    return null;
  }

  async run(): Promise<{ meta: { changes: number } }> {
    const s = this.sql.toLowerCase();
    if (s.includes('insert into installations')) {
      const [id] = this.params;
      if (!this.dbState.installations.some((i: any) => i.id === id)) {
        this.dbState.installations.push({ id, is_pro: 0, pro_expires_at: null });
      }
    }
    if (s.includes('insert into streaks')) {
      const [instId, freezes] = this.params;
      if (!this.dbState.installations.some((i: any) => i.id === instId)) {
        throw new Error('FOREIGN KEY constraint failed: streaks(installation_id) -> installations(id)');
      }
      this.dbState.streaks.push({ installation_id: instId, current_streak: 0, freeze_count: freezes, last_checkin_date: '' });
    }
    if (s.includes('update installations set is_pro = 0')) {
      const [id, instId, token] = this.params;
      // Check NOT EXISTS subquery logic:
      const hasOtherEntitlement = this.dbState.subscriptions.some(
        (sub: any) => sub.installation_id === instId && sub.purchase_token !== token && (sub.product_id === 'vibekit_pro_lifetime' || sub.status === 'ACTIVE')
      );
      if (!hasOtherEntitlement) {
        const inst = this.dbState.installations.find((i: any) => i.id === id);
        if (inst) inst.is_pro = 0;
      }
    }
    return { meta: { changes: 1 } };
  }
}

class MockD1Database {
  public state = {
    installations: [] as any[],
    nonces: [] as any[],
    ssvTxs: [] as any[],
    creditPacks: [] as any[],
    referrals: [] as any[],
    streaks: [] as any[],
    subscriptions: [] as any[],
  };

  prepare(sql: string) {
    return new MockD1Statement(sql, [], this.state);
  }

  async batch(statements: MockD1Statement[]) {
    const results = [];
    for (const stmt of statements) {
      results.push(await stmt.run());
    }
    return results;
  }
}

describe('Critical Bug Fixes & Regression Test Suite', () => {
  let mockDb: MockD1Database;

  beforeEach(() => {
    mockDb = new MockD1Database();
  });

  it('Bug #1: AdsRepository.isTransactionRecorded verifies using consumed nonce', async () => {
    const adsRepo = new AdsRepository(mockDb as any);
    const instId = 'inst_ads_user_1';
    const nonce = 'nonce_secret_123';

    // Nonce not yet consumed -> false
    mockDb.state.nonces.push({ nonce, installation_id: instId, used_at: null });
    let verified = await adsRepo.isTransactionRecorded(instId, undefined, undefined, nonce);
    expect(verified).toBe(false);

    // Nonce consumed by SSV callback -> true
    mockDb.state.nonces[0].used_at = new Date().toISOString();
    verified = await adsRepo.isTransactionRecorded(instId, undefined, undefined, nonce);
    expect(verified).toBe(true);
  });

  it('Bug #2: PurchasesRepository upserts installation before recording credit pack', async () => {
    const purchasesRepo = new PurchasesRepository(mockDb as any);
    const freshInstId = 'inst_fresh_buyer_99';

    // Fresh install has no prior record in installations
    expect(mockDb.state.installations.some((i) => i.id === freshInstId)).toBe(false);

    // Recording credit pack must succeed and automatically ensure installation exists
    await purchasesRepo.recordCreditPackAndGrantCredits({
      orderId: 'order_google_123',
      installationId: freshInstId,
      productId: 'vibekit_credits_50',
      creditsGranted: 50,
      purchaseToken: 'tok_credit_pack_99',
    });

    expect(mockDb.state.installations.some((i) => i.id === freshInstId)).toBe(true);
  });

  it('Bug #2 & #6: StreaksRepository upserts installation before inserting streaks row', async () => {
    const streaksRepo = new StreaksRepository(mockDb as any);
    const freshInstId = 'inst_streak_new_user';

    // Must not throw SQLite foreign key violation on fresh install
    const streak = await streaksRepo.getOrCreateStreak(freshInstId, false);
    expect(streak.installation_id).toBe(freshInstId);
    expect(mockDb.state.installations.some((i) => i.id === freshInstId)).toBe(true);
  });

  it('Bug #3: handleSubscriptionLifecycleUpdate preserves Lifetime Pass when an old subscription expires', async () => {
    const qm = new QuotaManager({ DB: mockDb as any } as any);
    const instId = 'inst_lifetime_vip_user';

    // User owns a Lifetime pass AND had an old monthly subscription
    mockDb.state.installations.push({ id: instId, is_pro: 1, pro_expires_at: null });
    mockDb.state.subscriptions.push({
      id: 'sub_lifetime_1',
      installation_id: instId,
      product_id: 'vibekit_pro_lifetime',
      purchase_token: 'tok_lifetime_token',
      status: 'ACTIVE',
      expires_at: null,
    });
    mockDb.state.subscriptions.push({
      id: 'sub_monthly_old',
      installation_id: instId,
      product_id: 'vibekit_pro_monthly',
      purchase_token: 'tok_old_monthly_token',
      status: 'ACTIVE',
      expires_at: new Date().toISOString(),
    });

    // The old monthly subscription expires
    await qm.handleSubscriptionLifecycleUpdate({
      purchaseToken: 'tok_old_monthly_token',
      status: 'EXPIRED',
      expiresAt: new Date().toISOString(),
    });

    // The user's installation MUST REMAIN is_pro = 1!
    const inst = mockDb.state.installations.find((i) => i.id === instId);
    expect(inst.is_pro).toBe(1);
  });

  it('Bug #4: safeFetch allowlist accepts openrouter.ai and rejects prohibited hosts', () => {
    const openrouterUrl = validateOutboundUrl('https://openrouter.ai/api/v1/chat/completions');
    expect(openrouterUrl.hostname).toBe('openrouter.ai');

    const geminiUrl = validateOutboundUrl('https://generativelanguage.googleapis.com/v1beta/models');
    expect(geminiUrl.hostname).toBe('generativelanguage.googleapis.com');

    // Untrusted host must throw SSRF violation
    expect(() => validateOutboundUrl('https://evil-untrusted-server.com/api')).toThrow('SSRF Violation');
  });

  it('Bug #7: installationMiddleware sanitizes special characters and clamps length to 64', async () => {
    const app = new Hono<any>();
    app.use('*', installationMiddleware());
    app.get('/test-inst', (c) => {
      return c.json({ installationId: c.get('installationId'), requestId: c.get('requestId') });
    });

    // Test sanitization of malicious characters and long string
    const maliciousHeader = 'malicious_user!@#$%^&*()_+=12345678901234567890123456789012345678901234567890EXTRA';
    const res = await app.request('/test-inst', {
      headers: {
        'X-App-Instance-Id': maliciousHeader,
      },
    });

    expect(res.status).toBe(200);
    const data = (await res.json()) as { installationId: string; requestId: string };
    expect(data.installationId.length).toBeLessThanOrEqual(64);
    expect(data.installationId).not.toContain('!');
    expect(data.installationId).not.toContain('@');
    expect(data.installationId).not.toContain('$');
    expect(data.installationId).toMatch(/^[a-zA-Z0-9_\-\.]+$/);
  });

  it('Bug #8: bodyLimitMiddleware rejects oversized chunked payload even without Content-Length header', async () => {
    const app = new Hono<any>();
    app.use('*', bodyLimitMiddleware(100)); // Limit to 100 bytes
    app.post('/test-body', async (c) => {
      const body = await c.req.json();
      return c.json({ ok: true, body });
    });

    const largePayload = JSON.stringify({ data: 'a'.repeat(200) });
    // Strip Content-Length header to simulate chunked/streaming transmission
    const req = new Request('http://localhost/test-body', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: largePayload,
    });

    try {
      const res = await app.fetch(req);
      expect(res.status).toBeGreaterThanOrEqual(400);
    } catch (err: any) {
      expect(err.name).toBe('ValidationError');
    }
  });

  it('Bug #10: rateLimiterMiddleware gracefully runs without D1 and handles request rate limiting cleanly', async () => {
    const app = new Hono<any>();
    app.use('*', rateLimiterMiddleware({ generalLimit: 3, windowSeconds: 60 }));
    app.get('/test-rate', (c) => c.text('ok'));

    const req = (ip: string) =>
      app.request('/test-rate', {
        headers: { 'CF-Connecting-IP': ip, 'X-App-Instance-Id': 'rate_user_1' },
      });

    // 3 allowed requests
    const res1 = await req('1.2.3.4');
    expect(res1.status).toBe(200);
    const res2 = await req('1.2.3.4');
    expect(res2.status).toBe(200);
    const res3 = await req('1.2.3.4');
    expect(res3.status).toBe(200);

    // 4th request must be 429
    const res4 = await req('1.2.3.4');
    expect(res4.status).toBe(429);
    const body = (await res4.json()) as { error: { code: string; message: string } };
    expect(body.error.code).toBe('RATE_LIMIT_EXCEEDED');
  });

  it('Bug #11: /terms serves genuine Terms of Service rather than Privacy Policy', async () => {
    const { default: appEntry } = await import('../src/index');
    const res = await appEntry.request('/terms', { method: 'GET' });
    expect(res.status).toBe(200);
    const html = await res.text();
    expect(html).toContain('Terms of Service');
    expect(html).toContain('Acceptance of Terms');
  });

  it('Bug #12: QuotaManager reserveCredit & refundCredit roll back cleanly on failure', async () => {
    const qm = new QuotaManager({
      ENVIRONMENT: 'test',
      MAX_DAILY_FREE_CREDITS: '3',
    } as any);
    const id = `inst_refund_${Date.now()}`;

    const bucket = await qm.reserveCredit(id);
    expect(bucket).toBe('free');
    expect((await qm.getQuotaStatus(id)).free_credits_remaining).toBe(2);

    await qm.refundCredit(id, bucket!);
    expect((await qm.getQuotaStatus(id)).free_credits_remaining).toBe(3);

    await qm.deleteUserData(id);
    expect((await qm.getQuotaStatus(id)).free_credits_remaining).toBe(3);
  });

  it('Bug #13: /v1/auth/attest fails closed in production without signing secret', async () => {
    const { default: appEntry } = await import('../src/index');
    const res = await appEntry.request(
      '/v1/auth/attest',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-App-Instance-Id': 'prod_test_user',
        },
        body: JSON.stringify({ integrityToken: 'mock_token' }),
      },
      { ENVIRONMENT: 'production', GOOGLE_PLAY_SERVICE_ACCOUNT_JSON: undefined } as any
    );
    expect(res.status).toBeGreaterThanOrEqual(400);
  });

  it('Bug #14: FallbackChainAIProvider rethrows SAFETY_VIOLATION without fallback or opening circuit', async () => {
    resetFallbackCircuitBreaker();
    let primaryCalls = 0;
    let fallbackCalls = 0;

    const primary: AIProvider = {
      generateReplies: async () => {
        primaryCalls += 1;
        if (primaryCalls <= 4) {
          throw new Error('SAFETY_VIOLATION: Content blocked by safety policy');
        }
        return ['Safe reply'];
      },
      generateCaptions: async () => ({ captions: [], hooks: [], callToActions: [], hashtags: [] }),
      generateBios: async () => ({ bios: [], usernames: [] }),
      vibeCheck: async () => ({ score: 80, title: 'Ok', verdict: 'Ok', tags: [], rewrites: [] }),
    };

    const fallback: AIProvider = {
      generateReplies: async () => {
        fallbackCalls += 1;
        return ['Fallback reply'];
      },
      generateCaptions: async () => ({ captions: [], hooks: [], callToActions: [], hashtags: [] }),
      generateBios: async () => ({ bios: [], usernames: [] }),
      vibeCheck: async () => ({ score: 80, title: 'Ok', verdict: 'Ok', tags: [], rewrites: [] }),
    };

    const chain = new FallbackChainAIProvider(primary, fallback);
    const params = { message: 'unsafe', tone: 'Funny', language: 'English', length: 'short', count: 1 };

    for (let i = 0; i < 4; i++) {
      await expect(chain.generateReplies(params)).rejects.toThrow('SAFETY_VIOLATION');
    }
    expect(fallbackCalls).toBe(0);

    // 5th clean request must still hit primary because safety errors did not trip circuit breaker
    const res = await chain.generateReplies({ ...params, message: 'safe' });
    expect(res).toEqual(['Safe reply']);
    expect(primaryCalls).toBe(5);
    expect(fallbackCalls).toBe(0);
  });

  it('Bug #15: UsageRepository.deductRewardedCreditAtomic binds exact 2 params matching SQL placeholders', async () => {
    let capturedSql = '';
    let capturedArgs: unknown[] = [];

    const mockDb = {
      prepare: (sql: string) => {
        capturedSql = sql;
        return {
          bind: (...args: unknown[]) => {
            capturedArgs = args;
            return {
              run: async () => ({ meta: { changes: 1 } }),
            };
          },
        };
      },
    };

    const repo = new UsageRepository(mockDb as any);
    const deducted = await repo.deductRewardedCreditAtomic('inst_rew_1');
    expect(deducted).toBe(true);
    expect((capturedSql.match(/\?/g) || []).length).toBe(2);
    expect(capturedArgs).toHaveLength(2);
    expect(capturedArgs[1]).toBe('inst_rew_1');
    expect(capturedSql.toUpperCase()).toContain('ORDER BY USAGE_DATE ASC');
  });

  it('Bug #16: POST /v1/purchases/rtdn skips subNotice missing purchaseToken or subscriptionId', async () => {
    const { default: appEntry } = await import('../src/index');
    const encoded = btoa(JSON.stringify({ subscriptionNotification: { notificationType: 2 } }));
    const res = await appEntry.request(
      '/v1/purchases/rtdn',
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          message: { data: encoded, messageId: 'msg_missing_fields_1' },
        }),
      },
      { ENVIRONMENT: 'production' } as any
    );

    expect(res.status).toBe(200);
    const json: any = await res.json();
    expect(json.processed).toBe(false);
    expect(json.reason).toBe('MISSING_FIELDS');
  });

  it('Bug #17: verifySessionToken rejects signed payloads with missing or invalid exp', async () => {
    const secret = 'test_session_secret_value';
    const b64u = (str: string) => btoa(str).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
    const header = b64u(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
    const malformedPayload = b64u(JSON.stringify({ sub: 'inst_1', dev: 'dev_1' })); // Missing exp
    const message = `${header}.${malformedPayload}`;
    const key = await crypto.subtle.importKey(
      'raw',
      new TextEncoder().encode(secret),
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['sign']
    );
    const sigBuf = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(message));
    const sig = b64u(String.fromCharCode(...new Uint8Array(sigBuf)));
    const forgedWithoutExp = `${message}.${sig}`;

    expect(await verifySessionToken(forgedWithoutExp, secret)).toBeNull();

    const validToken = await mintSessionToken('inst_1', 'dev_1', secret, 60);
    const verified = await verifySessionToken(validToken, secret);
    expect(verified?.sub).toBe('inst_1');
  });

  it('Bug #18: installationMiddleware exempts external SSV and RTDN webhooks from installation tracking', async () => {
    const queries: string[] = [];
    const spyingDb = {
      prepare: (sql: string) => {
        queries.push(sql);
        return {
          bind: () => ({
            first: async () => null,
            run: async () => ({ meta: { changes: 0 } }),
          }),
        };
      },
    };

    const webhookApp = new Hono<any>();
    webhookApp.use('*', async (c, next) => {
      c.env = { DB: spyingDb };
      await next();
    });
    webhookApp.use('/v1/*', installationMiddleware());
    webhookApp.get('/v1/ads/ssv', (c) => c.text('OK'));
    webhookApp.post('/v1/purchases/rtdn', (c) => c.json({ ok: true }));

    const ssvRes = await webhookApp.request('/v1/ads/ssv', { method: 'GET' });
    const rtdnRes = await webhookApp.request('/v1/purchases/rtdn', { method: 'POST' });

    expect(ssvRes.status).toBe(200);
    expect(rtdnRes.status).toBe(200);
    expect(queries).toHaveLength(0);
  });

  it('Bug #19: OpenAICompatibleProvider maps content_filter responses to SAFETY_VIOLATION', async () => {
    const mockFetch = vi.fn().mockResolvedValue(
      new Response(
        JSON.stringify({
          choices: [{ finish_reason: 'content_filter', message: { content: '' } }],
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      )
    );
    vi.stubGlobal('fetch', mockFetch);

    try {
      const provider = new OpenAICompatibleProvider(
        'test_key',
        'https://api.openai.com/v1',
        'gpt-4o-mini'
      );
      await expect(
        provider.generateReplies({
          message: 'unsafe test',
          tone: 'Funny',
          language: 'English',
          length: 'short',
          count: 1,
        })
      ).rejects.toThrow('SAFETY_VIOLATION');
    } finally {
      vi.unstubAllGlobals();
    }
  });

  it('Bug #20: handleScheduledTask purges expired idempotency_keys alongside rate_limit_counters', async () => {
    const executedSqls: string[] = [];
    const mockDb = {
      prepare: (sql: string) => {
        executedSqls.push(sql);
        return {
          bind: () => ({
            first: async () => ({ total: 0, successes: 0, avg_latency: 0 }),
            all: async () => ({ results: [] }),
            run: async () => ({ meta: { changes: 1 } }),
          }),
          all: async () => ({ results: [] }),
          first: async () => null,
          run: async () => ({ meta: { changes: 0 } }),
        };
      },
      batch: async () => [],
    };

    const waitPromises: Promise<unknown>[] = [];
    const ctx = {
      waitUntil: (p: Promise<unknown>) => {
        waitPromises.push(p);
      },
    } as any;

    await handleScheduledTask({} as any, { DB: mockDb, ENVIRONMENT: 'production' } as any, ctx);
    await Promise.all(waitPromises);

    expect(executedSqls.some((s) => s.includes('DELETE FROM rate_limit_counters'))).toBe(true);
    expect(executedSqls.some((s) => s.includes('DELETE FROM idempotency_keys WHERE expires_at <='))).toBe(true);
  });

  it('Bug #21: POST /v1/ads/verify-reward limit error reflects 200 monthly credits without unlimited claim', async () => {
    const { default: appEntry } = await import('../src/index');
    const env = { ENVIRONMENT: 'test', MAX_DAILY_REWARDS: '1' } as any;
    const headers = {
      'Content-Type': 'application/json',
      'X-App-Instance-Id': `inst_ad_cap_${Date.now()}`,
    };

    const firstRes = await appEntry.request(
      '/v1/ads/verify-reward',
      { method: 'POST', headers, body: JSON.stringify({ reward_id: 'r1' }) },
      env
    );
    expect(firstRes.status).toBe(200);

    const secondRes = await appEntry.request(
      '/v1/ads/verify-reward',
      { method: 'POST', headers, body: JSON.stringify({ reward_id: 'r2' }) },
      env
    );
    expect(secondRes.status).toBe(429);
    const body: any = await secondRes.json();
    expect(body.error?.message).toContain('200 monthly');
    expect(body.error?.message?.toLowerCase()).not.toContain('unlimited');
  });
});

describe('Bug #22 & #23: CORS Preflight X-Timezone-Offset & Gujarati Mock Localization', () => {
  it('allows X-Timezone-Offset and X-Installation-Id in CORS preflight for localhost:8888', async () => {
    const { default: appEntry } = await import('../src/index');
    const preflightRes = await appEntry.request(
      '/v1/generations/reply',
      {
        method: 'OPTIONS',
        headers: {
          Origin: 'http://localhost:8888',
          'Access-Control-Request-Method': 'POST',
          'Access-Control-Request-Headers':
            'content-type,x-app-instance-id,x-app-version,x-request-id,x-timezone-offset',
        },
      },
      { ENVIRONMENT: 'development', AI_PROVIDER: 'mock' } as any
    );

    expect(preflightRes.status).toBe(204);
    expect(preflightRes.headers.get('access-control-allow-origin')).toBe('http://localhost:8888');
    const allowedHeaders = (preflightRes.headers.get('access-control-allow-headers') ?? '').toLowerCase();
    expect(allowedHeaders).toContain('x-timezone-offset');
    expect(allowedHeaders).toContain('x-installation-id');
  });

  it('localizes mockBios and mockVibeCheck in Gujarati script when language is Gujarati', async () => {
    const { mockBios, mockVibeCheck } = await import('../src/ai/mock_outputs');
    const gujaratiRegex = /[\u0A80-\u0AFF]/;

    const bioOut = mockBios({
      interests: 'coffee and code',
      platform: 'Instagram',
      vibe: 'Witty',
      language: 'Gujarati',
      includeUsernames: true,
    });
    expect(bioOut.bios.length).toBeGreaterThan(0);
    expect(bioOut.bios.some((b) => gujaratiRegex.test(b))).toBe(true);
    expect(bioOut.usernames.length).toBeGreaterThan(0);

    const vibeFlags = mockVibeCheck({
      text: 'hi',
      mode: 'flags',
      language: 'Gujarati',
    });
    const vibeRoast = mockVibeCheck({
      text: 'hi',
      mode: 'roast',
      language: 'Gujarati',
    });
    expect(gujaratiRegex.test(vibeFlags.title)).toBe(true);
    expect(gujaratiRegex.test(vibeFlags.verdict)).toBe(true);
    expect(vibeFlags.tags.some((t) => gujaratiRegex.test(t))).toBe(true);
    expect(vibeFlags.rewrites.some((r) => gujaratiRegex.test(r))).toBe(true);
    expect(vibeFlags.title).not.toBe(vibeRoast.title);
    expect(vibeFlags.verdict).not.toBe(vibeRoast.verdict);
  });
});

describe('Security & Consistency Audit Regression Tests (CRIT & HIGH fixes)', () => {
  it('CRIT-05: adminAuthMiddleware rejects unsigned Cf-Access-Jwt-Assertion in production', async () => {
    const app = new Hono<any>();
    app.onError(globalErrorHandler);
    app.use('*', async (c, next) => {
      c.env = {
        ENVIRONMENT: 'production',
        ADMIN_EMAILS: 'admin@vibekit.ai',
      };
      await next();
    });
    app.use('/admin/*', adminAuthMiddleware());
    app.get('/admin/stats', (c) => c.json({ ok: true }));

    const header = btoa(JSON.stringify({ alg: 'RS256', typ: 'JWT' })).replace(/=+$/, '');
    const payload = btoa(
      JSON.stringify({
        email: 'admin@vibekit.ai',
        exp: Math.floor(Date.now() / 1000) + 3600,
      })
    ).replace(/=+$/, '');
    const forgedJwt = `${header}.${payload}.forgedsig`;

    const res = await app.request('/admin/stats', {
      headers: { 'Cf-Access-Jwt-Assertion': forgedJwt },
    });
    expect(res.status).toBe(401);
  });

  it('CRIT-08: rateLimiterMiddleware enforces per-IP cap across rotating X-App-Instance-Id values', async () => {
    const app = new Hono<any>();
    app.use('*', rateLimiterMiddleware({ generalLimit: 2, windowSeconds: 60 }));
    app.get('/test-ip-cap', (c) => c.text('ok'));

    const sharedIp = '203.0.113.77';
    // generalLimit = 2 -> per-IP cap is Math.max(2 * 3, 2 + 10) = 12 across unique installation IDs
    for (let i = 0; i < 12; i++) {
      const res = await app.request('/test-ip-cap', {
        headers: {
          'CF-Connecting-IP': sharedIp,
          'X-App-Instance-Id': `rotating_inst_${i}`,
        },
      });
      expect(res.status).toBe(200);
    }

    const blockedRes = await app.request('/test-ip-cap', {
      headers: {
        'CF-Connecting-IP': sharedIp,
        'X-App-Instance-Id': 'rotating_inst_12',
      },
    });
    expect(blockedRes.status).toBe(429);
  });

  it('HIGH-14: bodyLimitMiddleware rejects malformed or negative Content-Length headers', async () => {
    const app = new Hono<any>();
    app.onError(globalErrorHandler);
    app.use('*', bodyLimitMiddleware(1024));
    app.post('/test-cl', (c) => c.json({ ok: true }));

    const badAlpha = await app.request('/test-cl', {
      method: 'POST',
      headers: { 'Content-Length': '10abc', 'Content-Type': 'application/json' },
      body: '{}',
    });
    expect(badAlpha.status).toBe(400);

    const badNeg = await app.request('/test-cl', {
      method: 'POST',
      headers: { 'Content-Length': '-5', 'Content-Type': 'application/json' },
      body: '{}',
    });
    expect(badNeg.status).toBe(400);
  });

  it('HIGH-01 & HIGH-02: /privacy/delete-data moved to /v1, rejects anonymous_default, and preserves bans table', async () => {
    const { default: appEntry } = await import('../src/index');
    const deletedTables: string[] = [];

    const mockDb = {
      prepare: (sql: string) => {
        const makeExec = () => ({
          first: async () => null,
          all: async () => ({ results: [] }),
          run: async () => {
            const match = sql.match(/DELETE FROM\s+([a-z_]+)/i);
            if (match?.[1]) deletedTables.push(match[1].toLowerCase());
            return { meta: { changes: 1 } };
          },
        });
        return {
          bind: (..._args: unknown[]) => makeExec(),
          ...makeExec(),
        };
      },
      batch: async (stmts: Array<{ run: () => Promise<unknown> }>) => {
        return Promise.all(stmts.map((s) => s.run()));
      },
    };

    const rootRes = await appEntry.request('/privacy/delete-data', { method: 'POST' }, {
      ENVIRONMENT: 'test',
      DB: mockDb,
    } as any);
    expect(rootRes.status).toBe(404);

    const anonRes = await appEntry.request(
      '/v1/privacy/delete-data',
      { method: 'POST' },
      { ENVIRONMENT: 'test', DB: mockDb } as any
    );
    expect(anonRes.status).toBe(401);

    const validRes = await appEntry.request(
      '/v1/privacy/delete-data',
      {
        method: 'POST',
        headers: { 'X-App-Instance-Id': 'user_delete_test_1' },
      },
      { ENVIRONMENT: 'test', DB: mockDb } as any
    );
    expect(validRes.status).toBe(200);
    expect(deletedTables).toContain('installations');
    expect(deletedTables).not.toContain('bans');
  });

  it('CRIT-01, CRIT-02 & HIGH-03: QuotaManager Pro rewarded fallback and Lifetime Pro preservation', async () => {
    const futureIso = new Date(Date.now() + 86400_000).toISOString();
    const pastIso = new Date(Date.now() - 86400_000).toISOString();
    const state = {
      installation: { id: 'inst_pro_1', is_pro: 1, pro_expires_at: null as string | null },
      cycle: {
        id: 'cyc_1',
        installation_id: 'inst_pro_1',
        cycle_start: pastIso,
        cycle_end: futureIso,
        credits_used: 200,
      },
      dailyUsage: {
        id: 'du_1',
        installation_id: 'inst_pro_1',
        usage_date: new Date().toISOString().split('T')[0] ?? '',
        free_credits_used: 0,
        rewarded_credits_earned: 3,
        rewarded_ads_watched: 1,
      },
      entitlements: [
        {
          id: 'ent_life_1',
          installation_id: 'inst_pro_1',
          product_id: 'vibekit_pro_lifetime',
          purchase_token: 'tok_life_1',
          status: 'ACTIVE',
          expires_at: null as string | null,
        },
      ],
    };

    const mockDb = {
      prepare: (sql: string) => ({
        bind: (...args: unknown[]) => ({
          first: async () => {
            const s = sql.toLowerCase();
            if (s.includes('from installations where id = ?')) return { ...state.installation };
            if (s.includes('from pro_cycle_usage')) return { ...state.cycle };
            if (s.includes('from subscription_entitlements')) {
              if (s.includes('purchase_token = ?')) {
                return state.entitlements.find((e) => e.purchase_token === args[0]) ?? null;
              }
              return state.entitlements.find((e) => e.installation_id === args[0] && e.expires_at === null) ?? null;
            }
            if (s.includes('from daily_usage') && s.includes('usage_date = ?')) return { ...state.dailyUsage };
            if (s.includes('sum(rewarded_credits_earned)')) {
              return { total_rewarded: state.dailyUsage.rewarded_credits_earned };
            }
            if (s.includes('sum(pro_credits_used)')) return { total: 0 };
            return null;
          },
          all: async () => {
            const s = sql.toLowerCase();
            if (s.includes('from daily_usage') && s.includes('rewarded_credits_earned > 0')) {
              return { results: state.dailyUsage.rewarded_credits_earned > 0 ? [{ ...state.dailyUsage }] : [] };
            }
            return { results: [] };
          },
          run: async () => {
            const s = sql.toLowerCase();
            if (s.includes('insert into installations') && s.includes('pro_expires_at')) {
              const incomingExpires = args[3] as string | null;
              state.installation.is_pro = 1;
              if (incomingExpires === null) {
                state.installation.pro_expires_at = null;
              } else {
                state.installation.pro_expires_at = incomingExpires ?? state.installation.pro_expires_at;
              }
            }
            if (s.includes('update pro_cycle_usage') && s.includes('credits_used = credits_used + 1')) {
              const limit = Number(args[2] ?? 200);
              if (state.cycle.credits_used < limit) {
                state.cycle.credits_used += 1;
                return { meta: { changes: 1 } };
              }
              return { meta: { changes: 0 } };
            }
            if (s.includes('rewarded_credits_earned = rewarded_credits_earned - 1')) {
              if (state.dailyUsage.rewarded_credits_earned > 0) {
                state.dailyUsage.rewarded_credits_earned -= 1;
                return { meta: { changes: 1 } };
              }
              return { meta: { changes: 0 } };
            }
            return { meta: { changes: 1 } };
          },
        }),
      }),
    };

    const qm = new QuotaManager({ DB: mockDb as any } as any);

    // Exhausted Pro cycle must still fall back to rewarded credits
    const reserved = await qm.reserveCreditWithDate('inst_pro_1');
    expect(reserved).toEqual({ bucket: 'rewarded', usageDate: state.dailyUsage.usage_date });
    expect(state.dailyUsage.rewarded_credits_earned).toBe(2);

    // Lifetime Pro (pro_expires_at = null) must never be overwritten by a timed expiry
    await qm.activatePro('inst_pro_1', 'vibekit_pro_monthly', 'tok_m1', 'ord_m1', '2027-01-01T00:00:00.000Z');
    expect(state.installation.pro_expires_at).toBeNull();
  });

  it('HIGH-05: verifyAdMobSsvSignature verifies callbacks even when signature param appears first', async () => {
    const keyPair = (await crypto.subtle.generateKey(
      { name: 'ECDSA', namedCurve: 'P-256' },
      true,
      ['sign', 'verify']
    )) as CryptoKeyPair;
    const spkiBuf = (await crypto.subtle.exportKey('spki', keyPair.publicKey)) as ArrayBuffer;
    const spkiB64 = btoa(String.fromCharCode(...new Uint8Array(spkiBuf)));

    const signedPayload = 'custom_data=user_1&key_id=777&reward_amount=3';
    const sigBuf = await crypto.subtle.sign(
      { name: 'ECDSA', hash: 'SHA-256' },
      keyPair.privateKey,
      new TextEncoder().encode(signedPayload)
    );
    const sigB64Url = btoa(String.fromCharCode(...new Uint8Array(sigBuf)))
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=+$/, '');

    const mockFetch = vi.fn().mockResolvedValue(
      new Response(JSON.stringify({ keys: [{ keyId: 777, base64: spkiB64 }] }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      })
    );
    vi.stubGlobal('fetch', mockFetch);

    try {
      const reorderedQuery = `signature=${encodeURIComponent(sigB64Url)}&${signedPayload}`;
      const ok = await verifyAdMobSsvSignature(
        reorderedQuery,
        '777',
        sigB64Url,
        'https://gstatic.com/admob/reward/verifier-keys.json',
        false
      );
      expect(ok).toBe(true);
    } finally {
      vi.unstubAllGlobals();
    }
  });
});
