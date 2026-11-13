# VibeKit AI — Google AdMob Setup & Policy Runbook

**SDK:** `google_mobile_ads: ^9.1.0`  
**Current Testing State:** Configured with Google's official AdMob sample/test App ID and Ad Unit IDs. Zero risk of policy violations or invalid traffic flags during local testing.

---

## 1. Test IDs in Current Codebase

- **Android App ID (`AndroidManifest.xml` via placeholder `${admobAppId}`):** `ca-app-pub-3940256099942544~3347511713` (defaults in `app/android/app/build.gradle.kts`)
- **Banner Ad Unit ID (`AppConfig.testBannerAdUnitId`):** `ca-app-pub-3940256099942544/6300978111`
- **Rewarded Ad Unit ID (`AppConfig.testRewardedAdUnitId`):** `ca-app-pub-3940256099942544/5224354917`

---

## 2. Production Account Steps (Manual Action for User)

1. **Sign up or log in to AdMob:** [https://admob.google.com/](https://admob.google.com/)
2. **Add Application:**
   - Platform: **Android**
   - Is the app listed on a supported app store? **No** (until published on Google Play)
   - App name: **VibeKit AI**
3. **Copy your Real AdMob App ID:**
   - Format: `ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY`
   - Set in `app/android/key.properties` (or pass via `-PadmobAppId=...` / Gradle property):
     ```properties
     admobAppId=ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY
     ```
     `app/android/app/build.gradle.kts` injects this dynamically into `AndroidManifest.xml` via `manifestPlaceholders["admobAppId"]`.
4. **Create Ad Units:**
   - **Banner Ad Unit:** Name: `VibeKit_Home_Banner`
   - **Rewarded Ad Unit:** Name: `VibeKit_Reward_Credits`
     - Reward amount: `3`
     - Reward item: `Credits`
     - (Optional) Enable Server-Side Verification (SSV) callback to:
       `https://api.vibekit.ai/v1/ads/verify-reward`
5. **Update Unit IDs in `app/lib/core/config/app_config.dart`:**
   Replace the test IDs with your production ad unit IDs prior to building release AAB.

---

## 3. Policy Compliance Checklist

- [x] **Ad Placements:** Banner placed away from touch buttons to prevent accidental clicks.
- [x] **Ad-Free Pro State:** Pro users never see banners or forced rewarded ad prompts.
- [x] **Verified Rewards Only:** Reward credits are only issued via `onUserEarnedReward` callback. Closing or failing to load an ad never issues free credits.
- [x] **Child Safety:** App declares target age 13+.
