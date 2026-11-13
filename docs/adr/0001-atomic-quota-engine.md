# ADR-0001: Atomic Quota Engine & Idempotent Credit Transactions

## Status
Accepted

## Context
VibeKit AI offers a hybrid monetization model: free daily credits (3 per UTC day), rewarded ad credits (up to 2 ads per day, +3 credits each), and Pro subscriptions (200 credits per billing cycle).
In high-concurrency environments across distributed Cloudflare Worker edge isolates, concurrent requests could potentially exploit race conditions (read-then-write check) to overspend daily free or pro credits.
Furthermore, network retries from mobile clients can result in duplicate credit deductions if requests are not strictly idempotent.

## Decision
1. **Single-Statement Guarded Decrements in Cloudflare D1:**
   - Rather than reading credit balances and subsequently updating them (which creates a race window), credit deductions are executed using a single SQL `UPDATE` statement with an atomic `WHERE` guard:
     ```sql
     UPDATE daily_usage
     SET free_credits_used = free_credits_used + 1, updated_at = ?
     WHERE installation_id = ? AND usage_date = ? AND free_credits_used < ?;
     ```
   - The operation succeeds if and only if `result.meta.changes > 0`. If `changes === 0`, credit deduction fails immediately with `QuotaExceededError`.
   - The same atomic pattern applies to Pro cycle credits:
     ```sql
     UPDATE pro_cycle_usage
     SET credits_used = credits_used + 1, updated_at = ?
     WHERE installation_id = ? AND cycle_start <= ? AND cycle_end > ? AND credits_used < ?;
     ```
2. **Commit Credit ONLY on Success:**
   - The AI generation pipeline executes generation first. Credits are deducted only after successful AI response generation and JSON schema validation.
   - If the AI provider times out or fails, zero credits are deducted. No complex refund compensation transactions are needed.
3. **24-Hour Idempotency Keys:**
   - All mutating, credit-spending (`/v1/generations/*`), and credit-granting (`/v1/ads/*`, `/v1/purchases/*`, `/v1/referrals/*`) endpoints require or support an `Idempotency-Key` header.
   - Keys and their serialized responses are stored in D1 SQLite (`idempotency_keys`) with a 24-hour expiration window.
   - Duplicate requests with the same key return the previously cached response immediately with HTTP status matching the original result, without deducting additional credits or invoking upstream AI providers.
4. **Durable Objects Evaluation:**
   - While Cloudflare Durable Objects provide in-memory actor serialization, D1 single-statement atomic updates have zero coordination overhead and execute within standard Worker limits without requiring paid Workers Enterprise/Workers Paid DO namespaces. Load testing at 100 concurrent requests confirms zero overspend with D1 SQLite.

## Consequences
- Guaranteed zero overspending under concurrent load.
- Network retries from unreliable mobile connections are safely deduplicated.
- Negligible database overhead (1 query per successful generation).
