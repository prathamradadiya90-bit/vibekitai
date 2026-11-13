# VibeKit AI - Phase 9 Admin Panel Specification & Operations Guide

## 1. Executive Summary

Phase 9 delivers a lightweight, production-grade Admin Console directly hosted from Cloudflare Workers edge nodes at `/admin`. The panel provides real-time business and technical observability (DAU, WAU, MAU, generation volumes, latency percentiles, AdMob revenue estimates, Google Play subscription health) and operational management (credit adjustments, installation bans, versioned remote configuration with instant rollback, and GDPR privacy compliance purges).

---

## 2. Architecture & Tech Stack

```
                              ┌────────────────────────────────────────┐
                              │ Cloudflare Zero Trust (Access Gateway) │
                              │   - Single Sign-On (Google / GitHub)   │
                              │   - Team Domain / JWT Assertion        │
                              └───────────────────┬────────────────────┘
                                                  │
                                                  ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ Cloudflare Worker (VibeKit Backend)                                                   │
│                                                                                        │
│  [adminAuthMiddleware]                                                                 │
│    ├── Validates Cf-Access-Jwt-Assertion (or signed session token)                    │
│    ├── Enforces RBAC (admin vs viewer)                                                 │
│    ├── Enforces CSRF Protection (X-Admin-Action header)                                │
│    └── Applies Strict Security Headers (CSP, X-Robots-Tag: noindex)                   │
│                                                                                        │
│  [/admin (SPA)]                   [/v1/admin/* (REST API)]       [Cron Trigger (0 1 *)]│
│    ├── Vanilla HTML5/CSS3/ES6        ├── Zod Validation            └── nightly_stats.ts│
│    ├── Zero external dependencies    ├── AdminAuditRepository            ├── Aggregate │
│    ├── Inline SVG Trend Charts       ├── BansRepository (Cache)          └── D1 Update │
│    └── Mobile-responsive UI          └── RemoteConfigRepository (v1..n)                │
└─────────────────────────────────────────┬──────────────────────────────────────────────┘
                                          │
                                          ▼
                      ┌────────────────────────────────────────┐
                      │ Cloudflare D1 Distributed SQLite DB    │
                      │   - admin_audit_log (Append-only)      │
                      │   - remote_config_versions (History)   │
                      │   - bans (Device enforcement)          │
                      │   - daily_stats (Precomputed metrics)  │
                      │   - feedback_records (Status tracking) │
                      └────────────────────────────────────────┘
```

### Key Design Highlights:
1. **Zero External Dependencies:** Built with pure TypeScript, standard Hono routes, and Vanilla HTML/CSS/JS. No heavy React/Node framework bundle overhead, keeping worker bundles ultra-lean (<1.5MB total).
2. **Edge-Native Speed:** Sub-10ms response times for dashboards and installations via in-memory isolate caching and precomputed `daily_stats`.
3. **Zero Prompt Retention Compliance:** The admin panel has no routes or SQL queries that fetch user prompts or generated texts. All data is restricted to anonymized IDs, counts, timestamps, and performance metrics.

---

## 3. Security Model & Role-Based Access Control (RBAC)

### 3.1 Authentication Gate
- **Primary:** Cloudflare Access sets the signed JWT header `Cf-Access-Jwt-Assertion` upon successful corporate identity authentication.
- **Development / CLI Fallback:** `Authorization: Bearer <ADMIN_SECRET>` or cookie `vibekit_admin_session`.

### 3.2 Role Hierarchy
| Role | Permissions | Mutating Operations Allowed? |
| :--- | :--- | :---: |
| `viewer` | Read-only dashboards, installation search, subscriptions, audit logs, AI health | ❌ (Rejected with HTTP 403 `FORBIDDEN`) |
| `admin` | Full control: credit grants, bans/unbans, remote config updates, rollback, data erasures | ✅ (Requires CSRF header `X-Admin-Action: 1`) |

### 3.3 Append-Only Audit Logging
Every mutating operation writes an immutable record to `admin_audit_log`:
- `admin_email`: Email of the administrator who executed the action.
- `action`: Canonical action name (`GRANT_CREDITS`, `BAN_INSTALLATION`, `UPDATE_REMOTE_CONFIG`, etc.).
- `target_id`: Target installation ID or config key.
- `details_json`: Serialized JSON payload containing before/after details.
- `created_at`: UTC ISO-8601 timestamp.

---

## 4. Setup Guide: Cloudflare Access

1. Open **Cloudflare Zero Trust** (`https://one.dash.cloudflare.com/`).
2. Navigate to **Access** > **Applications** > **Add an application**.
3. Choose **Self-Hosted**.
4. Configure Details:
   - **Application name:** `VibeKit AI Admin`
   - **Application domain:** `api.vibekit.ai`
   - **Path:** `/admin*` and `/v1/admin*`
5. Configure Policies:
   - **Rule Action:** `Allow`
   - **Include:** `Emails ending in @vibekit.ai` (or specific administrator emails).
6. Copy the **AUD** (Application Audience Tag) from the application overview page.

---

## 5. Wrangler Secrets Configuration

Execute the following commands to configure production secrets:

