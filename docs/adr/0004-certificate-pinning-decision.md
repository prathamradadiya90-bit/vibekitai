# ADR 0004: Mobile Network Security & Certificate Pinning Strategy

## Status
Accepted

## Context
Mobile clients communicating with the VibeKit AI edge backend (`https://api.vibekit.ai` or Cloudflare Workers) require defense against Machine-in-the-Middle (MitM) attacks, credential interception, and reverse-engineering proxies (e.g., Charles Proxy, HTTP Toolkit, Burp Suite).

Mobile security audits commonly recommend Certificate Pinning (pinning the leaf public key or certificate fingerprint in the client app). However, deploying static leaf certificate pinning in apps fronted by Cloudflare Workers presents critical operational risks:
1. **Dynamic Edge Certificate Rotation:** Cloudflare automatically rotates SSL/TLS certificates across multiple Certificate Authorities (Google Trust Services, Let's Encrypt, Cloudflare Managed CA) on 90-day cycles or during automated security revocations.
2. **App Bricking Hazard:** Hardcoding a leaf certificate pin without multi-CA backup pins will permanently brick the mobile application for existing users if Cloudflare rotates certificates before users update their app from Google Play.
3. **Emergency Fallback Vulnerability:** If a pinned CA key is revoked, the app cannot communicate with the backend until a new APK is reviewed, approved by Google Play, and downloaded by users (a 24–72 hour outage).

## Decision
We adopt a Defense-in-Depth Network Security Model rather than brittle static leaf certificate pinning:

1. **Strict TLS 1.3 & System CA Trust Only:**
   - Enforce TLS 1.3 transport security.
   - Configure Android `network_security_config.xml` with `<base-config cleartextTrafficPermitted="false">` and trust only `<certificates src="system" />`. User-installed root certificates (e.g., Charles Proxy / HTTP Toolkit debugging profiles) are strictly ignored in production builds.

2. **Cryptographic Device Attestation (Play Integrity):**
   - Client performs Google Play Integrity hardware-backed attestation (`POST /v1/auth/attest`).
   - The backend validates the hardware signature, app package name, and signing certificate hash directly with Google servers, then issues a short-lived (15-minute) HMAC-SHA256 session token (`X-Session-Token`).
   - Proxy tools without genuine Play Integrity attestation tokens cannot generate valid API sessions.

3. **End-to-End Idempotency & Request Tracing:**
   - Client sends unique `X-Request-Id` and `X-Idempotency-Key` headers on all mutating generation calls.
   - Retries use exponential backoff only on verified idempotent calls.

4. **Future Static Pinning Threshold:**
   - Static public key pinning (SPKI) will only be introduced if VibeKit AI transitions to a dedicated Enterprise Cloudflare Custom SSL certificate with guaranteed multi-year public key persistence and dual backup pins.

## Consequences
- **Positive:** Zero risk of app bricking during routine Cloudflare edge SSL rotations.
- **Positive:** Zero cleartext HTTP traffic allowed by Android OS network stack.
- **Positive:** Automated MitM proxies without Google Play Integrity hardware tokens are completely shut out from backend generation endpoints.
- **Trade-off:** Dedicated reverse-engineers with rooted devices and Frida can bypass user-certificate restrictions locally, but are still blocked by Play Integrity hardware checks and server-side quota tracking.
