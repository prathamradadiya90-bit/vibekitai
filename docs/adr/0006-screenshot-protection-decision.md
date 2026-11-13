# ADR 0006: Screenshot Protection and Window Security Strategy

## Status
Accepted

## Context
Mobile application security standards (OWASP MASVS-STORAGE-2 / ASVS) frequently recommend enabling Android `WindowManager.LayoutParams.FLAG_SECURE` to prevent screen capture, screen recording, and exposure in the OS application switcher ("recents" screen).

We must evaluate whether to apply `FLAG_SECURE` to VibeKit AI, specifically on the Paywall / Purchase screens versus general application screens.

## Analysis
1. **Core Product Value & User Flow:**
   - VibeKit AI is a creator utility designed for social sharing (viral meme cards, aesthetic quotes, Instagram captions, smart replies).
   - Users frequently take screenshots of generated replies or card previews to share directly in messaging apps or social stories.
   - Setting `FLAG_SECURE` globally across the Flutter `MainActivity` would completely break native screenshot sharing and disrupt core product virality.

2. **Paywall & Payment Architecture:**
   - VibeKit AI does **NOT** collect, handle, or store credit card numbers, bank accounts, or payment credentials directly in the Flutter app.
   - All subscription and consumable credit transactions are executed through the official Google Play Billing library (`com.android.billingclient`).
   - When the user taps "Upgrade to Pro" or "Purchase Credits", the payment modal is rendered by the Android OS / Google Play Services in a separate system window that automatically and natively enforces `FLAG_SECURE`.
   - The in-app `PaywallScreen` displays only promotional marketing copy, feature comparison bullet points, and localized pricing fetched from Google Play. No sensitive financial information is present on the Flutter surface.

## Decision
1. **No Global `FLAG_SECURE` on Flutter Activity:**
   - `FLAG_SECURE` is **NOT** applied to the primary Flutter window. This guarantees users can capture and share generated quote cards and replies without friction.
2. **Rely on Google Play OS-Level Security for Payments:**
   - Financial input security is delegated to Google Play Billing's native secure window, ensuring zero exposure of card details or authentication credentials.
3. **Data Masking in App Switcher:**
   - Transient user input fields (e.g. text message in Reply Studio) are cleared upon successful generation or reset, preventing persistent display in the OS application switcher preview.

## Consequences
- **Positive:** Unhindered user experience for social card creation, screenshotting, and viral sharing.
- **Positive:** 100% compliance with Google Play Billing security guidelines without custom window management hacks.
- **Trade-off:** Content displayed on promotional marketing screens (such as the Paywall pricing overview) can be screenshotted by users, which poses no security or compliance risk as pricing and marketing claims are public.
