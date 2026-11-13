# VibeKit AI — Master Test Plan

---

## 1. Test Levels & Strategy

1. **Static Analysis & Linting:**
   - Flutter / Dart: `flutter analyze` enforcing `flutter_lints`.
   - Dart Formatting: `dart format --output=none --set-exit-if-changed .`
   - TypeScript: `npm run typecheck` (`tsc --noEmit`).
2. **Flutter Unit & Widget Tests:**
   - Quota Model calculations and boundary conditions.
   - Serialization and deserialization of Generation contracts.
   - LocalDatabase fallback store CRUD operations (filtering, favorites, deletions).
   - CardTemplates registry completeness.
   - Widget tests for OnboardingScreen and HomeScreen rendering.
3. **Backend Integration Tests (Vitest):**
   - Health and Config routes (`/v1/health`, `/v1/config`).
   - Quota status calculations (`/v1/usage`).
   - Generation endpoints (`/v1/generations/reply`, `/v1/generations/caption`).
   - Validation failure responses (empty prompts, oversized payloads).
   - Purchase verification and entitlement activation (`/v1/purchases/verify`, `/v1/subscription/status`).
   - Rewarded ad callback verification (`/v1/ads/verify-reward`).
   - Data privacy deletion route (`/v1/privacy/delete-data`).
   - User feedback ingestion (`/v1/feedback`).
4. **Android Build & Configuration Verification:**
   - Validation of `compileSdkVersion 36`, `targetSdkVersion 35`, `minSdkVersion 24`.
   - AndroidManifest metadata validation for Google Mobile Ads App ID placeholder.
