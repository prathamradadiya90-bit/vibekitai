import { AIProvider } from './factory';

// Shared circuit breaker state across requests within isolate
let sharedFailureCount = 0;
let sharedCircuitOpenUntil = 0;
let halfOpenProbeInFlight = false;

export function resetFallbackCircuitBreaker(): void {
  sharedFailureCount = 0;
  sharedCircuitOpenUntil = 0;
  halfOpenProbeInFlight = false;
}

export class FallbackChainAIProvider implements AIProvider {
  private primary: AIProvider;
  private fallback?: AIProvider;
  private readonly failureThreshold = 3;
  private readonly circuitCooldownMs = 60000;

  constructor(primary: AIProvider, fallback?: AIProvider) {
    this.primary = primary;
    this.fallback = fallback;
  }

  private isCircuitOpen(): boolean {
    if (sharedCircuitOpenUntil === 0) return false;
    return Date.now() < sharedCircuitOpenUntil;
  }

  private recordSuccess(): void {
    sharedFailureCount = 0;
    sharedCircuitOpenUntil = 0;
    halfOpenProbeInFlight = false;
  }

  private isSafetyOrPolicyError(error: any): boolean {
    const errMessage = (error?.message || String(error)).toUpperCase();
    return (
      errMessage.includes('SAFETY_VIOLATION') ||
      errMessage.includes('SAFETY POLICY') ||
      errMessage.includes('SAFETY FILTER') ||
      errMessage.includes('BLOCKED BY SAFETY')
    );
  }

  private recordFailure(error: any): void {
    halfOpenProbeInFlight = false;
    if (this.isSafetyOrPolicyError(error)) {
      return;
    }

    sharedFailureCount += 1;
    console.warn(`Primary AI provider failure #${sharedFailureCount}:`, error?.message || error);
    if (sharedFailureCount >= this.failureThreshold) {
      sharedCircuitOpenUntil = Date.now() + this.circuitCooldownMs;
      console.warn(`Circuit breaker tripped. Routing all AI traffic to fallback for ${this.circuitCooldownMs / 1000}s`);
    }
  }

  private async runWithFallback<T>(
    runPrimary: () => Promise<T>,
    runFallback?: () => Promise<T>
  ): Promise<T> {
    if (!runFallback) {
      return runPrimary();
    }

    if (this.isCircuitOpen()) {
      return runFallback();
    }

    // Half-open probe gate: after cooldown expires, let only one request probe primary
    const isHalfOpen = sharedCircuitOpenUntil > 0 && Date.now() >= sharedCircuitOpenUntil;
    let acquiredProbe = false;
    if (isHalfOpen) {
      if (halfOpenProbeInFlight) {
        return runFallback();
      }
      halfOpenProbeInFlight = true;
      acquiredProbe = true;
    }

    try {
      const result = await runPrimary();
      this.recordSuccess();
      return result;
    } catch (err) {
      if (this.isSafetyOrPolicyError(err)) {
        if (acquiredProbe) halfOpenProbeInFlight = false;
        throw err;
      }
      this.recordFailure(err);
      return runFallback();
    }
  }

  async generateReplies(params: {
    message: string;
    tone: string;
    language: string;
    length: string;
    count: number;
  }): Promise<string[]> {
    return this.runWithFallback(
      () => this.primary.generateReplies(params),
      this.fallback ? () => this.fallback!.generateReplies(params) : undefined
    );
  }

  async generateCaptions(params: {
    topic: string;
    platform: string;
    tone: string;
    language: string;
    length: string;
    includeHooks: boolean;
    includeHashtags: boolean;
  }): Promise<{
    captions: string[];
    hooks: string[];
    callToActions: string[];
    hashtags: string[];
  }> {
    return this.runWithFallback(
      () => this.primary.generateCaptions(params),
      this.fallback ? () => this.fallback!.generateCaptions(params) : undefined
    );
  }

  async generateBios(params: {
    interests: string;
    platform: string;
    vibe: string;
    language: string;
    includeUsernames: boolean;
  }): Promise<{
    bios: string[];
    usernames: string[];
  }> {
    return this.runWithFallback(
      () => this.primary.generateBios(params),
      this.fallback ? () => this.fallback!.generateBios(params) : undefined
    );
  }

  async vibeCheck(params: {
    text: string;
    mode: string;
    language: string;
  }): Promise<{
    score: number;
    title: string;
    verdict: string;
    tags: string[];
    rewrites: string[];
  }> {
    return this.runWithFallback(
      () => this.primary.vibeCheck(params),
      this.fallback ? () => this.fallback!.vibeCheck(params) : undefined
    );
  }
}
