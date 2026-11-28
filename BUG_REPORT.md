# ReplyVibe AI (VibeKit AI) — Comprehensive Bug Audit Report

**Audit Date:** 2026-11-27  
**Scope:** Backend (`backend/src/*`, `backend/migrations/*`, `backend/wrangler.toml`) & Flutter App (`app/lib/*`, `app/android/app/*`)  
**Verification Basis:** Every bug below was directly verified by inspecting source files, schemas, SQL migrations, and client/backend contracts.

---

## Summary by Severity

| Severity | Count | Key Risk Areas |
| :--- | :---: | :--- |
| **Critical** | 9 | Pro credit lockout (`cycle_start <= T0` race, ignored credit packs, `canGenerate` / `setPro` / `syncCredits`), auth bypasses (unsigned admin JWT, unused session tokens, fail-open Play Integrity, per-instance rate limiter), `wrangler.toml` dev defaults |
| **High** | 21 | Ban self-removal via `ON DELETE CASCADE`, unguarded root `/privacy/delete-data`, Lifetime Pro expiry overwrite, AdMob SSV & Web fake-credit desync, Streak XP/freeze exploits, referral/RTDN gaps, Demo UI DOM XSS, SSRF redirects, Challenge cache cross-user leak, Billing/AdMob/`autoDispose` lifecycle bugs |
| **Medium** | 13 | Missing XP telemetry & ephemeral Achievement XP, report-button state mismatch, synchronous `setState` in `didUpdateWidget`, Android release fallback & ProGuard rules, AdMob/Banner lifecycle bugs, dark-mode contrast, backend stats/admin/cron/SSV/AI error handling |
| **Low** | 7 | `'CANCELED'` & midnight edge cases in `QuotaManager`, unclamped `X-Timezone-Offset` 500s, single-pass `<user_input>` sanitizer, `apiClient` URL normalization & `errorBuilder` navigation |
| **Total** | **50** | — |

---

## 1. Critical Bugs

### CRIT-01: First Pro Generation / New Cycle Fails with `429 QuotaExceededError` (Stale `nowIso` Race)
- **Location:** `backend/src/quota/quota_manager.ts` (`L178-L217`, `L235-L297`, `L660`)
- **Symbols:** `QuotaManager.reserveCredit`, `QuotaManager.ensureActiveProCycle`, `QuotaManager.activatePro`
- **Root Cause:**
  1. `reserveCredit` captures `const nowIso = new Date().toISOString()` (`T0`, `L237`) before awaiting a D1 query on `installations` (`L258-L261`).
  2. It then calls `ensureActiveProCycle` (`L266`), which captures a fresh timestamp (`T1`, `L183`), awaits a `SELECT` on `pro_cycle_usage` (`L185-L193`), and inserts the first cycle row with `cycle_start = T1` (`L201-L211`).
  3. Back in `reserveCredit` (`L274-L279`), the atomic `UPDATE pro_cycle_usage` checks `WHERE ... cycle_start <= ? AND cycle_end > ?` binding the stale `T0` (`L237`). Whenever `>= 1 ms` elapses during those D1 awaits (`T1 > T0`), `cycle_start <= T0` is `false`, `changes` is `0`, and `reserveCredit` returns `null`.
- **Impact:** A user who upgrades to Pro and immediately generates without calling `GET /v1/usage` first — or any Pro user hitting a fresh 30-day cycle — fails with `429 QuotaExceededError` despite having 200 unused Pro credits.
- **Recommended Fix:** Re-capture `const updateNow = new Date().toISOString()` after `ensureActiveProCycle` returns, or omit `cycle_start <= ?` and select by `id = ? AND credits_used < ?`.

### CRIT-02: Pro Users Cannot Spend Purchased Credit Packs, Referral Bonuses, Milestones, or Admin Grants
- **Location:** `backend/src/quota/quota_manager.ts` (`L219-L225`, `L265-L297`), `backend/src/routes/purchases.ts` (`L356-L364`)
- **Symbols:** `QuotaManager.reserveCredit`, `QuotaManager.hasAvailableCredits`, `purchasesRoute` (`/purchases/credit-pack`)
- **Root Cause:** Credit packs, referrals, streak milestones, and admin grants credit `daily_usage.rewarded_credits_earned`. When `isPro` is `true`, `reserveCredit` (`L265-L297`) only attempts deduction from `pro_cycle_usage` and immediately returns `null` at `L296` instead of falling through to `daily_usage.rewarded_credits_earned` (`L340-L361`). `hasAvailableCredits` (`L221-L223`) also checks only `pro_credits_remaining > 0`.
- **Impact:** A Pro user who exhausts their 200 monthly Pro credits and buys a 50-credit pack (or earns referral/milestone credits) still gets `429 QuotaExceededError` until Pro expires.
- **Recommended Fix:** When Pro cycle deduction returns `0` changes, fall through to Step 3 (`daily_usage.rewarded_credits_earned`), and include `rewarded_credits_remaining > 0` in `hasAvailableCredits` for Pro users.

### CRIT-03: Pro Upgrade UI Stays Locked at `PRO (0)`, and Exhausted Pro Users Bypass Client Checks to Hit Server 429s
- **Location:**
  - `app/lib/models/quota_model.dart` (`L72-L73`)
  - `app/lib/main.dart` (`L70-L73`)
  - `app/lib/core/providers/app_providers.dart` (`L205-L208`)
  - `app/lib/core/controllers/generation_controller.dart` (`L57-L66`)
  - `backend/src/quota/quota_manager.ts` (`L162-L171`, `L219-L225`)
- **Symbols:** `QuotaModel.canGenerate`, `QuotaNotifier.setPro`, `GenerationNotifier.execute`
- **Root Cause:**
  1. When a user with `0` credits completes a purchase, `billing.onProStatusChanged` (`main.dart:70-73`) only calls `quotaProvider.notifier.setPro(true)`, flipping `isPro = true` while leaving `proCreditsRemaining = 0` (`totalCreditsRemaining = 0`). `QuotaModel.canGenerate` evaluates `false`, locking the newly upgraded Pro user out of generating until a manual refresh.
  2. Conversely, when a Pro user spends all 200 Pro credits on the backend, `GET /v1/usage` still returns `free_credits_remaining: 3` and `total_credits_remaining >= 3` (`quota_manager.ts:165-171`). Because `QuotaModel.canGenerate` checks `totalCreditsRemaining > 0 || (isPro && proCreditsRemaining > 0)` (`quota_model.dart:72-73`), `canGenerate` stays `true`, causing every tap to hit the server and fail with `429`.
- **Recommended Fix:** Have `onProStatusChanged(true)` await `quotaProvider.notifier.refresh()`, and update `canGenerate` to mirror server semantics once credit-bucket behavior is aligned (`isPro ? (proCreditsRemaining > 0 || rewardedCreditsRemaining > 0) : totalCreditsRemaining > 0`).

