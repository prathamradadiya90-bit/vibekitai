# ADR 0007: In-App Review and Rating Trigger Policy

**Date:** 2026-10-24  
**Status:** Approved  
**Context:** VibeKit AI Flutter Client  

---

## 1. Context & Problem Statement

Organic Google Play Store ratings are critical for conversion rate optimization (ASO) and viral organic growth. However, poorly timed rating prompts degrade user experience, cause app store rejections, or violate Google Play's Developer Content Policies against manipulative review gating.

We require a standardized in-app review triggering policy that:
1. Prompts users exclusively at moments of verified delight (positive achievement).
2. Never interrupts critical user generation or editing flows.
3. Enforces strict frequency limits (maximum once per 90 days).
4. Strictly adheres to Google Play Anti-Review-Gating rules (no "sentiment filtering" that sends 5-star users to the Play Store and 1-star users to private feedback).

---

## 2. Decision

We implement a dedicated `ReviewPromptService` with the following architectural rules:

### 2.1 Trigger Moments (Positive Delight Only)
A review prompt may only be requested when one of the following criteria is met:
1. **Milestone Generation:** Immediately after the user's **2nd successful generation** (after they copy or export the result).
2. **Streak Milestone:** Immediately after claiming the **Day 3 or Day 7 streak reward**.

### 2.2 Strict Suppression Rules (Negative Moments)
Review prompts are **strictly blocked** if:
- An API error, rate limit (429), or network failure occurred in the current session.
- The user has been prompted within the last **90 days**.
- The user has already engaged with the review dialog (`has_rated = true`).
- The user has less than 2 total generations recorded.

### 2.3 Direct Google Play Deep Link & In-App Flow
- Uses `market://details?id=com.vibekit.ai` with fallback to `https://play.google.com/store/apps/details?id=com.vibekit.ai`.
- Shows a clean, honest dialog asking if the user is enjoying VibeKit AI with direct navigation to the Play Store.
- No artificial intermediate star filters that hide negative feedback from the public store.

---

## 3. Consequences

### Positive
- **High Rating Quality:** Prompts occur only after genuine value has been demonstrated, maximizing 5-star ratios.
- **Zero Dark Patterns:** 100% compliant with Google Play In-App Review guidelines and Google Play Policy.
- **Polite UX:** 90-day cooldown ensures users are never badgered.

### Negative / Trade-offs
- Volume of reviews is slightly lower than aggressive prompting, but organic sentiment and retention are strictly protected.
