import { Env } from '../types';
import { GeminiProvider } from './gemini';
import { OpenAICompatibleProvider } from './openai_compatible';
import { FallbackChainAIProvider } from './fallback_chain';

export interface AIProvider {
  generateReplies(params: {
    message: string;
    tone: string;
    language: string;
    length: string;
    count: number;
  }): Promise<string[]>;

  generateCaptions(params: {
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
  }>;

  generateBios(params: {
    interests: string;
    platform: string;
    vibe: string;
    language: string;
    includeUsernames: boolean;
  }): Promise<{
    bios: string[];
    usernames: string[];
  }>;

  vibeCheck(params: {
    text: string;
    mode: string;
    language: string;
  }): Promise<{
    score: number;
    title: string;
    verdict: string;
    tags: string[];
    rewrites: string[];
  }>;
}

function createSingleProvider(
  providerType: string | undefined,
  apiKey: string | undefined,
  baseUrl: string | undefined,
  model: string | undefined,
  env: Env
): AIProvider {
  if (apiKey && (providerType === 'groq' || (!providerType && baseUrl?.includes('groq')))) {
    return new OpenAICompatibleProvider(apiKey, baseUrl || 'https://api.groq.com/openai/v1', model || 'llama-3.3-70b-versatile');
  }

  if (apiKey && (providerType === 'openrouter' || baseUrl?.includes('openrouter'))) {
    return new OpenAICompatibleProvider(apiKey, baseUrl || 'https://openrouter.ai/api/v1', model || 'meta-llama/llama-3.3-70b-instruct:free');
  }

  if (apiKey && (providerType === 'openai' || baseUrl?.includes('openai.com'))) {
    return new OpenAICompatibleProvider(apiKey, baseUrl || 'https://api.openai.com/v1', model || 'gpt-4o-mini');
  }

  if (apiKey && baseUrl) {
    return new OpenAICompatibleProvider(apiKey, baseUrl, model || 'llama-3.3-70b-versatile');
  }

  return new GeminiProvider(env);
}

export function createAIProvider(env: Env): AIProvider {
  // Determine Primary Provider
  const primaryProvider = createSingleProvider(
    env.AI_PROVIDER,
    env.AI_API_KEY || env.GEMINI_API_KEY,
    env.AI_BASE_URL,
    env.AI_MODEL || env.GEMINI_MODEL,
    env
  );

  // Determine Secondary / Fallback Provider
  let fallbackProvider: AIProvider | undefined;
  if (env.FALLBACK_AI_API_KEY || env.GROQ_API_KEY || env.OPENROUTER_API_KEY) {
    fallbackProvider = createSingleProvider(
      env.FALLBACK_AI_PROVIDER || (env.GROQ_API_KEY ? 'groq' : 'openrouter'),
      env.FALLBACK_AI_API_KEY || env.GROQ_API_KEY || env.OPENROUTER_API_KEY,
      env.FALLBACK_AI_BASE_URL,
      env.FALLBACK_AI_MODEL,
      env
    );
  }

  // Wrap in Fallback Chain with Circuit Breaker
  return new FallbackChainAIProvider(primaryProvider, fallbackProvider);
}
