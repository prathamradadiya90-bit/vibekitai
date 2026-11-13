# VibeKit AI — Secret & Credential Rotation Procedure

## 1. Overview & Policy
All production secrets must be rotated periodically and immediately upon suspicion of compromise.
- **Normal Rotation Cadence:** 90 days.
- **Emergency Rotation Window:** < 1 hour from reported incident.
- **Storage Location:** Cloudflare Workers Secrets (`wrangler secret put <NAME>`) and Google Cloud Secret Manager.
- **Prohibition:** Zero secrets in code, repositories, commit history, build scripts, or client APKs.

---

## 2. Secrets Inventory & Blast Radius

| Secret Key | Description | Storage | Rotation Impact & Downtime |
| :--- | :--- | :--- | :--- |
| `GEMINI_API_KEY` | Google AI Studio / Vertex AI primary inference | Cloudflare Secret | **Zero downtime.** Fallback provider automatically serves traffic during switch. |
| `GROQ_API_KEY` | Groq LPUs secondary fallback inference | Cloudflare Secret | **Zero downtime.** |
| `OPENAI_API_KEY` | OpenAI tertiary fallback inference | Cloudflare Secret | **Zero downtime.** |
| `ADMIN_SECRET` | Superadmin session token / admin API auth | Cloudflare Secret | Active admin sessions invalidated immediately; re-login required. |
| `SESSION_HMAC_SECRET` | Web Crypto HMAC-SHA256 session token minter | Cloudflare Secret | Active 15-minute app sessions expire; clients auto-refresh token. |
| `GOOGLE_SERVICE_ACCOUNT_KEY` | Play Integrity attestation & Developer API | Cloudflare Secret | Dual-key rotation supported in GCP console. |

---

## 3. Step-by-Step Rotation Playbooks

### 3.1 AI Provider API Keys (`GEMINI_API_KEY`, `GROQ_API_KEY`, `OPENAI_API_KEY`)
1. **Generate New Key:** Log into the provider developer console and create a new key with restricted billing permissions.
2. **Deploy to Staging:** Verify the new key in staging with `npx wrangler secret put GEMINI_API_KEY --env staging`.
3. **Deploy to Production:** Execute:
   ```bash
   npx wrangler secret put GEMINI_API_KEY
   ```
4. **Verify Traffic:** Monitor Cloudflare Workers analytics for HTTP 200 responses on `/v1/generations/reply`.
5. **Revoke Old Key:** After 15 minutes of stable production traffic, revoke the legacy key in the provider console.

### 3.2 Admin Secret (`ADMIN_SECRET`)
1. Generate high-entropy 256-bit secret:
   ```bash
   openssl rand -hex 32
   ```
2. Update Cloudflare Worker secret:
   ```bash
   npx wrangler secret put ADMIN_SECRET
   ```
3. Update team password manager (1Password / Bitwarden).
4. Verify admin login at `/admin`.

### 3.3 Google Cloud Service Account Key (`GOOGLE_SERVICE_ACCOUNT_KEY`)
1. In Google Cloud Console > IAM & Admin > Service Accounts > VibeKit Backend SA:
2. Select **Keys > Add Key > Create new key (JSON)**.
3. Compress and minify JSON into single-line format:
   ```bash
   cat key.json | jq -c . | wrangler secret put GOOGLE_SERVICE_ACCOUNT_KEY
   ```
4. Test Play Integrity attestation (`POST /v1/auth/attest`).
5. In GCP Console, delete the old service account key.

---

## 4. Emergency Revocation Checklist
In the event of an accidental leak (e.g. public repository alert):
1. [ ] **Kill the key immediately** in the upstream cloud provider dashboard.
2. [ ] Trigger Cloudflare Workers deployment with temporary empty/mock key to prevent credit abuse.
3. [ ] Check Cloudflare and AI provider billing usage logs for anomalies during the exposure window.
4. [ ] Mint and deploy fresh credentials following the above playbooks.
5. [ ] Conduct git commit history scrubbing using `git filter-repo` or BFG Repo-Cleaner if accidentally committed locally.
