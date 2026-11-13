-- VibeKit AI Database Migration 0006_performance_indexes.sql
-- Optimizes hot query performance and prevents table scans

CREATE INDEX IF NOT EXISTS idx_daily_usage_inst_date ON daily_usage(installation_id, usage_date);
CREATE INDEX IF NOT EXISTS idx_entitlements_inst ON subscription_entitlements(installation_id);
CREATE INDEX IF NOT EXISTS idx_entitlements_token ON subscription_entitlements(purchase_token);
CREATE INDEX IF NOT EXISTS idx_gen_meta_inst ON generation_metadata(installation_id);
