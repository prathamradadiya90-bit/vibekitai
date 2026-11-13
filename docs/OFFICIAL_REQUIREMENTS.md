# VibeKit AI — Official Requirements & Standards

**Date Checked:** October 10, 2026  
**Reference Sources:** Official Google Play Developer Policies, Android Developer Documentation, Google Mobile Ads, Gemini API docs, and Cloudflare Workers documentation.

---

## 1. Android & Google Play Target Requirements

- **Target SDK Version:** Google Play requires all new apps and app updates to target at least **API level 34 or 35** (Android 14/15). VibeKit AI configures:
  - `compileSdkVersion`: 36
  - `targetSdkVersion`: 35
  - `minSdkVersion`: 24 (Android 7.0 Nougat), guaranteeing support for >96% of global active Android devices while supporting Java 8+ desugaring, modern TLS 1.3, modern notification channels, and photo picker APIs.
- **Android App Bundle (AAB):** Google Play requires apps to be published as Android App Bundles (`.aab`) rather than universal `.apk` files for dynamic feature delivery and device-optimized APK generation.
- **64-bit Architecture:** Native libraries (if any) must support 64-bit architectures (`arm64-v8a`, `x86_64`).

---

## 2. Google Play Billing Library Requirements

- **Billing Version:** Google Play requires all updates to use Google Play Billing Library version 6.x or 7.x.
- **Server-Side Verification:** In accordance with Google Play developer policy, client-side purchase acknowledgments without backend validation are vulnerable to tampering. VibeKit AI utilizes the official Google Play Developer API (`purchases.subscriptionsv2.get` / `purchases.subscriptions.acknowledge`) via Cloudflare Workers to verify purchase tokens authoritatively.
- **Grace Periods & Account Hold:** Subscriptions must handle `SUBSCRIPTION_IN_GRACE_PERIOD`, `SUBSCRIPTION_ON_HOLD`, `SUBSCRIPTION_CANCELED`, and `SUBSCRIPTION_EXPIRED` states.
- **Price Disclosure:** Apps must clearly display the localized price, billing cycle, renewal terms, and cancellation instructions before initiating the purchase flow.
- **Cancellation Link:** Settings and Paywall must provide a direct deep link to Google Play Subscriptions management (`https://play.google.com/store/account/subscriptions?package=com.vibekit.vibekit_ai`).

---

## 3. Google AdMob Policies & Guidelines

- **Ad Placements:**
  - Banner ads must be anchored cleanly outside primary interactive touch targets to prevent accidental clicks.
  - Rewarded ads must only be triggered following explicit user opt-in ("Watch Ad to Unlock 3 Credits").
  - An ad closing or failing to load must NOT trigger credit grants. Only the verified `onUserEarnedReward` callback (optionally validated with AdMob Server-Side Verification SSV) can issue reward credits.
  - Ads must not obstruct critical navigation, purchase dialogs, or system overlays.
- **Families & Age-Appropriate Content:**
  - VibeKit AI is targeted at general audiences (13+). Content rating questionnaires will declare that the app is not primarily directed at children under 13.
  - `tagForChildDirectedTreatment` and `tagForUnderAgeOfConsent` will be explicitly set to adhere to COPPA / GDPR-K standards.
- **EU/UK Consent (UMP SDK):** Google User Messaging Platform (UMP) SDK must be integrated for collecting GDPR/ePrivacy user consent in EEA/UK regions prior to requesting personalized ads.

---

## 4. Google Gemini API Specifications

- **Current Models:**
  - `gemini-1.5-flash` / `gemini-2.0-flash`: Highly optimized for low latency, high throughput, and cost-efficient structured text generation.
- **Server-Side Security:**
  - API keys must never be exposed to the client. All calls pass through the Cloudflare Worker proxy `/v1/generations/*`.
- **Structured Output:**
  - Model responses utilize structured JSON schemas (`response_schema` / JSON mode) with Zod validation to ensure deterministic output (3 distinct suggestions for replies, categorized sections for captions).
- **Safety Thresholds:**
  - Set explicit `HARM_CATEGORY_HARASSMENT`, `HARM_CATEGORY_HATE_SPEECH`, `HARM_CATEGORY_SEXUALLY_EXPLICIT`, and `HARM_CATEGORY_DANGEROUS_CONTENT` thresholds to protect users from malicious or harmful outputs.
- **Prompt Defense:**
  - Separation of system instruction context and user-supplied text to prevent prompt injection and model jailbreaks.

---

## 5. Cloudflare Workers & Cloudflare D1 Limits

- **Free Tier Allowances:**
  - Workers: 100,000 requests per day across all worker routes.
  - D1 SQLite: 5 million read rows per day, 100,000 write rows per day, 5 GB storage.
- **Worker Execution Constraints:**
  - 10 ms CPU time per request on Free Tier (sufficient for I/O bound fetch proxying to Gemini and D1 queries).
  - Subrequests: Up to 50 subrequests per incoming request.
- **Latency & Reliability:**
  - Workers run at edge locations worldwide, providing sub-50ms API routing for Indian and international users.

---

## 6. Play Store Data Safety & Privacy Declarations

- **Data Collected:**
  - Pseudonymous Installation Identifier (Diagnostics & Quota Management).
  - Purchase History (Transaction receipt tokens for subscription entitlement).
  - Crash logs and aggregate diagnostics (optional, if Crashlytics enabled).
- **Data Not Collected:**
  - Real names, phone numbers, contact lists, GPS locations, user photos, or microphone inputs are never collected or stored.
- **Data Deletion:**
  - Users have an in-app "Delete All Data" control that wipes local database storage and dispatches a cryptographically signed erasure request to the Cloudflare D1 endpoint `/v1/privacy/delete-data`.
