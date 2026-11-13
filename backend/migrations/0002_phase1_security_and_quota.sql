-- VibeKit AI Database Migration 0002_phase1_security_and_quota.sql
-- Fixes pro quota cycle tracking, AdMob SSV, abuse signals, and challenge cache

-- 1. Pro Subscription Billing Cycle Tracking
CREATE TABLE IF NOT EXISTS pro_cycle_usage (
  id TEXT PRIMARY KEY,
  installation_id TEXT NOT NULL,
  cycle_start TEXT NOT NULL, -- ISO-8601 UTC timestamp of cycle start
  cycle_end TEXT NOT NULL,   -- ISO-8601 UTC timestamp of cycle renewal/expiry
  credits_used INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (installation_id) REFERENCES installations(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_pro_cycle_lookup ON pro_cycle_usage(installation_id, cycle_start, cycle_end);

-- 2. AdMob SSV (Server-Side Verification) Transactions
CREATE TABLE IF NOT EXISTS admob_ssv_transactions (
  transaction_id TEXT PRIMARY KEY,
  installation_id TEXT NOT NULL,
  reward_id TEXT,
  key_id INTEGER NOT NULL,
  verified_at TEXT NOT NULL,
  ad_network TEXT DEFAULT 'admob',
  FOREIGN KEY (installation_id) REFERENCES installations(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_admob_ssv_inst ON admob_ssv_transactions(installation_id);

-- 3. Ad Nonces (Prevents replay attacks on rewarded ads)
CREATE TABLE IF NOT EXISTS ad_nonces (
  nonce TEXT PRIMARY KEY,
  installation_id TEXT NOT NULL,
  created_at TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  used_at TEXT,
  FOREIGN KEY (installation_id) REFERENCES installations(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_ad_nonces_expiry ON ad_nonces(expires_at);

-- 4. Abuse Signals (Hashed IP & device integrity verdicts - ZERO raw IPs stored)
CREATE TABLE IF NOT EXISTS abuse_signals (
  id TEXT PRIMARY KEY,
  ip_hash TEXT NOT NULL,
  device_integrity_hash TEXT,
  request_count INTEGER NOT NULL DEFAULT 1,
  window_start TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_abuse_signals_lookup ON abuse_signals(ip_hash, window_start);

-- 5. Rate Limiting Sliding Window (Shared across edge isolates)
CREATE TABLE IF NOT EXISTS rate_limit_counters (
  key TEXT PRIMARY KEY,
  count INTEGER NOT NULL DEFAULT 1,
  window_start INTEGER NOT NULL, -- Unix timestamp in seconds
  expires_at INTEGER NOT NULL    -- Unix timestamp in seconds
);

CREATE INDEX IF NOT EXISTS idx_rate_limit_expiry ON rate_limit_counters(expires_at);

-- 6. Daily Challenge Response Cache (Static daily prompts only - NEVER user-private text)
CREATE TABLE IF NOT EXISTS daily_challenge_cache (
  cache_key TEXT PRIMARY KEY, -- SHA-256 of (challenge_id, tone, language)
  category TEXT NOT NULL,     -- 'reply' | 'caption'
  response_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  expires_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_challenge_cache_expiry ON daily_challenge_cache(expires_at);
