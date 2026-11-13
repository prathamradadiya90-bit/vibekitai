import { Env } from '../src/types';

export function createMockEnv(overrides?: Partial<Env>): Env {
  return {
    DB: undefined as any,
    ENVIRONMENT: 'test',
    GEMINI_API_KEY: undefined,
    GEMINI_MODEL: 'gemini-1.5-flash',
    MAX_DAILY_FREE_CREDITS: '3',
    REWARD_CREDITS_PER_AD: '3',
    MAX_DAILY_REWARDS: '2',
    MONTHLY_PRO_CREDITS: '200',
    SKIP_SSV_VERIFY_FOR_DEV: 'true',
    ...overrides,
  };
}

export function createMockD1Database(): D1Database {
  const store = new Map<string, unknown>();
  return {
    prepare: (query: string) => {
      let boundArgs: unknown[] = [];
      const stmt: any = {
        bind: (...args: unknown[]) => {
          boundArgs = args;
          return stmt;
        },
        first: async <T>() => null as T | null,
        all: async <T>() => ({ results: [] as T[], success: true, meta: { changes: 1 } }),
        run: async () => ({ success: true, meta: { changes: 1 } }),
      };
      return stmt;
    },
    batch: async (statements: any[]) => {
      return statements.map(() => ({ success: true, meta: { changes: 1 } }));
    },
    exec: async () => ({ count: 0, duration: 0 }),
    dump: async () => new ArrayBuffer(0),
  } as unknown as D1Database;
}