### CRIT-04: `QuotaNotifier.syncCredits` Ignores Server Credit Increases & Corrupts Pro Credits on Fallback
- **Location:** `app/lib/core/providers/app_providers.dart` (`L57-L74`, `L97-L115`), `app/lib/core/network/api_client.dart` (`L226`, `L240-L249`, `L325-L328`, `L410-L413`), `app/lib/core/storage/preferences_service.dart` (`L103-L118`)
- **Symbols:** `QuotaNotifier.syncCredits`, `ApiClient._runGenerationWithFallback`, `ApiClient.verifyCreditPack`, `ApiClient.claimReferral`
- **Root Cause:**
  1. For free users, `syncCredits(remaining)` computes `newTotal = remaining < state.totalCreditsRemaining ? remaining : (state.totalCreditsRemaining - 1).clamp(0, 999)`. Whenever the server balance increased since the last local refresh (UTC midnight reset, referral, milestone, or credit pack), `remaining >= state.totalCreditsRemaining` triggers the stale decrement branch and drops the server balance.
  2. For Pro users, `_runGenerationWithFallback` stores `proCreditsRemaining` into `_prefs.setCachedCredits` (`L226`), `checkAndPerformDailyLocalReset` (`preferences_service.dart:113`) resets `_keyCredits` to `3 + rewarded` each day, and `verifyCreditPack` / `claimReferral` never update `_keyRewardedCredits` (so bonus credits are wiped at local midnight). Worse, if a Pro user hits an offline/5xx fallback while `_prefs.getCachedCredits()` holds `3`, `fallbackBuilder(2)` -> `syncCredits(2)` overwrites `proCreditsRemaining` to `2` in state.
- **Recommended Fix:** Trust the authoritative server `remaining` value in `syncCredits`, separate cached Pro vs free/rewarded balances in `PreferencesService`, and update `cachedRewardedCredits` on credit packs/referrals.

### CRIT-05: Admin Auth Never Verifies `Cf-Access-Jwt-Assertion` Signatures & Allows Missing `exp`
- **Location:** `backend/src/admin/auth.ts` (`L9-L26`, `L80-L108`), `backend/src/index.ts` (`L30-L37`, `L68`)
- **Symbols:** `parseJwtPayload`, `adminAuthMiddleware`
- **Root Cause:** `parseJwtPayload` splits on `.` and base64-decodes the JSON payload with zero cryptographic signature or JWKS verification (`CF_ACCESS_TEAM_NAME` is unused). Additionally, `isExpired` (`L87`) only triggers when `typeof payload?.['exp'] === 'number'`, so omitting `exp` treats the forged assertion as valid forever.
- **Impact:** On any deployment not guaranteed to sit exclusively behind Cloudflare Access header stripping (such as Vercel runtime `replyvibe-api.vercel.app` supported in `index.ts:30-37,68` or an exposed `workers.dev` route), an attacker can send an unsigned `Cf-Access-Jwt-Assertion` header with `aud` + an allowed admin email (without knowing any secret) and obtain full `admin` access to `/v1/admin/*`.
- **Recommended Fix:** Verify RS256 signatures against Cloudflare Access JWKS (`https://<CF_ACCESS_TEAM_NAME>.cloudflareaccess.com/cdn-cgi/access/certs`), require `iss` matching the team domain, and require numeric finite `exp` > `nowSec`.

### CRIT-06: `verifySessionToken` Is Dead Code & `anonymous_default` Allows Account/Quota Impersonation
- **Location:** `backend/src/security/session_tokens.ts` (`L66-L107`), `backend/src/middleware/installation.ts` (`L20-L26`, `L47-L73`), `backend/src/routes/referrals.ts` (`L101`)
- **Symbols:** `verifySessionToken`, `installationMiddleware`
- **Root Cause:** `verifySessionToken` is never imported or called anywhere in `backend/src/`. `installationMiddleware` trusts the client-supplied `X-App-Instance-Id` / `X-Installation-Id` directly without verifying `X-Session-Token`. Moreover, missing or non-alphanumeric headers fall back to a shared `'anonymous_default'` tenant (`installation.ts:26`).
- **Impact:**
  1. Anyone can forge arbitrary `X-App-Instance-Id` strings to spawn unlimited 3-credit/day accounts.
  2. Because a user's `installationId` is also shared publicly as their `referral_code` (`referrals.ts:101`), anyone with a user's referral link can impersonate `X-App-Instance-Id: <referral_code>` to drain that user's Pro credits or wipe their data via `POST /v1/privacy/delete-data`.
  3. Clients missing an instance ID share one `'anonymous_default'` quota/ban/Pro row.
- **Recommended Fix:** Separate public `referral_code` from `installationId`, reject missing/empty installation IDs with `401`, and verify `X-Session-Token` (matching `payload.sub === installationId`) in production on protected routes.

### CRIT-07: Play Integrity Verification Fails Open in Production & Reads Wrong JSON Field
- **Location:** `backend/src/security/play_integrity.ts` (`L24-L48`, `L70-L84`)
- **Symbols:** `verifyPlayIntegrityToken`
- **Root Cause:**
  1. When `env.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` is missing in `production`, `L32` only returns invalid if `!token && isCreditGrant && env.ENVIRONMENT === 'production'`. Passing **any** non-empty string for `token` falls through to `L35-L40` and returns `{ isValid: true, appLicensingVerdict: 'LICENSED', ... }`.
  2. When Play Integrity API *is* called, `L73` reads `tokenPayload.appLicensingVerdict?.licensingStatus` instead of Google's `tokenPayload.accountDetails?.appLicensingVerdict`, leaving `licensing` always `undefined`. Then `L80` sets `isValid: meetsBasic` without checking `appRecognitionVerdict === 'PLAY_RECOGNIZED'`, `appLicensingVerdict === 'LICENSED'`, or `requestDetails.requestPackageName`.
- **Impact:** Missing Play credentials allow fake-string integrity bypasses in production; with credentials set, unlicensed/cloned/repackaged builds still pass.
- **Recommended Fix:** Fail closed (`isValid: !isCreditGrant` / `false`) whenever `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` is missing in `production`; fix `tokenPayload.accountDetails?.appLicensingVerdict` parsing and enforce `appRecognitionVerdict` + package name + timestamp checks.

### CRIT-08: Rate Limiter Bypassable via Rotating `X-App-Instance-Id` & Spoofable `CF-Connecting-IP`
- **Location:** `backend/src/middleware/rate_limit.ts` (`L22-L27`, `L42-L55`)
- **Symbols:** `rateLimiterMiddleware`
- **Root Cause:** The rate limit bucket key is `${installId}_${firstIp}_${isGeneration ? 'gen' : 'all'}_${windowStart}` (`L43`). Because there is no separate per-IP bucket, rotating `X-App-Instance-Id` creates a brand-new counter on every request. Additionally, on non-Cloudflare runtimes (e.g., Vercel), `CF-Connecting-IP` can be spoofed by the caller.
- **Impact:** A single attacker IP can send unlimited requests to `/v1/generations/*` and `/v1/admin/*` (including brute-forcing `ADMIN_SECRET`).
- **Recommended Fix:** Enforce an independent per-IP limit alongside the per-installation limit, and avoid trusting spoofable `CF-Connecting-IP` headers outside Cloudflare workers.

