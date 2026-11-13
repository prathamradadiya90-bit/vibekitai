# VibeKit AI — Comprehensive Project Overview & System Documentation

> **Prepared for Claude AI Context Ingestion**  
> **Repository:** VibeKit AI (`vibekit-ai`)  
> **Target Platforms:** Android (Target SDK 35, Flutter M3) & Cloudflare Workers Edge API  
> **Core Tagline:** *"Create your next reply, caption and shareable card."*

---

## 1. Executive Summary

**VibeKit AI** is a production-grade, privacy-first, monetization-ready mobile application and edge API ecosystem designed for social media creators, casual communicators, and digital professionals.

The project enables users to:
1. **Generate context-aware social replies** across 8 tones and 4 languages (English, Hindi, Hinglish, Gujarati).
2. **Craft high-conversion social captions, viral hooks, and hashtags** optimized for Instagram Reels, Posts, WhatsApp Status, and YouTube Shorts.
3. **Design meme and quote cards 100% offline** via a local vector/raster rendering engine (`RepaintBoundary` -> PNG) with dynamic watermarking.
4. **Engage in Daily Creative Challenges** with rotating creative prompts.
5. **Manage local history & favorites** backed by an embedded SQLite database.
6. **Operate under a sustainable hybrid monetization model**:
   - **Free tier:** 3 AI generations per UTC day + up to 2 rewarded ads per day (+3 credits per ad).
   - **Pro tier:** `vibekit_pro_monthly` & `vibekit_pro_yearly` via Google Play Billing, providing ad-free usage, watermark removal, and 200 monthly AI generations.

---

## 2. High-Level Architecture

