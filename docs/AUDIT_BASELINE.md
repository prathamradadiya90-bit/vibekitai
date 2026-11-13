# VibeKit AI — Audit Baseline & System Diagnostic Report

**Target Bar:** Industry-Grade, Play Store-Ready, Revenue-Ready (100/100 Quality Bar)  
**Date:** Current Baseline (Phase 0)  
**Status:** Audit Complete — Zero Code Modified

---

## 1. Executive Summary

This diagnostic report establishes the empirical baseline across the Flutter Android client (`app/`), the Cloudflare Workers Edge API (`backend/`), and existing documentation. It identifies critical technical debt, security gaps, performance bottlenecks, and architectural risks that must be resolved in Phases 1 through 9.

---

## 2. Codebase Baseline Metrics

| Metric | Measured Baseline | Target Standard | Gap / Status |
| :--- | :--- | :--- | :--- |
| **Backend TypeScript LOC** | 5,898 LOC across 38 files | Clean, modular | Baseline established |
| **Backend Test Suite** | 42 tests passing (Vitest) | Contract, chaos, concurrency | Missing load & concurrency tests |
| **Backend Worker Bundle Size** | 364.49 KiB (gzip: 76.51 KiB) | < 1 MB | Well within budget |
| **Backend Dependency Vulnerabilities** | 1 High (`zod < 4.6.6` GHSA-mrhx-c7xc-m3w5) | 0 vulnerabilities | Requires update / remediation |
| **Flutter Client LOC** | 2,922 LOC | Layered architecture | Presentation/domain bleed |
| **Flutter Test Coverage** | **28.10%** (821 / 2,922 lines) | >= 85% coverage | Significant coverage deficit |
| **Flutter Dependencies Outdated** | 22 upgradable, 15 resolvable | Fully maintained | Major package updates pending |
| **Flutter Static Analysis** | 0 warnings (`very_good_analysis` baseline) | 0 warnings | Clean |
| **Android AAB Size (est.)** | ~18.5 MB - 22.0 MB | < 25 MB | Within budget |
| **Cold-Start Time (est.)** | ~1.8s - 2.2s on mid-range Android | < 2.0s | Near budget ceiling |

---

## 3. Deep-Dive Audit Findings

### 3.1 Duplication Hotspots
1. **Frontend Presentation / State Duplication:**
   - Although generic `GenerationNotifier` and shared widgets were introduced, individual screen implementations (`reply_studio_screen.dart`, `caption_lab_screen.dart`, `bio_lab_screen.dart`) still duplicate error dialogue handling, snackbar triggers, and history persistence hooks.
2. **Backend Query Assembly & Validation:**
   - Repeated pagination logic (`limit`, `offset` sanitization) across `installations`, `subscriptions`, `feedback`, and `audit-log` routes.
3. **Test Setup & Fixtures:**
   - Mock D1 and mock environment setups are partially duplicated across `api.test.ts`, `ads_ssv.test.ts`, and `admin.test.ts`.

### 3.2 Concurrency & Race Conditions
1. **Multi-Isolate D1 Quota Contention:**
   - Single-statement atomic decrements (`UPDATE daily_usage ... WHERE free_credits_used < max`) prevent isolate race conditions in a single database replica. However, under high concurrency (>50 req/sec) across distributed Cloudflare edge POPs, D1 SQLite transactions can suffer from lock contention or replication read lag.
   - *Risk:* Credit double-spending or spurious 500 errors during traffic bursts.
   - *Decision Point:* Evaluate a Durable Object serialized per installation in Phase 1 if contention appears under load.
2. **Ad Nonce Verification & SSV Deduplication:**
   - `ad_nonces` and `admob_ssv_transactions` verify uniqueness, but nonces are checked and marked used in separate statements. If two concurrent SSV requests arrive with the same transaction or nonce, both might pass if not enclosed in an atomic batch.
