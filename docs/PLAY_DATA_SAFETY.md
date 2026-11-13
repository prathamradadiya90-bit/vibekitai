# Google Play Data Safety Declaration & Audit

**Document Version:** 2.0.0  
**Status:** Approved for Google Play Production Submission  
**Last Updated:** November 2026  
**Applicability:** VibeKit AI (`com.vibekit.vibekit_ai`)  

---

## 1. Overview & Data Philosophy

VibeKit AI operates under a **Zero-Prompt-Retention, Local-First Architecture**:
- User inputs (messages, topics, interests) are processed **ephemerally** solely for real-time AI generation and are **never logged, permanently stored, or indexed** in persistent databases or server logs.
- Generation history, favorite items, and generated image cards are saved **locally on the user's device** using SQLite.
- Users can purge all local data and submit a server-side pseudonymized installation deletion request with one tap in Settings (*Delete All My Data*).
- An active web URL is available for users who have uninstalled the app to request data deletion.

---

## 2. Google Play Data Safety Form Questionnaire Responses

### 2.1 Data Collection & Security
- **Does your app collect or share any of the required user data types?**  
  **Yes** (pseudonymous device installation ID, advertising ID via AdMob, and purchase tokens via Play Billing).
- **Is all of the user data collected by your app encrypted in transit?**  
  **Yes** (Strict TLS 1.3 with HTTPS enforcement).
- **Do you provide a way for users to request that their data be deleted?**  
  **Yes** (In-app one-click data deletion under Settings, plus web deletion request URL at `https://<backend-domain>/delete-account` or `https://<backend-domain>/delete-data`).

---

### 2.2 Detailed Data Types Breakdown

| Data Category | Specific Data Type | Collected? | Shared? | Ephemeral? | Purpose | Optional or Required? |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Personal Info** | Name, Email, Phone, Address | **No** | **No** | N/A | Not collected | N/A |
| **Financial Info** | Credit card, Bank info | **No** | **No** | N/A | Handled 100% by Google Play Billing | N/A |
| **Financial Info** | Purchase History / Entitlements | **Yes** | **No** | No | App functionality (Entitlement verification & fraud prevention) | Required |
| **Messages / Prompts** | In-app messages, generation prompts | **No** | **No** | **Yes (Ephemeral)** | Not collected. Discarded immediately after inference. | N/A |
| **App Info & Performance**| Crash logs & diagnostics | **Yes** | **No** | No | Analytics & crash resolution (PII scrubbed) | Optional |
| **Device or other IDs** | Device ID / Installation ID | **Yes** | **No** | No | App functionality (Daily quota tracking, abuse mitigation, anti-fraud) | Required |
| **Advertising ID** | Google Advertising ID (AD_ID) | **Yes** | **Yes (Google AdMob)** | No | Ad delivery, fraud prevention, and rewarded verification | Required for free tier |

---

## 3. Third-Party SDK Disclosures

1. **Google Play Billing Library (`com.android.billingclient`):**
   - Collects purchase tokens and order IDs to process subscriptions and consumable credit packs.
   - Handled directly by Google Play services.

2. **Google Mobile Ads (AdMob & UMP SDK):**
   - Collects Advertising ID (`AD_ID`) if personalized ads are consented to via the UMP dialog.
   - If user denies consent or resets GAID, serves non-personalized contextual ads without user identifiers.

3. **Cloudflare Edge Workers:**
   - Evaluates incoming request IP for DDoS prevention and rate limiting (hashed with daily salt; zero raw IP addresses stored).
   - Zero prompt text logged in Cloudflare Logs.

---

## 4. Verification Checklists for Reviewers

- [x] Privacy Policy link is live at `https://<backend-domain>/privacy`.
- [x] Web data deletion request mechanism is active at `https://<backend-domain>/delete-account`.
- [x] In-app *Delete All My Data* button purges local SQLite database, clears SharedPreferences, and invokes `POST /v1/privacy/delete-data` on the backend.
- [x] Zero prompt retention confirmed via automated vitest suites and structured logger audits.
- [x] In-app report button on every result card to report objectionable AI content under Google Play Generative AI Policy.