```
┌────────────────────────────────────────────────────────────────────────┐
│                        ANDROID MOBILE CLIENT (FLUTTER)                 │
│                                                                        │
│  ┌───────────────────────┐  ┌─────────────────┐  ┌──────────────────┐  │
│  │   UI & Presentation   │  │ State / Domain  │  │ Local Rendering  │  │
│  │  - Material 3 Design  │  │  - Riverpod 2.x │  │  - RepaintBound. │  │
│  │  - GoRouter (9 routes)│  │  - Quota State  │  │  - 8+ Templates  │  │
│  │  - Responsive Layout  │  │  - Billing Notif│  │  - High-res PNG  │  │
│  └───────────┬───────────┘  └────────┬────────┘  └─────────┬────────┘  │
│              │                       │                     │           │
│  ┌───────────▼───────────────────────▼─────────────────────▼────────┐  │
│  │ Storage & Services: SharedPreferences | SQLite (sqflite) | HTTP   │  │
│  │ Google Mobile Ads SDK | Google Play In-App Purchase | SharePlus   │  │
│  └───────────────────────────────────┬──────────────────────────────┘  │
└──────────────────────────────────────┼─────────────────────────────────┘
                                       │ HTTPS / JSON (TLS 1.3)
                                       │ Headers: X-App-Instance-Id, X-Request-Id
                                       ▼
┌────────────────────────────────────────────────────────────────────────┐
│                   CLOUDFLARE WORKERS (EDGE BACKEND)                    │
│                                                                        │
│  ┌───────────────────────── Middleware Pipeline ────────────────────┐  │
│  │ RequestID | CORS | Security Headers | Error Boundary | Rate Limit│  │
│  └───────────────────────────────────┬──────────────────────────────┘  │
│                                      │                                 │
│  ┌────────────────────────────── Route Handlers ──────────────────┐    │
│  │ /v1/health | /v1/config | /v1/usage                            │    │
│  │ /v1/generations/reply | /v1/generations/caption                │    │
│  │ /v1/purchases/verify  | /v1/ads/verify-reward                  │    │
│  │ /v1/feedback          | /v1/privacy/delete-data                │    │
│  └───────────────┬───────────────────────────┬────────────────────┘    │
│                  │                           │                         │
│  ┌───────────────▼───────────┐   ┌───────────▼──────────────────────┐  │
│  │      Cloudflare D1        │   │       Multi-AI Engine Adapter    │  │
│  │  - installations          │   │  - Google Gemini 1.5/2.0 Flash   │  │
│  │  - daily_usage            │   │  - OpenAI-Compatible Providers   │  │
│  │  - generation_metadata    │   │    (Groq, Cerebras, DeepSeek)    │  │
│  │  - subscription_entitlem. │   │  - Structured JSON Output Enforc.│  │
│  │  - reward_events          │   │  - Prompt Safety Defense         │  │
│  │  - feedback_records       │   └──────────────────────────────────┘  │
│  └───────────────────────────┘                                         │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Technology Stack & Key Dependencies

### 3.1 Mobile Client (Flutter / Dart)
- **Framework:** Flutter (Channel stable, Dart SDK `>=3.3.0 <4.0.0`)
- **UI System:** Material 3 with dynamic theme switching (Dark & Light) and Google Fonts (`Inter`, `Playfair Display`, `Space Mono`, `Caveat`).
- **State Management:** `flutter_riverpod: ^2.6.1` (immutable StateNotifier and AsyncNotifier providers).
- **Navigation:** `go_router: ^14.8.0` (type-safe, declarative route hierarchy with deep link readiness).
- **Network Client:** `http: ^1.3.0` wrapped in an resilient `ApiClient` with retry logic, timeouts, and error parsing.
- **Local Database:** `sqflite: ^2.4.1` with `path: ^1.9.0` and `path_provider: ^2.1.5`.
- **Local Key-Value Cache:** `shared_preferences: ^2.3.5`.
- **Monetization & Ads:** `google_mobile_ads: ^9.1.0` (Banners + Rewarded Video Ads).
- **In-App Billing:** `in_app_purchase: ^3.2.0` (Google Play Subscriptions with backend receipt validation).
- **Sharing & System Integration:** `share_plus: ^10.1.4`, `url_launcher: ^6.3.1`, `uuid: ^4.5.1`.

### 3.2 Edge Backend (Cloudflare Workers / TypeScript)
- **Runtime:** Cloudflare Workers (V8 isolates at global edge points of presence, near-zero cold start).
- **Web Framework:** `hono: ^4.6.17` (lightweight, edge-native microframework).
- **Validation Engine:** `zod: ^3.24.1` (strict input validation on all request payloads).
- **Database:** Cloudflare D1 (distributed SQL database backed by SQLite).
- **Testing:** `vitest: ^2.1.8` (17/17 automated tests passing).
- **Deployment & Config:** `wrangler: ^3.103.1` with `wrangler.toml`.

### 3.3 AI Model Providers
- **Primary:** Google Gemini 1.5 Flash / Gemini 2.0 Flash (`GEMINI_API_KEY`).
- **Alternative/Fallback:** OpenAI-compatible LLM edge endpoints (`AI_PROVIDER="openai-compatible"`, e.g., Groq `llama-3.3-70b-versatile`, Cerebras `llama-3.3-70b`, DeepSeek, or local Ollama).

---

## 4. Repository Directory Structure

```
vibekit-ai/
├── README.md                      # Primary project readme & quickstart
├── PROJECT_OVERVIEW.md            # This Claude AI overview document
├── app/                           # Flutter Android Mobile Application
│   ├── android/                   # Android native platform code
│   │   ├── app/
│   │   │   ├── build.gradle       # targetSdk 35, compileSdk 35, minSdk 21
│   │   │   └── src/main/AndroidManifest.xml # Permissions, AdMob App ID
│   │   └── build.gradle           # Root Gradle build configuration
│   ├── assets/                    # Static packaged assets
│   │   ├── data/challenges.json   # 30+ bundled daily creative challenges
│   │   └── icons/                 # App icon & UI vectors
│   ├── lib/
│   │   ├── core/                  # Shared infrastructural code
│   │   │   ├── config/            # App environment & API endpoints config
│   │   │   ├── constants/         # App colors, sizes, string keys
│   │   │   ├── network/           # ApiClient, ApiEndpoints, ApiException
│   │   │   ├── providers/         # Global Riverpod providers (Quota, Billing, Ads)
│   │   │   ├── router/            # GoRouter configuration & routes
│   │   │   ├── services/          # AdMob, Play Billing, CardExport, Share
│   │   │   ├── storage/           # LocalDatabase (SQLite) & PreferencesService
│   │   │   └── theme/             # Material 3 theme definitions & palettes
│   │   ├── features/              # Feature modules (Domain & Presentation)
│   │   │   ├── caption_lab/       # Captions, Hooks & Hashtag generator
│   │   │   ├── card_maker/        # Offline Meme/Quote card canvas & exporter
│   │   │   ├── challenge/         # Daily challenge rotating prompt viewer
│   │   │   ├── history/           # Local saved items & favorites browser
│   │   │   ├── home/              # Dashboard, quick actions, daily quota widget
│   │   │   ├── onboarding/        # 3-step introduction & permissions walkthrough
│   │   │   ├── paywall/           # Pro subscription plans & feature comparison
│   │   │   ├── reply_studio/      # Tone & language-specific reply generator
│   │   │   └── settings/          # Cache clear, data wipe, privacy policy viewer
│   │   ├── models/                # Typed data transfer and entity objects
│   │   │   ├── caption_item.dart
│   │   │   ├── card_template.dart
│   │   │   ├── history_item.dart
│   │   │   ├── quota_status.dart
│   │   │   └── reply_item.dart
│   │   └── main.dart              # Client application entry point & DI init
│   ├── test/                      # Unit and widget test suite (7/7 passed)
│   └── pubspec.yaml               # Flutter package dependencies & assets declaration
├── backend/                       # Cloudflare Workers TypeScript Edge API
│   ├── migrations/
│   │   └── 0001_init.sql          # D1 SQLite schema (6 tables + indexes)
│   ├── src/
│   │   ├── ai/                    # Multi-provider AI abstraction layer
│   │   │   ├── factory.ts         # Provider factory (Gemini vs OpenAI-compatible)
│   │   │   ├── gemini.ts          # Google Gemini adapter with JSON mode & safety
│   │   │   └── openai_compatible.ts # Edge provider adapter (Groq, Cerebras, etc.)
│   │   ├── quota/                 # Daily credit calculation, rate limiting, and accounting
│   │   │   └── quota_manager.ts
│   │   ├── routes/                # Hono route controllers
│   │   │   ├── ads.ts             # POST /v1/ads/verify-reward
│   │   │   ├── config.ts          # GET /v1/config (feature flags, limits)
│   │   │   ├── feedback.ts        # POST /v1/feedback
│   │   │   ├── generations.ts     # POST /v1/generations/reply & /caption
│   │   │   ├── health.ts          # GET /v1/health
│   │   │   ├── privacy.ts         # POST /v1/privacy/delete-data & policy HTML
│   │   │   ├── purchases.ts       # POST /v1/purchases/verify & GET /subscription
│   │   │   └── usage.ts           # GET /v1/usage (quota checking)
│   │   ├── schemas/               # Zod validation schemas
│   │   │   └── validation.ts
│   │   ├── index.ts               # Hono app entry point & security middleware
│   │   └── types.ts               # Cloudflare Env bindings & TypeScript interfaces
│   ├── test/                      # Vitest test suite (17/17 passed)
│   ├── package.json               # Backend npm scripts and dependencies
│   ├── tsconfig.json              # Strict TypeScript compiler options
│   └── wrangler.toml              # Cloudflare worker & D1 binding configuration
└── docs/                          # Comprehensive 23-document technical library
    ├── ADMOB_SETUP.md             # AdMob setup and rewarded ad runbook
    ├── AI_PROVIDER_SETUP.md       # Google Gemini 1.5/2.0 configuration guide
    ├── API_DOCUMENTATION.md       # Complete HTTP API specification & payloads
    ├── ARCHITECTURE.md            # Detailed system architecture document
    ├── COST_CONTROL.md            # Token efficiency and Cloudflare/AI cost control
    ├── DEPENDENCIES.md            # Dependency audit & license evaluation
    ├── DEPLOYMENT_GUIDE.md        # Worker deploy and production checklist
    ├── FREE_AI_PROVIDERS.md       # Alternative zero-cost AI provider guide
    ├── GOOGLE_PLAY_SETUP.md       # Play Console app bundle and release guide
    ├── IMPLEMENTATION_PLAN.md     # Engineering phases & milestones
    ├── INITIAL_AUDIT.md           # Baseline code audit report
    ├── KNOWN_ISSUES.md            # Tracked edge cases & mitigation strategies
    ├── OFFICIAL_REQUIREMENTS.md   # Product & engineering specification check
    ├── PLAY_BILLING_SETUP.md      # Play In-App Purchase integration runbook
    ├── PLAY_STORE_AND_ADMOB_AUDIT.md # Monetization & store compliance audit
    ├── PLAY_STORE_LISTING.md      # Optimized Play Store metadata & copy
    ├── PLAY_STORE_RELEASE_CHECKLIST.md # Release verification checklist
    ├── PRIVACY_AND_DATA_FLOW.md   # Data flow, GDPR/CCPA, and privacy policies
    ├── RISKS_AND_BLOCKERS.md      # Risk matrix and fallback architectures
    ├── SECURITY_REVIEW.md         # Threat model, input sanitization, API defense
    ├── TEST_PLAN.md               # Quality assurance and testing protocol
    ├── TEST_RESULTS.md            # Verified test outputs (Unit, Widget, API)
    └── THREE_PASS_AUDIT.md        # Comprehensive multi-pass code quality audit