### CRIT-09: `backend/wrangler.toml` Uses Placeholder D1 ID & Defaults to `ENVIRONMENT = "development"`
- **Location:** `backend/wrangler.toml` (`L7`, `L17`), `backend/src/routes/auth.ts` (`L31`, `L36-L43`), `backend/src/routes/ads.ts` (`L43-L45`), `backend/src/routes/streak.ts` (`L295-L297`)
- **Root Cause:** `database_id = "vibekit-d1-placeholder-id"` is a placeholder, and `[vars]` sets `ENVIRONMENT = "development"` with no `[env.production]` override. With `ENVIRONMENT = "development"`, `/v1/auth/attest` skips Play Integrity & falls back to the hardcoded default session secret, `/v1/ads/ssv` permits localhost SSV key URLs, and `/v1/streak/earn-freeze` skips ad verification.
- **Impact:** Deploying via `wrangler.toml` fails real D1 binding or accidentally runs production APIs with dev security bypasses enabled.
- **Recommended Fix:** Configure real D1 IDs and add explicit `[env.production]` vars (`ENVIRONMENT = "production"`).

---

## 2. High Bugs

### HIGH-01: Banned Users Can Self-Unban via `/v1/privacy/delete-data` & Banning Unseen IDs Crashes with 500
- **Location:** `backend/migrations/0007_admin_panel.sql` (`L32-L38`), `backend/src/quota/quota_manager.ts` (`L719-L739`), `backend/src/middleware/installation.ts` (`L35-L45`), `backend/src/routes/admin.ts` (`L241-L260`), `backend/src/db/bans.repo.ts` (`L32-L47`)
- **Root Cause:** `bans` defines `FOREIGN KEY (installation_id) REFERENCES installations(id) ON DELETE CASCADE` (`0007` `L37`). Because `/v1/privacy/delete-data` is exempt from ban checks (`installation.ts:35`) and runs `DELETE FROM installations WHERE id = ?` (`quota_manager.ts:737`), cascading delete erases the ban row. Conversely, banning an ID not yet present in `installations` violates the FK and throws a `500` error.
- **Impact:** Any banned user can unban themselves via GDPR data deletion and reuse the same ID; admins get 500 errors banning unknown/purged IDs.
- **Recommended Fix:** Remove `ON DELETE CASCADE` (and/or remove the FK) on `bans.installation_id` so bans persist independently of `installations` deletion/presence.

### HIGH-02: Root-Mounted `/privacy/delete-data` Bypasses All `/v1/*` Security Middleware
- **Location:** `backend/src/index.ts` (`L54`, `L95-L101`, `L119`, `L123`)
- **Root Cause:** `privacyRoute` is mounted at both `/v1` (`L119`) and `/` (`L123`), while `bodyLimitMiddleware`, `installationMiddleware`, `structuredLoggerMiddleware`, and `rateLimiterMiddleware` apply only to `'/v1/*'`.
- **Impact:** Calling `POST /privacy/delete-data` skips body limits, rate limiting, ban checks, and logging, enabling unthrottled 15-statement D1 `batch` delete floods.
- **Recommended Fix:** Either remove the unversioned `/` mount or apply security middleware to `/privacy/*` (keeping only `/privacy-policy`, `/terms`, etc. public).

### HIGH-03: Timed Subscription Events Overwrite Lifetime Pro (`pro_expires_at = NULL`) and Deactivate Lifetime Access
- **Location:** `backend/src/quota/quota_manager.ts` (`L114-L128`, `L612-L622`, `L689-L694`)
- **Root Cause:** `activatePro` (`L617-L618`) unconditionally executes `pro_expires_at = excluded.pro_expires_at` and `handleSubscriptionLifecycleUpdate` (`L691`) sets `pro_expires_at = COALESCE(?, pro_expires_at)`. If a user has a Lifetime Pass (`pro_expires_at = NULL`) plus an older timed subscription whose restore/RTDN renewal arrives later, `installations.pro_expires_at` is overwritten with the timed expiry date. When that date passes, `getQuotaStatus` (`L115-L124`) disables `is_pro = 0` and marks all `'ACTIVE'` entitlements (including the lifetime row) `'EXPIRED'`.
- **Impact:** Lifetime Pro buyers with any historical timed subscription can lose Lifetime access.
- **Recommended Fix:** Never overwrite `pro_expires_at` with a non-null date when an active lifetime pass exists on `subscription_entitlements`, and filter out lifetime rows in `getQuotaStatus` expiration updates.

### HIGH-04: `ensureActiveProCycle` TOCTOU Race Causes `500` Primary-Key Collisions & Shadow Credit Cycles
- **Location:** `backend/src/quota/quota_manager.ts` (`L178-L217`)
- **Root Cause:** No `UNIQUE` constraint restricts a single active cycle per `installation_id`, and `ensureActiveProCycle` uses non-atomic `SELECT` (`L185-L193`) -> `INSERT` with `id = pcu_${installationId}_${Date.now()}` (`L203-L211`). Parallel requests in the same millisecond fail with D1 `UNIQUE constraint failed` (`500`); requests 1ms apart insert two active rows, allowing usage bypass via `ORDER BY cycle_end DESC LIMIT 1`.
- **Impact:** Concurrent first-cycle Pro requests throw `500` errors or split/reset Pro quota tracking.
- **Recommended Fix:** Use deterministic cycle window keys (`ON CONFLICT DO NOTHING` + re-`SELECT`) keyed by cycle start window or serialize active cycle creation via unique constraint.

### HIGH-05: AdMob SSV Race Consumes Nonces on Cap Failure, Returns False `verified: true`, & Allows Dev Double-Credit
- **Location:** `backend/src/quota/quota_manager.ts` (`L517-L587`), `backend/src/routes/ads.ts` (`L66-L79`, `L107-L170`)
- **Root Cause:**
  1. `recordSsvReward` consumes `ad_nonces` (`L535-L547`) and inserts `admob_ssv_transactions` (`L560-L566`) **before** enforcing the capped `daily_usage` increment (`L569-L584`). Under concurrency, losing callbacks consume nonces and persist `transaction_id`, returning `DAILY_REWARD_LIMIT_REACHED`, after which `POST /v1/ads/verify-reward` (`ads.ts:154-169`) still sees the recorded row and returns `{ verified: true }` even though 0 credits were added.
  2. Concurrent duplicate `transaction_id` SSV callbacks pass `L518` simultaneously and crash on PK insert (`500`) instead of `200 OK: Duplicate transaction ignored`.
  3. If `MAX_DAILY_REWARDS=0`, the `INSERT INTO daily_usage ... VALUES (..., 1)` path ignores the `ON CONFLICT ... WHERE` cap check and grants 1 reward.
  4. In `ads.ts`: `POST /ads/verify-reward` ignores `!bodyResult.success` (`L109`), production omits `credits_added` (`L164-L169` vs dev `L143`), dev mode uses random `transactionId` on every request without `UNIQUE(reward_id)` (allowing double-credits with the same `reward_id`), and `GET /ads/ssv` (`L68-L73`) throws `TypeError` (500) on `custom_data="null"`.