3. **Streak Advancement:**
   - `last_checkin_date` is validated, but concurrent requests from multi-device users or network retries on UTC midnight boundaries could trigger multiple check-in XP increments.

### 3.3 N+1 & Extra D1 Round Trips per Endpoint
Every generation request currently performs multiple sequential D1 queries:
| Step | Operation | Current Mechanism | Overhead |
| :--- | :--- | :--- | :--- |
| **1. Middleware** | `bans.isBanned` | Cached in isolate; DB query on cold start | 1 round trip (cold) |
| **2. Middleware** | `installations.upsert` | D1 SQL insert/update | 1 round trip |
| **3. Rate Limiter** | `rate_limit_counters` | SQL query + update | 1-2 round trips |
| **4. Quota Engine** | `daily_usage` decrement | Single statement atomic update | 1 round trip |
| **5. Metadata Write** | `generation_metadata` | SQL insert on completion | 1 round trip |
| **Total per AI request** | **4 to 5 distinct D1 network round trips** | **Sequential execution** | **~80ms - 150ms DB latency overhead** |

*Optimization Target:* Combine Steps 1, 2, and 4 into a single `db.batch()` execution to reduce D1 round trips to 1 before calling the AI provider, and 1 after completion.

### 3.4 Unbounded Queries
1. **Admin Streak Distribution Scan:**
   - `SELECT current_streak FROM streaks` in `stats.repo.ts` pulls all streak rows into Worker RAM. At 100k+ active installations, this will exhaust the 128MB Worker memory limit.
   - *Fix:* Must use `SELECT CASE ... GROUP BY bucket` or precompute in `daily_stats`.
2. **Unindexed Installation Search:**
   - `SELECT * FROM installations WHERE id LIKE ?` performs a full table scan on D1 when wildcards are used.
3. **Local SQLite History:**
   - While pagination was added, searching history (`queryHistory`) lacks SQLite FTS (Full Text Search) indexing, causing full table scans as user history grows beyond 1,000 entries.

### 3.5 Missing Database Indexes
Hot query analysis reveals the following missing indexes:
- `daily_usage(usage_date, free_credits_used)` — Used for daily quota exhaustion aggregation.
- `generation_metadata(installation_id, created_at)` — Used for single installation detail view.
- `feedback_records(status, created_at)` — Used for admin feedback filtering.
- `streaks(current_streak)` — Required if bucketed aggregations are queried directly.

### 3.6 Unhandled Error Paths
1. **AI Provider Cascading Failure:**
   - If Google Gemini returns HTTP 429 (Resource Exhausted) and the fallback provider (e.g., Groq) also errors, the client receives a generic 502 `AI_PROVIDER_ERROR`. There is currently no client-side retry with exponential backoff or local offline fallback draft suggestion.
2. **Google Play Billing Disconnects:**
   - If Google Play Services is absent (de-Googled devices, Chinese ROMs, emulators), `InAppPurchase.instance` throws an unhandled platform exception that can prevent the paywall screen from rendering.
3. **Device Storage Full:**
   - If device disk space is exhausted, `card_export_service.dart` fails silently or throws an uncaught I/O exception when saving high-resolution PNGs.

### 3.7 Leaked Resources & Lifecycle Issues
1. **Flutter Controllers & FocusNodes:**
   - Several feature screens create `TextEditingController` and `ScrollController` instances inside `StatefulWidget` without guaranteed disposal in `dispose()`.
2. **Card Maker Image Rendering:**
   - While `ui.Image.dispose()` was implemented for card export, the interactive preview canvas retains texture buffers across fast template switches.

### 3.8 Security & Threat Gaps
1. **Forged `X-App-Instance-Id`:**
   - The edge API trusts arbitrary client-generated UUIDs in `X-App-Instance-Id`. Any script or bot can generate infinite UUIDs to bypass the 3-credit free daily quota.
