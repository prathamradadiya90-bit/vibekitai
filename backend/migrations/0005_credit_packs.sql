-- VibeKit AI Database Migration 0005_credit_packs.sql
-- Implements Idempotent One-time Consumable Credit Pack Accounting

CREATE TABLE IF NOT EXISTS credit_pack_purchases (
  order_id TEXT PRIMARY KEY,
  installation_id TEXT NOT NULL,
  product_id TEXT NOT NULL,
  credits_granted INTEGER NOT NULL,
  purchase_token TEXT NOT NULL,
  purchased_at TEXT NOT NULL,
  FOREIGN KEY (installation_id) REFERENCES installations(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_credit_pack_installation ON credit_pack_purchases(installation_id);