```bash
# Set Cloudflare Access Audience Tag
npx wrangler secret put CF_ACCESS_AUD

# Set Cloudflare Access Team Name
npx wrangler secret put CF_ACCESS_TEAM_NAME

# Set Admin Secret Key (used for emergency / local token access)
npx wrangler secret put ADMIN_SECRET

# Set Role Mapping (JSON mapping email to 'admin' or 'viewer')
npx wrangler secret put ADMIN_USERS_JSON
# Value: {"lead@vibekit.ai": "admin", "analyst@vibekit.ai": "viewer"}
```

---

## 6. Scheduled Cron Trigger

Expensive analytics queries (DAU, WAU, MAU, latency percentiles) are precomputed by a nightly cron job so page loads never perform table scans:

- **Schedule:** `0 1 * * *` (01:00 UTC daily)
- **Wrangler Configuration:**
  ```toml
  [triggers]
  crons = ["0 1 * * *"]
  ```
- **Handler:** `handleScheduledTask` in `src/cron/nightly_stats.ts`.
- **Manual Recalculation:** Administrators can trigger immediate recalculation via the Admin Console button or `POST /v1/admin/aggregate-daily`.

---

## 7. Database Migrations Applied

Migration `0007_admin_panel.sql`:
1. `admin_audit_log`: Append-only audit trail.
2. `remote_config_versions`: Versioned remote configuration entries.
3. `bans`: Suspended installations list with reasons and admin attribution.
4. `daily_stats`: Precomputed daily aggregate table.
5. `feedback_records`: Added `status`, `resolved_by`, and `resolved_at` columns.

To apply to production Cloudflare D1:
```bash
npx wrangler d1 migrations apply DB --remote
```

---

## 8. Complete Admin API Route Reference

All routes are mounted under `/v1/admin/*` and require admin authentication:

| Method | Route | Required Role | Description |
| :--- | :--- | :---: | :--- |
| `GET` | `/v1/admin/me` | `viewer` | Returns authenticated email, role, and auth source |
| `GET` | `/v1/admin/dashboard` | `viewer` | Returns DAU/WAU/MAU, generations breakdown, latency, est. revenue, streaks |
| `POST` | `/v1/admin/aggregate-daily` | `admin` | Manually triggers daily stats aggregation for a date |
| `GET` | `/v1/admin/installations` | `viewer` | Search & list installations with usage, streak, and tier status |
| `GET` | `/v1/admin/installations/:id` | `viewer` | Detailed view of single installation with 7-day usage & entitlements |
| `POST` | `/v1/admin/installations/:id/grant-credits` | `admin` | Grants or revokes credits with reason & audit record |
| `POST` | `/v1/admin/installations/:id/ban` | `admin` | Bans or unbans an installation ID |
| `POST` | `/v1/admin/installations/:id/resync` | `admin` | Re-verifies entitlements with Google Play |
| `DELETE` | `/v1/admin/installations/:id/data` | `admin` | Permanently deletes all installation data (GDPR compliant) |
| `GET` | `/v1/admin/subscriptions` | `viewer` | Lists subscriptions, filtered by status (`ACTIVE`, `EXPIRED`, `CANCELED`) |
| `GET` | `/v1/admin/config` | `viewer` | Returns active remote config and version history |
| `POST` | `/v1/admin/config` | `admin` | Updates remote config, increments version, and invalidates edge cache |
| `POST` | `/v1/admin/config/revert` | `admin` | Rolls back remote config to any historical version |
| `GET` | `/v1/admin/feedback` | `viewer` | Lists user feedback inbox |
| `POST` | `/v1/admin/feedback/:id/resolve` | `admin` | Marks a feedback message as resolved |
| `GET` | `/v1/admin/ai-health` | `viewer` | AI provider success rates, fallback counts, and average latencies |
| `GET` | `/v1/admin/abuse` | `viewer` | Lists flagged IP hashes with high request volumes |
| `GET` | `/v1/admin/audit-log` | `viewer` | Paginated append-only audit trail |

---

## 9. Admin QA Checklist

- [x] **Unauthenticated Access:** Navigating to `/v1/admin/me` without a token returns HTTP 401 `UNAUTHORIZED`.
- [x] **Cloudflare Access JWT:** Requests with valid `Cf-Access-Jwt-Assertion` correctly authenticate and identify the user.
- [x] **Viewer Role Restrictions:** Users with `viewer` role can view KPIs and tables, but mutating actions (`POST`, `PUT`, `DELETE`) are rejected with HTTP 403 `FORBIDDEN`.
- [x] **Audit Trail Verification:** Every credit adjustment, ban, config change, and feedback resolution creates a record in `admin_audit_log`.
- [x] **Ban Enforcement:** Banned installations receive HTTP 403 `ACCOUNT_BANNED` on `/v1/generations/*` and `/v1/ads/*`.
- [x] **Zero Prompt Retention:** Verified that no prompt strings, user inputs, or generated texts are exposed in any admin endpoint.
- [x] **Remote Config Versioning:** Config updates increment version numbers and can be reverted cleanly using the revert endpoint.
- [x] **Mobile Responsiveness:** The Admin Console at `/admin` renders seamlessly on desktop, tablet, and mobile browsers.
- [x] **Automated Tests:** 42/42 backend tests passing, 20/20 Flutter tests passing, and 0 lint warnings.