2. **Absence of Play Integrity Attestation:**
   - No hardware attestation or app licensing checks exist. Compromised or cloned APKs can consume AI edge quotas freely.
3. **Permissive CORS Header:**
   - `Access-Control-Allow-Origin: *` is present on all backend routes, allowing arbitrary browser origins to invoke the API.
4. **Zod Memory Exhaustion (GHSA-mrhx-c7xc-m3w5):**
   - High-severity vulnerability in `zod < 4.6.6` regarding memory exhaustion on oversized payloads. Needs immediate request body size limiting (< 64 KB) and safe Zod schema constraints.
5. **Lack of Request Signing:**
   - No cryptographic signing or HMAC verification exists on sensitive mutation requests.

### 3.9 Accessibility & Localization Gaps
1. **TalkBack / Screen Reader:**
   - Many icon buttons (`IconButton`) and card canvas controls lack explicit `Semantics(label: ...)` definitions.
2. **Touch Target Sizing:**
   - Tone selector chips and card ratio toggle buttons have hit areas of ~36x36 dp, violating the Material 3 minimum target of 48x48 dp.
3. **Dynamic Font Scaling:**
   - Card maker typography uses fixed pixel values that can clip or overflow when Android system font scaling is set to 150% - 200%.
4. **Hardcoded Strings:**
   - Several error messages and validation alerts are hardcoded in English, failing localization requirements for Hindi and Gujarati.

---

## 4. Test Coverage Baseline Breakdown

### Flutter Client Coverage: 28.10% (821 / 2,922 lines)
- `core/config/app_config.dart`: 50.0% (9/18 lines)
- `core/services/admob_service.dart`: 23.5% (16/68 lines)
- `core/controllers/generation_controller.dart`: 82.4% (42/51 lines)
- `core/widgets/result_card.dart`: 89.1% (41/46 lines)
- `features/paywall/`: 0.0% (Uncovered)
- `features/history/`: 15.2% (Partially covered)
- `features/card_maker/`: 0.0% (Uncovered)
- `features/streaks/`: 0.0% (Uncovered)
- `features/referrals/`: 0.0% (Uncovered)

### Backend API Coverage: ~65% (42 automated tests)
- `pipeline.ts`: ~90% (Input validation, fallback, quota check covered)
- `admin/`: ~85% (RBAC, bans, config versioning covered)
- `ads.ts`: ~80% (SSV verification, nonce check covered)
- `purchases.ts`: ~40% (Mock verification only; lacks RTDN webhook & reconciliation tests)
- `privacy.ts`: ~50% (Delete data happy path covered; missing concurrent erasure tests)
- `rate_limit.ts`: ~60% (Sliding window logic tested; missing distributed burst tests)

---

## 5. Prioritized Remediation Roadmap (Phases 1 - 9)

```
Phase 1: Correctness & Abuse-Proof Core (Play Integrity, Atomic Quotas, Authoritative Billing)
Phase 2: Clean Architecture & Strict Dependency Layering (Domain/Data/Presentation, Very Good Analysis)
Phase 3: Security Hardening (OWASP MASVS L1/L2, ASVS L2, Request Signing, Zod Hardening)
Phase 4: Observability, SRE & Cost Control (Analytics Engine, Redaction, Runbooks, Restore Drills)
Phase 5: Growth, Accessibility & i18n (TalkBack 48dp, ARB Localization for EN/HI/GU, Referral Integrity)
Phase 6: Monetization Engine (Ad Mediation, Subscriptions v2, Paywall Variant Optimization)
Phase 7: Zero-Trust Admin (Cloudflare Access production hardening, Aggregates, Audit Trail)
Phase 8: Testing Pyramid & CI/CD (Property-based tests, Goldens, k6 Load Tests, GitHub Actions)
Phase 9: Play Store Compliance Readiness (Data Safety, 16KB pages, ASO listing, Pre-launch matrix)
Phase 10: Quality Scorecard & 90-Day Backlog
```
