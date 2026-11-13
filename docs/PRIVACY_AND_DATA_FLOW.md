# VibeKit AI — Privacy Architecture, Provider Terms Reconciliation & Data Safety

**Architecture Principle:** Local-First Storage with Transient Edge Processing & Zero Prompt Retention.

---

## 1. End-to-End Data Flow Diagram

```
[ User Text Input ] ────────► [ Local Flutter App ] (SQLite History & SharedPreferences)
                                     │
                                     │ HTTPS (TLS 1.3)
                                     │ Headers: X-App-Instance-Id, X-Request-Id, X-Session-Token
                                     ▼
                        [ Cloudflare Worker Edge ]
                                     │
         ┌───────────────────────────┴───────────────────────────┐
         │                                                       │
         ▼                                                       ▼
[ Cloudflare D1 ]                                      [ AI Inference Provider ]
- installations (ID, timestamps, pro status)           - Google Gemini / Groq / OpenAI
- pro_cycle_usage (cycle credit accounting)            - Transient processing in RAM
- daily_usage (integer credits used, ads watched)      - Returns structured JSON
- generation_metadata (status, latency, NO prompts)    - Zero prompt storage on edge
- subscription_entitlements (purchase tokens)
- rtdn_event_log (billing sync deduplication)
- idempotency_keys (24h response cache for retries)
- admob_ssv_transactions (verified ad claims)
- abuse_signals (hashed IP / device signals only)
```

---

## 2. What We Collect vs What We Never Collect

| Category | Stored Locally | Sent to Cloudflare/D1 | Sent to AI Providers |
| :--- | :--- | :--- | :--- |
| **User Messages & Context** | Yes (in local device SQLite) | Transient in-memory payload only (never written to DB, disk, or logs) | Sent via TLS 1.3 to inference API (transient execution only; never retained) |
| **Generated Replies & Captions** | Yes (in local device SQLite) | Transient output only (cached in `idempotency_keys` up to 24h solely for network retry safety) | Returned to app via edge proxy |
| **Meme & Quote Card Images** | Yes (local PNG files in app cache) | **Never** | **Never** (rendered 100% offline on-device via Flutter Canvas) |
| **Names, Emails, Phone Numbers** | **Never** | **Never** | **Never** (no account registration or identity linking required) |
| **Raw IP Addresses & GPS** | **Never** | Transient IP for edge rate limiting; hashed SHA-256 in abuse signals | **Never** |
| **Installation ID** | Yes (UUIDv4 in SharedPreferences) | Yes (used for quota calculations and billing sync) | **Never** |
| **Purchase Receipt Token** | Yes | Yes (stored in D1 for Play Billing sync & RTDN) | Sent to Google Play Developer API for authoritative verification |

---

## 3. AI Provider Commercial Terms & Zero-Training Reconciliation

VibeKit AI mandates strict commercial / paid API agreements with upstream AI inference providers. We explicitly reject free consumer tiers that utilize user prompts for foundation model training.

### 3.1 Google Gemini (Google Cloud Vertex AI / Paid Gemini API)
- **Data Terms:** Under the Google Cloud Paid Commercial Terms and Vertex AI data governance:
  - Prompts, input context, and generated completions are **NOT** used to train Google foundation models.
  - Data is processed transiently in volatile memory and is not stored or reviewed by human evaluators.
  - Compliant with ISO/IEC 27001, SOC 1/2/3, and GDPR.
- **Enforcement:** Production deployments mandate Google Cloud Billing enabled on the Google Cloud Project hosting the Gemini API key.

### 3.2 Groq Cloud (Secondary / High-Speed Fallback)
- **Data Terms:** Under Groq's Commercial API Terms of Service:
  - Customer data (prompts and completions) is never used for training or fine-tuning models.
  - Inference requests are processed ephemerally on Groq LPUs.
  - No prompt or response content is logged to persistent storage by default.

