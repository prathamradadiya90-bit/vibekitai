# ReplyVibe AI — Google AdMob Production Monetization & Ads Setup Guide

This guide walks you through setting up real Google AdMob ads so you can earn real money from **Banner Ads**, **Rewarded Video Ads**, and **Interstitial Ads**.

---

## 1. What Ads are Already Built in the App?

| Ad Format | Where it Appears in App | Purpose & User Incentive | Revenue Potential |
| :--- | :--- | :--- | :--- |
| **Rewarded Video** | **Home Screen** (Daily Creator Perks) | User taps **"Watch Ad (+3 Credits)"** to earn free AI credits. Includes Server-Side Verification (SSV). | **Highest eCPM ($15–$40)** — high user intent and completion rate. |
| **Adaptive Banner** | **Home Screen** (Bottom of feed) | Continuous non-intrusive banner anchored at the bottom. Auto-hidden for PRO subscribers. | **Steady recurring impressions ($1–$4 eCPM)**. |
| **Interstitial** | **Meme & Card Studio** (On Export) | Full-screen ad triggered after generating/saving a card. Strictly capped at 1 ad per 180 seconds. | **High eCPM ($5–$15)**. |

---

## 2. Step-by-Step: Getting Your Real AdMob IDs

### Step 1: Create a Google AdMob Account
1. Go to [https://admob.google.com/](https://admob.google.com/) and sign in with your Google account.
2. Complete your payment and tax profile (so Google can transfer your earnings directly to your bank).

### Step 2: Add Your App to AdMob
1. In the left navigation, click **Apps** &rarr; **Add App**.
2. Select Platform: **Android**.
3. *Is the app listed on a supported app store?*
   - Select **No** (if not yet published on Google Play) or **Yes** (if published).
4. App Name: **ReplyVibe AI**
5. Click **Add App**.
6. **Important:** Copy your **AdMob App ID**.
   - Format: `ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY` (Notice the tilde `~`).

### Step 3: Create the 3 Ad Units
In the AdMob dashboard for your app, go to **Ad Units** &rarr; **Add Ad Unit**:

1. **Banner Ad Unit:**
   - Click **Banner**.
   - Ad unit name: `ReplyVibe_Home_Banner`
   - Click **Create ad unit**.
   - Copy the Ad Unit ID (Format: `ca-app-pub-XXXXXXXXXXXXXXXX/1111111111`).

2. **Rewarded Video Ad Unit (For Free Credits):**
   - Click **Rewarded**.
   - Ad unit name: `ReplyVibe_Rewarded_Credits`
   - Reward settings:
     - Reward amount: `3`
     - Reward item: `Credits`
   - **Enable Server-Side Verification (SSV):**
     - Expand **Advanced settings** &rarr; check **Server-side verification**.
     - Callback URL: `https://replyvibe-api.vercel.app/v1/ads/ssv`
     - Click **Verify URL** (AdMob verifies the endpoint returns 200).
   - Click **Create ad unit**.
   - Copy the Ad Unit ID (Format: `ca-app-pub-XXXXXXXXXXXXXXXX/2222222222`).

3. **Interstitial Ad Unit (For Card Exports):**
   - Click **Interstitial**.
   - Ad unit name: `ReplyVibe_Card_Export_Interstitial`
   - Click **Create ad unit**.
   - Copy the Ad Unit ID (Format: `ca-app-pub-XXXXXXXXXXXXXXXX/3333333333`).

---

## 3. Where to Put Your Real IDs in the Codebase

You have two easy ways to add your IDs:

### Method A: Direct Paste in `AppConfig` (Easiest)

1. Open [`app/lib/core/config/app_config.dart`](file:///d:/Downloads/Vibe%20kit%20ai/app/lib/core/config/app_config.dart).
2. Paste your 3 Ad Unit IDs in lines 38–40:
   ```dart
   static const String prodBannerAdUnitId = 'ca-app-pub-XXXXXXXXXXXXXXXX/1111111111';
   static const String prodRewardedAdUnitId = 'ca-app-pub-XXXXXXXXXXXXXXXX/2222222222';
   static const String prodInterstitialAdUnitId = 'ca-app-pub-XXXXXXXXXXXXXXXX/3333333333';
   ```
3. Open [`app/android/key.properties`](file:///d:/Downloads/Vibe%20kit%20ai/app/android/key.properties) (or copy from `key.properties.example`):
   ```properties
   admobAppId=ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY
   ```
   *(The build system automatically injects this into `AndroidManifest.xml`).*

> **Safety Guarantee:** While testing locally in debug mode (`flutter run`), the app automatically uses Google's official test IDs to protect your account. When you build for release (`flutter build appbundle`), it automatically switches to your real revenue-generating ads!

---

### Method B: Via Build Flags (Standard CI/CD)

Build your production release bundle using `--dart-define`:
```powershell
flutter build appbundle --release `
  --dart-define=API_URL=https://replyvibe-api.vercel.app `
  --dart-define=ADMOB_BANNER_ID=ca-app-pub-XXXXXXXXXXXXXXXX/1111111111 `
  --dart-define=ADMOB_REWARDED_ID=ca-app-pub-XXXXXXXXXXXXXXXX/2222222222 `
  --dart-define=ADMOB_INTERSTITIAL_ID=ca-app-pub-XXXXXXXXXXXXXXXX/3333333333
```

---

## 4. Setup `app-ads.txt` (Required to Earn Revenue)

Google AdMob requires an `app-ads.txt` file hosted on your developer domain to prevent counterfeit ad impressions.

1. In AdMob, go to **Apps** &rarr; **app-ads.txt**.
2. Copy your publisher snippet (e.g. `google.com, pub-XXXXXXXXXXXXXXXX, DIRECT, f08c47fec0942fa0`).
3. Place this snippet in a file at `https://yourdomain.com/app-ads.txt`.
4. Ensure the website URL in your Google Play Store listing matches `https://yourdomain.com`.

---

## 5. Critical Golden Rules to Protect Your Earnings

1. **NEVER click on your own live ads:** Google's automated fraud detection flags self-clicks and will suspend your AdMob account.
2. **Add Test Devices:** If testing on your personal phone with production builds, add your phone's Advertising ID as a "Test Device" in AdMob Settings:
   - AdMob Console &rarr; **Settings** &rarr; **Test devices** &rarr; **Add test device**.
3. **New Accounts take 24–48 hours to serve live ads:** When you first create an AdMob account, ad inventory may take up to 24–48 hours to start filling impressions.
4. **Link to Google Play once live:** Once your app is published on the Play Store, go to AdMob &rarr; **App Settings** &rarr; **App store details** &rarr; **Link with Google Play**. This unlocks maximum eCPM and brand advertiser budgets.