- **Recommended Fix:** Run cap check + nonce consumption + SSV transaction insert atomically inside D1 `batch` or insert SSV transaction only when credit grant succeeds (`INSERT OR IGNORE`), validate `bodyResult.success`, guard `parsed && typeof parsed === 'object'`, and make `reward_id` unique/idempotent in dev mode.

### HIGH-06: Production Flutter Web Rewarded-Ad Mock Grants Fake Credits That Fail Generation with `429`
- **Location:** `app/lib/core/services/admob_service.dart` (`L158-L164`), `app/lib/core/providers/app_providers.dart` (`L190-L202`), `app/lib/features/home/home_screen.dart` (`L216-L233`)
- **Root Cause:** On Web (`kIsWeb`), `showRewardedAd` simulates an ad after 600ms and calls `onRewardEarned`. Because no real AdMob SSV callback occurs, `grantRewardCredit` polls `/v1/ads/verify-reward` 4 times (`verified: false` in prod) and then hits `if ((AppConfig.isDev || kIsWeb) && state.canWatchRewardedAd)` (`app_providers.dart:191`), adding `+3` local-only credits even in Web **release** builds.
- **Impact:** Web users see `+3 Bonus AI Credits unlocked!` locally while server credits stay `0`, failing immediately with `429 QUOTA_EXCEEDED` when generating.
- **Recommended Fix:** Gate simulated ad rewards strictly on `AppConfig.isDev` (never `!AppConfig.isDev && kIsWeb`), and hide or disable rewarded-ad credit CTAs on unsupported web production builds.

### HIGH-07: `ApiClient.getUsage()` Swallows Errors & Fabricates `200` Pro Credits and `0` Ads Watched
- **Location:** `app/lib/core/network/api_client.dart` (`L188-L213`), `app/lib/core/providers/app_providers.dart` (`L76-L95`)
- **Root Cause:** `getUsage()` catches all network/server errors (`L196-L212`) and returns a synthesized `QuotaModel` hardcoding `proCreditsRemaining: _prefs.getCachedIsPro() ? 200 : 0` and `rewardedAdsWatchedToday: 0` instead of rethrowing. As a result, `QuotaNotifier.refresh()`'s `catch (_)` (`L92-L94`) is unreachable and `state = quota` overwrites in-memory usage.
- **Impact:** Pulling to refresh while offline resets Pro balance display to `200` and resets `rewardedAdsWatchedToday` back to `0/2`.
- **Recommended Fix:** Let `getUsage()` propagate transient errors so `QuotaNotifier.refresh()` keeps live state, or restore real cached `proCreditsRemaining` and `rewardedAdsWatchedToday`.

### HIGH-08: Streak & XP Exploits (`utc_offset_minutes` Farming & Unlimited Freezes per Ad)
- **Location:** `backend/src/routes/streak.ts` (`L111-L185`, `L287-L331`)
- **Symbols:** `handleCheckin`, `streakRoute` (`/streak/earn-freeze`)
- **Root Cause:**
  1. `POST /v1/streak/checkin` trusts client-supplied `utc_offset_minutes` (`-840..840`). Checking in once with `+840` sets `last_checkin_date` to tomorrow (`UTC+14`), then calling again with `-720` yields `todayLocal < last_checkin_date` (`diff < 0` at `L155`). The once-per-day XP guard at `L140-L148` only runs when `last_checkin_date === todayLocal`, so `effectiveXp` is awarded on **every single call**. Alternately switching `+840` and `-720` across UTC midnight also inflates `current_streak`.
  2. `POST /v1/streak/earn-freeze` (`L297`) only checks `quota.rewarded_ads_watched_today === 0` and never tracks whether an ad watch was already redeemed for a freeze; 1 rewarded ad enables claiming freezes up to the cap (`2`, or higher concurrently since freeze updates lack a SQL `< 2` guard).
- **Recommended Fix:** Query `xp_events` across an authoritative 24h/server window regardless of `diff < 0` (set `effectiveXp = 0` when `diff < 0` or `last_checkin_date >= todayLocal`), store timezone offset/last-freeze-ad count atomically, and enforce `WHERE freeze_count < 2` in SQL.

### HIGH-09: Referrals Skip Play Integrity When `integrity_token` Is Omitted & Lack Atomic Cap Guard
- **Location:** `backend/src/routes/referrals.ts` (`L30-L68`)
- **Root Cause:** `if (integrity_token)` (`L30`) skips `verifyPlayIntegrityToken` entirely whenever the optional `integrity_token` field is omitted, even in `production`. Additionally, `getRewardedReferralsCount()` -> `recordReferralAndAwardCredits()` (`L62-L68`) has no SQL `< 10` check, and concurrent duplicate claims from the same `referredInstallationId` crash on `UNIQUE` instead of returning `409`.
- **Impact:** Attackers can claim referral credits in production without Play Integrity attestation and bypass the 10-referral limit under concurrency.
- **Recommended Fix:** Require and verify `integrity_token` in `production`, and enforce the 10-referral cap + duplicate rejection atomically in SQL (`INSERT ... SELECT ... WHERE count < 10` / `ON CONFLICT`).

### HIGH-10: RTDN Ignores Voided Credit Packs & Concurrent Credit-Pack Calls Throw `500`
- **Location:** `backend/src/routes/purchases.ts` (`L217-L254`, `L344-L364`)
- **Root Cause:**
  1. `voidedPurchaseNotification` (`L217-L254`) only checks `subscription_entitlements` (`L221`), returning `UNKNOWN_TOKEN` for refunded/charged-back consumable `credit_pack_purchases` while leaving granted credits untouched.
  2. `isCreditPackProcessed()` (`L345`) -> `recordCreditPackAndGrantCredits()` (`L357`) is non-atomic; concurrent duplicate requests both pass `L345` and the second crashes on PK/`purchase_token` uniqueness (`500`) instead of returning `{ already_processed: true }`.
- **Impact:** Chargebacks/refunds on credit packs do not revoke credits; concurrent client retries fail with HTTP `500`.
- **Recommended Fix:** Look up `credit_pack_purchases` on `voidedPurchaseNotification` and claw back/mark revoked; catch unique-constraint conflict on `credit_pack_purchases` insert to return idempotent `200`.

