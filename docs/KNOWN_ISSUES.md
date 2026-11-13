# VibeKit AI — Known Issues & Environmental Limitations

**Status as of October 10, 2026:**

---

## 1. External Account Dependencies (Normal Greenfield Requirements)

1. **Live Google Gemini API Key:**
   - *Status:* Configured with graceful fallback in development/test mode. Live text generation in production requires setting `GEMINI_API_KEY` on Cloudflare Secrets.
2. **AdMob Production Approval:**
   - *Status:* Configured with Google's official AdMob sample App ID and test ad units. Zero policy violation risk during local testing. Live revenue requires user's AdMob account approval and replacing test IDs.
3. **Google Play Console Subscription Products:**
   - *Status:* `in_app_purchase` is fully implemented and tested with server-side token verification. Products (`vibekit_pro_monthly`, `vibekit_pro_yearly`) must be published in Google Play Console for real store checkout to complete.

---

## 2. Platform / Build Environment

1. **Android Studio cmdline-tools Component:**
   - Android SDK 35 and Java 21 OpenJDK are present. Running `flutter doctor` flags `cmdline-tools` missing on this Windows workstation until Android Studio's SDK manager installs the CLI tools package. Flutter unit tests, widget tests, and static analysis execute with 100% green pass.
