# VibeKit AI — Risks, Blockers & Mitigations

**Date:** October 10, 2026  
**Status:** Pre-Implementation Risk Matrix

---

## 1. Technical & Release Risks

| # | Risk Description | Severity | Impact | Mitigation Strategy |
| :- | :--- | :--- | :--- | :--- |
| **R1** | **Google Play Billing Account / Products Unconfigured** | High | Live in-app purchases fail until Play Console products (`vibekit_pro_monthly`, `vibekit_pro_yearly`) and Google Play service accounts are configured. | Build an abstracted `BillingService` with full real `InAppPurchase` implementation + a clear development/test fallback mode. Write comprehensive setup guide in `docs/PLAY_BILLING_SETUP.md`. |
| **R2** | **AdMob Account & App ID Pending Approval** | High | Real ads will not serve until AdMob app ID and ad units are approved by Google. | Use Google's official AdMob sample/test ad unit IDs during development (`ca-app-pub-3940256099942544/...`). Include remote/local toggle to disable ads seamlessly if unconfigured. |
| **R3** | **Gemini API Key Required** | High | Backend cannot complete live generations without a valid Google Gemini API key. | Abstract the AI provider into `GeminiProvider`. Support mock/stub response mode in local unit tests and provide clear instructions in `docs/AI_PROVIDER_SETUP.md`. Server-side key storage only. |
| **R4** | **Google Play 14/20 Tester Requirement** | Medium | Personal developer accounts require 14 days of closed testing with 20 opt-in testers before production access is unlocked. | Document exact closed testing and production promotion steps in `docs/PLAY_STORE_RELEASE_CHECKLIST.md`. |
| **R5** | **Android cmdline-tools not in default PATH** | Low | `flutter doctor` flags missing `cmdline-tools` component in some Windows developer setups. | JDK 21 is identified in Android Studio JBR. App will be scaffolded, tested with Flutter unit/widget test suites, formatted, analyzed, and Gradle configs prepared for build. |

---

## 2. Security & Compliance Protections

- **Secret Leakage Prevention:** `.gitignore` configured to exclude `.env`, `service-account*.json`, `*.keystore`, `*.jks`, and `wrangler.toml` secret overrides.
- **Abuse & Bot Protection:** The Cloudflare Worker enforces an IP-level + `app_instance_id` rate limiter to prevent denial-of-wallet attacks against Gemini quotas.
- **Prompt Injection Defense:** Strict separation of prompt instructions from user input. Prompts explicitly command the LLM to refuse role overrides and system prompt disclosure.