### HIGH-11: Google Play `:acknowledge` Failure Is Ignored & OAuth Token Cache Sticks on `401`
- **Location:** `backend/src/security/google_play.ts` (`L63`, `L89-L130`, `L144-L147`, `L210-L217`, `L265-L272`)
- **Root Cause:**
  1. When Play Developer API `:acknowledge` fails (`!ack.ok`), `L216` and `L271` only `console.warn` and still return `{ ok: true, entitled: true }` / `{ ok: true, purchased: true }`. If client acknowledgement also fails within 3 days, Google auto-refunds the purchase while D1 retains Pro/Lifetime status.
  2. `cachedToken` (`L63`) is a global singleton not keyed by credentials and never invalidated on HTTP `401` responses from `playApi`, trapping verification in `401` errors for up to 59 minutes.
- **Impact:** Risk of unacknowledged auto-refunded free Pro/Lifetime passes and sticky OAuth token failures.
- **Recommended Fix:** Return a retryable failure (`503`) if server acknowledgement fails, and invalidate `cachedToken` whenever `playApi` returns `401`.

### HIGH-12: DOM XSS & Broken Action Buttons (`escapeJs` / Raw `err.message`) in Web Demo UI
- **Location:** `backend/src/web/demo_ui.ts` (`L488-L497`, `L533-L542`, `L584-L593`, `L628-L630`), `backend/src/index.ts` (`L47-L48`)
- **Symbols:** `escapeJs`, `generateReplies`, `generateCaptions`, `runVibeCheck`
- **Root Cause:** `escapeJs` (`L628-L630`) is interpolated inside HTML attributes (`onclick="sendToCard('${escapeJs(s)}')"`) without escaping `&`, `\n`, `\r`, `\u2028`, or `\u2029`. HTML entities such as `&#39;` pass `escapeJs`, get decoded by the browser HTML parser before JS parsing, and break out of the JS string literal (executable under CSP `'unsafe-inline'`, `index.ts:48`). Real newlines in LLM output cause `SyntaxError` and break buttons. Catch blocks (`L497`, `L542`, `L593`) also insert unescaped `err.message` into `innerHTML`.
- **Recommended Fix:** Replace inline `onclick` string interpolation with `data-*` attributes + `addEventListener` delegators using `.textContent`, and escape `err.message` via `escapeHtml`.

### HIGH-13: SSRF Redirect Bypass in `safeFetch` & Missing Allowlisted Provider Hosts
- **Location:** `backend/src/security/safe_fetch.ts` (`L6-L31`, `L83-L90`)
- **Root Cause:** `safeFetch` validates only the initial URL and delegates to `fetch()` with default `redirect: 'follow'`, so an allowlisted/dev host returning a `302` redirect bypasses `validateOutboundUrl` to reach internal/metadata URLs. `BLOCKED_IP_PATTERNS` also misses IPv6 `fd00::/8`, `[::]`, and `[::ffff:...]`, while `ALLOWED_HOSTS` omits documented provider hosts (`api.together.xyz`, `api.deepseek.com`, `api.mistral.ai`).
- **Recommended Fix:** Set `redirect: 'manual'` (or re-validate `Location` on redirects up to a strict hop cap), block remaining IPv6 private/mapped forms, and complete `ALLOWED_HOSTS`.

### HIGH-14: Body Size Limit (`16 KB`) Bypassable via Malformed/Spoofed `Content-Length`
- **Location:** `backend/src/middleware/body_limit.ts` (`L8-L30`)
- **Root Cause:** `L11` checks `if (contentLength && parseInt(contentLength, 10) > maxBytes)` and `L18` only reads/measures the body `if (!contentLength && ...)`. Sending a non-numeric `Content-Length` (e.g., `abc` -> `NaN`) or negative `Content-Length` skips **both** checks; sending a small `Content-Length` on a larger synthetic stream also bypasses `L18`. When omitted, `L20` buffers the entire stream in memory before failing.
- **Recommended Fix:** Parse `Content-Length` strictly (reject non-numeric/negative headers with `400`), always enforce stream/clone byte reading on `POST`/`PUT`/`PATCH` when length is suspect or read via bounded `ReadableStream` chunk counter.

### HIGH-15: Daily Challenge Cache Key Collisions & Cross-User Private Output Leakage
- **Location:** `backend/src/ai/challenge_cache.ts` (`L7-L68`), `backend/src/ai/pipeline.ts` (`L62-L98`, `L152-L162`)
- **Root Cause:**
  1. Cache key `` `challenge_${challengeId}_${tone.toLowerCase()}_${language.toLowerCase()}` `` omits `category`, `length`, `count`, `platform`, `include_hooks`, and `include_hashtags`, colliding on `cache_key` PK and serving wrong shapes/options.
  2. Neither `challenge_cache.ts` nor `pipeline.ts` validates `challenge_id` against known public challenges or includes prompt text in the key: any user can submit a private prompt with `challenge_id: "c1"` and have subsequent users requesting `"c1"` receive the first user's output.
- **Recommended Fix:** Include `category` and all output-shaping parameters (or prompt hash) in `cacheKey`, and validate `challenge_id` against an allowlist of official challenge IDs.

### HIGH-16: `StudioScreen` Hardcodes `maxLength: 500`, Breaking Bio (`300`) & Caption (`400`) Backend Validation
- **Location:** `app/lib/features/studio/studio_screen.dart` (`L605`, `L640`), `backend/src/schemas/validation.ts` (`L36`, `L82`, `L99`)
- **Root Cause:** `StudioScreen` uses `maxLength: 500` (`.../500`) across all 4 tabs, while `BioRequestSchema.interests` enforces max `300`, `CaptionRequestSchema.topic` enforces max `400`, and `VibeCheckRequestSchema.text` allows `600`.
- **Impact:** Entering 301–500 chars on Bio Lab or 401–500 chars on Captions in Studio fails with HTTP `400 VALIDATION_ERROR`.
- **Recommended Fix:** Derive `maxLength` dynamically from `_activeTab` (`reply: 500`, `caption: 400`, `bio: 300`, `vibeCheck: 600`).

### HIGH-17: Billing Callbacks Unwired, HTTP `402` Fails to Revoke Pro, & Settings URL Change Orphans `BillingService`
- **Location:** `app/lib/main.dart` (`L68-L76`), `app/lib/core/services/billing_service.dart` (`L26-L29`, `L120`, `L153-L168`, `L193-L216`, `L228-L238`), `app/lib/core/providers/app_providers.dart` (`L35-L38`), `app/lib/features/settings/settings_screen.dart` (`L414`, `L425`, `L448`)
- **Root Cause:**
  1. `onBillingMessage` and `onSubscriptionStateChanged` are never assigned anywhere, silently dropping pending/error/credit-pack feedback.
  2. In `_settleEntitlement` (`billing_service.dart:195-215`), `/v1/purchases/verify` HTTP `402` (`is_verified: false`) throws `ApiException(statusCode: 402)` into the `catch` block (`L212`), skipping `else` (`L205-L210`) so `_subscriptionState` stays unreset and `onProStatusChanged(false)` never fires.
  3. `billingServiceProvider` watches `apiClientProvider` (`app_providers.dart:35-38`). Calling `ref.invalidate(apiClientProvider)` in `SettingsScreen` disposes the active `BillingService` and instantiates a new uninitialized one without calling `init()` or rebinding callbacks.
