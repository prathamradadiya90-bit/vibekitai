# Free AI API Key Providers Guide — VibeKit AI

This guide lists the top websites and platforms offering **100% free AI API keys** with no credit card required, along with their rate limits, available models, and instructions for connecting them to VibeKit AI.

---

## Quick Comparison Table

| Provider | Website | Free Tier Allowance | Top Free Models | Credit Card Required? | VibeKit Compatibility |
| :--- | :--- | :--- | :--- | :---: | :---: |
| **Google AI Studio** | [aistudio.google.com](https://aistudio.google.com/) | 1,500 requests/day, 15 RPM | `gemini-1.5-flash`, `gemini-2.0-flash` | **No** | Native Default |
| **Groq Cloud** | [console.groq.com](https://console.groq.com/) | 14,400 requests/day, 30 RPM (Ultra-fast 300+ tok/s) | `llama-3.3-70b-versatile`, `llama-3.1-8b-instant`, `mixtral-8x7b-32768` | **No** | Full Native Support |
| **OpenRouter** | [openrouter.ai](https://openrouter.ai/) | Free access to all `:free` models | `meta-llama/llama-3.3-70b-instruct:free`, `deepseek/deepseek-r1:free`, `google/gemini-2.0-flash-exp:free` | **No** | Full Native Support |
| **GitHub Models** | [github.com/marketplace/models](https://github.com/marketplace/models) | 150 requests/day (15 RPM) | `gpt-4o-mini`, `gpt-4o`, `meta-llama-3.3-70b-instruct` | **No** | Azure / OpenAI Compatible |
| **Together AI** | [api.together.ai](https://api.together.ai/) | $5.00 free starting credit (~5M tokens) | `meta-llama/Llama-3-70b-chat-hf`, `mistralai/Mixtral-8x7B` | **No** | OpenAI Compatible |
| **Mistral AI** | [console.mistral.ai](https://console.mistral.ai/) | Free Experimentation tier | `mistral-small-latest`, `codestral` | **No** | OpenAI Compatible |
| **Cloudflare Workers AI** | [dash.cloudflare.com](https://dash.cloudflare.com/) | 10,000 Neurons/day free forever | `@cf/meta/llama-3.3-70b-instruct` | **No** | Built-in Edge Support |

---

## 1. Google AI Studio (Recommended for VibeKit AI)
Google AI Studio is the default and recommended engine for VibeKit AI.

### How to Get Your Free Key:
1. Visit **[https://aistudio.google.com/](https://aistudio.google.com/)**.
2. Sign in with any standard Google account.
3. Click **"Get API key"** in the top-left sidebar.
4. Click **"Create API key in new project"**.
5. Copy your generated key (starts with `AIzaSy...`).

### How to use in VibeKit AI:
Add to `backend/.dev.vars`:
```env
GEMINI_API_KEY="AIzaSyYourGeneratedGeminiKey"
```

---

## 2. Groq Cloud (Fastest Inference in the Industry)
Groq uses custom LPU (Language Processing Unit) hardware that generates replies at speeds over 300 tokens per second.

### How to Get Your Free Key:
1. Visit **[https://console.groq.com/](https://console.groq.com/)**.
2. Sign in with GitHub or Google.
3. In the left menu, click **"API Keys"**.
4. Click **"Create API Key"**, give it a name like `vibekit`, and copy the key (starts with `gsk_...`).

### How to use in VibeKit AI:
Add to `backend/.dev.vars`:
```env
GROQ_API_KEY="gsk_YourGeneratedGroqKey"
AI_MODEL="llama-3.3-70b-versatile"
```

---

## 3. OpenRouter (Access to 20+ Free Models in One Key)
OpenRouter provides an aggregator API with many high-performing models that are 100% free.

### How to Get Your Free Key:
1. Visit **[https://openrouter.ai/](https://openrouter.ai/)**.
2. Sign in with your Google or GitHub account.
3. Go to **Settings -> Keys** ([openrouter.ai/keys](https://openrouter.ai/keys)).
4. Click **"Create Key"** and copy the key (starts with `sk-or-...`).

### How to use in VibeKit AI:
Add to `backend/.dev.vars`:
```env
OPENROUTER_API_KEY="sk-or-v1-YourOpenRouterKey"
AI_MODEL="meta-llama/llama-3.3-70b-instruct:free"
```
*Other free models you can use with OpenRouter:*
- `deepseek/deepseek-r1:free`
- `google/gemini-2.0-flash-exp:free`
- `mistralai/mistral-7b-instruct:free`

---

## 4. GitHub Models (Free GPT-4o & Llama for Developers)
GitHub allows every developer with a GitHub account to run OpenAI GPT-4o, GPT-4o-mini, and Llama 3 for free.

### How to Get Your Free Key:
1. Go to **[https://github.com/marketplace/models](https://github.com/marketplace/models)**.
2. Pick any model (e.g. `gpt-4o-mini`).
3. Click **"Get API key"** / create a GitHub Personal Access Token (PAT) with `read` permissions.

### How to use in VibeKit AI:
Add to `backend/.dev.vars`:
```env
AI_PROVIDER="custom"
AI_BASE_URL="https://models.inference.ai.azure.com"
AI_API_KEY="ghp_YourGitHubToken"
AI_MODEL="gpt-4o-mini"
```

---

## 5. Together AI ($5.00 Free Starting Credit)
Together AI gives you $5 of free credit upon sign-up, which covers roughly 5,000,000 tokens of generation.

### How to Get Your Free Key:
1. Visit **[https://api.together.ai/](https://api.together.ai/)**.
2. Sign up with Google/GitHub.
3. Go to **Settings -> API Keys** and copy your key.

### How to use in VibeKit AI:
Add to `backend/.dev.vars`:
```env
AI_PROVIDER="custom"
AI_BASE_URL="https://api.together.xyz/v1"
AI_API_KEY="your-together-key"
AI_MODEL="meta-llama/Llama-3-70b-chat-hf"
```

---

## Production Deployment (Cloudflare Workers)

When you deploy VibeKit AI to production on Cloudflare Workers, add your chosen key as an encrypted secret using the Wrangler CLI:

```powershell
# For Gemini
npx wrangler secret put GEMINI_API_KEY

# OR for Groq
npx wrangler secret put GROQ_API_KEY

# OR for OpenRouter
npx wrangler secret put OPENROUTER_API_KEY
```
