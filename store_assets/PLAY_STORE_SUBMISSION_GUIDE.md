# 🚀 ReplyVibe AI — Google Play Console Submission Guide

This dossier contains all the pre-filled metadata, policy declarations, data safety questionnaire answers, and asset paths required to submit **ReplyVibe AI** to the Google Play Console for Production or Closed Testing.

---

## 1. 📦 Build Artifact & Signing Details

| Item | Value |
| :--- | :--- |
| **Package Name / App ID** | `com.vibekit.vibekit_ai` |
| **Target SDK Version** | `36` (Android 16 / 15 — Exceeds Google Play requirement) |
| **Minimum SDK Version** | `24` (Android 7.0 Nougat — Covers 98%+ of global active Android devices) |
| **Version Code** | `3` |
| **Version Name** | `1.0.2` |
| **Signed Release AAB File** | `ReplyVibe-AI-v1.0.2-release.aab` / `app/build/app/outputs/bundle/release/app-release.aab` |
| **AAB File Size** | `~62.8 MB` |
| **Keystore File** | `app/android/upload-keystore.jks` |
| **Keystore Alias** | `upload` |
| **Cleartext HTTP Allowed** | `false` (Strict TLS 1.3 enforced via `network_security_config.xml`) |

---

## 2. 📝 Store Listing Metadata

### App Title (Max 30 characters)
```text
ReplyVibe AI - Smart Replies
```

### Short Description (Max 80 characters)
```text
AI smart replies, savage comebacks, viral captions & aesthetic quote cards.
```

### Full Description (Max 4,000 characters)
```text
Stuck on what to reply? Need the perfect savage comeback, an aesthetic Instagram caption, or a viral Reel hook? 

ReplyVibe AI is your all-in-one texting copilot and social media creativity studio, powered by Google Gemini AI.

🔥 WHAT YOU CAN DO WITH REPLYVIBE AI:

💬 1. SMART REPLY STUDIO
Never leave anyone on "read" again. Paste any DM, awkward text, flirtatious compliment, or professional inquiry and get instant tailored responses across 8 distinct tones:
• Funny & Witty
• Savage & Sarcastic
• Flirty & Charming
• Confident & Direct
• Polite & Professional
• Supportive & Warm

🔥 2. VIBE CHECK & ROAST
Paste any draft or message before you hit send. ReplyVibe rates the tone, roasts cringe texts, and rewrites your message for maximum confidence. Modes include Roast Me, Vibe Polish, Date Doctor, and Boss Mode.

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

Download ReplyVibe AI now and elevate your social texting game!
```

---

## 3. 🎨 Store Assets Checklist

All assets are located in the `store_assets/` directory:

| Asset | Specifications | File Path |
| :--- | :--- | :--- |
| **App Icon** | 512 x 512 px PNG (32-bit, max 1024KB) | `store_assets/icon_512x512.png` |
| **Feature Graphic** | 1024 x 500 px PNG (No transparency, max 1024KB) | `store_assets/feature_graphic_1024x500.png` |
| **Phone Screenshots (9:16)** | Minimum 1080x1920 (exceeds Google Play 1080px rule) | `store_assets/phone_screenshots/` |

---

## 4. 📋 Google Play Console Policy Questionnaire Answers

### A. App Access
* **Selection:** `All functionality is available without special access credentials.`
* *(Explanation: ReplyVibe AI uses a seamless device-based pseudonymous ID; users do not need a login/password to access any screen).*

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

### H. In-App Products & Subscriptions Setup (Monetization)
Create these exact Product IDs in Play Console under **Monetize > In-app products / Subscriptions**:
* **Subscriptions:**
  * `vibekit_pro_yearly` (Base Plan: Yearly with 3-day free trial)
  * `vibekit_pro_monthly` (Base Plan: Monthly recurring)
  * `vibekit_pro_weekly` (Base Plan: Weekly recurring, optional)
* **In-App Products:**
  * `vibekit_pro_lifetime` (Non-consumable: One-time Lifetime VIP pass)
  * `vibekit_credits_50` (Consumable: 50 AI Credits top-up)

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

* **Privacy Policy URL:** `https://vibekit-ai-privacy.vercel.app`
* **Terms of Service URL:** `https://vibekit-ai-privacy.vercel.app/terms.html`
* **Account / Data Deletion URL:** `https://vibekit-ai-privacy.vercel.app/#deletion`
* **Support Email:** `support@vibekit.ai` / `privacy@vibekit.ai`

---

## 7. 🚀 Final Submission Steps

1. Log in to [Google Play Console](https://play.google.com/console).
2. Set Name to `ReplyVibe AI - Smart Replies`, select **App** and **Free**.
3. Under **Grow > Store presence > Main store listing**:
   - Paste Title, Short Description, and Full Description from Section 2.
   - Upload `store_assets/icon_512x512.png`.
   - Upload `store_assets/feature_graphic_1024x500.png`.
   - Upload screenshots from `store_assets/phone_screenshots/`.
4. Under **Policy > App content**:
   - Complete each section using the exact answers in Section 4 & 5.
5. Under **Release > Closed testing**:
   - Create a new release.
   - Drag & drop `ReplyVibe-AI-v1.0.2-release.aab`.
   - Review release notes and click **Start rollout to Closed testing**!


