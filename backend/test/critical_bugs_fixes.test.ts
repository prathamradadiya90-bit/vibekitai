import { describe, it, expect, beforeEach } from 'vitest';
import { Hono } from 'hono';
import { AdsRepository } from '../src/db/ads.repo';
import { PurchasesRepository } from '../src/db/purchases.repo';
import { ReferralsRepository } from '../src/db/referrals.repo';
import { StreaksRepository } from '../src/db/streaks.repo';
import { QuotaManager } from '../src/quota/quota_manager';
import { validateOutboundUrl } from '../src/security/safe_fetch';
import { installationMiddleware } from '../src/middleware/installation';
import { bodyLimitMiddleware } from '../src/middleware/body_limit';
import { rateLimiterMiddleware } from '../src/middleware/rate_limit';

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
    const data = await res.json();
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
    const body = await res4.json();
    expect(body.error.code).toBe('RATE_LIMIT_EXCEEDED');
  });
});
