-- VibeKit AI Database Migration 0007_admin_panel.sql
-- Implements Admin Audit Log, Remote Config Versioning, Bans, Daily Stats Aggregates, and Feedback Status

-- 1. Admin Audit Log (Append-only security log for all mutating admin actions)
CREATE TABLE IF NOT EXISTS admin_audit_log (
  id TEXT PRIMARY KEY,
  admin_email TEXT NOT NULL,
  action TEXT NOT NULL,
  target_id TEXT,
  details_json TEXT NOT NULL,
  ip_hash TEXT,
  created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_admin_audit_created ON admin_audit_log(created_at);
CREATE INDEX IF NOT EXISTS idx_admin_audit_target ON admin_audit_log(target_id);
CREATE INDEX IF NOT EXISTS idx_admin_audit_admin ON admin_audit_log(admin_email);

-- 2. Versioned Remote Config Table
CREATE TABLE IF NOT EXISTS remote_config_versions (
  id TEXT PRIMARY KEY,
  config_key TEXT NOT NULL,
  value_json TEXT NOT NULL,
  version INTEGER NOT NULL DEFAULT 1,
  updated_by TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_remote_config_key_ver ON remote_config_versions(config_key, version);

-- 3. Installation Bans Table
CREATE TABLE IF NOT EXISTS bans (
  installation_id TEXT PRIMARY KEY,
  reason TEXT NOT NULL,
  banned_by TEXT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY (installation_id) REFERENCES installations(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_bans_created ON bans(created_at);

-- 4. Precomputed Daily Stats (For high-speed dashboard loading without expensive raw table scans)
CREATE TABLE IF NOT EXISTS daily_stats (
  stat_date TEXT PRIMARY KEY, -- UTC YYYY-MM-DD
  dau INTEGER NOT NULL DEFAULT 0,
  wau INTEGER NOT NULL DEFAULT 0,
  mau INTEGER NOT NULL DEFAULT 0,
  new_installs INTEGER NOT NULL DEFAULT 0,
  total_generations INTEGER NOT NULL DEFAULT 0,
  failed_generations INTEGER NOT NULL DEFAULT 0,
  avg_latency_ms INTEGER NOT NULL DEFAULT 0,
  p95_latency_ms INTEGER NOT NULL DEFAULT 0,
  rewarded_ads INTEGER NOT NULL DEFAULT 0,
  pro_active_count INTEGER NOT NULL DEFAULT 0,
  estimated_revenue_inr INTEGER NOT NULL DEFAULT 0,
  computed_at TEXT NOT NULL
);

-- 5. Feedback resolution status
-- Check if column exists is handled by SQLite standard table alteration
ALTER TABLE feedback_records ADD COLUMN status TEXT DEFAULT 'OPEN';
ALTER TABLE feedback_records ADD COLUMN resolved_by TEXT;
ALTER TABLE feedback_records ADD COLUMN resolved_at TEXT;