- **Recommended Fix:** Revoke Pro / set `SubscriptionState.inactive` on HTTP `402` in `_settleEntitlement`, decouple `BillingService` lifecycle from `apiClientProvider` invalidation, and wire UI feedback for `onBillingMessage`.

### HIGH-18: `.autoDispose` `GenerationNotifier` & `StreakNotifier.claimMilestone` Crash After Widget Disposal
- **Location:** `app/lib/core/controllers/generation_controller.dart` (`L76-L116`), `app/lib/core/providers/app_providers.dart` (`L275-L297`), `app/lib/features/streaks/providers/streak_provider.dart` (`L48-L62`)
- **Root Cause:** All 4 generation providers are `.autoDispose`; navigating away while `await caller()` or `await db.insertItem(item)` runs disposes the notifier and its `Ref`. Resuming without `if (!mounted)` checks throws `StateError` on `ref.read(...)` / `state = ...`. Similarly, `StreakNotifier.claimMilestone(day, WidgetRef ref)` (`streak_provider.dart:48-55`) calls `ref.read(...)` after `await` on a potentially disposed widget `WidgetRef`.
- **Recommended Fix:** Guard all post-`await` `ref.read` and `state = ...` calls with `if (!mounted) return false;`, and inject `Ref` (via provider) instead of `WidgetRef` into `StreakNotifier`.

### HIGH-19: `StreakScreen` `+1 Freeze` Skips Ad Flow & Fails Silently; Day 7/14 Unlocked Templates Stay Locked
- **Location:** `app/lib/features/streaks/presentation/streak_screen.dart` (`L238-L259`, `L285-L306`), `backend/src/routes/streak.ts` (`L297`), `app/lib/features/card_maker/card_maker_screen.dart` (`L681`, `L726`)
- **Root Cause:**
  1. Tapping `+1 Freeze` (`streak_screen.dart:249-256`) calls `earnFreeze()` without showing a rewarded ad. In production (`streak.ts:297`), `/v1/streak/earn-freeze` returns `400 AD_REQUIRED` if `rewarded_ads_watched_today == 0`; `earnFreeze()` swallows the error and returns `false` with zero user message.
  2. Streak Day 7 (`Aura Card Template`) and Day 14 (`Cyberpunk Template Pack`) claim to unlock card templates (`streak_screen.dart:290,301`), yet `CardMakerScreen` only checks `t.isProOnly && !isPro` (`L681`, `L726`), keeping them locked behind the paywall.
- **Recommended Fix:** Check/trigger a rewarded ad (or inform the user to watch one first) and surface failure feedback; pass `streakProvider.claimedMilestones` into template unlock checks in `CardMakerScreen`.

### HIGH-20: `ApiException.isQuotaExceeded` Conflates 1-Minute Rate Limits with Exhausted Daily Credits
- **Location:** `app/lib/core/network/api_exception.dart` (`L15`), `backend/src/middleware/rate_limit.ts` (`L57-L99`)
- **Root Cause:** `bool get isQuotaExceeded => code == 'QUOTA_EXCEEDED' || statusCode == 429;` treats rate-limiter `429` (`code: 'RATE_LIMIT_EXCEEDED'`) as exhausted credits.
- **Impact:** Pro users or credited free users who exceed 15 req/min are told `"Daily credits exhausted"` and routed to `/paywall`.
- **Recommended Fix:** Exclude `code == 'RATE_LIMIT_EXCEEDED'` from `isQuotaExceeded` (and handle rate limits with a dedicated cooldown message).

### HIGH-21: `CaptionResponse.callToActions` Returned by API Is Never Rendered in Any UI
- **Location:** `app/lib/features/caption_lab/caption_lab_screen.dart` (`L578-L650`), `app/lib/features/studio/studio_screen.dart` (`L1093-L1126`), `backend/src/web/demo_ui.ts` (`L526-L538`), `backend/src/schemas/validation.ts` (`L75`)
- **Root Cause:** Backend generates and returns `call_to_actions`, and `CaptionResponse.fromJson` parses `callToActions`, yet neither `CaptionLabScreen`, `StudioScreen` (`StudioTab.caption`), nor `demo_ui.ts` displays them.
- **Recommended Fix:** Render `callToActions` cards below captions/hooks across all caption views.

---

## 3. Medium Bugs

### MED-01: Challenges & Card Exports Fail to Sync XP/Streaks; Home Check-In Shows Unconditional Success
- **Location:** `app/lib/features/challenge/challenge_screen.dart` (`L43-L65`), `app/lib/features/home/home_screen.dart` (`L1344-L1358`), `app/lib/features/card_maker/card_maker_screen.dart` (`L225-L264`), `app/lib/features/streaks/providers/streak_provider.dart` (`L30-L46`)
- **Root Cause:**
  1. `ChallengeScreen._startChallenge` increments `challengesSolved` immediately on tap without calling `streakProvider.notifier.recordAction('challenge')`.
  2. `CardMakerScreen` export/save never calls `streakProvider.notifier.recordAction('card_export')` despite Streak UI/backend supporting `+15 XP` for `card_export`.
  3. `HomeScreen` `Check In (+10 XP)` (`L1348`) awaits `recordAction('checkin')` (which swallows all errors and returns `void`) and unconditionally shows the green `+10 XP awarded!` snackbar.

### MED-02: Achievement Bonus XP Is Ephemeral In-Memory & Lost on Refresh/Restart
- **Location:** `app/lib/core/services/achievement_service.dart` (`L139-L149`), `app/lib/features/streaks/providers/streak_provider.dart` (`L13-L24`)
- **Root Cause:** `checkAndUnlockAchievements` updates `streakProvider` only via `updateStreakLocally(...)` without persisting or syncing to the backend. Any subsequent `fetchStreak()` overwrites `totalXp` and `level` with server state.

### MED-03: `"Report AI Verdict"` Button Never Disables After Reporting in `VibeCheckScreen` & `StudioScreen`
- **Location:** `app/lib/features/vibe_check/vibe_check_screen.dart` (`L702-L718`), `app/lib/features/studio/studio_screen.dart` (`L1063-L1077`, `L1156-L1165`)
- **Root Cause:** `onPressed` passes `'${result.title}: ${result.verdict}'` to `_reportContent`, which stores that composite key in `_reportedContents`, while the button's enabled/label checks test `_reportedContents.contains(result.verdict)` (which never matches).

### MED-04: `StudioScreen.didUpdateWidget` Calls Synchronous `setState()` During Build
- **Location:** `app/lib/features/studio/studio_screen.dart` (`L205-L219`, `L227-L238`)
- **Root Cause:** Updating `initialTabId` triggers `_switchTab(...)` synchronously inside `didUpdateWidget`, calling `setState` during widget update instead of mutating state directly.

