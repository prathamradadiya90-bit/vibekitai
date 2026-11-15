import { describe, it, expect } from 'vitest';
import {
  ReplyRequestSchema,
  CaptionRequestSchema,
  BioRequestSchema,
  VibeCheckRequestSchema,
} from '../src/schemas/validation';
import { mockReplies, mockVibeCheck, mockBios, mockCaptions } from '../src/ai/mock_outputs';
import { buildReplyPrompt, buildVibeCheckPrompt, buildCaptionPrompt, buildBioPrompt } from '../src/ai/prompts';

describe('New High-Value Use Cases & Presets Audit', () => {
  it('validates ReplyRequestSchema accepts Unbothered and Opener tones', () => {
    const unbothered = ReplyRequestSchema.safeParse({
      message: 'why did you take so long to text me back?',
      tone: 'Unbothered',
      language: 'English',
    });
    expect(unbothered.success).toBe(true);

    const opener = ReplyRequestSchema.safeParse({
      message: 'Matched on dating app, she has photos with her golden retriever',
      tone: 'Opener',
      language: 'Hinglish',
    });
    expect(opener.success).toBe(true);
  });

  it('generates mock replies for Unbothered and Opener across languages', () => {
    const enUnbothered = mockReplies({ tone: 'Unbothered', language: 'English', count: 3 });
    expect(enUnbothered.length).toBe(3);
    expect(enUnbothered[0]).toContain('All good');

    const hinglishOpener = mockReplies({ tone: 'Opener', language: 'Hinglish', count: 3 });
    expect(hinglishOpener.length).toBe(3);
    expect(hinglishOpener[0]).toContain('chai ya coffee');
  });

  it('validates VibeCheckRequestSchema accepts revival, apology, and overthinking modes', () => {
    const revival = VibeCheckRequestSchema.safeParse({
      text: 'Hey stranger, long time no see!',
      mode: 'revival',
      language: 'English',
    });
    expect(revival.success).toBe(true);

    const apology = VibeCheckRequestSchema.safeParse({
      text: 'Sorry for being snappy earlier, had a rough day at work.',
      mode: 'apology',
      language: 'English',
    });
    expect(apology.success).toBe(true);

    const overthinking = VibeCheckRequestSchema.safeParse({
      text: 'I know you are super busy and probably do not care, but if you have a minute maybe we could talk?',
      mode: 'overthinking',
      language: 'English',
    });
    expect(overthinking.success).toBe(true);
  });

  it('generates rich mock evaluations for revival, apology, and overthinking modes', () => {
    const revivalEval = mockVibeCheck({
      text: 'Hey stranger!',
      mode: 'revival',
      language: 'English',
    });
    expect(revivalEval.score).toBeGreaterThanOrEqual(80);
    expect(revivalEval.title).toContain('Zombie');
    expect(revivalEval.rewrites.length).toBe(3);
    expect(revivalEval.tags).toContain('🧟 Ghosting Revival');

    const apologyEval = mockVibeCheck({
      text: 'Sorry I was late',
      mode: 'apology',
      language: 'English',
    });
    expect(apologyEval.score).toBeGreaterThanOrEqual(85);
    expect(apologyEval.tags).toContain('🤝 Restores Trust');
    expect(apologyEval.rewrites.length).toBe(3);

    const overthinkEval = mockVibeCheck({
      text: 'So much text...',
      mode: 'overthinking',
      language: 'English',
    });
    expect(overthinkEval.score).toBeGreaterThanOrEqual(85);
    expect(overthinkEval.tags).toContain('🧠 Overthinking Antidote');
    expect(overthinkEval.rewrites.length).toBe(3);
  });

  it('validates CaptionRequestSchema accepts TikTok & Shorts and Threads & X', () => {
    const tiktok = CaptionRequestSchema.safeParse({
      topic: 'Morning routine before 7 AM',
      platform: 'TikTok & Shorts',
      tone: 'Trendy',
      language: 'English',
    });
    expect(tiktok.success).toBe(true);

    const threads = CaptionRequestSchema.safeParse({
      topic: 'Why working remotely is better for creativity',
      platform: 'Threads & X',
      tone: 'Witty',
      language: 'English',
    });
    expect(threads.success).toBe(true);
  });

  it('validates BioRequestSchema accepts Dating App platform', () => {
    const datingBio = BioRequestSchema.safeParse({
      interests: 'Matcha, indie rock, bouldering, board games',
      platform: 'Dating App',
      vibe: 'Aesthetic',
      language: 'English',
    });
    expect(datingBio.success).toBe(true);
  });

  it('builds valid prompts for the new modes and tones without leakage', () => {
    const promptPair = buildVibeCheckPrompt({
      text: 'Hey sorry for ghosting!',
      mode: 'revival',
      language: 'English',
    });
    expect(promptPair.system).toContain('Ghosting revival');
    expect(promptPair.user).toContain('Hey sorry for ghosting!');
    expect(promptPair.system).not.toContain('temperature');
  });
});
