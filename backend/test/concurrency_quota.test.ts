import { describe, it, expect, beforeEach } from 'vitest';
import app from '../src/index';
import { Env } from '../src/types';
import { QuotaManager } from '../src/quota/quota_manager';
import { AICircuitBreaker } from '../src/security/circuit_breaker';

function createMockD1DatabaseWithAtomicLock(): D1Database {
  // In-memory relational tables simulating D1 SQLite locking semantics
  const usageStore = new Map<string, { free_credits_used: number; rewarded_credits_earned: number }>();
  const idempotencyStore = new Map<string, any>();
  const budgetStore = new Map<string, any>();
  const genMetadataStore: any[] = [];
  const installationsStore = new Map<string, any>();

  return {
    prepare: (query: string) => {
      let boundArgs: any[] = [];
      const stmt: any = {
        bind: (...args: any[]) => {
          boundArgs = args;
          return stmt;
        },
        first: async <T>() => {
          const lower = query.toLowerCase().replace(/\s+/g, ' ');
          if (lower.includes('from daily_usage where installation_id = ? and usage_date = ?')) {
            const [instId, date] = boundArgs;
            const row = usageStore.get(`${instId}_${date}`);
            return (row ? { ...row, usage_date: date, pro_credits_used: 0, rewarded_ads_watched: 0 } : null) as T | null;
          }
          if (lower.includes('from idempotency_keys')) {
            const [key, instId, endpoint, now] = boundArgs;
            const rec = idempotencyStore.get(key);
            if (rec && rec.installation_id === instId && rec.endpoint === endpoint && rec.expires_at > now) {
              return rec as T | null;
            }
            return null as T | null;
          }
          if (lower.includes('from ai_daily_budget')) {
            const date = boundArgs[0];
            return (budgetStore.get(date) || null) as T | null;
          }
          if (lower.includes('from installations where id = ?')) {
            const instId = boundArgs[0];
            return (installationsStore.get(instId) || { id: instId, is_pro: 0, pro_expires_at: null }) as T | null;
          }
          return null as T | null;
        },
        all: async <T>() => ({ results: [] as T[], success: true }),
        run: async () => {
          const lower = query.toLowerCase().replace(/\s+/g, ' ');

          // 1. Atomic Free Credit Guarded Update
          if (lower.includes('update daily_usage set free_credits_used = free_credits_used + 1')) {
            const [nowIso, instId, usageDate, maxDailyFree] = boundArgs;
            const key = `${instId}_${usageDate}`;
            const row = usageStore.get(key);

            if (row && row.free_credits_used < maxDailyFree) {
              row.free_credits_used += 1;
              usageStore.set(key, row);
              return { success: true, meta: { changes: 1 } };
            }
            return { success: true, meta: { changes: 0 } };
          }

          // 2. Initial Day Insertion
          if (lower.includes('insert into daily_usage (id, installation_id, usage_date, free_credits_used')) {
            const [id, instId, usageDate] = boundArgs;
            const key = `${instId}_${usageDate}`;
            if (usageStore.has(key)) {
              throw new Error('UNIQUE constraint failed: daily_usage');
            }
            usageStore.set(key, { free_credits_used: 1, rewarded_credits_earned: 0 });
            return { success: true, meta: { changes: 1 } };
          }

          // 3. Idempotency store
          if (lower.includes('insert into idempotency_keys')) {
            const [key, instId, endpoint, reqHash, resJson, status, now, exp] = boundArgs;
            idempotencyStore.set(key, {
              idempotency_key: key,
              installation_id: instId,
              endpoint,
              request_hash: reqHash,
              response_json: resJson,
              status_code: status,
              created_at: now,
              expires_at: exp,
            });
            return { success: true, meta: { changes: 1 } };
          }

          // 4. AI Budget Break
          if (lower.includes('insert into ai_daily_budget')) {
            const [date, spend, maxBudget, now] = boundArgs;
            const current = budgetStore.get(date) || { total_spend_usd: 0, max_budget_usd: maxBudget, is_tripped: 0 };
            current.total_spend_usd += spend;
            if (current.total_spend_usd >= maxBudget) {
              current.is_tripped = 1;
            }
            budgetStore.set(date, current);
            return { success: true, meta: { changes: 1 } };
          }

          // 5. Metadata write
          if (lower.includes('insert into generation_metadata')) {
            genMetadataStore.push({ id: boundArgs[0] });
            return { success: true, meta: { changes: 1 } };
          }

          if (lower.startsWith('update ')) {
            return { success: true, meta: { changes: 0 } };
          }

          return { success: true, meta: { changes: 1 } };
        },
      };
      return stmt;
    },
    batch: async (statements: any[]) => statements.map(() => ({ success: true, meta: { changes: 1 } })),
    exec: async () => ({ count: 0, duration: 0 }),
    dump: async () => new ArrayBuffer(0),
  } as unknown as D1Database;
}

