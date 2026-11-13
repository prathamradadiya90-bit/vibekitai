# VibeKit AI — Play Store Release Checklist & Production Runbook

---

## 1. Automated Implementation Tasks Completed by Engineering

- [x] **Application ID & Namespace:** `com.vibekit.vibekit_ai`
- [x] **Target SDK 35 Compliance:** `compileSdkVersion 36`, `targetSdkVersion 35`, `minSdkVersion 24`
- [x] **16 KB Page-Size Ready:** Android NDK `28.2.13676358` configured with standard AGP 8+ page-alignment.
- [x] **Android 13+ (API 33+) Permissions:** `POST_NOTIFICATIONS` declared for opt-in daily streak reminders.
- [x] **Edge-to-Edge Enabled:** System UI edge-to-edge transparent navigation enabled in themes.
- [x] **AdMob Server-Side Verification (SSV):** Signed ECDSA P-256 callback endpoint `GET /v1/ads/ssv` with Google public key caching, nonce generation, and duplicate transaction prevention.
- [x] **Google Play Billing Library:** Integrated for weekly, monthly, yearly subscriptions with 3-day trial and consumable credit packs.
- [x] **Google Play Real-Time Developer Notifications (RTDN):** Pub/Sub webhook `POST /v1/purchases/rtdn` handling renewal, cancel, expire, grace period, on-hold, and revocation.
- [x] **Google Play Integrity API:** Server-side verification for credit-granting calls and abuse prevention.
- [x] **Anti-Abuse Accounting:** SHA-256 hashed device & IP fingerprints in `abuse_signals` table; zero raw IP addresses or serials stored.
- [x] **Vibe Streaks & Rewards Engine:** Daily streaks, streak freeze, XP levels, and milestone rewards.
- [x] **Bio & Username Lab Module:** Creative Instagram/WhatsApp/LinkedIn bios and usernames with direct bridge to Card Maker.
- [x] **Viral Share Loops & Referrals:** Deep links with referral codes (`https://play.google.com/store/apps/details?id=com.vibekit.ai&referrer=ref_<id>`), granting +2 credits to both users with atomic ledger and max 10 cap.
- [x] **Smart Prompts & In-App Review:** Rating prompt displayed on 3rd successful generation.
- [x] **Privacy-Safe Analytics:** Discrete funnel event whitelist; strictly zero user prompt or text retention.
- [x] **Ad Frequency Limits & UMP Consent:** Rewarded video max 2/day, Interstitial min 180s gap + max 3/day (natural breaks only), UMP GDPR consent flow.

---

## 2. Google Play Console Data Safety Form Guidance

| Data Category | Collected? | Shared? | Purpose | Ephemeral? |
| :--- | :--- | :--- | :--- | :--- |
| **User Text / Prompts** | **NO** | **NO** | Not collected. Discarded immediately after inference. | Yes (in-flight only) |
| **Pseudonymous Device ID** | Yes | No | Account Quota, Streaks & Anti-Abuse (`UUIDv4`) | Stored |
| **App Activity / Analytics** | Yes | No | Funnel Analytics (e.g. `generate_success`, `paywall_view`) | Stored |
| **Financial / Purchase Info** | Yes | No | Play Store Purchase Tokens (Subscription entitlement) | Stored |
| **Advertising ID (AD_ID)** | Yes | Yes (Google AdMob) | Ad Delivery, Fraud Prevention & Rewarded Verification | Managed by Google Mobile Ads SDK |

---

## 3. Play Console In-App Products & Subscriptions Setup

### Subscriptions
1. **`vibekit_pro_weekly`**:
   - Base plan: Auto-renewing weekly
   - Default Price: ₹49 / week
2. **`vibekit_pro_monthly`**:
   - Base plan: Auto-renewing monthly
   - Default Price: ₹99 / month
3. **`vibekit_pro_yearly`**:
   - Base plan: Auto-renewing yearly
   - Offer: 3-day free trial
   - Default Price: ₹699 / year (~41% savings callout)

### In-App Products (One-Time Purchases & Consumables)
1. **`vibekit_pro_lifetime`**:
   - One-time non-consumable product (Lifetime VIP Pass)
   - Grants permanent Pro entitlement (100 years / 36,500 days)
   - Default Price: ₹1,499 / $19.99 (High ARPU anchor)
2. **`vibekit_credits_50`**:
   - Consumable product
   - Default Price: ₹49 (Grants 50 AI credits)

---

## 4. Backend Cloudflare Workers Deployment Runbook

### Apply All D1 Migrations Remotely
```bash
cd backend
npx wrangler d1 migrations apply vibekit-ai-db --remote
```
Migrations applied:
- `0001_init.sql` (Installations, daily usage, subscriptions)
- `0002_phase1_security_and_quota.sql` (Pro cycle windows, SSV transactions, nonces, abuse signals, rate limits, challenge cache)
- `0003_streaks_and_rewards.sql` (Streaks, XP events, milestone claims)
- `0004_referrals_and_growth.sql` (Referrals and viral accounting)
- `0005_credit_packs.sql` (Idempotent consumable credit pack ledger)

### Set Production Secrets
```bash
# Primary Gemini API Key (Paid Tier recommended for zero prompt logging)
npx wrangler secret put GEMINI_API_KEY

# Optional Fallback Provider (Groq / OpenRouter / OpenAI)
npx wrangler secret put GROQ_API_KEY

# Google Play Service Account JSON (For Play Developer API subscriptionsv2 & RTDN acknowledgment)
npx wrangler secret put GOOGLE_PLAY_SERVICE_ACCOUNT_JSON

# Google Play Integrity API Decryption Key (Optional, for decrypting integrity verdicts server-side)
npx wrangler secret put PLAY_INTEGRITY_DECRYPTION_KEY

# Deploy to Cloudflare Edge
npx wrangler deploy
```

---

## 5. Mobile App Production Build Commands

```bash
cd app

# Build signed Release Android App Bundle (AAB)
flutter build appbundle --release --dart-define=API_URL=https://api.vibekit.ai --dart-define=ADMOB_BANNER_ID=ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY --dart-define=ADMOB_REWARDED_ID=ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ --dart-define=ADMOB_INTERSTITIAL_ID=ca-app-pub-XXXXXXXXXXXXXXXX/WWWWWWWWWW
```
Output artifact: `app/build/app/outputs/bundle/release/app-release.aab`
