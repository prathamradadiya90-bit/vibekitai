# VibeKit AI — AI Provider Setup Guide (Google Gemini)

**Target Provider:** Google Gemini Generative Language API  
**Recommended Production Model:** `gemini-1.5-flash` or `gemini-2.0-flash`  
**Security Mandate:** API key resides **strictly on the Cloudflare Workers backend** and is never compiled into client code or transmitted to the mobile app.

---

## 1. Obtaining a Gemini API Key

1. Navigate to Google AI Studio: [https://aistudio.google.com/](https://aistudio.google.com/)
2. Sign in with your Google account.
3. Click **Get API key** in the top navigation bar.
4. Select or create a Google Cloud Project (e.g. `vibekit-ai-prod`).
5. Generate the key and copy the string.

---

## 2. Configuring Secrets on Cloudflare Workers

### Local Development (`.dev.vars` / `.env`)
Inside `backend/`, copy `.env.example` to `.dev.vars` (Cloudflare Worker's local secret file):
```bash
GEMINI_API_KEY="AIzaSyYourGeminiApiKeyHere"
GEMINI_MODEL="gemini-1.5-flash"
ENVIRONMENT="development"
```

### Production Deployment via Wrangler
Run the following interactive command in your terminal:
```bash
cd backend
npx wrangler secret put GEMINI_API_KEY
# Enter your secret when prompted
```

---

## 3. Cost & Free-Tier Quota Details

| Tier | Rate Limits | Price | Data Handling Note |
| :--- | :--- | :--- | :--- |
| **Gemini 1.5 Flash (Free Tier)** | 15 Requests Per Minute (RPM), 1 Million Tokens/min, 1,500 Requests/day | **$0.00** | Google states prompts may be reviewed by human reviewers to improve products on free tier. |
| **Gemini 1.5 Flash (Paid / Pay-as-you-go)** | Up to 1,000 RPM | **$0.075 per 1M input tokens** / **$0.30 per 1M output tokens** | Prompts are NOT used to train Google models. |

*Cost for VibeKit AI:*  
An average reply generation uses ~150 input tokens and ~80 output tokens.  
10,000 generations cost approximately:
`10,000 * (150 * $0.000000075 + 80 * $0.00000030) ≈ $0.35 USD`  
This makes operating VibeKit AI extremely sustainable on Cloudflare + Gemini.
