# 🚀 VibeKit AI — Google Play Console Submission Guide

This dossier contains all the pre-filled metadata, policy declarations, data safety questionnaire answers, and asset paths required to submit **VibeKit AI** to the Google Play Console for Production or Closed Testing.

---

## 1. 📦 Build Artifact & Signing Details

| Item | Value |
| :--- | :--- |
| **Package Name / App ID** | `com.vibekit.vibekit_ai` |
| **Target SDK Version** | `35` (Android 15 — Exceeds Google Play 2024–2026 requirement) |
| **Minimum SDK Version** | `24` (Android 7.0 Nougat — Covers 98%+ of global active Android devices) |
| **Version Code** | `1` |
| **Version Name** | `1.0.0` |
| **Signed Release AAB File** | `app/build/app/outputs/bundle/release/app-release.aab` |
| **AAB File Size** | `~62.5 MB` (Optimized with Proguard/R8 & shrinkResources) |
| **Keystore File** | `app/android/upload-keystore.jks` |
| **Keystore Alias** | `upload` |
| **Cleartext HTTP Allowed** | `false` (Strict TLS 1.3 enforced via `network_security_config.xml`) |

---

## 2. 📝 Store Listing Metadata

### App Title (Max 30 characters)
```text
VibeKit AI - Vibe & Comebacks
```

### Short Description (Max 80 characters)
```text
AI smart replies, savage comebacks, viral captions & aesthetic quote cards.
```

### Full Description (Max 4,000 characters)
```text
Stuck on what to reply? Need the perfect savage comeback, an aesthetic Instagram caption, or a viral Reel hook? 

VibeKit AI is your all-in-one texting copilot and social media creativity studio, powered by Google Gemini AI.

🔥 WHAT YOU CAN DO WITH VIBEKIT AI:

💬 1. SMART REPLY STUDIO
Never leave anyone on "read" again. Paste any DM, awkward text, flirtatious compliment, or professional inquiry and get instant tailored responses across 8 distinct tones:
• Funny & Witty
• Savage & Sarcastic
• Flirty & Charming
• Confident & Direct
• Polite & Professional
• Supportive & Warm

🔥 2. VIBE CHECK & ROAST
Paste any draft or message before you hit send. VibeKit rates the tone, roasts cringe texts, and rewrites your message for maximum confidence. Modes include Roast Me, Vibe Polish, Date Doctor, and Boss Mode.

✨ 3. CAPTION & REEL HOOK LAB
Level up your social media presence. Generate scroll-stopping captions, high-converting hooks, and trending hashtags for Instagram, TikTok, and X. Choose from Aesthetic, Savage, Hustle, Poetic, and Minimal vibes.

👤 4. BIO LAB
Transform your digital first impression with aesthetic bios, clever one-liners, and unique handle ideas crafted for creators, entrepreneurs, and lifestyle profiles.

🎨 5. MEME & QUOTE CARD MAKER (100% OFFLINE)
Turn your favorite quotes, comebacks, and thoughts into stunning, high-resolution aesthetic cards ready for Instagram Stories, Pinterest, and WhatsApp Status. Works 100% offline directly on your device.

🏆 6. VIBE STREAKS & REWARDS
Build your creative momentum! Complete daily challenges, extend your streak, earn XP, and unlock exclusive designer card templates and bonus credits.

🔒 PRIVACY & ZERO PROMPT RETENTION:
• No account registration or email required.
• Your prompts are processed transiently in volatile RAM and never stored in a permanent database or used to train third-party foundation models.
• 100% offline local card rendering.
• You have the "Right to be Forgotten" with 1-tap data deletion in Settings.

Download VibeKit AI now and elevate your social texting game!
```

---

## 3. 🎨 Store Assets Checklist

All assets are located in the `store_assets/` directory:

| Asset | Specifications | File Path |
| :--- | :--- | :--- |
| **App Icon** | 512 x 512 px PNG (32-bit, max 1024KB) | `store_assets/icon_512x512.png` |
| **Feature Graphic** | 1024 x 500 px PNG (No transparency, max 1024KB) | `store_assets/feature_graphic_1024x500.png` |
| **Phone Screenshot 1** | Home & Daily Spark Hero | `store_assets/screenshot_01_home.png` |
| **Phone Screenshot 2** | AI Reply Studio & Tones | `store_assets/screenshot_02_reply_studio.png` |
| **Phone Screenshot 3** | Vibe Check & Roast | `store_assets/screenshot_03_vibe_check.png` |
| **Phone Screenshot 4** | Caption & Reel Hooks Lab | `store_assets/screenshot_04_caption_lab.png` |
| **Phone Screenshot 5** | Meme & Quote Card Maker | `store_assets/screenshot_05_card_maker.png` |
| **Phone Screenshot 6** | Streaks & Milestone Rewards | `store_assets/screenshot_06_streaks_rewards.png` |
| **Phone Screenshot 7** | VIP & Pro Paywall | `store_assets/screenshot_07_pro_paywall.png` |

