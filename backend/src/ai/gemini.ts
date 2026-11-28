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

declare const process: any;

const GEMINI_SAFETY_FINISH_REASONS = new Set([
  'SAFETY',
  'PROHIBITED_CONTENT',
  'BLOCKLIST',
  'SPII',
  'RECITATION',
]);

function extractJsonObject(raw: string): GenerationResult | null {
  try {
    return JSON.parse(raw) as GenerationResult;
  } catch {
    const fenced = raw.match(/```(?:json)?\s*([\s\S]*?)\s*```/i);
    if (fenced && fenced[1] && fenced[1].trim()) {
      try {
        return JSON.parse(fenced[1]) as GenerationResult;
      } catch {
        // fall through to brace matching
      }
    }
    const start = raw.indexOf('{');
    const end = raw.lastIndexOf('}');
    if (start !== -1 && end > start) {
      try {
        return JSON.parse(raw.slice(start, end + 1)) as GenerationResult;
      } catch {
        return null;
      }
    }
    return null;
  }
}

export class GeminiProvider {
  private apiKey?: string;
  private model: string;
  private isDevelopmentOrTest: boolean;

  constructor(env: Env) {
    this.apiKey = env.GEMINI_API_KEY || (typeof process !== 'undefined' ? process.env?.GEMINI_API_KEY : undefined);
    this.model = env.GEMINI_MODEL || (typeof process !== 'undefined' ? process.env?.GEMINI_MODEL : undefined) || 'gemini-2.0-flash';
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
      return mockReplies(params);
    }

    const prompt = buildReplyPrompt(params);
    const result = await this.callGeminiWithSafety(prompt.system, prompt.user, 'reply');
    const suggestions = humanizeList(result?.suggestions, params.count);
    if (suggestions.length > 0) return suggestions;

    throw new Error('Gemini returned empty reply suggestions.');
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
      return mockCaptions(params);
    }

    const prompt = buildCaptionPrompt(params);
    const result = await this.callGeminiWithSafety(prompt.system, prompt.user, 'caption');
    const captions = humanizeList(result?.captions, 3);
    if (result && captions.length > 0) {
      return {
        captions,
        hooks: params.includeHooks ? humanizeList(result.hooks, 2) : [],
        callToActions: humanizeList(result.call_to_actions, 2),
        hashtags: params.includeHashtags ? normalizeHashtags(result.hashtags).slice(0, 12) : [],
      };
    }

    throw new Error('Gemini returned empty captions.');
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
      return mockBios(params);
    }

    const prompt = buildBioPrompt(params);
    const result = await this.callGeminiWithSafety(prompt.system, prompt.user, 'bio');
    const bios = humanizeList(result?.bios, 3);
    if (result && bios.length > 0) {
      return {
        bios,
        usernames: params.includeUsernames ? normalizeUsernames(result.usernames).slice(0, 5) : [],
      };
    }

    throw new Error('Gemini returned empty bios.');
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
      return mockVibeCheck(params);
    }

    const prompt = buildVibeCheckPrompt(params);
    const result = await this.callGeminiWithSafety(prompt.system, prompt.user, 'vibe_check');
    const rewrites = humanizeList(result?.rewrites, 3);
    const score = typeof result?.score === 'number' && Number.isFinite(result.score) ? result.score : NaN;
    if (result && Number.isFinite(score) && rewrites.length > 0) {
      const normalizedTags = humanizeList(result.tags, 4).map((t) =>
        t.startsWith('#') ? t : `#${t.replace(/\s+/g, '')}`
      );
      const title =
        typeof result.title === 'string' && result.title.trim().length > 0
          ? result.title.trim()
          : 'Vibe Check';
      const verdict =
        typeof result.verdict === 'string' && result.verdict.trim().length > 0
          ? result.verdict.trim()
          : 'Analysis completed.';
      return {
        score: Math.min(100, Math.max(0, Math.round(score))),
        title,
        verdict,
        tags: normalizedTags.length > 0 ? normalizedTags : ['#VibeCheck', '#SocialTone', '#LeveledUp'],
        rewrites,
      };
    }

    throw new Error('Gemini returned invalid vibe check payload.');
  }

  private async callGeminiWithSafety(
    systemInstruction: string,
    prompt: string,
    task: TaskKind
  ): Promise<GenerationResult | null> {
    try {
      return await this.callGeminiApi(systemInstruction, prompt, task);
    } catch (err: any) {
      const msg = String(err?.message || err);
      if (msg.toUpperCase().includes('SAFETY_VIOLATION')) {
        throw err;
      }
      throw err instanceof Error ? err : new Error(msg);
    }
  }

  private async callGeminiApi(
    systemInstruction: string,
    prompt: string,
    task: TaskKind
  ): Promise<GenerationResult | null> {
    const sampling = SAMPLING[task];
    if (!this.apiKey) {
      throw new Error('GEMINI_API_KEY is not configured on the server.');
    }

    const url = `https://generativelanguage.googleapis.com/v1beta/models/${this.model}:generateContent`;

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

    try {
      const response = await safeFetch(
        url,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': this.apiKey,
          },
          body: JSON.stringify(payload),
          signal: controller.signal,
        },
        this.isDevelopmentOrTest
      );

      if (!response.ok) {
        const errText = await response.text().catch(() => '');
        console.warn(`Gemini upstream HTTP ${response.status}:`, errText.slice(0, 200));
        throw new Error(`Gemini API HTTP ${response.status}`);
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
      if (candidate?.finishReason && GEMINI_SAFETY_FINISH_REASONS.has(candidate.finishReason)) {
        throw new Error(`SAFETY_VIOLATION: The prompt triggered safety filter (${candidate.finishReason}).`);
      }

      const text = (candidate?.content?.parts ?? [])
        .map((p) => p.text ?? '')
        .join('')
        .trim();
      if (!text) return null;

      return extractJsonObject(text);
    } finally {
      clearTimeout(timer);
    }
  }
}