### 3.3 OpenAI (Tertiary Fallback)
- **Data Terms:** Governed by OpenAI Business / Commercial API Data Privacy:
  - API data is not used for training OpenAI models by default.
  - Ephemeral abuse monitoring data is retained up to 30 days in secure, encrypted transient storage if needed for legal compliance, with Zero Data Retention (ZDR) available for qualifying enterprise accounts.

---

## 4. Google Play Store "Data Safety" Questionnaire Alignment

When declaring Data Safety answers in the Google Play Console for VibeKit AI, submit the following verified declarations:

### 4.1 Data Collection & Sharing Overview
- **Does your app collect or share any of the required user data types?** Yes.
- **Is all of the user data collected by your app encrypted in transit?** Yes (all client-server traffic is TLS 1.3 enforced).
- **Do you provide a way for users to request that their data be deleted?** Yes (Settings > "Delete All Data" triggers immediate client wipe and backend cascading D1 purge).

### 4.2 Specific Data Types Collected

| Data Type | Purpose | Ephemeral? | Required or Optional? | Shared with Third Parties? |
| :--- | :--- | :--- | :--- | :--- |
| **App Activity > User Generated Content (Text)** | App functionality (generating replies, captions, bios) | **Yes** (processed transiently in volatile RAM for inference, never stored on server DB or disk) | Required for core feature | No (sent only to secure AI processor as service provider) |
| **Financial Info > Purchase History** | App functionality, fraud prevention, subscription entitlement sync | No (purchase token and expiry stored in D1) | Optional (only for Pro/Credit purchases) | No |
| **Device or other IDs > Installation ID** | App functionality, analytics, quota management, fraud prevention | No (stored in D1 linked to quota usage) | Required | No |
| **App Performance > Crash logs / Diagnostics** | Analytics, developer troubleshooting | No (aggregated crash metrics without PII) | Optional | No |

---

## 5. In-App Privacy Copy Alignment

To ensure 100% truth in advertising across app onboarding, settings, and consent modals, use the following standardized copy:

### 5.1 Onboarding Privacy Banner
> **Zero Retention Guarantee:**  
> We believe your conversations are your business. VibeKit AI never stores your messages, context, or generated content on our servers. All history remains strictly on your device.

### 5.2 Settings Screen: "Privacy & Data"
> **How your data is handled:**  
> • **Prompts & Context:** Streamed to enterprise AI APIs for instant generation and discarded immediately from RAM. Never saved in server databases.  
> • **AI Model Training:** We use paid enterprise tiers where your data is never used to train AI models.  
> • **Local History:** Your generated cards and favorites live on your phone in an encrypted local database.

---

## 6. Complete Data Deletion Protocol ("Right to be Forgotten")

When a user selects **Delete My Data** in the Settings screen:
1. `POST /v1/privacy/delete-data` is dispatched with `X-App-Instance-Id` and `X-Session-Token`.
2. Cloudflare D1 executes an atomic batch deletion across all tables:
   ```sql
   DELETE FROM idempotency_keys WHERE installation_id = ?;
   DELETE FROM pro_cycle_usage WHERE installation_id = ?;
   DELETE FROM admob_ssv_transactions WHERE installation_id = ?;
   DELETE FROM ad_nonces WHERE installation_id = ?;
   DELETE FROM daily_usage WHERE installation_id = ?;
   DELETE FROM generation_metadata WHERE installation_id = ?;
   DELETE FROM reward_events WHERE installation_id = ?;
   DELETE FROM subscription_entitlements WHERE installation_id = ?;
   DELETE FROM feedback_records WHERE installation_id = ?;
   DELETE FROM rtdn_event_log WHERE purchase_token IN (
     SELECT purchase_token FROM subscription_entitlements WHERE installation_id = ?
   );
   DELETE FROM installations WHERE id = ?;
   ```
3. Client executes:
   - `LocalDatabase.clearAll()` (drops all SQLite history, drafts, and favorites)
   - `PreferencesService.clearAll()` (resets onboarding and settings)
4. A fresh UUIDv4 instance ID is minted on next launch.