### MED-05: Streak Reminder Toggle Is Non-Persistent, Fires Immediately Instead of Daily, & Android-Only
- **Location:** `app/lib/features/streaks/presentation/streak_screen.dart` (`L341-L366`), `app/lib/core/services/notification_service.dart` (`L10-L65`)
- **Root Cause:** `notificationEnabledProvider` is an ephemeral `StateProvider<bool>((_) => true)` not persisted in `PreferencesService`; toggling only fires a one-time immediate notification (`_plugin.show`) with no daily schedule; `NotificationService.init()` is Android-only (`InitializationSettings(android: ...)`) and called unawaited in the provider.

### MED-06: `LocalDatabase` Wipes History on Web Reload & Has SQL `LIKE` / Duplicate Content Bugs
- **Location:** `app/lib/core/storage/local_database.dart` (`L13-L49`, `L84-L100`, `L124-L141`)
- **Root Cause:** `sqflite` is unsupported on Web (`init()` catches and falls back to volatile RAM `_fallbackMemoryStore` wiped on refresh); `getItems` omits `ESCAPE` on `LIKE` queries (so `%`/`_` match wildcards); `findItemByContent` matches only `LIMIT 1` by raw `content`.

### MED-07: Local Midnight vs Server UTC Midnight Quota Reset Mismatch & Unused `_keyRewardedAdsWatched`
- **Location:** `app/lib/core/storage/preferences_service.dart` (`L74`, `L77-L83`, `L103-L118`), `backend/src/quota/quota_manager.ts` (`L110-L164`)
- **Root Cause:** Client local credit reset uses `DateTime.now()` (local calendar day) whereas backend resets at `00:00 UTC`, leaving non-UTC users out of sync around midnight. `_keyRewardedAdsWatched` is written on daily reset (`preferences_service.dart:114`) and never read.

### MED-08: Android Release Build Silently Falls Back to Test AdMob App ID & Debug Signing
- **Location:** `app/android/app/build.gradle.kts` (`L35-L38`, `L57-L61`)
- **Root Cause:** If `-PadmobAppId` / `key.properties` lacks `admobAppId`, `manifestPlaceholders["admobAppId"]` falls back to Google's test App ID (`ca-app-pub-3940256099942544~3347511713`) even in `release` builds where `AppConfig` uses live production ad unit IDs; missing `key.properties` also silently signs `release` with the debug keystore.

### MED-09: `proguard-rules.pro` Keeps Wrong IAP Package & Omits AdMob UMP Consent Classes
- **Location:** `app/android/app/proguard-rules.pro` (`L18-L27`)
- **Root Cause:** Keeps `com.dooboolab.flutterinapppurchase.**` instead of `io.flutter.plugins.inapppurchase.**` (the package used by `in_app_purchase_android`), and omits `com.google.android.ump.**` used under R8 minification (`isMinifyEnabled = true`).

### MED-10: `AdMobService` Consent Race, Rewarded `show()` Mutex Deadlock, & Interstitial Double-Show Gap
- **Location:** `app/lib/core/services/admob_service.dart` (`L80-L101`, `L179-L232`, `L283-L337`, `L367-L377`)
- **Root Cause:** `_requestConsent()` returns before `requestConsentInfoUpdate` finishes (`Completer` missing), initializing `MobileAds` before UMP completes; `showRewardedAd()` sets `_isShowingRewardedAd = true` (`L179`) without `try/catch` around `await _rewardedAd!.show(...)` (`L223`), permanently locking out future rewarded ads if `show()` throws; `showInterstitialIfEligible` lacks an in-flight mutex; `updateProStatus(true)` calls `dispose()` without resetting `_isRewardedAdLoading` / `_isInterstitialLoading`.

### MED-11: `AdaptiveBannerWidget` Double-Disposes Failed Ads & Fails Pro->Free Reload
- **Location:** `app/lib/core/widgets/adaptive_banner_widget.dart` (`L60-L66`, `L74-L92`), `app/lib/core/services/admob_service.dart` (`L358-L362`)
- **Root Cause:** `AdMobService.createBannerAd` disposes the `BannerAd` inside `onAdFailedToLoad` (`admob_service.dart:360`), while `AdaptiveBannerWidget` keeps `_bannerAd` non-null (`L60-L66`), disposing the already-disposed instance again in `dispose()`/`ref.listen` and blocking reload on Pro->Free downgrade (`!next && _bannerAd == null`).

### MED-12: Dark Mode Contrast Failure (`AppTheme.darkTheme`) & `AppBottomNav` Navigation Trap / Overflow
- **Location:** `app/lib/core/theme/app_theme.dart` (`L17-L26`), `app/lib/core/widgets/app_bottom_nav.dart` (`L63-L117`)
- **Root Cause:**
  1. `darkTheme` configures `ColorScheme.dark(primary: AppColors.primary)` (dark espresso `#6B4226`) on `#140E0A`/`#1E140E` dark backgrounds with no custom `textButtonTheme`, producing low contrast (~2:1) on default `TextButton`s/controls.
  2. `AppBottomNav` skips `context.go(item.route)` when `index == currentIndex` (`L76`), preventing users on standalone legacy screens passing `currentIndex: 1` from tapping Studio to open `/studio`, and lacks `Expanded`/`Flexible` around items in `Row` (`L63-L117`).

