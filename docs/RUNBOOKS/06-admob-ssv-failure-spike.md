# Runbook 06: Google AdMob SSV Signature Verification Spike

## 1. Alert Summary
- **Trigger Condition:** `/ads/ssv` returns HTTP 403 (signature verification failed) on > 10% of requests over 15 minutes.
- **SLO Impact:** Free users unable to claim rewarded credits (+3 credits) after watching video ads.
- **Severity:** P2 (High).

---

## 2. Immediate Symptoms
- Free tier users reporting rewarded credits not being credited after video ad completion.
- Edge logs show `AdMob SSV signature rejected for transaction ...`.

---

## 3. Diagnostic Steps
1. Verify Google public key fetch from Cloudflare Worker edge:
   ```bash
   curl -I "https://admob.googleapis.com/v1/publicKeys"
   ```
2. Check if Google rotated public keys and cached keys in `admob_ssv.ts` are stale.
3. Tail edge logs to inspect key IDs received in callbacks vs key IDs in cache:
   ```bash
   npx wrangler tail --format=json | jq 'select(.path=="/ads/ssv")'
   ```

---

## 4. Mitigation Actions
- **Flush Key Cache:**
  Deploy a worker restart or trigger key re-fetch by clearing in-memory variable `cachedKeys`.
- **Verify Alternative Key URL:**
  Check backup key URL `https://www.gstatic.com/admob/reward/verifier-keys.json`.
- **Temporary Dev Mode Override (Emergency Only):**
  If Google AdMob infrastructure is experiencing a verified key outage:
  Set `SKIP_SSV_VERIFY_FOR_DEV="true"` temporarily while monitoring nonce consumption to prevent unlimited credit grinding.

---

## 5. Verification
- Complete a test rewarded ad callback on a staging device.
- Verify that `verifyRewardedAd()` receives HTTP 200 with updated credit balance.
