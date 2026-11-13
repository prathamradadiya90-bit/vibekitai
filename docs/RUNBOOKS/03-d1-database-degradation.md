# Runbook 03: Cloudflare D1 Database Degradation & Lock Contention

## 1. Alert Summary
- **Trigger Condition:** D1 query execution time > 250ms or `SQLITE_BUSY: database is locked` errors > 10 in 5 minutes.
- **SLO Impact:** Breaches p95 API latency (< 800ms for non-AI routes) and transaction consistency.
- **Severity:** P2 (High).

---

## 2. Immediate Symptoms
- Quota lookups and streak updates failing with `HTTP 500`.
- Latency spikes on `/v1/usage` and `/v1/streak`.

---

## 3. Diagnostic Steps
1. Inspect query logs in Cloudflare D1 Console:
   ```bash
   npx wrangler d1 insights DB --period 1h
   ```
2. Identify slow or unindexed queries. Verify that queries on `daily_usage`, `generation_metadata`, and `idempotency_keys` utilize composite indexes:
   ```bash
   npx wrangler d1 execute DB --command "EXPLAIN QUERY PLAN SELECT * FROM daily_usage WHERE installation_id = 'test' AND usage_date = '2026-10-24'"
   ```
   *Expected:* `SEARCH daily_usage USING INDEX idx_daily_usage_lookup` (SCAN is a failure).

---

## 4. Mitigation Actions
- **Apply Missing Indexes:**
  Execute migration `0006_performance_indexes.sql` or `0008_idempotency_and_rtdn.sql` if unapplied.
- **Prune Expired Data:**
  Purge expired idempotency keys and stale ad nonces:
  ```bash
  npx wrangler d1 execute DB --command "DELETE FROM idempotency_keys WHERE expires_at < unixepoch()"
  npx wrangler d1 execute DB --command "DELETE FROM ad_nonces WHERE expires_at < datetime('now')"
  ```
- **Time Travel Restore (If Corrupted):**
  If D1 database suffers state corruption or unrecoverable schema drift, utilize D1 Time Travel point-in-time recovery (see `docs/DISASTER_RECOVERY_AND_BACKUPS.md`).

---

## 5. Verification
- Verify query execution latency returns to < 20ms in D1 insights.
- Confirm zero `SQLITE_BUSY` errors in live logs.
