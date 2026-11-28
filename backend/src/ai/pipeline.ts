import { Context } from 'hono';
import { z } from 'zod';
import { AppHonoEnv } from '../types';
import { ValidationError, QuotaExceededError, ProviderError } from '../errors/app_error';
import { QuotaManager } from '../quota/quota_manager';
import { createAIProvider } from './factory';
import { getCachedChallengeResponse, setCachedChallengeResponse } from './challenge_cache';
import { GenerationsRepository } from '../db/generations.repo';
import { IdempotencyRepository } from '../db/idempotency.repo';
import { AICircuitBreaker } from '../security/circuit_breaker';
import { sha256Hex } from '../security/play_integrity';

export interface GenerationPipelineConfig<TInput, TOutput> {
  category: 'reply' | 'caption' | 'bio' | 'vibe_check';
  inputSchema: z.ZodType<TInput, any, any>;
  outputSchema: z.ZodType<TOutput, any, any>;
  extractChallengeId?: (input: TInput) => string | undefined;
  getCacheTone?: (input: TInput) => string;
  getCacheLanguage?: (input: TInput) => string;
  getCacheVariant?: (input: TInput) => string;
  generate: (ai: ReturnType<typeof createAIProvider>, input: TInput) => Promise<TOutput>;
  formatResponse: (output: TOutput, input: TInput, creditsRemaining: number, cached?: boolean) => Record<string, unknown>;
}

