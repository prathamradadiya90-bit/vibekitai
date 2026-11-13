# VibeKit AI — Deployment & Local Setup Guide

---

## 1. Prerequisites

- **Flutter SDK:** 3.24+ or 3.47+ (Stable channel)
- **Dart SDK:** 3.3+ (Built into Flutter)
- **Node.js:** v18+ or v20+ (Node v23.3.0 tested)
- **npm:** v10+ (npm 11.1.0 tested)
- **Cloudflare Wrangler CLI:** `npm install -g wrangler` or use `npx wrangler`

---

## 2. Backend Local Execution & D1 Setup

1. Open a terminal in `backend/`:
   ```bash
   cd backend
   npm install
   ```
2. Apply SQLite migrations to local D1 emulator:
   ```bash
   npx wrangler d1 migrations apply DB --local
   ```
3. Run backend locally:
   ```bash
   npx wrangler dev --port 8787
   ```
   The backend will be available at `http://127.0.0.1:8787` (or `http://10.0.2.2:8787` from Android Emulator).

---

## 3. Running the Flutter App Locally

1. Open a terminal in `app/`:
   ```bash
   cd app
   flutter pub get
   ```
2. Run on connected Android device or emulator:
   ```bash
   flutter run
   ```
3. To specify a custom backend API URL during build or run:
   ```bash
   flutter run --dart-define=API_URL=https://api.vibekit.ai
   ```

---

## 4. Deploying Backend to Cloudflare Workers

1. Authenticate with Cloudflare:
   ```bash
   npx wrangler login
   ```
2. Create production D1 database:
   ```bash
   npx wrangler d1 create vibekit-prod
   ```
   Copy the generated `database_id` into `backend/wrangler.toml`.
3. Apply database migrations to production:
   ```bash
   npx wrangler d1 migrations apply DB --remote
   ```
4. Set Gemini API Key secret:
   ```bash
   npx wrangler secret put GEMINI_API_KEY
   ```
5. Deploy Worker to edge:
   ```bash
   npx wrangler deploy
   ```

---

## 5. Building the Production Android App Bundle (AAB)

To generate the release bundle for Google Play Console:
```bash
cd app
flutter build appbundle --release
```
The output file will be generated at:  
`app/build/app/outputs/bundle/release/app-release.aab`
