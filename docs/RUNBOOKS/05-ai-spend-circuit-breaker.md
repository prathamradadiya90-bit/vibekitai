# Runbook 05: Daily AI Spend Budget Circuit Breaker Tripped

## 1. Alert Summary
- **Trigger Condition:** `ai_daily_budget` spend >= `max_budget_usd` (default $25.00/day) or `is_tripped == 1`.
- **SLO Impact:** Protects against unbounded cloud spend and runaway API costs. New generation requests return `HTTP 429 DAILY_BUDGET_EXCEEDED`.
- **Severity:** P1 (Critical Cost Alert).

---

## 2. Immediate Symptoms
- All generation requests fail with `{ error: { code: "DAILY_BUDGET_EXCEEDED", message: "Global AI compute capacity temporarily reached for the day." } }`.
- Cloudflare log shows `Circuit breaker TRIPPED` entries.

---

## 3. Diagnostic Steps
1. Query current budget status from D1:
   ```bash
   npx wrangler d1 execute DB --command "SELECT * FROM ai_daily_budget WHERE budget_date = date('now')"
   ```
2. Identify whether the spike is organic user growth or an abuse flood:
   - Check unique active installations today:
     ```bash
     npx wrangler d1 execute DB --command "SELECT COUNT(DISTINCT installation_id) FROM generation_metadata WHERE date(created_at) = date('now')"
     ```
   - Check if a small number of installations account for an anomalous share of requests (bypassing rate limits).
3. Check upstream provider billings (Google Cloud, Groq, OpenAI).

---

## 4. Mitigation Actions
- **If Legitimate Viral Growth (e.g., App Store feature / TikTok viral trend):**
  Increase the daily ceiling in D1 to accommodate legitimate traffic:
  ```bash
  npx wrangler d1 execute DB --command "UPDATE ai_daily_budget SET max_budget_usd = 100.0, is_tripped = 0 WHERE budget_date = date('now')"
  ```
- **If Scraping / Abuse Attack:**
  - Locate abusive installation IDs:
    ```bash
    npx wrangler d1 execute DB --command "SELECT installation_id, COUNT(*) as c FROM generation_metadata WHERE date(created_at) = date('now') GROUP BY installation_id ORDER BY c DESC LIMIT 10"
    ```
  - Ban abusive installation IDs in the Admin Panel (`POST /v1/admin/installations/:id/ban`).
  - Keep circuit breaker active until abusive IPs are blocked on Cloudflare WAF.

---

## 5. Verification
- Verify that generation requests resume succeeding with HTTP 200 for legitimate users.
- Confirm total daily spend stays safely within newly approved operational threshold.
