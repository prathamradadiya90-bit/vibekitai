import { Hono } from 'hono';
import { AppHonoEnv } from '../types';
import {
  ReplyRequestSchema,
  ReplyOutputSchema,
  ReplyRequest,
  ReplyOutput,
  CaptionRequestSchema,
  CaptionOutputSchema,
  CaptionRequest,
  CaptionOutput,
  BioRequestSchema,
  BioOutputSchema,
  BioRequest,
  BioOutput,
  VibeCheckRequestSchema,
  VibeCheckOutputSchema,
  VibeCheckRequest,
  VibeCheckOutput,
} from '../schemas/validation';
import { runGeneration } from '../ai/pipeline';

export const generationsRoute = new Hono<AppHonoEnv>();

// 1. POST /v1/generations/reply
generationsRoute.post('/generations/reply', async (c) => {
  return runGeneration<ReplyRequest, ReplyOutput>(c, {
    category: 'reply',
    inputSchema: ReplyRequestSchema,
    outputSchema: ReplyOutputSchema,
    extractChallengeId: (req) => req.challenge_id,
    getCacheTone: (req) => req.tone,
    getCacheLanguage: (req) => req.language,
    generate: async (ai, req) => {
      const suggestions = await ai.generateReplies(req);
      return { suggestions };
    },
    formatResponse: (output, req, creditsRemaining, cached) => ({
      suggestions: output.suggestions,
      tone: req.tone,
      language: req.language,
      credits_remaining: creditsRemaining,
      ...(cached ? { cached: true } : {}),
    }),
  });
});

// 2. POST /v1/generations/caption
generationsRoute.post('/generations/caption', async (c) => {
  return runGeneration<CaptionRequest, CaptionOutput>(c, {
    category: 'caption',
    inputSchema: CaptionRequestSchema,
    outputSchema: CaptionOutputSchema,
    extractChallengeId: (req) => req.challenge_id,
    getCacheTone: (req) => req.tone,
    getCacheLanguage: (req) => req.language,
    generate: async (ai, req) => {
      const res = await ai.generateCaptions({
        topic: req.topic,
        platform: req.platform,
        tone: req.tone,
        language: req.language,
        length: req.length,
        includeHooks: req.include_hooks,
        includeHashtags: req.include_hashtags,
      });
      return {
        captions: res.captions,
        hooks: res.hooks,
        call_to_actions: res.callToActions,
        hashtags: res.hashtags,
      };
    },
    formatResponse: (output, req, creditsRemaining, cached) => ({
      captions: output.captions,
      hooks: output.hooks,
      call_to_actions: output.call_to_actions,
      hashtags: output.hashtags,
      platform: req.platform,
      tone: req.tone,
      language: req.language,
      credits_remaining: creditsRemaining,
      ...(cached ? { cached: true } : {}),
    }),
  });
});

// 3. POST /v1/generations/bio
generationsRoute.post('/generations/bio', async (c) => {
  return runGeneration<BioRequest, BioOutput>(c, {
    category: 'bio',
    inputSchema: BioRequestSchema,
    outputSchema: BioOutputSchema,
    getCacheTone: (req) => req.vibe,
    getCacheLanguage: (req) => req.language,
    generate: async (ai, req) => {
      const res = await ai.generateBios({
        interests: req.interests,
        platform: req.platform,
        vibe: req.vibe,
        language: req.language,
        includeUsernames: req.include_usernames,
      });
      return {
        bios: res.bios,
        usernames: res.usernames,
      };
    },
    formatResponse: (output, req, creditsRemaining) => ({
      bios: output.bios,
      usernames: output.usernames,
      platform: req.platform,
      vibe: req.vibe,
      language: req.language,
      credits_remaining: creditsRemaining,
    }),
  });
});

// 4. POST /v1/generations/vibe-check
generationsRoute.post('/generations/vibe-check', async (c) => {
  return runGeneration<VibeCheckRequest, VibeCheckOutput>(c, {
    category: 'vibe_check',
    inputSchema: VibeCheckRequestSchema,
    outputSchema: VibeCheckOutputSchema,
    getCacheTone: (req) => req.mode,
    getCacheLanguage: (req) => req.language,
    generate: async (ai, req) => {
      const res = await ai.vibeCheck({
        text: req.text,
        mode: req.mode,
        language: req.language,
      });
      return {
        score: res.score,
        title: res.title,
        verdict: res.verdict,
        tags: res.tags,
        rewrites: res.rewrites,
      };
    },
    formatResponse: (output, req, creditsRemaining) => ({
      score: output.score,
      title: output.title,
      verdict: output.verdict,
      tags: output.tags,
      rewrites: output.rewrites,
      mode: req.mode,
      language: req.language,
      credits_remaining: creditsRemaining,
    }),
  });
});
