# VibeKit AI — Disaster Recovery & Backup Architecture (D1 Time Travel)

## 1. Objectives & Metrics
- **Recovery Point Objective (RPO):** < 1 minute (Cloudflare D1 continuous replication and WAL journaling).
- **Recovery Time Objective (RTO):** < 15 minutes (Full restore via D1 Time Travel CLI commands).
- **Data Durability:** 99.999999999% (Cloudflare distributed storage across regional clusters).

---

## 2. Cloudflare D1 Time Travel Architecture
Cloudflare D1 provides automated **Time Travel** continuous transaction logging without manual snapshot maintenance:
1. Every write transaction (commit) in D1 is tracked with a monotonic timestamp and bookmarked against a transaction log.
2. The database can be restored to any second within the retention window (up to 30 days on paid Cloudflare plans).
3. Restoring does **not** require downloading massive SQLite database dumps; Cloudflare performs server-side rewind at the block level.

---

## 3. Disaster Recovery Playbook & Restore Drill

### Scenario A: Accidental Bad Migration or Data Corruption
If an unvetted SQL migration corrupted production tables:
1. **Determine the exact corruption timestamp ($T_{bad}$):**
   ```bash
   npx wrangler tail --format=json | jq 'select(.status >= 500)'
   ```
2. **Retrieve Time Travel bookmark timestamp prior to corruption:**
   ```bash
   npx wrangler d1 time-travel info DB
   ```
3. **Execute Point-in-Time Restore Drill:**
   ```bash
   # Restore DB to exact UTC timestamp prior to the incident
   npx wrangler d1 time-travel restore DB --timestamp="2026-10-24T12:00:00Z"
   ```
4. **Confirm Database Integrity:**
   ```bash
   npx wrangler d1 execute DB --command "PRAGMA integrity_check;"
   ```
5. **Verify Core Entity Counts:**
   ```bash
   npx wrangler d1 execute DB --command "SELECT count(*) FROM installations;"
   npx wrangler d1 execute DB --command "SELECT count(*) FROM subscription_entitlements;"
   ```

### Scenario B: Accidental Table Deletion
If a table was dropped:
1. Time Travel rewind automatically reconstructs dropped tables and schema definitions.
2. Client app continues functioning offline using device-local SQLite cache while backend restore completes.

---

## 4. Client-Side Data Durability (Local-First Resilience)
- **Local SQLite History:** Stored in `databases/vibekit_creations.db` with SQLite Write-Ahead Logging (WAL) mode.
- **Preferences & Quota Mirror:** Stored in Android encrypted private `shared_prefs/`.
- If Cloudflare Workers or D1 experiences a total regional outage:
  - Mobile client displays cached historical cards and favorites.
  - Offline card maker canvas remains 100% interactive and operational.
  - Network requests fail over cleanly without losing user creations.
