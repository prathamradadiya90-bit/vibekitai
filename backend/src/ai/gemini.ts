import { Env } from '../types';
import { safeFetch } from '../security/safe_fetch';
import {
  SAMPLING,
  TaskKind,
  buildBioPrompt,
  buildCaptionPrompt,
  buildReplyPrompt,
  buildVibeCheckPrompt,
  humanizeList,
  normalizeHashtags,
  normalizeUsernames,
} from './prompts';
import { mockBios, mockCaptions, mockReplies, mockVibeCheck } from './mock_outputs';

export interface GenerationResult {
  suggestions?: string[];
  bios?: string[];
  usernames?: string[];
  captions?: string[];
  hooks?: string[];
  call_to_actions?: string[];
  hashtags?: string[];
  score?: number;
  title?: string;
  verdict?: string;
  tags?: string[];
  rewrites?: string[];
}

export class GeminiProvider {
  private apiKey?: string;
  private model: string;
  private isDevelopmentOrTest: boolean;

  constructor(env: Env) {
    this.apiKey = env.GEMINI_API_KEY;
    this.model = env.GEMINI_MODEL || 'gemini-2.0-flash';
    this.isDevelopmentOrTest = env.ENVIRONMENT === 'development' || env.ENVIRONMENT === 'test';
  }

  async generateReplies(params: {
    message: string;
    tone: string;
    language: string;
    length: string;
    count: number;
  }): Promise<string[]> {
    if (!this.apiKey) {
      if (this.isDevelopmentOrTest) return mockReplies(params);
      throw new Error('GEMINI_API_KEY is not configured on the server.');
    }

    const prompt = buildReplyPrompt(params);
    let result: GenerationResult | null = null;
    try {
      result = await this.callGeminiApi(prompt.system, prompt.user, 'reply');
    } catch (err: any) {
      if (this.isDevelopmentOrTest) {
        console.warn('Gemini API call failed in dev/test, using fallback mock:', err?.message || err);
        return mockReplies(params);
      }
      throw err;
    }
    const suggestions = humanizeList(result?.suggestions, params.count);
    if (suggestions.length > 0) return suggestions;

    if (this.isDevelopmentOrTest) return mockReplies(params);
    throw new Error('AI generation failed to produce valid reply suggestions.');
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
    if (!this.apiKey) {
      if (this.isDevelopmentOrTest) return mockCaptions(params);
      throw new Error('GEMINI_API_KEY is not configured on the server.');
    }

    const prompt = buildCaptionPrompt(params);
    let result: GenerationResult | null = null;
    try {
      result = await this.callGeminiApi(prompt.system, prompt.user, 'caption');
    } catch (err: any) {
      if (this.isDevelopmentOrTest) {
        console.warn('Gemini API call failed in dev/test, using fallback mock:', err?.message || err);
        return mockCaptions(params);
      }
      throw err;
    }
    const captions = humanizeList(result?.captions, 3);
    if (result && captions.length > 0) {
      return {
        captions,
        hooks: params.includeHooks ? humanizeList(result.hooks, 2) : [],
        callToActions: humanizeList(result.call_to_actions, 2),
        hashtags: params.includeHashtags ? normalizeHashtags(result.hashtags).slice(0, 12) : [],
      };
    }

    if (this.isDevelopmentOrTest) return mockCaptions(params);
    throw new Error('AI generation failed to produce valid caption suggestions.');
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
    if (!this.apiKey) {
      if (this.isDevelopmentOrTest) return mockBios(params);
      throw new Error('GEMINI_API_KEY is not configured on the server.');
    }

    const prompt = buildBioPrompt(params);
    let result: GenerationResult | null = null;
    try {
      result = await this.callGeminiApi(prompt.system, prompt.user, 'bio');
    } catch (err: any) {
      if (this.isDevelopmentOrTest) {
        console.warn('Gemini API call failed in dev/test, using fallback mock:', err?.message || err);
        return mockBios(params);
      }
      throw err;
    }
    const bios = humanizeList(result?.bios, 3);
    if (result && bios.length > 0) {
      return {
        bios,
        usernames: params.includeUsernames ? normalizeUsernames(result.usernames).slice(0, 5) : [],
      };
    }

    if (this.isDevelopmentOrTest) return mockBios(params);
    throw new Error('AI generation failed to produce valid bio suggestions.');
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
    if (!this.apiKey) {
      if (this.isDevelopmentOrTest) return mockVibeCheck(params);
      throw new Error('GEMINI_API_KEY is not configured on the server.');
    }

    const prompt = buildVibeCheckPrompt(params);

    let result: GenerationResult | null = null;
    try {
      result = await this.callGeminiApi(prompt.system, prompt.user, 'vibe_check');
    } catch (err: any) {
      if (this.isDevelopmentOrTest) {
        console.warn('Gemini API call failed in dev/test, using fallback mock:', err?.message || err);
        return mockVibeCheck(params);
      }
      throw err;
    }
    if (result && typeof result.score === 'number' && Array.isArray(result.rewrites) && result.rewrites.length > 0) {
      return {
        score: Math.min(100, Math.max(0, Math.round(result.score))),
        title: result.title || 'Vibe Check',
        verdict: result.verdict || 'Analysis completed.',
        tags: Array.isArray(result.tags) && result.tags.length > 0
          ? result.tags.slice(0, 4).map(t => t.startsWith('#') ? t : `#${t.replace(/\s+/g, '')}`)
          : ['#VibeCheck', '#SocialTone', '#LeveledUp'],
        rewrites: humanizeList(result.rewrites, 3),
      };
    }

    if (this.isDevelopmentOrTest) return mockVibeCheck(params);
    throw new Error('AI generation failed to produce valid vibe check evaluation.');
  }

