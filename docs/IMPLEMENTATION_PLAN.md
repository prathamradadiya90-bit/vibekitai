# VibeKit AI — Master Implementation Plan

**Objective:** Autonomous end-to-end delivery of VibeKit AI Flutter client and Cloudflare Workers backend, including testing, security review, Play Store documentation, and release readiness.

---

## Phase Breakdown & Execution Sequence

### Phase 1: Environment & Project Scaffolding
- Initialize Flutter project with standard package structure (`com.vibekit.vibekit_ai`).
- Initialize Cloudflare Workers TypeScript backend project (`backend/`).
- Set up root `.gitignore` protecting secrets, keys, and build artifacts.
- Configure Android Gradle settings (`compileSdkVersion 36`, `targetSdkVersion 35`, `minSdkVersion 24`, Java 17/21 compatibility).

### Phase 2: Design System & Shared Client Foundation
- Define Deep Purple & Indigo brand design system (`AppTheme`, `AppColors`, typography, glass accents).
- Setup GoRouter declarative routes with clean page transitions.
- Configure Riverpod state container and global service providers.
- Implement persistent local storage (Settings, Daily Challenge cache, History, Favorites).

### Phase 3: Screen Implementations
1. **Splash & Onboarding:** Features explanation, skip button, AI accuracy & privacy disclosure.
2. **Home Dashboard:** Greeting, credit counter badge, quick action buttons, rotating daily challenge card, recent creations list.
3. **Reply Studio:** Multi-line text input, tone selector (Funny, Friendly, Flirty, Confident, Professional, Polite, Supportive, Witty), language selector (English, Hindi, Hinglish, Gujarati), length selector, generation of 3 distinct suggestions, copy/share/favorite actions.
4. **Caption Lab:** Topic input, platform selector (Instagram, Reels, WhatsApp Status, YouTube Shorts), tone/length selectors, generation of multiple captions, hooks, CTAs, and relevant hashtags.
5. **Meme and Card Maker:** Interactive canvas, text input, typography selector, 8+ built-in original templates (Modern Gradient, Minimalist Dark, Paper Retro, Neon Glow, etc.), aspect ratio selector (1:1 Square, 9:16 Story, 4:5 Portrait), high-res RepaintBoundary PNG rendering, native Android share sheet integration, watermark control.
6. **Daily Creative Challenge:** Curated challenges, offline fallback, direct "Try this prompt" integration.
7. **History & Favorites:** Saved items list, search & filter by category, item deletion, "Clear All History" with safety confirmation.
8. **Settings & Legal:** Theme selector, language picker, subscription management & restore purchases, Privacy Policy screen, Terms of Service screen, AI Processing Disclosure, and working Data Deletion flow.
9. **Paywall / Subscription Screen:** Feature comparison matrix, localized price presentation, subscription restoration, Play Store billing terms.

### Phase 4: Backend & Database Engineering
- Cloudflare Workers API routes with Hono and Zod validation:
  - `GET /v1/health`
  - `GET /v1/config`
  - `GET /v1/usage`
  - `POST /v1/generations/reply`
  - `POST /v1/generations/caption` (generates captions, hooks, and hashtags)
  - `POST /v1/feedback`
  - `POST /v1/privacy/delete-data`
  - `POST /v1/purchases/verify`
  - `GET /v1/subscription/status`
  - `POST /v1/ads/verify-reward`
- Cloudflare D1 migrations:
  - `installations`
  - `daily_usage`
  - `generation_metadata`
  - `subscription_entitlements`
  - `reward_events`
- Google Gemini AI Adapter with prompt defense, strict JSON output schemas, and content safety filters.
- Rate limiting, UTC daily quota reset, and deduplication logic.

### Phase 5: Monetisation Integrations
- AdMob banner & rewarded ads implementation with official Google test ad unit IDs.
- Reward callback verification to grant 3 bonus credits (max 2/day).
- Google Play Billing service with `in_app_purchase` integration, product details querying, purchase token verification against backend, and subscription status reconciliation.

### Phase 6: Automated Testing & Quality Gates
- Flutter unit tests: Quota calculation, prompt formatting, card layout measurement, history storage, theme persistence.
- Flutter widget tests: Navigation, form validation, theme switching, empty/loading/error states.
- Backend tests: Vitest test suite covering all routes, validation errors, quota enforcement, and mock AI responses.
- Static analysis: `flutter analyze` and TypeScript `tsc --noEmit`.

### Phase 7: Three-Pass Final Audit
- Pass 1: Functional Completeness review.
- Pass 2: Security, Data Protection & Monetisation audit.
- Pass 3: Release & Regression Readiness check.

### Phase 8: Release Preparation & Final Documentation
- Generate original app icon vector/assets and splash screen configs.
- Android release signing configuration templates.
- Complete documentation suite (`README.md`, `docs/API_DOCUMENTATION.md`, `docs/PLAY_STORE_LISTING.md`, etc.).
- Final executive report.
