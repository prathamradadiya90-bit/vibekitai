# Runbook 02: AI Provider Outage & Failover

## 1. Alert Summary
- **Trigger Condition:** Primary AI provider (Google Gemini) consecutive failure count > 5 or p95 inference latency > 8000ms.
- **SLO Impact:** Breaches generation latency target (p95 < 2500ms) and generation success target (> 98%).
- **Severity:** P2 (High).

---

## 2. Immediate Symptoms
- Logs show `Primary AI provider failure #N: Primary rate limit 429` or `AbortError: The operation was aborted`.
- Generation response times degrade past 15-second client timeouts.

---

## 3. Diagnostic Steps
1. Run direct health test against Gemini endpoint:
   ```bash
   curl -X POST "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$GEMINI_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{"contents":[{"parts":[{"text":"ping"}]}]}'
   ```
2. Verify if automatic fallback chain in `FallbackChainAIProvider` switched to Groq / OpenAI.
3. Check if provider rate limits or billing quota exceeded on Google Cloud console.

---

## 4. Mitigation Actions
- **Forced Primary Provider Switch:**
  Update remote config via Admin Panel or Cloudflare environment variable:
  ```bash
  # In Admin Panel > Kill Switches > Set 'primary_provider_override' to 'groq' or 'openai'
  ```
- **If Upstream Billing Cap Tripped:**
  Log into Google Cloud Console > Billing > Increase monthly budget alert thresholds.
- **If Complete Upstream Regional Outage:**
  The Flutter app gracefully activates local card rendering and displays cached creations from `LocalDatabase`.

---

## 5. Verification & Resolution
- Confirm requests routed to fallback provider return HTTP 200 within < 1200ms.
- Once Gemini status returns to Normal, deactivate the manual override in Admin Panel.
