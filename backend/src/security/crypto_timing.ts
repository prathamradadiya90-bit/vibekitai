/**
 * Constant-time string comparison utility using SHA-256 digest normalization.
 * Protects secrets, API tokens, and HMACs against timing side-channel attacks.
 */
export async function timingSafeEqual(a: string, b: string): Promise<boolean> {
  const enc = new TextEncoder();
  const [aHash, bHash] = await Promise.all([
    crypto.subtle.digest('SHA-256', enc.encode(a)),
    crypto.subtle.digest('SHA-256', enc.encode(b)),
  ]);

  const aView = new Uint8Array(aHash);
  const bView = new Uint8Array(bHash);

  let diff = 0;
  for (let i = 0; i < 32; i++) {
    diff |= (aView[i] ?? 0) ^ (bView[i] ?? 0);
  }

  return diff === 0 && a.length === b.length;
}