```

---

## 5. Core Features & Functional Modules

### 5.1 Reply Studio
- **Functionality:** Ingests incoming messages or conversational context and generates 3 tailored reply variations.
- **Tones Supported (8):** `Funny`, `Friendly`, `Flirty`, `Confident`, `Professional`, `Polite`, `Supportive`, `Witty`.
- **Languages Supported (4):** `English`, `Hindi`, `Hinglish` (hybrid Hindi-English in Latin script), `Gujarati`.
- **Features:** One-tap copy, share, save to favorites, regenerate, and send to Card Maker.

### 5.2 Caption Lab
- **Functionality:** Produces engagement-optimized content for social media creators.
- **Outputs Provided in 1 AI Request:**
  - 3 Viral Scroll-Stopping Hooks (with psychological angles).
  - 2 Structured Captions (including spacing and formatting).
  - 2 Clear Calls-To-Action (CTAs).
  - Categorized Hashtags (Niche, Trending, High-Reach).
- **Target Platforms:** Instagram Reels, Instagram Feed Posts, WhatsApp Status, YouTube Shorts.

### 5.3 Meme & Quote Card Maker (Local-First Engine)
- **100% Offline Generation:** Does **not** require any cloud graphic APIs.
- **Rendering Pipeline:** Built using Flutter's `RepaintBoundary` linked to a `GlobalKey`.
  ```dart
  RenderRepaintBoundary boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  ui.Image image = await boundary.toImage(pixelRatio: 3.0);
  ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  Uint8List pngBytes = byteData!.buffer.asUint8List();
  ```
- **Templates:** 8+ prebuilt visual templates (Gradient Aura, Minimalist Monochrome, Cyber Neon, Editorial Paper, Pastel Aesthetic, Bold Retro, etc.).
- **Typography & Scripts:** Multi-script Unicode support ensuring Hindi, Gujarati, and emoji render without glyph truncation or layout overflow.
- **Aspect Ratios:** 1:1 (Square), 9:16 (Stories/Reels/Shorts), 4:5 (Portrait).
- **Watermark Logic:** Renders a discreet `"Made with VibeKit AI"` watermark badge for Free tier users, automatically suppressed for verified Pro subscribers.

### 5.4 Daily Creative Challenge
- **Functionality:** Delivers a fresh creative prompt every day to spark content creation.
- **Offline Capability:** Ships with a bundled fallback JSON file (`assets/data/challenges.json`) containing 30+ pre-seeded challenges, rotating deterministically based on day-of-the-year.
- **Action Link:** One-tap button immediately launches Reply Studio or Caption Lab pre-populated with the challenge prompt.

### 5.5 Local History & Favorites
- **Engine:** On-device SQLite (`sqflite`).
- **Features:**
  - Automatically records generated replies, captions, and created cards.
  - Full-text search and category filtering (`all`, `reply`, `caption`, `card`).
  - Toggle favorite status.
  - One-tap data wipe for user privacy compliance.

### 5.6 Paywall & Google Play In-App Billing
- **Products Registered:**
  - `vibekit_pro_monthly`
  - `vibekit_pro_yearly`
- **Features:** Restores purchases on app launch, performs authoritative backend verification (`/v1/purchases/verify`), and updates UI state instantly across all screens.

---

## 6. Backend API Specification

**Base URL:** `https://<worker-domain>.workers.dev` (or `http://127.0.0.1:8787` locally)  
**Standard Headers Sent by Flutter App:**
```http
X-App-Instance-Id: <uuid-v4-persisted-in-secure-storage>
X-Request-Id: req_<timestamp>_<random>
Content-Type: application/json
Accept: application/json
```

