# VibeKit AI — Google Play Console & Signing Setup

---

## 1. Keystore Creation for Release Signing

To create the production signing key locally (never commit this file to Git):
```bash
keytool -genkey -v -keystore vibekit-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias vibekit_key
```

Create `app/android/key.properties` (strictly gitignored):
```properties
storePassword=YourStorePasswordHere
keyPassword=YourKeyPasswordHere
keyAlias=vibekit_key
storeFile=../../vibekit-release.jks
admobAppId=ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY
```

---

## 2. Play Console Application Configuration

- **Application ID:** `com.vibekit.vibekit_ai`
- **Default Language:** English (United States) / English (India)
- **App Type:** App
- **Free or Paid:** Free (with In-App Purchases)
- **Declarations:**
  - Content Rating: Complete IARC questionnaire (General audience 13+).
  - Target Audience: 13-17, 18 and over. Check "Not designed for children".
  - Data Safety: Pseudonymous Device ID collected for functionality/analytics, Purchase history for account management. Zero user contact, camera, or audio data collected.
  - Ads: Declare that the app contains ads.
  - Financial Features: Declare that the app contains in-app digital content purchases.

---

## 3. Closed Testing (14 Days / 20 Testers)

For personal Google Play developer accounts created after November 2023:
1. Create a Closed Testing track named `alpha`.
2. Recruit 20 opt-in testers (friends, family, or testing groups).
3. Ensure testers download the app and remain opted in for 14 continuous days.
4. Apply for Production access directly within the Play Console dashboard after day 14.
