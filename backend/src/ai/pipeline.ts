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

export interface GenerationPipelineConfig<TInput, TOutput> {
  category: 'reply' | 'caption' | 'bio' | 'vibe_check';
  inputSchema: z.ZodType<TInput, any, any>;
  outputSchema: z.ZodType<TOutput, any, any>;
  extractChallengeId?: (input: TInput) => string | undefined;
  getCacheTone?: (input: TInput) => string;
  getCacheLanguage?: (input: TInput) => string;
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

  // 1. Idempotency Key Check (24-hour request deduplication)
  const idempotencyKey = c.req.header('Idempotency-Key')?.trim() || c.req.header('X-Idempotency-Key')?.trim();
  let idempotencyRepo: IdempotencyRepository | undefined;
  if (idempotencyKey && c.env.DB) {
    idempotencyRepo = new IdempotencyRepository(c.env.DB);
    const cachedResponse = await idempotencyRepo.getValidResponse(idempotencyKey, installation.id, c.req.path);
    if (cachedResponse) {
      return c.json(cachedResponse.data as any, cachedResponse.statusCode as any);
    }
  }

  // 2. Global AI Daily Budget Circuit Breaker Check
  const circuitBreaker = new AICircuitBreaker(c.env.DB);
  await circuitBreaker.checkBudgetGuard(0.001);

  // 3. Validate Input Payload with Zod
  const rawBody = await c.req.json();

  const parsed = config.inputSchema.safeParse(rawBody);
  if (!parsed.success) {
    throw new ValidationError('Invalid request payload.', parsed.error.format());
  }
  const input = parsed.data;

  // 4. Check Quota Availability
  const quotaManager = new QuotaManager(c.env);
  const hasCredits = await quotaManager.hasAvailableCredits(installation.id);
  if (!hasCredits) {
    throw new QuotaExceededError();
  }

  const challengeId = config.extractChallengeId ? config.extractChallengeId(input) : undefined;
  const tone = config.getCacheTone ? config.getCacheTone(input) : undefined;
  const language = config.getCacheLanguage ? config.getCacheLanguage(input) : undefined;

  // 5. Daily Challenge Cache Check (if challenge request)
  if (challengeId && tone && language && c.env.DB) {
    const cached = await getCachedChallengeResponse<TOutput>(
      c.env.DB,
      challengeId,
      tone,
      language,
      config.category
    );
    if (cached) {
      const creditDeducted = await quotaManager.deductCredit(installation.id);
      if (!creditDeducted) {
        throw new QuotaExceededError();
      }
      const quota = await quotaManager.getQuotaStatus(installation.id);
      const creditsRemaining = quota.is_pro ? quota.pro_credits_remaining : quota.total_credits_remaining;
      const cachedResponse = config.formatResponse(cached, input, creditsRemaining, true);

      if (idempotencyRepo && idempotencyKey) {
        await idempotencyRepo.storeResponse({
          key: idempotencyKey,
          installationId: installation.id,
          endpoint: c.req.path,
          requestHash: requestId,
          responseJson: JSON.stringify(cachedResponse),
          statusCode: 200,
        });
      }

      return c.json(cachedResponse);
    }
  }

  // 4. Call AI with Fallback Chain & Repair Retry
  const ai = createAIProvider(c.env);
  let output: TOutput;

  try {
    const rawResult = await aiGenerationWithTimeout(ai, input, config.generate, 20000);

    // Prompt injection leak guard
    const serialized = JSON.stringify(rawResult).toLowerCase();
    if (serialized.includes('system prompt') || serialized.includes('internal instructions')) {
      throw new ProviderError('AI response violated safety policy.');
    }

    // Validate output with Zod schema
    const validated = config.outputSchema.safeParse(rawResult);
    if (validated.success) {
      output = validated.data;
    } else {
      // 1 repair retry attempt
      console.warn(`[Pipeline] Output schema validation mismatch for ${config.category}, attempting repair retry.`);
      const retryResult = await aiGenerationWithTimeout(ai, input, config.generate, 15000);
      const retryValidated = config.outputSchema.safeParse(retryResult);
      if (retryValidated.success) {
        output = retryValidated.data;
      } else {
        throw new ProviderError('AI output schema validation failed.');
      }
    }
  } catch (err: unknown) {
    const errMessage = err instanceof Error ? err.message : 'AI generation error';
    // Record failure in audit metadata
    const genRepo = new GenerationsRepository(c.env.DB);
    await genRepo.insertMetadata({
      id: `gen_${Date.now()}_${Math.random().toString(36).substring(7)}`,
      requestId,
      installationId: installation.id,
      category: config.category,
      tone,
      language,
      status: errMessage.includes('SAFETY') ? 'safety_rejected' : 'failed',
      latencyMs: Date.now() - startTime,
    });
    throw new ProviderError(errMessage);
  }

  // 6. Commit Credit ONLY on Success
  const creditDeducted = await quotaManager.deductCredit(installation.id);
  if (!creditDeducted) {
    throw new QuotaExceededError();
  }

  const latencyMs = Date.now() - startTime;

  // 7. Cache challenge response if applicable
  if (challengeId && tone && language && c.env.DB) {
    await setCachedChallengeResponse(
      c.env.DB,
      challengeId,
      tone,
      language,
      config.category,
      output
    );
  }

  // 8. Write Audit Metadata (Never stores prompt content or generated text)
  const genRepo = new GenerationsRepository(c.env.DB);
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

  // 9. Record spend in daily budget
  await circuitBreaker.recordSpend(0.0001);

  // 10. Return Standardized Response & Cache in Idempotency Repo
  const quota = await quotaManager.getQuotaStatus(installation.id);
  const creditsRemaining = quota.is_pro ? quota.pro_credits_remaining : quota.total_credits_remaining;
  const finalResponse = config.formatResponse(output, input, creditsRemaining, false);

  if (idempotencyRepo && idempotencyKey) {
    await idempotencyRepo.storeResponse({
      key: idempotencyKey,
      installationId: installation.id,
      endpoint: c.req.path,
      requestHash: requestId,
      responseJson: JSON.stringify(finalResponse),
      statusCode: 200,
    });
  }

  return c.json(finalResponse);
}

async function aiGenerationWithTimeout<TInput, TOutput>(
  ai: ReturnType<typeof createAIProvider>,
  input: TInput,
  generator: (ai: ReturnType<typeof createAIProvider>, input: TInput) => Promise<TOutput>,
  timeoutMs: number
): Promise<TOutput> {
  let timer: any;
  const timeoutPromise = new Promise<never>((_, reject) => {
    timer = setTimeout(() => reject(new ProviderError(`AI provider timed out after ${timeoutMs}ms.`)), timeoutMs);
  });

  try {
    return await Promise.race([generator(ai, input), timeoutPromise]);
  } finally {
    clearTimeout(timer);
  }
}
