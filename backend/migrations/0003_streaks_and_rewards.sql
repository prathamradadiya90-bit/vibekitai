-- VibeKit AI Database Migration 0003_streaks_and_rewards.sql
-- Implements Vibe Streaks, XP Points, and Milestone Claims

-- 1. Streaks Table (Anti-tamper server mirror of local streaks)
CREATE TABLE IF NOT EXISTS streaks (
  installation_id TEXT PRIMARY KEY,
  current_streak INTEGER NOT NULL DEFAULT 0,
  longest_streak INTEGER NOT NULL DEFAULT 0,
  last_checkin_date TEXT NOT NULL, -- UTC YYYY-MM-DD
  freeze_count INTEGER NOT NULL DEFAULT 0,
  last_freeze_used_date TEXT,
  pro_freeze_refilled_at TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (installation_id) REFERENCES installations(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_streaks_checkin ON streaks(last_checkin_date);

-- 2. XP Events Table (Aggregated XP, zero private content stored)
CREATE TABLE IF NOT EXISTS xp_events (
  id TEXT PRIMARY KEY,
  installation_id TEXT NOT NULL,
  action_type TEXT NOT NULL, -- 'generate' | 'share' | 'save' | 'challenge' | 'streak_milestone'
  xp_points INTEGER NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY (installation_id) REFERENCES installations(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_xp_events_inst ON xp_events(installation_id, created_at);

-- 3. Milestone Claims Table (Idempotent: unique per installation + milestone)
CREATE TABLE IF NOT EXISTS milestone_claims (
  id TEXT PRIMARY KEY,
  installation_id TEXT NOT NULL,
  milestone_day INTEGER NOT NULL, -- 3, 7, 14, 30
  reward_type TEXT NOT NULL,      -- 'credit' | 'template_pack' | 'badge'
  bonus_credits INTEGER NOT NULL DEFAULT 0,
  claimed_at TEXT NOT NULL,
  UNIQUE(installation_id, milestone_day),
  FOREIGN KEY (installation_id) REFERENCES installations(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_milestone_claims_lookup ON milestone_claims(installation_id, milestone_day);
