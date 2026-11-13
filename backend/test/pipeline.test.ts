import { describe, it, expect } from 'vitest';
import app from '../src/index';
import { createMockEnv } from './fixtures';

describe('Shared Generation Pipeline & Central Errors', () => {
  const env = createMockEnv();

  it('validates input schema with ValidationError format', async () => {
    const res = await app.request(
      '/v1/generations/reply',
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          message: '', // empty violates min(1)
          tone: 'Funny',
          language: 'English',
        }),
      },
      env
    );

    expect(res.status).toBe(400);
    const json = (await res.json()) as any;
    expect(json.error).toBeDefined();
    expect(json.error.code).toBe('VALIDATION_ERROR');
    expect(json.error.details).toBeDefined();
  });

  it('runs reply generation successfully through the unified pipeline', async () => {
    const res = await app.request(
      '/v1/generations/reply',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-App-Instance-Id': 'pipeline_test_user_1',
        },
        body: JSON.stringify({
          message: 'Can we reschedule tomorrow?',
          tone: 'Friendly',
          language: 'English',
          count: 3,
        }),
      },
      env
    );

    expect(res.status).toBe(200);
    const json = (await res.json()) as any;
    expect(json.suggestions).toBeInstanceOf(Array);
    expect(json.suggestions.length).toBeGreaterThan(0);
    expect(json.credits_remaining).toBeDefined();
  });

  it('runs caption generation successfully through the unified pipeline', async () => {
    const res = await app.request(
      '/v1/generations/caption',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-App-Instance-Id': 'pipeline_test_user_2',
        },
        body: JSON.stringify({
          topic: 'Sunset over Mumbai skyline',
          platform: 'Instagram Reels',
          tone: 'Aesthetic',
          language: 'English',
        }),
      },
      env
    );

    expect(res.status).toBe(200);
    const json = (await res.json()) as any;
    expect(json.captions).toBeInstanceOf(Array);
    expect(json.captions.length).toBeGreaterThan(0);
    expect(json.credits_remaining).toBeDefined();
  });

  it('runs bio generation successfully through the unified pipeline', async () => {
    const res = await app.request(
      '/v1/generations/bio',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-App-Instance-Id': 'pipeline_test_user_3',
        },
        body: JSON.stringify({
          interests: 'Coffee, coding, open source AI',
          platform: 'Instagram',
          vibe: 'Minimalist',
          language: 'English',
        }),
      },
      env
    );

    expect(res.status).toBe(200);
    const json = (await res.json()) as any;
    expect(json.bios).toBeInstanceOf(Array);
    expect(json.bios.length).toBeGreaterThan(0);
    expect(json.credits_remaining).toBeDefined();
  });

  it('verifies config endpoint includes edge cache headers and typed constants', async () => {
    const res = await app.request('/v1/config', { method: 'GET' }, env);
    expect(res.status).toBe(200);
    expect(res.headers.get('Cache-Control')).toContain('max-age=300');
    const json = (await res.json()) as any;
    expect(json.daily_free_credits).toBe(3);
    expect(json.monthly_pro_credits).toBe(200);
  });
});