---

## 4. 📋 Google Play Console Policy Questionnaire Answers

### A. App Access
* **Selection:** `All functionality is available without special access credentials.`
* *(Explanation: VibeKit AI uses a seamless device-based pseudonymous ID; users do not need a login/password to access any screen).*

### B. Ads Declaration
* **Selection:** `Yes, my app contains ads.`
* *(Details: Integrated Google Mobile Ads SDK for optional rewarded video ads granting extra daily credits).*

### C. In-App Purchases
* **Selection:** `Yes, my app offers in-app purchases.`
* *(Details: Integrates Google Play Billing for Annual VIP subscription with 3-day trial and Lifetime VIP Pass).*

### D. Content Rating Questionnaire
* **Category:** Utility, Productivity, Communication, or Entertainment.
* **Violence:** No
* **Sexuality:** No
* **Language:** Mild profanity may be checked/roast; profanity filter is actively enabled.
* **Controlled Substances:** No
* **Promotion of illegal acts:** No
* **User interaction:** Yes (users can share text externally).
* **Expected Rating:** `Teen` (13+) or `Everyone 10+`.

### E. Target Audience & Content
* **Target age groups:** `13–17`, `18 and over` (Select Teens & Adults).
* **Could this app appeal to children?** `No`.

### F. News Apps / COVID-19 / Financial / Government
* **Is this a news app?** `No`.
* **COVID-19 Contact Tracing or Status?** `No`.
* **Financial Features:** `No`.
* **Government App:** `No`.

### G. Generative AI Policy Declaration (Mandatory for AI Apps)
* **Does your app generate AI content?** `Yes`.
* **Are user reporting mechanisms available?** `Yes`. (Every generated suggestion card includes a 1-tap Flag/Report button submitting reports directly to safety review).
* **Are content guardrails in place?** `Yes`. (Automated content filters block hate speech, sexual violence, self-harm, and illegal content).

---

## 5. 🛡️ Data Safety Section Questionnaire Guide

| Category | Question | Answer | Details / Purpose |
| :--- | :--- | :--- | :--- |
| **Data Collection** | Does your app collect or share user data? | **Yes** | Pseudonymous installation ID, app performance diagnostics, and optional user feedback. |
| **Encryption** | Is all user data encrypted in transit? | **Yes** | Transmitted over TLS 1.3 / HTTPS. Cleartext HTTP is blocked. |
| **Account Deletion** | Do you provide a way for users to request data deletion? | **Yes** | Direct 1-tap deletion in Settings (`Delete My Data`) & web request URL. |
| **Identifiers** | Device or other IDs | **Collected (Ephemeral)** | Used for free daily quota tracking and anti-abuse fraud prevention. Not tied to identity. |
| **User Content** | Text messages / Prompts | **Collected (Transient only)** | Transmitted transiently for AI inference; zero permanent storage. |
| **App Info** | Crash logs & diagnostics | **Collected (Diagnostics)** | Used for crash monitoring and service stability. |

---

## 6. 🌐 Mandatory Legal URLs

* **Privacy Policy URL:** `https://<YOUR_DEPLOYED_DOMAIN>/privacy-policy` (Served by `backend/src/routes/privacy.ts`)
* **Terms of Service URL:** `https://<YOUR_DEPLOYED_DOMAIN>/terms` (Served by `backend/src/routes/privacy.ts`)
* **Account / Data Deletion URL:** `https://<YOUR_DEPLOYED_DOMAIN>/delete-account` (Served by `backend/src/routes/privacy.ts`)
* **Support Email:** `support@vibekit.ai` / `privacy@vibekit.ai`

---

## 7. 🚀 Final Submission Steps

1. Log in to [Google Play Console](https://play.google.com/console).
2. Click **Create App** → Set Name to `VibeKit AI - Vibe & Comebacks`, select **App** and **Free**.
3. Under **Grow > Store presence > Main store listing**:
   - Paste Title, Short Description, and Full Description from Section 2.
   - Upload `store_assets/icon_512x512.png`.
   - Upload `store_assets/feature_graphic_1024x500.png`.
   - Upload `store_assets/screenshot_*.png`.
4. Under **Policy > App content**:
   - Complete each section using the exact answers in Section 4 & 5.
5. Under **Release > Production** (or **Closed testing**):
   - Create a new release.
   - Drag & drop `app/build/app/outputs/bundle/release/app-release.aab`.
   - Review release notes and click **Start rollout to Production**!

