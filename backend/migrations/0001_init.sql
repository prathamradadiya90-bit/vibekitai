-- VibeKit AI Database Migration 0001_init.sql
-- Cloudflare D1 Distributed SQLite Schema

CREATE TABLE IF NOT EXISTS installations (
  id TEXT PRIMARY KEY,
  created_at TEXT NOT NULL,
  last_active_at TEXT NOT NULL,
  is_pro INTEGER NOT NULL DEFAULT 0,
  pro_expires_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_installations_last_active ON installations(last_active_at);

CREATE TABLE IF NOT EXISTS daily_usage (
  id TEXT PRIMARY KEY,
  installation_id TEXT NOT NULL,
  usage_date TEXT NOT NULL, -- UTC YYYY-MM-DD
  free_credits_used INTEGER NOT NULL DEFAULT 0,
  rewarded_credits_earned INTEGER NOT NULL DEFAULT 0,
  rewarded_ads_watched INTEGER NOT NULL DEFAULT 0,
  pro_credits_used INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL,
  UNIQUE(installation_id, usage_date),
  FOREIGN KEY (installation_id) REFERENCES installations(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_daily_usage_lookup ON daily_usage(installation_id, usage_date);

CREATE TABLE IF NOT EXISTS generation_metadata (
  id TEXT PRIMARY KEY,
  request_id TEXT NOT NULL,
  installation_id TEXT NOT NULL,
  category TEXT NOT NULL, -- 'reply' | 'caption' | 'hooks'
  tone TEXT,
  language TEXT,
  status TEXT NOT NULL, -- 'success' | 'failed' | 'safety_rejected'
  latency_ms INTEGER,
  created_at TEXT NOT NULL,
  FOREIGN KEY (installation_id) REFERENCES installations(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_generation_metadata_date ON generation_metadata(created_at);

CREATE TABLE IF NOT EXISTS subscription_entitlements (
  id TEXT PRIMARY KEY,
  installation_id TEXT NOT NULL,
  product_id TEXT NOT NULL,
  purchase_token TEXT NOT NULL,
  order_id TEXT,
  status TEXT NOT NULL, -- 'ACTIVE' | 'EXPIRED' | 'CANCELED'
  verified_at TEXT NOT NULL,
  expires_at TEXT,
  UNIQUE(purchase_token),
  FOREIGN KEY (installation_id) REFERENCES installations(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS reward_events (
  id TEXT PRIMARY KEY,
  installation_id TEXT NOT NULL,
  reward_id TEXT NOT NULL,
  ad_network TEXT,
  credits_granted INTEGER NOT NULL,
  verified_at TEXT NOT NULL,
  UNIQUE(reward_id),
  FOREIGN KEY (installation_id) REFERENCES installations(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS feedback_records (
  id TEXT PRIMARY KEY,
  installation_id TEXT,
  message TEXT NOT NULL,
  created_at TEXT NOT NULL
);
