# VibeKit AI ⚡

> **Create your next reply, caption and shareable card.**

VibeKit AI is a production-oriented Android application engineered with **Flutter (Material 3, Riverpod, GoRouter)** and an edge backend running on **Cloudflare Workers (TypeScript, Cloudflare D1, Google Gemini)**.

---

## 📱 Features

- **💬 Reply Studio:** Context-aware suggestions across 8 distinct tones (Funny, Friendly, Flirty, Confident, Professional, Polite, Supportive, Witty) and 4 languages (English, Hindi, Hinglish, Gujarati).
- **✨ Caption Lab:** Scroll-stopping Reel hooks, viral captions, CTAs, and categorized hashtags for Instagram Reels, Posts, WhatsApp Status, and YouTube Shorts.
- **🎨 Meme & Card Maker:** 100% offline local-first visual card engine. 8+ original templates, custom typography, aspect ratios (1:1, 9:16, 4:5), and high-resolution PNG rendering via Flutter's `RepaintBoundary`.
- **🎯 Daily Creative Challenge:** Offline-capable rotating daily prompts to jumpstart creativity.
- **📁 Local History & Favorites:** SQLite storage with search, filters, one-tap copy/share, and data deletion.
- **🔒 Privacy First:** Zero mandatory account registration. Transient edge AI processing with zero permanent storage of user prompts.
- **💎 Monetisation Architecture:** Sustainable Google AdMob integration (banner + verified rewarded ads) and Google Play In-App Billing (`vibekit_pro_monthly`, `vibekit_pro_yearly`) with authoritative backend token verification.

---

## 🏗️ Architecture & Project Structure

```
vibekit-ai/
├── app/                        # Production Flutter Android Client
│   ├── android/                # Gradle wrapper, manifests, targetSdk 35
│   ├── assets/                 # Bundled challenges & icons
│   ├── lib/
│   │   ├── core/               # Theme, constants, network client, SQLite, providers
│   │   ├── features/           # All 8 feature screens
│   │   └── main.dart           # App entry point
│   ├── test/                   # Comprehensive unit & widget tests
│   └── pubspec.yaml            # Dependency manifest
├── backend/                    # Cloudflare Workers TypeScript Edge API
│   ├── migrations/             # D1 distributed SQLite schema migrations
│   ├── src/
│   │   ├── ai/                 # Gemini API adapter & prompt safety defense
│   │   ├── quota/              # Atomic rate limiting & daily quota accounting
│   │   ├── routes/             # Versioned REST endpoints (/v1/*)
│   │   └── index.ts            # Hono application & security headers
│   ├── test/                   # Vitest automated test suite (17/17 passed)
│   ├── wrangler.toml           # Worker & D1 database configuration
│   └── package.json            # Node/TS dependencies
└── docs/                       # Complete architecture, test, and release documentation
```

---

## 🚀 Quick Start & Testing

### 1. Flutter Mobile App
```bash
cd app
flutter pub get
flutter test       # Runs unit & widget test suite (All 7 passed)
flutter analyze    # Static analysis (No issues found)
flutter run        # Run locally
```

### 2. Cloudflare Workers Backend
```bash
cd backend
npm install
npm test           # Runs Vitest test suite (17/17 passed)
npm run typecheck  # TypeScript strict type check (100% clean)
npx wrangler dev   # Starts local edge server at http://127.0.0.1:8787
```

---

## 📚 Documentation Index

- [Initial Project Audit](docs/INITIAL_AUDIT.md)
- [Official Requirements Check](docs/OFFICIAL_REQUIREMENTS.md)
- [System Architecture](docs/ARCHITECTURE.md)
- [Implementation Plan](docs/IMPLEMENTATION_PLAN.md)
- [Dependencies & Package Hygiene](docs/DEPENDENCIES.md)
- [Risks & Mitigations](docs/RISKS_AND_BLOCKERS.md)
- [API Specification](docs/API_DOCUMENTATION.md)
- [Google Gemini Setup](docs/AI_PROVIDER_SETUP.md)
- [Free AI Providers Guide](docs/FREE_AI_PROVIDERS.md)
- [AdMob Integration Runbook](docs/ADMOB_SETUP.md)
- [Google Play Billing Setup](docs/PLAY_BILLING_SETUP.md)
- [Google Play Console Setup](docs/GOOGLE_PLAY_SETUP.md)
- [Privacy & Data Flow](docs/PRIVACY_AND_DATA_FLOW.md)
- [Security Review](docs/SECURITY_REVIEW.md)
- [Master Test Plan](docs/TEST_PLAN.md)
- [Automated Test Results](docs/TEST_RESULTS.md)
- [Three-Pass Audit Report](docs/THREE_PASS_AUDIT.md)
- [Production & Monetization Audit](docs/PLAY_STORE_AND_ADMOB_AUDIT.md)
- [Deployment Guide](docs/DEPLOYMENT_GUIDE.md)
- [Cost Control Guide](docs/COST_CONTROL.md)
- [Play Store Listing Copy](docs/PLAY_STORE_LISTING.md)
- [Play Store Release Checklist](docs/PLAY_STORE_RELEASE_CHECKLIST.md)
- [Known Issues Log](docs/KNOWN_ISSUES.md)