### 6.1 Endpoints Summary

| Method | Endpoint | Description | Auth / Headers |
|---|---|---|---|
| `GET` | `/v1/health` | Healthcheck and operational status | None |
| `GET` | `/v1/config` | Global configuration, feature flags, quota limits | None |
| `GET` | `/v1/usage` | Returns remaining free, rewarded, and pro credits | `X-App-Instance-Id` |
| `POST` | `/v1/generations/reply` | Generates 3 reply suggestions via AI | `X-App-Instance-Id` |
| `POST` | `/v1/generations/caption`| Generates hooks, captions, CTAs, hashtags | `X-App-Instance-Id` |
| `POST` | `/v1/purchases/verify` | Verifies Google Play purchase token | `X-App-Instance-Id` |
| `GET` | `/v1/purchases/status` | Queries active Pro subscription status | `X-App-Instance-Id` |
| `POST` | `/v1/ads/verify-reward` | Grants bonus credits after rewarded ad watch | `X-App-Instance-Id` |
| `POST` | `/v1/privacy/delete-data`| Complete deletion of installation & usage logs| `X-App-Instance-Id` |
| `GET` | `/privacy` / `/privacy-policy` | Renders HTML Privacy Policy for Play Store | Browser accessible |
| `POST` | `/v1/feedback` | Ingests user feedback and issue reports | `X-App-Instance-Id` |

