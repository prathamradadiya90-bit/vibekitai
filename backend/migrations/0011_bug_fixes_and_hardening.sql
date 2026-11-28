-- VibeKit AI Database Migration 0011_bug_fixes_and_hardening.sql
-- Fixes bans cascade/FK, separates public referral codes, strengthens SSV/credit-pack/freeze integrity

-- 1. Rebuild bans without ON DELETE CASCADE so self-deletion cannot erase bans
--    and admins can pre-ban unknown/purged installation IDs cleanly.
CREATE TABLE IF NOT EXISTS bans_v2 (
  installation_id TEXT PRIMARY KEY,
  reason TEXT NOT NULL,
  banned_by TEXT NOT NULL,
  created_at TEXT NOT NULL
);

INSERT OR IGNORE INTO bans_v2 (installation_id, reason, banned_by, created_at)
SELECT installation_id, reason, banned_by, created_at FROM bans;

DROP TABLE bans;
ALTER TABLE bans_v2 RENAME TO bans;
CREATE INDEX IF NOT EXISTS idx_bans_created ON bans(created_at);

-- 2. Dedicated public referral_code separate from private installation_id
ALTER TABLE installations ADD COLUMN referral_code TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS idx_installations_referral_code ON installations(referral_code);

-- 3. Prevent duplicate SSV/dev reward_id double-credits within an installation
CREATE UNIQUE INDEX IF NOT EXISTS idx_admob_ssv_reward_id
  ON admob_ssv_transactions(installation_id, reward_id)
  WHERE reward_id IS NOT NULL;

-- 4. Support chargeback/refund revocation tracking on credit packs
ALTER TABLE credit_pack_purchases ADD COLUMN revoked_at TEXT;

-- 5. Track how many daily rewarded ads have already redeemed a streak freeze
ALTER TABLE streaks ADD COLUMN last_freeze_ad_date TEXT;
ALTER TABLE streaks ADD COLUMN last_freeze_ads_count INTEGER NOT NULL DEFAULT 0;

-- 6. Enforce unique config versions per key
CREATE UNIQUE INDEX IF NOT EXISTS idx_remote_config_unique_ver
  ON remote_config_versions(config_key, version);

-- 7. Normalize legacy feedback status casing to lowercase ('open' / 'resolved')
UPDATE feedback_records SET status = LOWER(status) WHERE status != LOWER(status);
