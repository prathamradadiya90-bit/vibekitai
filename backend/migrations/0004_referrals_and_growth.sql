-- VibeKit AI Database Migration 0004_referrals_and_growth.sql
-- Implements Referral System, Growth Accounting, and Remote Config

CREATE TABLE IF NOT EXISTS referrals (
  id TEXT PRIMARY KEY,
  referrer_installation_id TEXT NOT NULL,
  referred_installation_id TEXT UNIQUE NOT NULL, -- Each device can only be referred once
  credits_awarded INTEGER NOT NULL DEFAULT 2,
  status TEXT NOT NULL, -- 'PENDING' | 'REWARDED' | 'REJECTED_ABUSE'
  created_at TEXT NOT NULL,
  FOREIGN KEY (referrer_installation_id) REFERENCES installations(id) ON DELETE CASCADE,
  FOREIGN KEY (referred_installation_id) REFERENCES installations(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_referrals_referrer ON referrals(referrer_installation_id);
