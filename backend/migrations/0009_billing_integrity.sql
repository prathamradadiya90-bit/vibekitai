-- VibeKit AI Database Migration 0009_billing_integrity.sql
-- 1. Pro credit cycles are monthly allowances: cap any existing cycle longer than 30 days
--    (yearly / lifetime plans previously got one cycle spanning the whole entitlement).
UPDATE pro_cycle_usage
SET cycle_end = strftime('%Y-%m-%dT%H:%M:%fZ', cycle_start, '+30 days')
WHERE julianday(cycle_end) - julianday(cycle_start) > 31;

-- 2. Lifetime passes never expire: represent that as NULL instead of a far-future date.
UPDATE subscription_entitlements
SET expires_at = NULL
WHERE product_id = 'vibekit_pro_lifetime' AND status = 'ACTIVE';

UPDATE installations
SET pro_expires_at = NULL
WHERE id IN (
  SELECT installation_id FROM subscription_entitlements
  WHERE product_id = 'vibekit_pro_lifetime' AND status = 'ACTIVE'
);

-- 3. A Play purchase token can only ever be credited once.
CREATE UNIQUE INDEX IF NOT EXISTS idx_credit_pack_token ON credit_pack_purchases(purchase_token);