  private async callGeminiApi(systemInstruction: string, prompt: string, task: TaskKind): Promise<GenerationResult | null> {
    const sampling = SAMPLING[task];
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${this.model}:generateContent?key=${this.apiKey}`;

    const payload = {
      systemInstruction: {
        parts: [{ text: systemInstruction }],
      },
      contents: [
        {
          role: 'user',
          parts: [{ text: prompt }],
        },
      ],
      generationConfig: {
        responseMimeType: 'application/json',
        temperature: sampling.temperature,
        topP: sampling.topP,
        maxOutputTokens: 1024,
      },
      safetySettings: [
        { category: 'HARM_CATEGORY_HARASSMENT', threshold: 'BLOCK_MEDIUM_AND_ABOVE' },
        { category: 'HARM_CATEGORY_HATE_SPEECH', threshold: 'BLOCK_MEDIUM_AND_ABOVE' },
        { category: 'HARM_CATEGORY_SEXUALLY_EXPLICIT', threshold: 'BLOCK_MEDIUM_AND_ABOVE' },
        { category: 'HARM_CATEGORY_DANGEROUS_CONTENT', threshold: 'BLOCK_MEDIUM_AND_ABOVE' },
      ],
    };

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 15000);

    let response: Response;
    try {
      response = await safeFetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
        signal: controller.signal,
      }, this.isDevelopmentOrTest);
    } finally {
      clearTimeout(timer);
    }

    if (!response.ok) {
      const errText = await response.text();
      throw new Error(`Gemini API error (${response.status}): ${errText}`);
    }

    interface GeminiCandidate {
      finishReason?: string;
      content?: {
        parts?: Array<{ text?: string }>;
      };
    }
    interface GeminiApiResponse {
      promptFeedback?: { blockReason?: string };
      candidates?: GeminiCandidate[];
    }

    const data = (await response.json()) as GeminiApiResponse;
    if (data.promptFeedback?.blockReason) {
      throw new Error(`SAFETY_VIOLATION: The prompt was blocked (${data.promptFeedback.blockReason}).`);
    }

    const candidate = data.candidates?.[0];
    if (candidate?.finishReason === 'SAFETY') {
      throw new Error('SAFETY_VIOLATION: The prompt triggered automated safety filters.');
    }

    const text = candidate?.content?.parts?.[0]?.text;
    if (!text) return null;

    try {
      return JSON.parse(text) as GenerationResult;
    } catch {
      const jsonMatch = text.match(/```json\s*([\s\S]*?)\s*```/) || text.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        try {
          return JSON.parse(jsonMatch[1] || jsonMatch[0] || '{}') as GenerationResult;
        } catch {
          return null;
        }
      }
      return null;
    }
  }
}
