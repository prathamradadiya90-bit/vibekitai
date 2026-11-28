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

function extractJsonObject(content: string): any {
  try {
    return JSON.parse(content);
  } catch {
    const fenced = content.match(/```(?:json)?\s*([\s\S]*?)\s*```/i);
    if (fenced && fenced[1] && fenced[1].trim()) {
      try {
        return JSON.parse(fenced[1]);
      } catch {
        // fall through
      }
    }
    const start = content.indexOf('{');
    const end = content.lastIndexOf('}');
    if (start !== -1 && end > start) {
      try {
        return JSON.parse(content.slice(start, end + 1));
      } catch {
        throw new Error('Failed to parse JSON response from AI provider.');
      }
    }
    throw new Error('Failed to parse JSON response from AI provider.');
  }
}

export class OpenAICompatibleProvider {
  private apiKey: string;
  private baseUrl: string;
  private model: string;
  private allowLocalhostInDev: boolean;

  constructor(apiKey: string, baseUrl: string, model: string, allowLocalhostInDev: boolean = false) {
    this.apiKey = apiKey;
    this.baseUrl = baseUrl.endsWith('/') ? baseUrl.slice(0, -1) : baseUrl;
    this.model = model;
    this.allowLocalhostInDev = allowLocalhostInDev;
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
    throw new Error('AI provider returned an invalid format for vibe check.');
  }

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
      ...(this.supportsPenalties()
        ? {
            presence_penalty: sampling.presencePenalty,
            frequency_penalty: sampling.frequencyPenalty,
          }
        : {}),
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
            Authorization: `Bearer ${this.apiKey}`,
          },
          body: JSON.stringify(payload),
          signal: controller.signal,
        },
        this.allowLocalhostInDev
      );

      if (!response.ok) {
        const errText = await response.text().catch(() => '');
        console.warn(`OpenAI-compatible API HTTP ${response.status}:`, errText.slice(0, 200));
        if (/content_filter|policy_violation|moderation/i.test(errText)) {
          throw new Error('SAFETY_VIOLATION: Request blocked by AI content policy.');
        }
        throw new Error(`AI API HTTP ${response.status}`);
      }

      interface ChatCompletionResponse {
        choices?: Array<{
          finish_reason?: string;
          message?: {
            content?: string;
          };
        }>;
      }

      const data = (await response.json()) as ChatCompletionResponse;
      const choice = data.choices?.[0];
      if (choice?.finish_reason === 'content_filter') {
        throw new Error('SAFETY_VIOLATION: The response triggered automated safety filters.');
      }
      const content = choice?.message?.content;
      if (!content) {
        throw new Error('Empty response from AI completion.');
      }

      return extractJsonObject(content);
    } finally {
      clearTimeout(timer);
    }
  }
}