### 6.2 Key Request & Response Contracts

#### `POST /v1/generations/reply`
**Request Payload:**
```json
{
  "context": "She sent: 'Are you free this weekend?' We went on one date last week.",
  "tone": "flirty",
  "language": "hinglish"
}
```
**Response (200 OK):**
```json
{
  "suggestions": [
    "Weekend ka toh pata nahi, but for you I can definitely clear my schedule 😉",
    "Depends... are we continuing our conversation from last week or starting a new chapter? ✨",
    "Only if it involves good coffee and better company. Where are we going?"
  ],
  "tone": "flirty",
  "language": "hinglish",
  "credits_remaining": 2
}
```

#### `POST /v1/generations/caption`
**Request Payload:**
```json
{
  "topic": "Weekend coding marathon and launching my new app",
  "platform": "instagram_reels",
  "tone": "confident",
  "language": "english"
}
```
**Response (200 OK):**
```json
{
  "hooks": [
    "They said don't build alone in a weekend. Here is what happened.",
    "0 users on Friday. Full launch on Sunday. Here is the stack.",
    "Stop waiting for the 'perfect time' to ship your idea."
  ],
  "captions": [
    "48 hours, 10 cups of black coffee, and one simple idea turned into working software. Building from scratch is brutal, but hitting 'deploy' makes every bug worth it. Link in bio to check it out!",
    "Weekend projects hit differently when you stop overthinking and start shipping. Here's a glimpse behind the scenes of launching VibeKit AI."
  ],
  "ctas": [
    "Drop a ⚡ if you're building something this month!",
    "Save this post for your next weekend hackathon inspiration."
  ],
  "hashtags": [
    "#buildinpublic",
    "#indiehacker",
    "#flutterdev",
    "#codinglife",
    "#startuplife"
  ],
  "credits_remaining": 1
}
```

#### Error Contract (Standardized)
```json
{
  "error": {
    "code": "QUOTA_EXCEEDED",
    "message": "You have reached your daily credit limit. Please watch an ad or upgrade to Pro."
  }
}
```

---

## 7. Database Schemas

### 7.1 Cloudflare D1 (Distributed SQLite Backend)
Defined in `backend/migrations/0001_init.sql`:

1. **`installations`**:
   - `id TEXT PRIMARY KEY` (UUID v4 `X-App-Instance-Id`)
   - `created_at TEXT NOT NULL`
   - `last_active_at TEXT NOT NULL`
   - `is_pro INTEGER NOT NULL DEFAULT 0`
   - `pro_expires_at TEXT`
2. **`daily_usage`**:
   - `id TEXT PRIMARY KEY`
   - `installation_id TEXT NOT NULL`
   - `usage_date TEXT NOT NULL` (UTC `YYYY-MM-DD`)
   - `free_credits_used INTEGER DEFAULT 0`
   - `rewarded_credits_earned INTEGER DEFAULT 0`
   - `rewarded_ads_watched INTEGER DEFAULT 0`
   - `pro_credits_used INTEGER DEFAULT 0`
   - `UNIQUE(installation_id, usage_date)`
