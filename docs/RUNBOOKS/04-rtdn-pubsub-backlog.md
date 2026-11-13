# Runbook 04: Google Play RTDN Pub/Sub Backlog & Subscription Desync

## 1. Alert Summary
- **Trigger Condition:** Google Cloud Pub/Sub unacknowledged message age > 300 seconds or `/v1/purchases/rtdn` 5xx rate > 1%.
- **SLO Impact:** Breaches real-time entitlement synchronization for paid subscribers.
- **Severity:** P2 (High).

---

## 2. Immediate Symptoms
- Users report subscription renewals, cancellations, or grace period restores not reflected immediately in app.
- Google Cloud Console shows undelivered messages building in the RTDN push subscription.

---

## 3. Diagnostic Steps
1. In Google Cloud Console > Pub/Sub > Subscriptions > `vibekit-rtdn-sub`:
   - Inspect **Unacked message count** and **Push endpoint HTTP response codes**.
2. Tail Cloudflare Workers logs for RTDN route:
   ```bash
   npx wrangler tail --format=json | jq 'select(.path=="/v1/purchases/rtdn")'
   ```
3. Check `rtdn_event_log` in D1 for recent events:
   ```bash
   npx wrangler d1 execute DB --command "SELECT * FROM rtdn_event_log ORDER BY event_time_millis DESC LIMIT 10"
   ```

---

## 4. Mitigation Actions
- **If Endpoint Returns 400 (Bad Payload):**
  Verify the Pub/Sub base64 payload format matches `RtdnNotificationSchema`.
- **If Endpoint Returns 500 (D1 Error):**
  Check D1 database health (Runbook 03).
- **Trigger Nightly Entitlement Reconciliation Immediately:**
  Run the scheduled reconciliation task on demand to force re-evaluation of all subscriptions against Google Play API:
  ```bash
  curl -X POST "https://api.vibekit.ai/__scheduled" -H "Authorization: Bearer $CRON_TRIGGER_SECRET"
  ```

---

## 5. Verification
- Confirm Pub/Sub unacked message count decreases to 0.
- Verify test subscription status updates from `IN_GRACE_PERIOD` to `ACTIVE` upon payment fix.