export async function runGeneration<TInput, TOutput>(
  c: Context<AppHonoEnv>,
  config: GenerationPipelineConfig<TInput, TOutput>
): Promise<Response> {
  const installation = c.get('installation');
  const requestId = c.get('requestId');
  const startTime = Date.now();

  // 1. Global AI Daily Budget Circuit Breaker Check
  const circuitBreaker = new AICircuitBreaker(c.env?.DB);
  await circuitBreaker.checkBudgetGuard(0.001);

  // 2. Validate Input Payload with Zod
  const rawBody = await c.req.json();
  const parsed = config.inputSchema.safeParse(rawBody);
  if (!parsed.success) {
    throw new ValidationError('Invalid request payload.', parsed.error.format());
  }
  const input = parsed.data;
  const payloadHash = await sha256Hex(JSON.stringify(input));

  // 3. Idempotency Key Check (24-hour deduplication; rejects parameter swaps under the same key)
  const idempotencyKey = c.req.header('Idempotency-Key')?.trim() || c.req.header('X-Idempotency-Key')?.trim();
  let idempotencyRepo: IdempotencyRepository | undefined;
  if (idempotencyKey && c.env?.DB) {
    idempotencyRepo = new IdempotencyRepository(c.env.DB);
    const cachedResponse = await idempotencyRepo.getValidResponse(idempotencyKey, installation.id, c.req.path);
    if (cachedResponse) {
      if (cachedResponse.requestHash && cachedResponse.requestHash !== payloadHash) {
        throw new ValidationError('Idempotency-Key cannot be reused with different request parameters.');
      }
      return c.json(cachedResponse.data as any, cachedResponse.statusCode as any);
    }
  }

  // 4. Atomically Reserve Credit Before Calling Upstream AI (with debited UTC date tracking)
  const quotaManager = new QuotaManager(c.env);
  const reserved = await quotaManager.reserveCreditWithDate(installation.id);
  if (!reserved) {
    throw new QuotaExceededError();
  }

  const challengeId = config.extractChallengeId ? config.extractChallengeId(input) : undefined;
  const tone = config.getCacheTone ? config.getCacheTone(input) : undefined;
  const language = config.getCacheLanguage ? config.getCacheLanguage(input) : undefined;
  const variantSig = config.getCacheVariant ? config.getCacheVariant(input) : payloadHash.slice(0, 16);

  // 5. Daily Challenge Cache Check (keyed cleanly by variant + prompt digest)
  if (challengeId && tone && language && c.env?.DB) {
    try {
      const cached = await getCachedChallengeResponse<TOutput>(
        c.env.DB,
        challengeId,
        tone,
        language,
        config.category,
        variantSig
      );
      if (cached) {
        const quota = await quotaManager.getQuotaStatus(installation.id);
        const creditsRemaining = quota.is_pro ? quota.pro_credits_remaining : quota.total_credits_remaining;
        const cachedResponse = config.formatResponse(cached, input, creditsRemaining, true);

        if (idempotencyRepo && idempotencyKey) {
          await idempotencyRepo.storeResponse({
            key: idempotencyKey,
            installationId: installation.id,
            endpoint: c.req.path,
            requestHash: payloadHash,
            responseJson: JSON.stringify(cachedResponse),
            statusCode: 200,
          });
        }

        return c.json(cachedResponse);
      }
    } catch (cacheErr) {
      await quotaManager.refundCredit(installation.id, reserved.bucket, reserved.usageDate);
      throw cacheErr;
    }
  }

  // 6. Call AI with Fallback Chain & Repair Retry
  const ai = createAIProvider(c.env);
  let output: TOutput;

  try {
    const rawResult = await aiGenerationWithTimeout(ai, input, config.generate, 20000);

    // Narrow prompt-injection leak guard (avoid false-positives on normal prose discussing prompts)
    const serialized = JSON.stringify(rawResult).toLowerCase();
    if (
      serialized.includes('my system prompt') ||
      serialized.includes('my internal instructions') ||
      serialized.includes('<user_input>') ||
      serialized.includes('system_prompt')
    ) {
      throw new ProviderError('SAFETY_VIOLATION: AI response violated safety policy.');
    }

    const validated = config.outputSchema.safeParse(rawResult);
    if (validated.success) {
      output = validated.data;
    } else {
      console.warn(`[Pipeline] Output schema validation mismatch for ${config.category}, attempting repair retry.`);
      await circuitBreaker.recordSpend(0.0001).catch(() => {});
      const retryResult = await aiGenerationWithTimeout(ai, input, config.generate, 15000);
      const retryValidated = config.outputSchema.safeParse(retryResult);
      if (retryValidated.success) {
        output = retryValidated.data;
      } else {
        throw new ProviderError('AI output schema validation failed.');
      }
    }
  } catch (err: unknown) {
    await quotaManager.refundCredit(installation.id, reserved.bucket, reserved.usageDate);
    await circuitBreaker.recordSpend(0.0001).catch(() => {});
    const errMessage = err instanceof Error ? err.message : 'AI generation error';
    const isSafety = errMessage.toUpperCase().includes('SAFETY');
    try {
      const genRepo = new GenerationsRepository(c.env?.DB);
      await genRepo.insertMetadata({
        id: `gen_${Date.now()}_${Math.random().toString(36).substring(7)}`,
        requestId,
        installationId: installation.id,
        category: config.category,
        tone,
        language,
        status: isSafety ? 'safety_rejected' : 'failed',
        latencyMs: Date.now() - startTime,
      });
    } catch (telemetryErr) {
      console.warn('[Pipeline] Failed to record failure metadata:', telemetryErr);
    }
    // Never leak internal upstream provider error details to end users
    throw new ProviderError(
      isSafety
        ? 'SAFETY_VIOLATION: The request could not be completed due to safety guidelines.'
        : 'AI generation service is temporarily unavailable. Please try again.'
    );
  }

  const latencyMs = Date.now() - startTime;

  // 7. Cache challenge response if applicable
  if (challengeId && tone && language && c.env?.DB) {
    await setCachedChallengeResponse(
      c.env.DB,
      challengeId,
      tone,
      language,
      config.category,
      output,
      variantSig
    );
  }

  // 8. Write Audit Metadata & budget spend
  try {
    const genRepo = new GenerationsRepository(c.env?.DB);
    await genRepo.insertMetadata({
      id: `gen_${Date.now()}_${Math.random().toString(36).substring(7)}`,
      requestId,
      installationId: installation.id,
      category: config.category,
      tone,
      language,
      status: 'success',
      latencyMs,
    });
    await circuitBreaker.recordSpend(0.0001);
  } catch (telemetryErr) {
    console.warn('[Pipeline] Non-fatal telemetry/budget write failed:', telemetryErr);
  }

  const quota = await quotaManager.getQuotaStatus(installation.id);
  const creditsRemaining = quota.is_pro ? quota.pro_credits_remaining : quota.total_credits_remaining;
  const finalResponse = config.formatResponse(output, input, creditsRemaining, false);

  if (idempotencyRepo && idempotencyKey) {
    try {
      await idempotencyRepo.storeResponse({
        key: idempotencyKey,
        installationId: installation.id,
        endpoint: c.req.path,
        requestHash: payloadHash,
        responseJson: JSON.stringify(finalResponse),
        statusCode: 200,
      });
    } catch (idempErr) {
      console.warn('[Pipeline] Non-fatal idempotency store failed:', idempErr);
    }
  }

  return c.json(finalResponse);
}

async function aiGenerationWithTimeout<TInput, TOutput>(
  ai: ReturnType<typeof createAIProvider>,
  input: TInput,
  generateFn: (ai: ReturnType<typeof createAIProvider>, input: TInput) => Promise<TOutput>,
  timeoutMs: number
): Promise<TOutput> {
  let timeoutId: ReturnType<typeof setTimeout>;
  const timeoutPromise = new Promise<never>((_, reject) => {
    timeoutId = setTimeout(() => {
      reject(new Error(`Upstream AI generation timed out after ${timeoutMs}ms`));
    }, timeoutMs);
  });

  try {
    return await Promise.race([generateFn(ai, input), timeoutPromise]);
  } finally {
    clearTimeout(timeoutId!);
  }
}
