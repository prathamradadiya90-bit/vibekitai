# VibeKit AI — System Architecture

**Author:** VibeKit AI Core Architecture Group  
**Document Version:** 1.0  
**Updated:** October 2026  

---

## 1. High-Level Architecture Overview

```
┌────────────────────────────────────────────────────────────────────────┐
│                        ANDROID MOBILE CLIENT (FLUTTER)                 │
│                                                                        │
│  ┌───────────────────────┐  ┌─────────────────┐  ┌──────────────────┐  │
│  │     Presentation      │  │ State / Domain  │  │ Local Rendering  │  │
│  │  - Material 3 Theme   │  │  - Riverpod     │  │  - RepaintBound. │  │
│  │  - GoRouter Routes    │  │  - Quota State  │  │  - 10+ Templates │  │
│  │  - Responsive Layout  │  │  - Subscriptions│  │  - High-res PNG  │  │
│  └───────────┬───────────┘  └────────┬────────┘  └─────────┬────────┘  │
│              │                       │                     │           │
│  ┌───────────▼───────────────────────▼─────────────────────▼────────┐  │
│  │ Data & Infrastructure: SecureStorage | SQLite/Prefs | HTTP Client│  │
│  └───────────────────────────────────┬──────────────────────────────┘  │
└──────────────────────────────────────┼─────────────────────────────────┘
                                       │ HTTPS / JSON (TLS 1.3)
                                       │ Bearer Header: X-App-Instance-Id
                                       ▼
┌────────────────────────────────────────────────────────────────────────┐
│                   CLOUDFLARE WORKERS (EDGE BACKEND)                    │
│                                                                        │
│  ┌───────────────────────── Middleware Pipeline ────────────────────┐  │
│  │ RequestID | CORS | RateLimiter | ErrorBoundary | AuthSanitizer   │  │
│  └───────────────────────────────────┬──────────────────────────────┘  │
│                                      │                                 │
│  ┌────────────────────────────── Route Handlers ──────────────────┐    │
│  │ /v1/health | /v1/config | /v1/usage                            │    │
│  │ /v1/generations/reply | /v1/generations/caption                │    │
│  │ /v1/purchases/verify  | /v1/subscription/status                │    │
│  │ /v1/ads/verify-reward | /v1/feedback | /v1/privacy/delete-data │    │
│  └───────────────┬───────────────────────────┬────────────────────┘    │
│                  │                           │                         │
│  ┌───────────────▼───────────┐   ┌───────────▼──────────────────────┐  │
│  │      Cloudflare D1        │   │    Google Gemini 1.5/2.0 API     │  │
│  │  - installations          │   │  - Structured JSON Mode          │  │
│  │  - daily_usage            │   │  - System Prompt Isolation       │  │
│  │  - generation_metadata    │   │  - Content Safety Filters        │  │
│  │  - subscription_entitlem. │   └──────────────────────────────────┘  │
│  │  - reward_events          │                                         │
│  │  - feedback_records       │                                         │
│  └───────────────────────────┘                                         │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Client Architecture (Flutter / Dart)

### 2.1 State Management: Riverpod 2.x
- **Unidirectional Data Flow:** Presentation components watch immutable state providers (`AsyncValue<T>`).
- **Separation of Concerns:**
  - `presentation/`: Widgets, screen layouts, animations, dialogs.
  - `providers/`: StateNotifier / AsyncNotifier controllers managing business rules.
  - `repositories/`: Data access layers wrapping local storage and remote HTTP APIs.
  - `services/`: Native bridges (InAppPurchase, GoogleMobileAds, SharePlus, RepaintBoundary exporter).

### 2.2 Navigation: GoRouter
- Declarative route hierarchy with deep linking support:
  - `/onboarding` (Onboarding introduction)
  - `/home` (Home Dashboard)
  - `/reply-studio` (Reply Generator)
  - `/caption-lab` (Caption & Hook Generator)
  - `/card-maker` (Meme & Quote Card Maker)
  - `/challenge` (Daily Creative Challenge)
  - `/history` (Saved creations and favorites)
  - `/paywall` (Subscription upgrade screen)
  - `/settings` (Settings, legal disclosures, data wipe)

### 2.3 Local-First Card Rendering Engine
- **Zero Cloud Image API dependency:** Meme and quote cards are rendered entirely locally using Flutter's custom rendering pipeline (`RepaintBoundary` -> `ui.Image` -> `toByteData(format: ui.ImageByteFormat.png)`).
- **Multi-Script Unicode Engine:** Fully supports Latin, Devanagari (Hindi), and Gujarati scripts without font clipping or layout overflow.
- **Dynamic Watermark System:** Renders an elegant "Made with VibeKit AI" watermark badge for free users, automatically omitted for verified Pro users.

---

## 3. Backend Architecture (Cloudflare Workers + D1)

### 3.1 Edge Execution Engine
- Written in modern TypeScript compiled for the Cloudflare V8 Workers runtime.
- Global low-latency edge dispatch with zero cold starts.

### 3.2 Database Layer: Cloudflare D1
- Embedded distributed SQLite database.
- Migration files tracked in `/migrations/` applied via `wrangler d1 migrations apply`.
- Parameterized queries to eliminate SQL injection risks.

### 3.3 Gemini AI Provider Adapter
- Strictly server-side authentication using `GEMINI_API_KEY`.
- Prompts are constructed using strict system delimiters. User inputs are treated solely as payload data.
- Enforces strict JSON response schemas so Flutter receives guaranteed type-safe responses.

---

## 4. Monetisation & Quota Architecture

### 4.1 Daily Free Allowance
- Every client receives **3 free successful generations per UTC calendar day**.
- Deduplication and idempotency keys (`X-Idempotency-Key`) prevent charging credits twice on network retry.
- Failed AI calls (timeouts or provider 500s) do not consume quota.

### 4.2 Rewarded Ads (Extra Credits)
- Free users can watch up to **2 rewarded ads per day**.
- Each verified completed ad grants **3 bonus credits**.
- Server verifies AdMob SSV callbacks or cryptographic tokens before incrementing `rewarded_credits_earned`.

### 4.3 Google Play Billing (VibeKit Pro)
- Products: `vibekit_pro_monthly` and `vibekit_pro_yearly`.
- Benefits:
  - Ad-free experience throughout the app.
  - 200 high-priority AI generations per monthly billing cycle.
  - Watermark-free high-resolution card exports.
  - Access to all premium card designer templates.
- Backend verification: Worker checks purchase tokens against Google Play Developer API before persisting entitlements in `subscription_entitlements`.
