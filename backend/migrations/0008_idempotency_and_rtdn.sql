-- VibeKit AI Database Migration 0008_idempotency_and_rtdn.sql
-- Implements Idempotency Keys, RTDN Event Log, AI Daily Budget Circuit Breaker, and Hot Query Indexes

-- 1. Idempotency Keys Table (24-hour request deduplication)
CREATE TABLE IF NOT EXISTS idempotency_keys (
  idempotency_key TEXT NOT NULL,
  installation_id TEXT NOT NULL,
  endpoint TEXT NOT NULL,
  request_hash TEXT NOT NULL,
  response_json TEXT NOT NULL,
  status_code INTEGER NOT NULL,
  created_at TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  PRIMARY KEY (installation_id, endpoint, idempotency_key)
);

CREATE INDEX IF NOT EXISTS idx_idempotency_expiry ON idempotency_keys(expires_at);
CREATE INDEX IF NOT EXISTS idx_idempotency_inst ON idempotency_keys(installation_id, endpoint);

-- 2. RTDN Event Log (Pub/Sub event ordering and deduplication)
CREATE TABLE IF NOT EXISTS rtdn_event_log (
  event_id TEXT PRIMARY KEY,
  purchase_token TEXT NOT NULL,
  notification_type INTEGER NOT NULL,
  event_time_millis INTEGER NOT NULL,
  status TEXT NOT NULL,
  processed_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_rtdn_token_time ON rtdn_event_log(purchase_token, event_time_millis);

-- 3. AI Daily Spend Budget Circuit Breaker
CREATE TABLE IF NOT EXISTS ai_daily_budget (
  stat_date TEXT PRIMARY KEY, -- UTC YYYY-MM-DD
  total_spend_usd REAL NOT NULL DEFAULT 0.0,
  max_budget_usd REAL NOT NULL DEFAULT 25.0,
  is_tripped INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL
);

-- 4. Hot Query Performance Indexes identified in Audit Baseline
CREATE INDEX IF NOT EXISTS idx_daily_usage_date_credits ON daily_usage(usage_date, free_credits_used);
CREATE INDEX IF NOT EXISTS idx_gen_metadata_inst_date ON generation_metadata(installation_id, created_at);
CREATE INDEX IF NOT EXISTS idx_feedback_status_created ON feedback_records(status, created_at);
