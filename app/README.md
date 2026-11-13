# VibeKit AI — Flutter Mobile Client ⚡

VibeKit AI is a production-grade Android application built with **Flutter (Material 3, Riverpod 2.x, GoRouter)**. It provides context-aware replies, viral social captions, and a 100% offline local-first quote & meme card designer.

---

## 📱 Features

- **Reply Studio:** Context-aware reply generator across 8 tones (*Funny, Friendly, Flirty, Confident, Professional, Polite, Supportive, Witty*) and 4 languages (*English, Hindi, Hinglish, Gujarati*).
- **Caption Lab:** Reel hooks, viral captions, CTAs, and hashtags for Instagram Reels, Posts, WhatsApp Status, and YouTube Shorts.
- **Meme & Card Maker:** 100% offline local card engine using Flutter's native `RepaintBoundary` (pixel ratio 3.0), 8 built-in designer templates, 3 aspect ratios (1:1, 9:16, 4:5), and watermark controls.
- **Daily Creative Challenge:** Bundled offline creative prompts.
- **History & Favorites:** SQLite storage with search, category filtering, one-tap copy/share, and data deletion.
- **Monetisation:** Integrated Google AdMob (banner + verified rewarded ads) and Google Play In-App Billing (`vibekit_pro_monthly`, `vibekit_pro_yearly`).

---

## 🛠️ Technology Stack & Dependencies

- **Framework:** Flutter SDK `3.24+` / `3.47+` (Dart 3.x)
- **State Management:** `flutter_riverpod: ^2.6.1`
- **Navigation:** `go_router: ^14.8.0`
- **Local Storage:** `sqflite: ^2.4.1`, `shared_preferences: ^2.3.5`
- **Monetisation:** `google_mobile_ads: ^9.1.0`, `in_app_purchase: ^3.2.0`
- **Native Sharing:** `share_plus: ^10.1.4`, `url_launcher: ^6.3.1`
- **Typography:** `google_fonts: ^6.2.1`

---

## 🚀 Running & Testing

```bash
# Install dependencies
flutter pub get

# Run static analysis (0 errors, 0 warnings)
flutter analyze

# Run unit and widget test suite (All 7 passed)
flutter test

# Run locally on connected device or emulator
flutter run

# Run with custom backend API URL
flutter run --dart-define=API_URL=https://api.vibekit.ai
```

---

## 📦 Building Release Bundle

```bash
# Generate signed Android App Bundle (AAB) for Google Play Console
flutter build appbundle --release
```
The output file is generated at `build/app/outputs/bundle/release/app-release.aab`.
