# ADR-0003: Authoritative Google Play Billing Verification, RTDN Webhooks & Reconciliation

## Status
Accepted

## Context
Mobile client claims of purchases can be intercepted, spoofed, or replayed using modified APKs or proxy tools like Lucky Patcher or Charles Proxy.
Furthermore, subscription states are dynamic: users renew, cancel, enter grace periods, pause subscriptions, or dispute charges. The backend must be the single source of truth for entitlements, acknowledging subscriptions within the mandatory 3-day deadline and reacting immediately to billing lifecycle events.

## Decision
1. **Server-Side Authoritative Verification:**
   - Client purchase tokens submitted to `/v1/purchases/verify` are verified directly with the Google Play Developer API using the official Google API v3 endpoint:
     - Subscriptions: `androidpublisher.purchases.subscriptionsv2.get`
     - Consumable credit packs: `androidpublisher.purchases.products.get`
   - The server verifies:
     - `subscriptionState == 'SUBSCRIPTION_STATE_ACTIVE'` or `'SUBSCRIPTION_STATE_IN_GRACE_PERIOD'`
     - `acknowledgementState == 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED'` (if unacknowledged, the server acknowledges it immediately via `purchases.subscriptionsv2.acknowledge` or `purchases.products.consume`).
2. **Real-Time Developer Notifications (RTDN):**
   - Google Cloud Pub/Sub pushes RTDN notifications to `/v1/purchases/rtdn`.
   - The endpoint verifies the Cloud Pub/Sub message structure and token.
   - Handlers process all 13 Google Play notification types:
     - `1: RECOVERED`, `2: RENEWED`, `4: PURCHASED`, `7: RESTARTED` $\to$ `status = 'ACTIVE'`, cycle extended.
     - `3: CANCELED` $\to$ `status = 'CANCELED'`, remains active until current cycle end date.
     - `5: ON_HOLD` $\to$ `status = 'ON_HOLD'`, credits paused.
     - `6: IN_GRACE_PERIOD` $\to$ `status = 'IN_GRACE_PERIOD'`, grace banner displayed, credits retained.
     - `10: PAUSED` $\to$ `status = 'PAUSED'`, credits paused.
     - `12: REVOKED` $\to$ `status = 'REVOKED'`, immediate credit revocation and downgrade to Free.
     - `13: EXPIRED` $\to$ `status = 'EXPIRED'`, immediate downgrade to Free.
   - Idempotency and out-of-order defense: Each notification includes `eventTimeMillis`. Updates are rejected if an event with a newer timestamp has already been processed for that `purchaseToken`.
3. **Nightly Entitlement Reconciliation Cron:**
   - Every night at 01:00 UTC, a scheduled task checks all subscriptions with status `ACTIVE` or `IN_GRACE_PERIOD` against the Google Play Developer API to fix any drift caused by missed Pub/Sub push messages.

## Consequences
- Guaranteed compliance with Google Play Developer policies (mandatory acknowledgement within 3 days).
- Zero revenue loss from spoofed client receipts or revoked charges.
- Accurate subscription lifecycle states reflected in real time.
