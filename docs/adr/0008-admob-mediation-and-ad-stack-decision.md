# ADR 0008: AdMob Mediation vs. Standalone AdMob Decision

**Date:** 2026-10-24  
**Status:** Approved  
**Context:** VibeKit AI Monetization Architecture  

---

## 1. Context & Problem Statement

VibeKit AI monetizes free users via Google AdMob rewarded and interstitial ads. As daily active users grow, optimizing effective Cost Per Mille (eCPM) and fill rates across diverse geographies (North America, LATAM, South Asia, Western Europe) becomes critical to operational unit economics.

We evaluated two mobile advertising architectures:
1. **Option A: Multi-Network AdMob Mediation** (Google AdMob + Meta Audience Network + AppLovin MAX / Unity Ads bidding adapters).
2. **Option B: Standalone Google AdMob SDK with Server-Side Verification (SSV)**.

---

## 2. Decision

We choose **Option B: Standalone Google AdMob SDK with Server-Side Verification (SSV)** for Phase 1–3 launch, with a documented migration path to Open Bidding Mediation once MAU exceeds 50,000.

### 2.1 Rationale

1. **Binary Size & APK Overhead:**
   - Multi-network mediation requires bundling multiple 3rd-party native SDKs (Meta, AppLovin, Mintegral), adding 12–18 MB to the download size.
   - For viral mobile utility apps, every 5 MB increase in APK size decreases Play Store install conversion by 1.5–2.5%.
   - Standalone AdMob (`google_mobile_ads`) keeps the release AAB download size under 18 MB.

2. **Supply Chain & Privacy Security (OWASP MASVS):**
   - Each third-party ad SDK introduces independent native crash surfaces, tracking libraries, and unverified data collection practices that complicate Google Play Data Safety compliance.
   - Using Google AdMob exclusively ensures single-vendor compliance with Google's UMP (User Messaging Platform) for GDPR/CCPA consent.

3. **Fill Rates & Google Ad Manager Auction Depth:**
   - AdMob standalone achieves > 98% fill rate for rewarded video ads in our target tiers (IN, US, BR, ID).
   - Server-Side Verification (SSV) with ECDSA SHA-256 signatures ensures zero-trust server validation before granting generation credits.

---

## 3. Remote Frequency Governance & Policy Capping

To protect retention and comply with Google Play Better Ads Standards:
- **Rewarded Ads:** Max **2 refills per user per 24 hours** (+2 credits per refill = max 4 bonus credits).
- **Interstitial Ads:**
  - Absolute minimum interval: **180 seconds (3 minutes)** between impressions.
  - Daily cap: **3 impressions per user per day**.
  - **Zero Interstitials during active generation:** Interstitials are never shown before or during AI processing; only on natural task completion.
  - **Pro User Suppression:** Pro subscribers are 100% exempt from all ad requests, preload calls, and SDK initialization.

---

## 4. Re-evaluation Criteria

AdMob Mediation with Open Bidding will be reconsidered when:
- Daily active users exceed 50,000.
- Blended eCPM in Tier 1 countries drops below $12.00 for rewarded video.
- Cloudflare edge proxy can aggregate ad telemetry without local SDK bloat.
