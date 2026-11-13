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

export class OpenAICompatibleProvider {
  private apiKey: string;
  private baseUrl: string;
  private model: string;

  constructor(apiKey: string, baseUrl: string, model: string) {
    this.apiKey = apiKey;
    this.baseUrl = baseUrl.endsWith('/') ? baseUrl.slice(0, -1) : baseUrl;
    this.model = model;
  }

  async generateReplies(params: {
    message: string;
    tone: string;
    language: string;
    length: string;
    count: number;
  }): Promise<string[]> {
    const prompt = buildReplyPrompt(params);
    const result = await this.callChatCompletion(prompt.system, prompt.user, 'reply');
    const suggestions = humanizeList(result?.suggestions, params.count);
    if (suggestions.length > 0) return suggestions;
    throw new Error('AI provider returned an invalid format for replies.');
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
    const prompt = buildCaptionPrompt(params);
    const result = await this.callChatCompletion(prompt.system, prompt.user, 'caption');
    const captions = humanizeList(result?.captions, 3);
    if (captions.length > 0) {
      return {
        captions,
        hooks: params.includeHooks ? humanizeList(result.hooks, 2) : [],
        callToActions: humanizeList(result.call_to_actions, 2),
        hashtags: params.includeHashtags ? normalizeHashtags(result.hashtags).slice(0, 12) : [],
      };
    }
    throw new Error('AI provider returned an invalid format for captions.');
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
    const prompt = buildBioPrompt(params);
    const result = await this.callChatCompletion(prompt.system, prompt.user, 'bio');
    const bios = humanizeList(result?.bios, 3);
    if (bios.length > 0) {
      return {
        bios,
        usernames: params.includeUsernames ? normalizeUsernames(result.usernames).slice(0, 5) : [],
      };
    }
    throw new Error('AI provider returned an invalid format for bios.');
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
    const prompt = buildVibeCheckPrompt(params);

    const result = await this.callChatCompletion(prompt.system, prompt.user, 'vibe_check');
    if (result && typeof result.score === 'number' && Array.isArray(result.rewrites) && result.rewrites.length > 0) {
      return {
        score: Math.min(100, Math.max(0, Math.round(result.score))),
        title: result.title || 'Vibe Check',
        verdict: result.verdict || 'Analysis completed.',
        tags: Array.isArray(result.tags) && result.tags.length > 0
          ? result.tags.slice(0, 4).map((t: string) => t.startsWith('#') ? t : `#${t.replace(/\s+/g, '')}`)
          : ['#VibeCheck', '#SocialTone', '#LeveledUp'],
        rewrites: humanizeList(result.rewrites, 3),
      };
    }
    throw new Error('AI provider returned an invalid format for vibe check.');
  }

  /** Groq rejects non-zero presence/frequency penalties on some models; OpenAI & OpenRouter accept them. */
  private supportsPenalties(): boolean {
    return !this.baseUrl.includes('groq.com');
  }

  private async callChatCompletion(systemPrompt: string, userPrompt: string, task: TaskKind): Promise<any> {
    const sampling = SAMPLING[task];
    const url = `${this.baseUrl}/chat/completions`;

    const payload = {
      model: this.model,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userPrompt },
      ],
      response_format: { type: 'json_object' },
      temperature: sampling.temperature,
      top_p: sampling.topP,
      max_tokens: 1024,
      // Penalties reduce repetitive phrasing; Groq/OpenRouter ignore or accept them safely.
      ...(this.supportsPenalties() ? {
        presence_penalty: sampling.presencePenalty,
        frequency_penalty: sampling.frequencyPenalty,
      } : {}),
    };

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 15000);

    let response: Response;
    try {
      response = await safeFetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${this.apiKey}`,
        },
        body: JSON.stringify(payload),
        signal: controller.signal,
      }, true);
    } finally {
      clearTimeout(timer);
    }

    if (!response.ok) {
      const errText = await response.text();
      throw new Error(`AI API error (${response.status}): ${errText}`);
    }

    interface ChatCompletionResponse {
      choices?: Array<{
        message?: {
          content?: string;
        };
      }>;
    }

    const data = (await response.json()) as ChatCompletionResponse;
    const content = data.choices?.[0]?.message?.content;
    if (!content) {
      throw new Error('Empty response from AI completion.');
    }

    try {
      return JSON.parse(content);
    } catch {
      // If model wrapped response in markdown json code block
      const jsonMatch = content.match(/```json\s*([\s\S]*?)\s*```/) || content.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        return JSON.parse(jsonMatch[1] || jsonMatch[0]);
      }
      throw new Error('Failed to parse JSON response from AI provider.');
    }
  }
}
