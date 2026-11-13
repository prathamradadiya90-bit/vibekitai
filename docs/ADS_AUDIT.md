# Phase 8: AdMob Implementation Audit & Fixes

## 1. Executive Summary
This document provides a thorough audit of the entire Google AdMob monetization and advertising architecture across the client application (`app/lib/core/services/admob_service.dart`, `app/lib/core/widgets/adaptive_banner_widget.dart`, `AndroidManifest.xml`) and the edge backend (`backend/src/routes/ads.ts`, `backend/src/quota/quota_manager.ts`). All identified architectural risks, memory leaks, frequency capping flaws, policy violations, and unhandled failure modes have been resolved.

---

## 2. Findings Table

| ID | Issue Description | Severity | Impacted File | Fix Implemented |
|---|---|---|---|---|
| **AD-01** | `MobileAds.instance.initialize()` was awaited synchronously before `runApp()`, causing startup jank and delaying first frame rendering. | **High** | `app/lib/main.dart` | Deferred AdMob initialization to `WidgetsBinding.instance.addPostFrameCallback` after the first frame rendered cleanly. |
| **AD-02** | `HomeScreen` declared `_bannerAd` and loaded it, but never placed it into the widget tree, leaving impressions unserved. | **High** | `app/lib/features/home/home_screen.dart` | Built `AdaptiveBannerWidget` with explicit `ADVERTISEMENT` policy label, auto-collapse on no-fill, and embedded it into the home feed. |
| **AD-03** | Ad reload on load failure lacked backoff, risking continuous tight request loops under network outages. | **High** | `app/lib/core/services/admob_service.dart` | Implemented exponential backoff ($2^n$ seconds: 2s, 4s, 8s) capped at 3 retries max. |
| **AD-04** | Rewarded ad button had no double-tap protection; rapid clicking could trigger concurrent ad displays. | **Medium** | `app/lib/core/services/admob_service.dart` | Added `_isShowingRewardedAd` mutex lock that rejects parallel invocations until ad dismiss. |
| **AD-05** | Early dismissal by user was not tracked as a distinct telemetry funnel event. | **Medium** | `app/lib/core/services/admob_service.dart`, `analytics_service.dart` | Added `_userEarnedReward` tracking; emits `ad_dismissed_early` if user closes ad prior to reward event. |
| **AD-06** | Release builds lacked runtime assertion to prevent accidental shipping with Google Test Ad Unit IDs. | **High** | `app/lib/core/config/app_config.dart` | Added `AppConfig.validateAdEnvironment()` asserting release builds use build flags (`--dart-define`). |
| **AD-07** | Pro subscribers still triggered ad loading in the background, wasting network bandwidth. | **Medium** | `app/lib/core/services/admob_service.dart` | Added `updateProStatus()`: suppresses preloading banners and interstitials, and hides rewarded entry points when user is Pro. |
| **AD-08** | Banner slot left blank whitespace if fill failed, violating Google AdMob layout policies. | **Medium** | `app/lib/core/widgets/adaptive_banner_widget.dart` | Configured `AdaptiveBannerWidget` to return `const SizedBox.shrink()` when `_loadFailed` or `!_isLoaded`. |
| **AD-09** | Backend `/ads/verify-reward` did not enforce the daily reward cap (max 2/day) in development/test branches. | **Medium** | `backend/src/routes/ads.ts` | Guarded reward crediting with `DAILY_REWARD_LIMIT_REACHED` (429) check on server. |
| **AD-10** | Missing standard ad telemetry events (`ad_load_success`, `ad_load_fail`, `ad_impression`, `ad_reward_granted`, `ad_dismissed_early`). | **Medium** | `app/lib/core/services/analytics_service.dart` | Whitelisted and implemented all 5 ad lifecycle telemetry events. |

---

## 3. Policy & Frequency Cap Specifications

1. **Credit-Rewarded Video Ads:**
   - **Client Cap:** Button disabled after 2 rewarded ads watched today (`quota.rewardedAdsWatchedToday >= 2`).
   - **Server Cap:** Authoritative rejection `DAILY_REWARD_LIMIT_REACHED` (429) if user attempts >2 rewards per UTC day.
   - **Double-Tap Guard:** Button locked immediately when showing ad.
   - **Server-Side Verification (SSV):** Cryptographic verification using Google's public key list (`https://www.gstatic.com/admob/reward/verifier-keys.json`) and SHA-256 with ECDSA P-256.

2. **Interstitial Ads:**
   - **Cooldown:** Minimum 180 seconds (3 minutes) between consecutive interstitial impressions.
   - **Daily Limit:** Maximum 3 interstitials per UTC day.
   - **Restricted Screens:** Prohibited on app open, during AI prompt generation, on onboarding, paywall, and settings screens.
   - **Natural Break Placement:** Displayed only after successful card export or challenge completion.

3. **Banner Ads:**
   - **Adaptive Sizing:** Anchored adaptive sizing matching screen width.
   - **Placement:** Displayed below the daily credits card on `HomeScreen`.
   - **Clear Labelling:** Accompanied by policy-mandated `ADVERTISEMENT` text.
   - **Zero Blank Space:** Collapses to 0-height (`SizedBox.shrink()`) on no-fill.

4. **Pro Users:**
   - Ads SDK completely unloads banners and interstitials.
   - Rewarded video entry points hidden.

---

## 4. Manual Verification Checklist (Using AdMob Test Units)

| Test Step | Test Action | Expected Result | Pass/Fail |
|---|---|---|---|
| **1. Startup** | Launch app from cold start | App opens without blocking; AdMob initializes after first frame. | ✅ PASS |
| **2. Banner Display** | View `HomeScreen` as a free user | Adaptive banner renders cleanly below credits card with `ADVERTISEMENT` label. | ✅ PASS |
| **3. Banner Collapse** | Simulate network disconnect before banner load | Banner slot completely collapses (`SizedBox.shrink()`), zero blank space. | ✅ PASS |
| **4. Rewarded Preload** | Inspect debug logs on startup | Rewarded ad preloads with exponential backoff on retry. | ✅ PASS |
| **5. Rewarded Completion** | Watch rewarded ad to completion | `onUserEarnedReward` fires, calls `/v1/ads/verify-reward`, user gets +3 credits, toast shows `+3 Bonus AI Credits`. | ✅ PASS |
| **6. Early Dismissal** | Close rewarded video before reward prompt | No credit granted; `ad_dismissed_early` event logged; ad preloads next. | ✅ PASS |
| **7. Rewarded Cap** | Watch 2 rewarded ads in the same UTC day | Button shows `2/2` cap reached; entry point disabled. | ✅ PASS |
| **8. Interstitial Cooldown** | Trigger interstitial, then attempt another after 1 minute | Suppressed with message: `Cooldown active (<180s)`. | ✅ PASS |
| **9. Interstitial Cap** | Trigger 3 interstitials across the day | 4th attempt suppressed with message: `Daily frequency cap reached (3/3)`. | ✅ PASS |
| **10. Pro Experience** | Upgrade to VibeKit Pro | Banner disappears, rewarded video button hidden, interstitials disabled. | ✅ PASS |
