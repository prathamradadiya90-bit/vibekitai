# VibeKit AI — Engineering & Growth Overhaul Changelog

---

## 1. What Was Fixed (Phase 1 Audit & Hardening)

1. **Pro Quota vs Daily Table Mismatch:**
   - Keyed pro allowances to actual Play subscription renewal cycles instead of calendar days via `pro_cycle_usage` table.
   - Handled cycle rollovers and upgrades atomically; added `pro_credits_remaining` and `pro_cycle_resets_at` to `/v1/usage`.
2. **Rewarded Ad Fraud Elimination:**
   - Built AdMob Server-Side Verification (SSV) callback endpoint (`GET /v1/ads/ssv`).
   - Verifies Google's ECDSA P-256 public key signatures with automatic key caching and single-use nonce validation.
   - Credits are only awarded server-side upon verified SSV callbacks. Max 2 credit rewarded ads per day enforced server-side.
3. **Free-Credit Abuse Mitigation:**
   - Server-side Play Integrity token verification for credit-granting endpoints.
   - Anonymous device and IP fingerprint accounting in `abuse_signals` using SHA-256 hashes (zero raw IP addresses stored).
4. **Isolate-Shared Rate Limiting:**
   - Replaced in-memory rate limiting with D1/edge-backed sliding window counters across all Cloudflare Worker isolates.
5. **Subscription Lifecycle & RTDN:**
   - Implemented Google Cloud Pub/Sub push webhook (`POST /v1/purchases/rtdn`) decoding `SubscriptionNotification`.
   - Authoritative handling of renewals, cancellations, expirations, grace periods, account holds, and revocations.
6. **Privacy Policy & Zero Prompt Retention:**
   - Documented Google AI Studio Paid Tier zero-training architecture in `docs/PRIVACY_AND_DATA_FLOW.md`.
   - Ensured zero prompt text or generated content is stored in D1, logs, or analytics.
7. **AI Reliability & Circuit Breaker:**
   - Built `FallbackChainAIProvider` with automatic circuit breaker (falling back from primary to secondary provider on 429/5xx).
   - Added response caching for Daily Creative Challenges only (never for user personal text).

---

## 2. New Modules & Growth Features Added

### Phase 2: Vibe Streaks & Rewards (`lib/features/streaks/`)
- Daily streak counter with client-side SQLite storage mirrored to D1 with client UTC timezone offset.
- Streak Freeze feature (free users earn 1 freeze via rewarded ad; Pro gets 1 free freeze/week).
- Vibe Points (XP) level progression with action tracking (`generate`, `card_export`, `challenge`, `share`, `save`).
- Milestone claim rewards for 3, 7, 14, and 30-day streaks.
- Scheduled local notifications for daily reminders and streak preservation.

### Phase 3: Bio & Username Lab (`lib/features/bio_lab/`)
- AI generator for Instagram, WhatsApp, LinkedIn, and X/Twitter bios and matching username handles in English, Hindi, Hinglish, and Gujarati.
- Direct bridge to Meme & Card Maker for creating high-res profile quote cards.

### Phase 4: Viral Share Loops & Growth Mechanics
- Automated viral deep links with referral parameters: `https://play.google.com/store/apps/details?id=com.vibekit.ai&referrer=ref_<installation_id>`.
- Referral system: "Invite a friend, both get +2 credits" with atomic accounting and max 10 cap per user (`/v1/referrals/claim` and `/v1/referrals/stats`).
- Smart review prompt via `ReviewService` on 3rd successful generation milestone.
- Privacy-safe `AnalyticsService` logging whitelisted funnel events without sensitive data.
- Remote A/B config endpoint (`GET /v1/config`) with dynamic feature flags.

### Phase 5: Monetization Optimization
- Weekly Pro subscription plan (`vibekit_pro_weekly`) added alongside monthly and yearly.
- 3-day free trial on yearly plan with honest price display and Play cancellation links.
- Interstitial ad manager with 180s cooldown, max 3/day cap, natural breaks only (after card export / 3rd generation).
- UMP GDPR/EEA consent dialog integration.
- Feature-flagged consumable Credit Pack (`POST /v1/purchases/credit-pack` for `vibekit_credits_50`).

---

## 3. Database Migrations Runbook

Run against Cloudflare D1:
```bash
cd backend
npx wrangler d1 migrations apply vibekit-ai-db --remote
```

Summary of migrations applied:
- `0001_init.sql`: Base installations, daily usage, subscriptions.
- `0002_phase1_security_and_quota.sql`: Pro cycles, SSV transactions, nonces, abuse signals, rate limits, challenge cache.
- `0003_streaks_and_rewards.sql`: Streaks, XP events, milestone claims.
- `0004_referrals_and_growth.sql`: Referrals and viral referral tracking.
- `0005_credit_packs.sql`: Consumable credit pack purchases ledger.

---

## 4. Required Secrets & Environment Variables

Set on Cloudflare Workers:
```bash
npx wrangler secret put GEMINI_API_KEY
npx wrangler secret put GROQ_API_KEY
npx wrangler secret put GOOGLE_PLAY_SERVICE_ACCOUNT_JSON
npx wrangler secret put PLAY_INTEGRITY_DECRYPTION_KEY
```

---

## 5. Manual QA Checklist

- [ ] **Billing Sandbox:** Make test purchases of weekly, monthly, and yearly subscriptions on Play Billing test track. Verify pro active state immediately.
- [ ] **SSV Rewarded Ad:** Watch rewarded ad in app, verify callback received on `GET /v1/ads/ssv`, verify transaction logged in `admob_ssv_transactions`, verify +3 credits unlocked.
- [ ] **RTDN Webhook:** Send simulated test Pub/Sub message to `/v1/purchases/rtdn` with notification type 2 (RENEWED) and 13 (EXPIRED), verify entitlement updates.
- [ ] **Streak Rollover:** Advance device date across UTC midnight, verify streak checkin calculates correct consecutive day count.
- [ ] **Ad Caps:** Verify interstitial does not show before 180s elapsed and suppresses after 3 impressions in a day.
- [ ] **Referral Claim:** Enter valid referral code from another device, verify +2 credits granted to both installations.
