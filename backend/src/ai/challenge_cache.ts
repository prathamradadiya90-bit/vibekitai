// Daily Challenge Response Cache
// IMPORTANT PRIVACY GUARANTEE: This cache is strictly utilized for pre-seeded
// public daily creative challenges. It is NEVER used for user-private custom inputs.

import { sha256Hex } from '../security/play_integrity';

export async function getCachedChallengeResponse<T>(
  db: D1Database | undefined,
  challengeId: string,
  tone: string,
  language: string,
  category: 'reply' | 'caption' | 'bio' | 'vibe_check'
): Promise<T | null> {
  if (!db) return null;

  const normalized = `challenge_${challengeId}_${tone.toLowerCase()}_${language.toLowerCase()}`;
  const cacheKey = await sha256Hex(normalized);
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
  ttlHours = 24
): Promise<void> {
  if (!db) return;

  const normalized = `challenge_${challengeId}_${tone.toLowerCase()}_${language.toLowerCase()}`;
  const cacheKey = await sha256Hex(normalized);
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
