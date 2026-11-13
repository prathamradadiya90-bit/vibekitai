# ADR-0002: Hardware Device Attestation & Ephemeral Session Tokens

## Status
Accepted

## Context
The initial implementation of VibeKit AI identified client devices solely by reading the client-supplied HTTP header `X-App-Instance-Id`.
Because HTTP headers can be easily forged by curl scripts, emulators, or reverse-engineered bots, malicious actors can generate arbitrary UUIDs to obtain unlimited 3-credit free allocations, resulting in AI compute cost exhaustion.

## Decision
1. **Google Play Integrity API Attestation:**
   - The Flutter Android client requests a hardware-attested integrity token from the Google Play Integrity SDK upon app startup and prior to high-value actions (first generation, credit grant).
   - The backend validates the token with Google (`https://playintegrity.googleapis.com/v1/{packageName}:decodeIntegrityToken`) or decrypts it locally using Google Play service account credentials.
   - The token must meet:
     - `appLicensingVerdict: LICENSED`
     - `deviceRecognitionVerdict: [MEETS_DEVICE_INTEGRITY | MEETS_BASIC_INTEGRITY]`
     - `appRecognitionVerdict: PLAY_RECOGNIZED`
2. **Ephemeral Session Tokens (JWT):**
   - Upon successful verification of the Play Integrity token, the server issues a short-lived, cryptographically signed session token (HMAC-SHA256, 15-minute TTL).
   - The session token binds the `installation_id` to a SHA-256 hash of the device integrity verdict (`device_integrity_hash`).
   - Sensitive credit-spending routes (`/v1/generations/*`) validate this session token in the `Authorization: Bearer <token>` or `X-Session-Token` header.
3. **Fail-Closed vs. Fail-Soft Strategy:**
   - **Credit-granting actions** (ad SSV, referrals, purchases): Fail closed (hard rejection if integrity is invalid or unverified in production).
   - **Read-only actions** (`/v1/config`, `/v1/health`): Fail soft (allow anonymous requests without integrity gating).
   - **Development & Automated Testing:** In `ENVIRONMENT=development` or `ENVIRONMENT=test`, or when Google Service Account credentials are not configured, integrity checks bypass to permit standard testing without Google Play Services.

## Consequences
- Prevents script-based botnets and unauthorized emulators from exhausting AI API quotas.
- Eliminates reliance on arbitrary, forgeable client headers.
- Session tokens expire in 15 minutes, limiting the window of replay attacks.