describe('Phase 1: Concurrency, Quotas & Abuse-Proofing', () => {
  let mockEnv: Env;
  let mockDb: D1Database;

  beforeEach(() => {
    mockDb = createMockD1DatabaseWithAtomicLock();
    mockEnv = {
      DB: mockDb,
      ENVIRONMENT: 'test',
      MAX_DAILY_FREE_CREDITS: '3',
      REWARD_CREDITS_PER_AD: '3',
      MAX_DAILY_REWARDS: '2',
      MONTHLY_PRO_CREDITS: '200',
      GEMINI_MODEL: 'gemini-1.5-flash',
    };
  });

  it('guarantees zero overspend when 100 parallel requests compete for 3 free credits', async () => {
    const installationId = 'inst_concurrent_stress_user';

    // Spawn 100 concurrent requests simultaneously
    const requests = Array.from({ length: 100 }).map((_, idx) =>
      app.request(
        '/v1/generations/reply',
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-App-Instance-Id': installationId,
          },
          body: JSON.stringify({
            message: `Concurrent message ${idx}`,
            tone: 'Funny',
            language: 'English',
          }),
        },
        mockEnv
      )
    );

    const responses = await Promise.all(requests);
    const statuses = responses.map((r) => r.status);

    const successful = statuses.filter((s) => s === 200).length;
    const quotaExceeded = statuses.filter((s) => s === 429).length;

    // Exactly 3 must succeed, exactly 97 must fail with 429 Quota Exceeded
    expect(successful).toBe(3);
    expect(quotaExceeded).toBe(97);

    // Verify quota status reflects exactly 0 credits remaining
    const quotaManager = new QuotaManager(mockEnv);
    const finalQuota = await quotaManager.getQuotaStatus(installationId);
    expect(finalQuota.free_credits_remaining).toBe(0);
    expect(finalQuota.total_credits_remaining).toBe(0);
  });

  it('deduplicates retried requests with Idempotency-Key and returns cached response without debiting', async () => {
    const installationId = 'inst_idempotency_user';
    const idempotencyKey = 'client_retry_key_unique_999';

    // 1. Initial Request
    const res1 = await app.request(
      '/v1/generations/reply',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-App-Instance-Id': installationId,
          'Idempotency-Key': idempotencyKey,
        },
        body: JSON.stringify({
          message: 'Tell me a witty joke',
          tone: 'Witty',
          language: 'English',
        }),
      },
      mockEnv
    );

    expect(res1.status).toBe(200);
    const json1 = (await res1.json()) as any;
    expect(json1.suggestions).toBeDefined();
    expect(json1.credits_remaining).toBe(2); // 1 credit spent out of 3

    // 2. Retry identical request 5 times with same Idempotency-Key
    for (let i = 0; i < 5; i++) {
      const retryRes = await app.request(
        '/v1/generations/reply',
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-App-Instance-Id': installationId,
            'Idempotency-Key': idempotencyKey,
          },
          body: JSON.stringify({
            message: 'Tell me a witty joke',
            tone: 'Witty',
            language: 'English',
          }),
        },
        mockEnv
      );

      expect(retryRes.status).toBe(200);
      const retryJson = (await retryRes.json()) as any;
      expect(retryJson.suggestions).toEqual(json1.suggestions);
      expect(retryJson.credits_remaining).toBe(2); // Still 2, zero additional credits deducted!
    }
  });

  it('rejects oversized request bodies >16KB with 400 VALIDATION_ERROR to prevent isolate OOM', async () => {
    const hugeMessage = 'A'.repeat(20000); // 20 KB
    const res = await app.request(
      '/v1/generations/reply',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': '20050',
          'X-App-Instance-Id': 'inst_large_body_user',
        },
        body: JSON.stringify({
          message: hugeMessage,
          tone: 'Friendly',
          language: 'English',
        }),
      },
      mockEnv
    );

    expect(res.status).toBe(400);
    const json = (await res.json()) as any;
    expect(json.error.code).toBe('VALIDATION_ERROR');
    expect(json.error.message).toContain('exceeds maximum allowed size');
  });

  it('trips global AI budget circuit breaker when daily spend threshold is breached', async () => {
    const circuitBreaker = new AICircuitBreaker(mockDb, 0.05); // Set tiny budget of $0.05

    // Simulate spend of $0.06
    await circuitBreaker.recordSpend(0.06);

    // Generation attempt should immediately throw 503 circuit breaker
    await expect(circuitBreaker.checkBudgetGuard(0.001)).rejects.toThrowError(
      /Daily AI generation budget limit reached/
    );
  });
});