### MED-13: Web Demo `'LinkedIn'` 400 Error, `'Chill'`/`'YouTube'`/`'TikTok'` Gaps, AI Provider Config & Parsing Bugs, & Admin/Stats Issues
- **Location & Verified Causes:**
  - **Prompt / Schema / Mock Mismatches (`backend/src/web/demo_ui.ts:353,371-375`, `backend/src/schemas/validation.ts:19,43-45`, `backend/src/ai/prompts.ts:51-86`):** Web Demo offers `'LinkedIn'` (absent from `CaptionRequestSchema` -> guaranteed HTTP `400`); `'Chill'` tone (valid in `ReplyRequestSchema` & Web Demo) is missing from `REPLY_TONES`; `'YouTube'` & `'TikTok'` are missing from `PLATFORM_GUIDES`; Web Demo `'Studio'` offers Bio/Caption without switching endpoints when Bio vs Caption is desired.
  - **AI Parsing & Provider Routing (`backend/src/ai/gemini.ts:140-150,204-263`, `backend/src/ai/openai_compatible.ts:106-116,146-204`, `backend/src/ai/factory.ts:54-106`, `backend/src/ai/pipeline.ts:108-148`):**
    - `vibeCheck` calls `t.startsWith('#')` without checking `typeof t === 'string'` (`gemini.ts:146`, `openai_compatible.ts:112`).
    - Fetch `AbortController` timer is cleared right after headers arrive (`gemini.ts:219`, `openai_compatible.ts:161`) before `response.json()` / `response.text()` finishes.
    - `gemini.ts` only checks `finishReason === 'SAFETY'` (missing `PROHIBITED_CONTENT`/`RECITATION`/`BLOCKLIST`) and only reads `parts?.[0]?.text`.
    - `factory.ts` (`L84-L102`) forwards `GEMINI_API_KEY`/`GEMINI_MODEL` to primary non-Gemini providers when `AI_API_KEY`/`AI_MODEL` are omitted, forwards `GROQ_API_KEY` to OpenRouter fallbacks, and ignores `OPENAI_API_KEY` / `!providerType` guards (`L67, L71`).
    - Upstream provider HTTP bodies (`errText`) propagate directly into `ProviderError` (`pipeline.ts:147`), and the `'system prompt'` leak guard logs status `'failed'` instead of `'safety_rejected'` (`L108-L141`).
  - **AdMob SSV Key Cache (`backend/src/security/admob_ssv.ts:8-37, 94-116`):** Caches `data.keys || []` for 24h without cache invalidation on key rotation (when `matchedKey` is missing) and sets `messageToVerify = ''` if `signature=` appears at the start of the query string.
  - **Stats, Cron, Admin, & Feedback Status (`backend/src/db/stats.repo.ts:58-74,301-333`, `backend/src/cron/nightly_stats.ts:21-23`, `backend/src/routes/admin.ts:277-300`, `backend/src/admin/ui.ts:709-750`, `backend/migrations/0007_admin_panel.sql:61`):** `daily_stats` upsert omits `wau`/`mau`/`p95_latency_ms`; cron aggregates stats *before* `reconcileEntitlementsNightly`; `POST /v1/admin/installations/:id/resync` performs a read-only `SELECT` without calling Google Play; Admin Config UI skips populating `#cfgMaintenanceMode` and drops `0` values (`if (data.current.daily_free_credits)`); `feedback_records.status` defaults to `'OPEN'` (uppercase) in SQL while code inserts `'open'` / `'resolved'` (lowercase).
  - **Admin Auth Config & Cookie Splitting (`backend/src/admin/auth.ts:49-51, 118-119, 135`):** `resolveRole` maps any unrecognized/whitespace role after `:` (e.g. `"a@b.com: viewer"`) to `'admin'`; cookie/token `split('=')` and `split(':')` truncate secrets containing `=` or `:`.

---

## 4. Low Bugs

### LOW-01: `QuotaManager` Lifecycle, Refund Midnight Drop, `MAX_DAILY_FREE_CREDITS=0`, & Multi-Date Rewarded Race
- **Location:** `backend/src/quota/quota_manager.ts` (`L114-L128`, `L300-L430`, `L648-L659`, `L695-L714`, `L741-L775`)
- **Root Cause:**
  1. `reconcileEntitlementsNightly` only selects `('ACTIVE', 'IN_GRACE_PERIOD')` (leaving `'CANCELED'` un-expired) and overwrites `expires_at` with `nowIso` (`L768`).
  2. `refundCredit` (`L370`) recalculates `today` at refund time, failing to refund a credit reserved before `00:00 UTC` if upstream fails after midnight.
  3. If `maxDailyFree <= 0`, `reserveCredit` (`L314-L324`) still executes the `INSERT ... free_credits_used = 1` fallback once per day.
  4. When rewarded credits span multiple `usage_date` rows, `ORDER BY usage_date ASC LIMIT 1` (`L343`) causes concurrent deduction on only the oldest row and spurious `429` if exhausted.

### LOW-02: Unclamped `X-Timezone-Offset` DoS (`500`), Hardcoded `isPro=false` on Check-In, & Swallowed Milestone Errors
- **Location:** `backend/src/routes/streak.ts` (`L21-L25`, `L40-L42`, `L132`, `L273-L283`)
- **Root Cause:** Huge integer `X-Timezone-Offset` headers produce `Invalid Date` in `getLocalDateString` (`RangeError` `500`); `handleCheckin` (`L132`) passes `false` to `getOrCreateStreak`, missing initial freeze for Pro users; `claim-milestone` (`L273-L283`) maps all DB errors to `400 ALREADY_CLAIMED`.

### LOW-03: Malformed JSON Swallowed on `/auth/attest` & Production Staging Gap
- **Location:** `backend/src/routes/auth.ts` (`L16`, `L31`)
- **Root Cause:** Invalid JSON falls back to `{}` (`L16`) instead of `400`; invalid Play Integrity verdicts are only rejected when `ENVIRONMENT === 'production'` (`L31`).

### LOW-04: Single-Pass `<user_input>` Tag Stripping in Prompts
- **Location:** `backend/src/ai/prompts.ts` (`L88-L91`)
- **Root Cause:** `input.replace(/<\/?user_input>/gi, '')` runs a single pass, so nested inputs like `<user<user_input>_input>` reassemble `<user_input>`.

### LOW-05: `Idempotency-Key` Ignores Payload Mismatches in `runGeneration`
- **Location:** `backend/src/ai/pipeline.ts` (`L32-L39`, `L86`, `L193`)
- **Root Cause:** Stores `requestHash: requestId` (a random UUID) instead of hashing the request payload, returning stale cached outputs if a caller reuses an `Idempotency-Key` with different inputs.

### LOW-06: Middleware Runs D1 Ban/Upsert Writes Before Rate Limiting & Swallows Ban DB Errors
- **Location:** `backend/src/index.ts` (`L95-L101`), `backend/src/middleware/installation.ts` (`L35-L60`), `backend/src/index.ts` (`L66`)
- **Root Cause:** `installationMiddleware` runs before `rateLimiterMiddleware`, causing D1 writes even on rate-limited traffic; `BansRepository.isBanned` errors are swallowed in `catch` (`installation.ts:42-44`); `origin.endsWith('.vibekit.ai')` (`index.ts:66`) matches `http://` subdomains.

### LOW-07: `ApiClient` Trailing-Slash URL Bug, Non-Map `error` Crash, Swallowed `404`/`502`, `CardMaker` Save Guard, & Empty `errorBuilder`
- **Location:**
  - `app/lib/core/network/api_client.dart` (`L28`, `L129`, `L146`, `L173-L181`, `L228-L238`)
  - `app/lib/features/card_maker/card_maker_screen.dart` (`L234-L264`)
  - `app/lib/core/services/card_export_service.dart` (`L51-L53`)
  - `app/lib/core/router/app_router.dart` (`L135-L139`)
- **Root Cause:** Custom API URLs with trailing `/` create `//v1/...` paths; non-Map `data['error']` throws `NoSuchMethodError` in `_handleResponse`; `_runGenerationWithFallback` omits `404`/`422`/`502` from `isClientOrPolicyError`, masking broken routes with offline fallback; `CardMakerScreen._saveToFavorites` lacks a save lock and ignores `filePath == null` errors (or `'web_export:...'` lack of binary bytes on Web); `app_router.dart`'s `errorBuilder` provides no button to return `/home`.
