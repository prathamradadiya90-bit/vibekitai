# Security Policy & Responsible Disclosure

## 1. Our Commitment
At VibeKit AI, user privacy and platform security are fundamental design principles. We welcome security researchers and ethical hackers to review our application and backend infrastructure responsibly.

---

## 2. Reporting a Vulnerability

If you discover a security vulnerability or potential threat in VibeKit AI (including client APK, Cloudflare Workers API, or AI pipeline), please report it immediately:

- **Security Contact Email:** `security@vibekit.ai`
- **PGP Key Fingerprint (Optional):** `4A12 89B3 0F42 9C77 1E5D 28AA 54D2 C018 7BE3 E419`
- **Subject Format:** `[Vulnerability Report] Component - Vulnerability Type`

### What to include in your report:
1. Detailed description of the vulnerability and its potential impact.
2. Step-by-step reproduction instructions or a minimal Proof of Concept (PoC).
3. Target environment (API endpoint, app version, Android OS version).
4. Any relevant HTTP requests, headers, or screenshots.

Please **do NOT** publicly disclose or publish details of the vulnerability until our security team has reviewed, remediated, and verified the fix.

---

## 3. Response SLAs & Commitments

- **Initial Acknowledgment:** Within **24 hours** of submission.
- **Triage & Severity Assessment:** Within **72 hours**.
- **Fix Deployment Target:**
  - Critical / High Severity (Remote Code Execution, Quota Bypasses, Authentication Bypasses, Prompt Retention): < **7 days**.
  - Medium / Low Severity: < **30 days**.

---

## 4. Scope

### In Scope
- VibeKit AI Android Application (Production releases from Google Play).
- Cloudflare Workers Edge API (`https://api.vibekit.ai` / `*.workers.dev`).
- Authentication, Session Tokens, and Play Integrity verification flows.
- Daily credit quota accounting and atomic decrement engines.
- AdMob SSV and Google Play Billing receipt validation mechanisms.
- Zero Prompt Retention invariants (evidence of prompts logged or stored on server disk/DB).

### Out of Scope
- Denial of Service (DoS/DDoS) attacks against Cloudflare Workers edge.
- Social engineering, phishing, or physical attacks against VibeKit staff.
- Issues affecting only rooted, jailbroken, or heavily modified Android emulators running modified Xposed/Frida modules without reproducible server-side exploitability.
- Automated vulnerability scanner spam without actionable PoCs.

---

## 5. Safe Harbor

If you conduct vulnerability research in good faith and adhere to this policy:
- We will not pursue legal action or report you to law enforcement.
- We will work collaboratively with you to understand and resolve the issue promptly.
- We will publicly credit you in our Hall of Fame (unless you request anonymity).
