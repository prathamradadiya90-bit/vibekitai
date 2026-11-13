# Runbook 01: API Error Rate SLO Burn (5xx Spike)

## 1. Alert Summary
- **Trigger Condition:** 5xx error rate > 0.5% over a 5-minute rolling window or 14.4x 1-hour error budget burn rate.
- **SLO Impact:** Breaches 99.9% availability target (allowed downtime: 43 minutes/month).
- **Severity:** P1 (Critical).

---

## 2. Immediate Symptoms
- Surge in `HTTP 500 INTERNAL_SERVER_ERROR` or `HTTP 502 BAD_GATEWAY` on `/v1/generations/*`.
- Client apps displaying generic retry dialogs to users.
- Workers analytics engine shows error spike in Cloudflare dashboard.

---

## 3. Diagnostic Steps (5-Minute Triage)
1. **Inspect Live Structured Error Logs:**
   Filter Cloudflare Workers live logs for `level == "error"`:
   ```bash
   npx wrangler tail --format=json | jq 'select(.level=="error")'
   ```
2. **Identify Impacted Route:**
   Determine whether errors are isolated to `/v1/generations/*`, `/v1/purchases/*`, or ubiquitous across all endpoints.
3. **Check Upstream AI Status:**
   - Google Vertex / Gemini status dashboard: `https://status.cloud.google.com/`
   - Groq status: `https://status.groq.com/`
   - OpenAI status: `https://status.openai.com/`
4. **Check D1 Database Errors:**
   Inspect D1 query latency and SQLite locked/timeout errors.

---

## 4. Mitigation Actions
- **If AI Provider Timeout/Error:**
  Activate remote config kill switch to force fallback to secondary/tertiary provider:
  ```bash
  # In Admin Panel > Kill Switches > AI Provider Fallback: force secondary provider
  ```
- **If Bad Worker Deployment:**
  Instantly roll back to the previous deployment version:
  ```bash
  npx wrangler rollback [DEPLOYMENT_ID]
  ```
- **If Malicious Flood / Scraping Attack:**
  Tighten Cloudflare rate limiter or enable "Under Attack Mode" on `api.vibekit.ai`.

---

## 5. Verification & Resolution
- Verify error rate drops below 0.1% for 15 consecutive minutes.
- Check that client mobile generations succeed cleanly with HTTP 200.
- Document post-mortem in incident tracker within 48 hours.
