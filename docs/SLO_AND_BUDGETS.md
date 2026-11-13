# VibeKit AI — Service Level Objectives (SLOs), Performance Budgets & Unit Economics

**Target Quality Standard:** 100/100 Production & Revenue-Ready  
**Document Status:** Authoritative Benchmark Specification (Phase 0)

---

## 1. Backend API Service Level Objectives (SLOs)

### 1.1 Availability & Uptime
- **SLO Target:** **99.9% Uptime** over any rolling 30-day window.
- **Allowed Downtime Budget:** Max **43.8 minutes** per calendar month (or 10.1 minutes per week).
- **Measurement:** Percentage of successful requests (HTTP status `< 500`) evaluated at the Cloudflare Edge Gateway, excluding client-side aborts or malformed client requests (`4xx`).
  $$\text{Availability} = \frac{\sum \text{Requests with status} < 500}{\sum \text{Total Valid Requests}} \ge 99.9\%$$

### 1.2 Latency Budgets by Endpoint Class
Latency is measured from the edge gateway perspective (time-to-first-byte):

| Endpoint Class | Examples | Target p50 | Target p95 | Target p99 | Strict SLA Ceiling |
| :--- | :--- | :---: | :---: | :---: | :---: |
| **Class A: Static / Edge Cached** | `/v1/config`, `/v1/health` | < 15 ms | **< 50 ms** | < 120 ms | 200 ms |
| **Class B: Transactional & Quota** | `/v1/usage`, `/v1/streak/*`, `/v1/ads/*` | < 35 ms | **< 150 ms** | < 300 ms | 500 ms |
| **Class C: AI Generation** | `/v1/generations/reply`, `caption`, `bio` | < 2.5 s | **< 6.0 s** | < 9.5 s | 12.0 s (Timeout) |
| **Class D: Admin Aggregates** | `/v1/admin/dashboard`, `/v1/admin/installations` | < 45 ms | **< 200 ms** | < 450 ms | 1.0 s |

### 1.3 Error Budget Policy & Burn Rate Alerting
When errors consume the 0.1% monthly error budget, automated alerting triggers graduated responses:

| Burn Rate | % Budget Consumed | Time to 100% Exhaustion | Severity | Action Triggered |
| :---: | :---: | :---: | :---: | :--- |
| **14.4x** | 2% in 1 hour | 2.0 days | **P1 (Critical)** | Page on-call; automated traffic shift to secondary AI provider. |
| **6.0x** | 5% in 6 hours | 5.0 days | **P2 (High)** | Investigate failing provider; halt non-essential deployments. |
| **1.0x** | 10% in 3 days | 30 days | **P3 (Warning)** | Ticket created; engineering focuses on bug fixes over features. |

---

## 2. Mobile App Performance Budgets (Android / Flutter)

All metrics are benchmarked on mid-range Android test devices (Reference Spec: Snapdragon 680, 4 GB RAM, Android 13/14, 60 Hz display).

### 2.1 Core App Vitals

| Performance Metric | Target Budget | Warning Threshold | Play Console Bad Behavior Limit |
| :--- | :---: | :---: | :---: |
| **Cold Start Time** (Process death to first frame) | **< 1.8 s** | > 2.0 s | > 5.0 s |
| **Warm / Hot Start Time** | **< 600 ms** | > 900 ms | > 2.0 s |
| **Frame Jank Rate** (Frames > 16.6ms) | **< 0.8%** | > 1.2% | > 2.5% |
| **ANR Rate** (Application Not Responding) | **< 0.10%** | > 0.20% | **0.47% (Play Store Threshold)** |
| **Crash-Free User Sessions** | **> 99.8%** | < 99.5% | < 99.0% |
| **Android App Bundle (AAB) Size** | **< 22.0 MB** | > 25.0 MB | > 50.0 MB |
| **Installed App Size (on device)** | **< 48.0 MB** | > 60.0 MB | - |
| **Memory Consumption (Idle)** | **< 95 MB** | > 130 MB | OOM Kill |
| **Memory Consumption (Peak Card Render)** | **< 180 MB** | > 220 MB | OOM Kill |

### 2.2 Card Maker & Visual Export Budget
- **Interactive Preview Canvas:** Constant **60 FPS** during template switching, aspect ratio changes, and text entry.
- **High-DPI PNG Export Latency:** **< 800 ms** at 1080x1920 (9:16) and 1080x1080 (1:1).
- **GPU Texture Disposal:** Maximum **1 texture in VRAM** simultaneously; `ui.Image` must be disposed of within **50 ms** of byte conversion.

---

## 3. Unit Economics, Cost Model & Gross Margins

### 3.1 AI Generation Cost Model (per 1,000 generations)

| AI Provider & Model | Input Tokens / Gen (avg 150) | Output Tokens / Gen (avg 200) | Blended Cost per 1k Gens | Target Ceiling |
| :--- | :---: | :---: | :---: | :---: |
| **Google Gemini 1.5 Flash** | $0.075 / 1M tokens | $0.300 / 1M tokens | **$0.071 (₹5.90 INR)** | < $0.35 |
| **Google Gemini 2.0 Flash** | $0.100 / 1M tokens | $0.400 / 1M tokens | **$0.095 (₹7.90 INR)** | < $0.35 |
| **Groq Llama 3.3 70B** | $0.590 / 1M tokens | $0.790 / 1M tokens | **$0.246 (₹20.50 INR)** | < $0.35 |
| **OpenAI GPT-4o-mini** | $0.150 / 1M tokens | $0.600 / 1M tokens | **$0.142 (₹11.80 INR)** | < $0.35 |
| **Target Blended Cost Target** | — | — | **< $0.150 / 1k Gens** | **< $0.350 / 1k Gens** |

### 3.2 Free User Unit Economics (Daily Active User)
- **Daily Free Quota:** 3 free AI generations.
- **Daily Rewarded Ads Allowed:** Up to 2 rewarded video ads (+3 credits each).
- **Daily Compute Cost (Free User with 3 gens):**
  $$3 \times \$0.000095 = \$0.000285 \text{ (₹0.024 INR)}$$
- **Expected Ad Revenue per Free User (1 rewarded ad impression @ $14 eCPM):**
  $$\frac{\$14.00}{1,000} = \$0.0140 \text{ (₹1.16 INR)}$$
- **Net Margin per Monetized Free User:**
  $$\$0.0140 - \$0.000285 = +\$0.0137 \text{ per day (~98% gross contribution margin)}$$

### 3.3 Pro Subscriber Margin Analysis

| Subscription Tier | End-User Price | Play Store Fee (15%) | Net Revenue | AI Compute Cost (200 gens max) | Net Contribution | Gross Margin |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **Weekly (₹49)** | $0.59 | $0.09 | $0.50 | $0.005 (50 gens) | **+$0.495** | **84%** |
| **Monthly (₹99)** | $1.19 | $0.18 | $1.01 | $0.019 (200 gens) | **+$0.991** | **83%** |
| **Yearly (₹699)** | $8.39 | $1.26 | $7.13 | $0.228 (2,400 gens) | **+$6.902** | **82%** |

*Target Margin Requirement:* Gross margin must consistently exceed **80%** across all subscription tiers, even under maximum allowed quota consumption.