3. **`generation_metadata`**:
   - `id TEXT PRIMARY KEY`, `request_id TEXT NOT NULL`, `installation_id TEXT NOT NULL`
   - `category TEXT NOT NULL` (`'reply'` | `'caption'`)
   - `tone TEXT`, `language TEXT`, `status TEXT` (`'success'` | `'failed'`)
   - `latency_ms INTEGER`, `created_at TEXT NOT NULL`
   - *(Note: Actual user prompt text and generated output text are NEVER stored in the database)*
4. **`subscription_entitlements`**:
   - `id TEXT PRIMARY KEY`, `installation_id TEXT NOT NULL`, `product_id TEXT NOT NULL`
   - `purchase_token TEXT UNIQUE`, `order_id TEXT`, `status TEXT`, `expires_at TEXT`
5. **`reward_events`**:
   - `id TEXT PRIMARY KEY`, `installation_id TEXT`, `reward_id TEXT UNIQUE`, `credits_granted INTEGER`
6. **`feedback_records`**:
   - `id TEXT PRIMARY KEY`, `installation_id TEXT`, `message TEXT`, `created_at TEXT`

### 7.2 Client-Side SQLite Database (`sqflite`)
Defined in `app/lib/core/storage/local_database.dart`:

1. **`history`**:
   - `id TEXT PRIMARY KEY`
   - `type TEXT NOT NULL` (`'reply'` | `'caption'` | `'card'`)
   - `content TEXT NOT NULL` (JSON string containing full metadata and options)
   - `created_at INTEGER NOT NULL`
   - `is_favorite INTEGER NOT NULL DEFAULT 0`

---

## 8. Quota, Rate Limiting & Monetization Flow

```
User triggers Generation
        │
        ▼
Is User Pro? ───(YES)──► Check Pro Quota (200/mo) ──► Allow Generation
        │
      (NO)
        ▼
Check UTC Daily Usage:
Free Used < 3? ──(YES)──► Deduct 1 Free Credit ────► Allow Generation
        │
      (NO)
        ▼
Rewarded Credits Available? ──(YES)──► Deduct 1 Rewarded Credit ──► Allow Generation
        │
      (NO)
        ▼
Reject with 429: "QUOTA_EXCEEDED"
Prompt UI Dialog: [Watch Rewarded Ad (+3 Credits)] or [Upgrade to Pro]
```

### Free vs. Pro Feature Matrix

| Feature | Free Tier | Pro Tier (`vibekit_pro_*`) |
|---|---|---|
| Daily Free AI Credits | 3 per UTC day | 200 per billing cycle |
| Extra Credits via Ads | Up to 2 ads/day (+3 credits each) | Ads completely disabled |
| Card Maker Templates | 8 standard templates | All templates unlocked |
| Card Watermark | "Made with VibeKit AI" badge | Watermark automatically removed |
| Generation Speed | Standard edge priority | High-priority edge queue |
| Banner Ads | Displayed at screen bottoms | 100% Ad-Free |

---

## 9. Security, Privacy & Compliance Architecture

1. **Zero Prompt Retention:** Neither Cloudflare Workers nor D1 persist the incoming user prompt or generated text. Prompts are processed strictly in volatile memory and passed over TLS 1.3 to Google Gemini.
2. **Prompt Injection & Jailbreak Defense:** User inputs are strictly typed and wrapped inside system delimiter blocks before reaching the LLM. System instructions strictly enforce JSON output mode.
3. **Identifier Sanitization:** The client utilizes an anonymous UUID v4 instance identifier stored securely on the device. No Google account, email, phone number, or biometric data is ever requested or stored.
4. **Data Deletion Rights (GDPR / CCPA / Play Store Compliance):** The mobile app provides a prominent "Delete All My Data" button under Settings. This triggers `POST /v1/privacy/delete-data`, wiping all installation records, usage counters, and audit logs on the server, followed by an immediate local SQLite wipe.
5. **Android Target SDK 35:** Fully configured with modern Android permissions, strict edge-to-edge support, and Gradle 8.x compatibility.

---

## 10. Development, Build & Testing Commands

