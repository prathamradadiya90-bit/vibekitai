# VibeKit AI — Backend Edge API

Cloudflare Workers Edge API with Cloudflare D1 distributed SQLite database, powering quota management, Google Gemini AI inference, and Google Play Billing verification for VibeKit AI.

---

## Tech Stack & Architecture

- **Runtime:** Cloudflare Workers (Edge V8 isolate)
- **Framework:** [Hono](https://hono.dev/) `^4.6.17`
- **Validation:** [Zod](https://zod.dev/) `^3.24.1`
- **Database:** Cloudflare D1 (Distributed SQLite)
- **AI Inference:** Google Gemini 1.5/2.0 Flash (`@google/genai` compatible REST API) & Groq fallback
- **Testing:** Vitest (`17/17 tests passing`)

---

## API Endpoints

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/v1/health` | Edge health status & version |
| `GET` | `/v1/config` | Feature flags, model ID & pricing metadata |
| `GET` | `/v1/usage` | Daily quota, reward allowance & Pro state |
| `POST` | `/v1/generations/reply` | Context-aware reply generator (3 variations) |
| `POST` | `/v1/generations/caption` | Caption, hooks, CTAs, and hashtags generator |
| `POST` | `/v1/purchases/verify` | Google Play Billing purchase verification |
| `GET` | `/v1/subscription/status` | Current Pro entitlement and remaining balance |
| `POST` | `/v1/ads/verify-reward` | AdMob rewarded ad verification (+3 credits) |
| `POST` | `/v1/feedback` | User feedback collection |
| `POST` | `/v1/privacy/delete-data` | GDPR/Play Store right-to-be-forgotten data purge |

---

## Local Development

```powershell
# Install dependencies
npm install

# Run static typecheck
npm run typecheck

# Run automated integration tests (Vitest)
npm test

# Start local edge dev server (http://127.0.0.1:8787)
npm run dev
```

---

## Deployment to Cloudflare Workers

1. Create a production D1 database:
   ```powershell
   npx wrangler d1 create vibekit-prod
   ```
2. Update `database_id` in `wrangler.toml` with the generated UUID.
3. Apply schema migrations:
   ```powershell
   npx wrangler d1 migrations apply vibekit-prod --remote
   ```
4. Configure required secrets:
   ```powershell
   npx wrangler secret put GEMINI_API_KEY
   ```
5. Deploy:
   ```powershell
   npm run deploy
   ```
