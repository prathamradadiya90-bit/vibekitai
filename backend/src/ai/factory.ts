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

function resolveKeyForProvider(providerType: string | undefined, explicitKey: string | undefined, env: Env): string | undefined {
  if (explicitKey) return explicitKey;
  switch (providerType) {
    case 'groq':
      return env.GROQ_API_KEY;
    case 'openrouter':
      return env.OPENROUTER_API_KEY;
    case 'openai':
      return env.OPENAI_API_KEY;
    case 'gemini':
      return env.GEMINI_API_KEY;
    default:
      return env.GEMINI_API_KEY;
  }
}

function createSingleProvider(
  providerType: string | undefined,
  apiKey: string | undefined,
  baseUrl: string | undefined,
  model: string | undefined,
  env: Env
): AIProvider {
  const allowLocalhostInDev = env.ENVIRONMENT === 'development' || env.ENVIRONMENT === 'test';
  const normalizedType = providerType?.toLowerCase().trim();

  if (normalizedType === 'gemini') {
    return new GeminiProvider({ ...env, GEMINI_API_KEY: apiKey || env.GEMINI_API_KEY, GEMINI_MODEL: model || env.GEMINI_MODEL });
  }

  if (apiKey && (normalizedType === 'groq' || (!normalizedType && baseUrl?.includes('groq')))) {
    return new OpenAICompatibleProvider(apiKey, baseUrl || 'https://api.groq.com/openai/v1', model || 'llama-3.3-70b-versatile', allowLocalhostInDev);
  }

  if (apiKey && (normalizedType === 'openrouter' || (!normalizedType && baseUrl?.includes('openrouter')))) {
    return new OpenAICompatibleProvider(apiKey, baseUrl || 'https://openrouter.ai/api/v1', model || 'meta-llama/llama-3.3-70b-instruct:free', allowLocalhostInDev);
  }

  if (apiKey && (normalizedType === 'openai' || (!normalizedType && baseUrl?.includes('openai.com')))) {
    return new OpenAICompatibleProvider(apiKey, baseUrl || 'https://api.openai.com/v1', model || 'gpt-4o-mini', allowLocalhostInDev);
  }

  if (apiKey && baseUrl) {
    return new OpenAICompatibleProvider(apiKey, baseUrl, model || 'llama-3.3-70b-versatile', allowLocalhostInDev);
  }

  return new GeminiProvider(env);
}

export function createAIProvider(env: Env): AIProvider {
  const primaryType = env.AI_PROVIDER?.toLowerCase().trim();
  const primaryKey = resolveKeyForProvider(primaryType, env.AI_API_KEY, env);
  const primaryModel = env.AI_MODEL || (!primaryType || primaryType === 'gemini' ? env.GEMINI_MODEL : undefined);

  const primaryProvider = createSingleProvider(
    primaryType,
    primaryKey,
    env.AI_BASE_URL,
    primaryModel,
    env
  );

  // Secondary / Fallback Provider: match fallback provider key cleanly without bleeding Groq keys into OpenRouter
  const fallbackType =
    env.FALLBACK_AI_PROVIDER?.toLowerCase().trim() ||
    (primaryType !== 'groq' && env.GROQ_API_KEY
      ? 'groq'
      : primaryType !== 'openrouter' && env.OPENROUTER_API_KEY
      ? 'openrouter'
      : primaryType !== 'openai' && env.OPENAI_API_KEY
      ? 'openai'
      : undefined);

  let fallbackProvider: AIProvider | undefined;
  if (fallbackType && fallbackType !== primaryType) {
    const fallbackKey = resolveKeyForProvider(fallbackType, env.FALLBACK_AI_API_KEY, env);
    if (fallbackKey || fallbackType === 'gemini') {
      fallbackProvider = createSingleProvider(
        fallbackType,
        fallbackKey,
        env.FALLBACK_AI_BASE_URL,
        env.FALLBACK_AI_MODEL,
        env
      );
    }
  } else if (env.FALLBACK_AI_API_KEY && env.FALLBACK_AI_BASE_URL) {
    fallbackProvider = createSingleProvider(
      fallbackType,
      env.FALLBACK_AI_API_KEY,
      env.FALLBACK_AI_BASE_URL,
      env.FALLBACK_AI_MODEL,
      env
    );
  }

  return new FallbackChainAIProvider(primaryProvider, fallbackProvider);
}
