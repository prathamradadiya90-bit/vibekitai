-- Migration 0010_fix_idempotency_pk.sql
-- Enforces per-installation composite primary key (installation_id, endpoint, idempotency_key)
-- Prevents cross-tenant idempotency cache collisions.

CREATE TABLE IF NOT EXISTS idempotency_keys_new (
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

INSERT OR IGNORE INTO idempotency_keys_new (
  idempotency_key, installation_id, endpoint, request_hash, response_json, status_code, created_at, expires_at
) SELECT idempotency_key, installation_id, endpoint, request_hash, response_json, status_code, created_at, expires_at
FROM idempotency_keys;

DROP TABLE idempotency_keys;
ALTER TABLE idempotency_keys_new RENAME TO idempotency_keys;

CREATE INDEX IF NOT EXISTS idx_idempotency_expiry ON idempotency_keys(expires_at);
CREATE INDEX IF NOT EXISTS idx_idempotency_inst ON idempotency_keys(installation_id, endpoint);