### 10.1 Mobile App (Flutter)
```bash
cd app

# Install dependencies
flutter pub get

# Run static code analysis (strict linter rules)
flutter analyze

# Execute automated unit and widget test suite
flutter test

# Run app on connected Android device/emulator
flutter run

# Build release Android App Bundle (AAB) for Play Store
flutter build appbundle --release
```

### 10.2 Edge Backend (Cloudflare Workers)
```bash
cd backend

# Install dependencies
npm install

# Run strict TypeScript typecheck
npm run typecheck

# Run automated Vitest test suite
npm test

# Start local edge development server (http://127.0.0.1:8787)
npm run dev

# Deploy to Cloudflare Workers production edge
npm run deploy

# Apply D1 migrations to remote production database
npx wrangler d1 migrations apply vibekit-ai-db --remote
```

---

## 11. Environment Variables & Secret Configuration

### Backend Secrets (`wrangler secret put <KEY>`)
- `GEMINI_API_KEY`: API key from Google AI Studio (paid tier for zero-retention guarantee).
- `GROQ_API_KEY`: Secondary fallback provider key.
- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`: Service account credentials for RTDN and `purchases.subscriptionsv2`.
- `PLAY_INTEGRITY_DECRYPTION_KEY`: Optional key for verifying Play Integrity tokens server-side.
- `ENABLE_CREDIT_PACKS`: Set to `"true"` to enable consumable credit pack purchases.
- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`: **Required** for any purchase to be accepted. Without it, `/v1/purchases/*` fail closed with 503.
- `ALLOW_UNVERIFIED_PURCHASES`: Local dev only (`.dev.vars`). Set to `"true"` to accept purchases without Google Play verification when no service account is configured. Never set in deployed environments.

### Flutter Build Flags
- Configured in `app/lib/core/config/app_config.dart` or via `--dart-define`:
  - `API_URL`: Production backend URL.
  - `ADMOB_BANNER_ID`: Google AdMob production/test banner ID.
  - `ADMOB_REWARDED_ID`: Google AdMob production/test rewarded video ID.
  - `ADMOB_INTERSTITIAL_ID`: Google AdMob production/test interstitial ID.

---

## 12. Implemented Modules & Systems

1. **Reply Studio (`lib/features/reply_studio/`)**: AI contextual message replies with 8 tones and 4 languages.
2. **Caption Lab (`lib/features/caption_lab/`)**: Social captions, hooks, CTAs, and hashtags.
3. **Bio & Username Lab (`lib/features/bio_lab/`)**: Creative bios and handles for Instagram/WhatsApp/LinkedIn with direct export to Card Maker.
4. **Vibe Streaks & Rewards (`lib/features/streaks/`)**: Daily streak tracking, streak freeze via rewarded ads, XP levels, and milestone rewards.
5. **Meme & Card Maker (`lib/features/card_maker/`)**: Local-first image card engine with 8 designer presets and watermark control.
6. **Referral Program (`lib/features/referrals/`)**: "Invite a friend, both get +2 credits" with atomic accounting.
7. **Monetization Engine (`lib/features/paywall/`)**: Weekly, monthly, and yearly Pro plans with 3-day trial and interstitial ad management (180s gap, max 3/day).
8. **Privacy-Safe Analytics (`lib/core/services/analytics_service.dart`)**: Discrete funnel metrics logging with zero text or prompt tracking.

---

## 13. Context & Guidance for Claude AI

When assisting with this codebase:
1. **Maintain Architectural Separation:** Keep UI widgets in `lib/features/<feature>/presentation/` and state logic in `lib/features/<feature>/providers/`. Global state belongs in `lib/core/providers/`.
2. **Preserve Privacy & Zero-Retention Invariants:** Never add backend logging that writes `context`, `topic`, or raw prompt strings into D1, console logs, or analytics.
3. **Respect Riverpod 2.x Patterns:** Use `ref.watch()` within widget `build()` methods and `ref.read()` within event callbacks. Keep providers granular.
4. **Uphold Local-First Card Rendering:** Any new card templates or visual layout features must be implemented in pure Flutter widgets compatible with `RepaintBoundary` rendering (avoid external WebViews or HTML rendering).
5. **Strict Type Safety:** Backend code uses Zod for incoming payloads and strict TypeScript (`noImplicitAny`). All route endpoints must return standardized JSON errors matching `{ error: { code, message } }`.
