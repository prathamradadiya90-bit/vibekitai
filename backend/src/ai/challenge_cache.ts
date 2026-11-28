// Daily Challenge Response Cache
// IMPORTANT PRIVACY GUARANTEE: Includes prompt/variant signature in cacheKey to prevent
// cross-category collisions and cross-user leakage of private prompts sharing a challengeId.

import { sha256Hex } from '../security/play_integrity';

async function buildCacheKey(
  category: 'reply' | 'caption' | 'bio' | 'vibe_check',
  challengeId: string,
  tone: string,
  language: string,
  variantSignature: string = ''
): Promise<string> {
  const normalized = `challenge_${category}_${challengeId}_${tone.toLowerCase()}_${language.toLowerCase()}_${variantSignature}`;
  return sha256Hex(normalized);
}

export async function getCachedChallengeResponse<T>(
  db: D1Database | undefined,
  challengeId: string,
  tone: string,
  language: string,
  category: 'reply' | 'caption' | 'bio' | 'vibe_check',
  variantSignature: string = ''
): Promise<T | null> {
  if (!db) return null;

  const cacheKey = await buildCacheKey(category, challengeId, tone, language, variantSignature);
  const nowIso = new Date().toISOString();

  try {
    const row = await db
      .prepare(
        'SELECT response_json FROM daily_challenge_cache WHERE cache_key = ? AND category = ? AND expires_at > ?'
      )
      .bind(cacheKey, category, nowIso)
      .first<{ response_json: string }>();

    if (row && row.response_json) {
      return JSON.parse(row.response_json) as T;
    }
  } catch (err) {
    console.warn('Daily challenge cache read error:', err);
  }

  return null;
}

export async function setCachedChallengeResponse(
  db: D1Database | undefined,
  challengeId: string,
  tone: string,
  language: string,
  category: 'reply' | 'caption' | 'bio' | 'vibe_check',
  data: any,
  variantSignature: string = '',
  ttlHours = 24
): Promise<void> {
  if (!db) return;

  const cacheKey = await buildCacheKey(category, challengeId, tone, language, variantSignature);
  const now = new Date();
  const expiresAt = new Date(now.getTime() + ttlHours * 60 * 60 * 1000);

  try {
    await db
      .prepare(
        `INSERT INTO daily_challenge_cache (cache_key, category, response_json, created_at, expires_at)
         VALUES (?, ?, ?, ?, ?)
         ON CONFLICT(cache_key) DO UPDATE SET
           response_json = excluded.response_json,
           expires_at = excluded.expires_at`
      )
      .bind(cacheKey, category, JSON.stringify(data), now.toISOString(), expiresAt.toISOString())
      .run();
  } catch (err) {
    console.warn('Daily challenge cache write error:', err);
  }
}
