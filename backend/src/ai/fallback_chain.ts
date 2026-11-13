import { AIProvider } from './factory';

export class FallbackChainAIProvider implements AIProvider {
  private primary: AIProvider;
  private fallback?: AIProvider;
  private failureCount = 0;
  private circuitOpenUntil = 0;
  private readonly failureThreshold = 3;
  private readonly circuitCooldownMs = 60000; // 60 seconds

  constructor(primary: AIProvider, fallback?: AIProvider) {
    this.primary = primary;
    this.fallback = fallback;
  }

  private isCircuitOpen(): boolean {
    return Date.now() < this.circuitOpenUntil;
  }

  private recordSuccess(): void {
    this.failureCount = 0;
    this.circuitOpenUntil = 0;
  }

  private recordFailure(error: any): void {
    const errMessage = (error?.message || String(error)).toUpperCase();
    // Prompt safety violations are user input validation errors, not provider outages
    if (errMessage.includes('SAFETY_VIOLATION') || errMessage.includes('SAFETY')) {
      return;
    }

    this.failureCount += 1;
    console.warn(`Primary AI provider failure #${this.failureCount}:`, error?.message || error);
    if (this.failureCount >= this.failureThreshold) {
      this.circuitOpenUntil = Date.now() + this.circuitCooldownMs;
      console.warn(`Circuit breaker tripped. Routing all AI traffic to fallback for ${this.circuitCooldownMs / 1000}s`);
    }
  }

  async generateReplies(params: {
    message: string;
    tone: string;
    language: string;
    length: string;
    count: number;
  }): Promise<string[]> {
    if (!this.fallback) {
      return this.primary.generateReplies(params);
    }

    if (this.isCircuitOpen()) {
      return this.fallback.generateReplies(params);
    }

    try {
      const result = await this.primary.generateReplies(params);
      this.recordSuccess();
      return result;
    } catch (err) {
      this.recordFailure(err);
      return this.fallback.generateReplies(params);
    }
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
    if (!this.fallback) {
      return this.primary.generateCaptions(params);
    }

    if (this.isCircuitOpen()) {
      return this.fallback.generateCaptions(params);
    }

    try {
      const result = await this.primary.generateCaptions(params);
      this.recordSuccess();
      return result;
    } catch (err) {
      this.recordFailure(err);
      return this.fallback.generateCaptions(params);
    }
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
    if (!this.fallback) {
      return this.primary.generateBios(params);
    }

    if (this.isCircuitOpen()) {
      return this.fallback.generateBios(params);
    }

    try {
      const result = await this.primary.generateBios(params);
      this.recordSuccess();
      return result;
    } catch (err) {
      this.recordFailure(err);
      return this.fallback.generateBios(params);
    }
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
    if (!this.fallback) {
      return this.primary.vibeCheck(params);
    }

    if (this.isCircuitOpen()) {
      return this.fallback.vibeCheck(params);
    }

    try {
      const result = await this.primary.vibeCheck(params);
      this.recordSuccess();
      return result;
    } catch (err) {
      this.recordFailure(err);
      return this.fallback.vibeCheck(params);
    }
  }
}
