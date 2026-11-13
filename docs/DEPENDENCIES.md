# VibeKit AI — Dependencies & Package Hygiene

**Audit Date:** October 10, 2026  
**License Policy:** Only permissive open-source licenses (MIT, Apache-2.0, BSD-3-Clause) are permitted. No GPL or copyleft packages.

---

## 1. Flutter Client Dependencies (`pubspec.yaml`)

| Package | Version Range | Purpose | License |
| :--- | :--- | :--- | :--- |
| `flutter_riverpod` | `^2.6.1` | State management with compile-time safety | MIT |
| `go_router` | `^14.8.0` | Declarative routing and deep linking | BSD-3-Clause |
| `http` | `^1.3.0` | Robust HTTP client with timeout handling | BSD-3-Clause |
| `shared_preferences` | `^2.3.5` | Key-value persistence for settings, onboarding, IDs | BSD-3-Clause |
| `sqflite` | `^2.4.1` | Embedded SQLite for history, favorites & offline cache | BSD-2-Clause |
| `path` | `^1.9.0` | File path manipulation operations | BSD-3-Clause |
| `path_provider` | `^2.1.5` | Resolves standard app storage directories | BSD-3-Clause |
| `share_plus` | `^10.1.4` | Native Android share sheet invocation | BSD-3-Clause |
| `google_mobile_ads` | `^9.1.0` | Official Google AdMob Flutter SDK | Apache-2.0 |
| `in_app_purchase` | `^3.2.0` | Official Flutter Google Play Billing SDK | BSD-3-Clause |
| `uuid` | `^4.5.1` | Cryptographically random UUID v4 generator | MIT |
| `intl` | `^0.20.2` | Date formatting, localization, and numbers | BSD-3-Clause |
| `google_fonts` | `^6.2.1` | Custom typography (Outfit, Plus Jakarta Sans, Noto) | Apache-2.0 |
| `cupertino_icons` | `^1.0.8` | Default iOS-style icons | MIT |
| `url_launcher` | `^6.3.1` | Launch URLs (Play Store subscription management) | BSD-3-Clause |
| `flutter_local_notifications` | `^18.0.1` | Retention streak reminders & nudge notifications (Phase 2) | BSD-3-Clause |

### Dev Dependencies
- `flutter_test`: Built into Flutter SDK
- `flutter_lints`: `^5.0.0` (Standard Flutter linting rules)

---

## 2. Cloudflare Workers Backend Dependencies (`package.json`)

| Package | Version Range | Purpose | License |
| :--- | :--- | :--- | :--- |
| `hono` | `^4.6.17` | Lightweight, zero-dependency web framework for Workers | MIT |
| `zod` | `^3.24.1` | Strict schema validation for inputs and outputs | MIT |
| `@cloudflare/workers-types` | `^4.20250109.0` | TypeScript definitions for Cloudflare Workers & D1 | MIT |
| `vitest` | `^2.1.8` | Modern testing framework for edge unit/integration tests | MIT |
| `typescript` | `^5.7.3` | Strict static typing compiler | Apache-2.0 |
| `wrangler` | `^3.103.1` | Cloudflare CLI for local development and deployment | Apache-2.0 |

---

## 3. Dependency Verification Check

- **Deprecation Check:** All selected packages are actively maintained by Google, Cloudflare, or top tier Flutter community maintainers.
- **Transitive Bloat:** Zero heavy unnecessary native packages (e.g., no bloated screenshot native plugins when Flutter's native `RepaintBoundary` is cleaner, lighter, and more reliable).
- **Supply Chain Security:** Lockfiles (`pubspec.lock` and `package-lock.json`) will be strictly maintained.
