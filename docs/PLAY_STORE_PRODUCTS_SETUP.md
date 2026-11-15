# Google Play In-App Products & Subscriptions Setup Guide

**App:** VibeKit AI (`com.vibekit.vibekit_ai`)  
**Billing Client Version:** 7.x (`in_app_purchase: ^3.2.0`)  
**Server Verification:** Server-Side Verification via Cloudflare Workers Edge API (`/v1/purchases/verify` and `/v1/purchases/credit-pack`)

---

## 1. Product IDs & Pricing Matrix

Configure the following exact Product IDs in **Google Play Console > Monetize > Products**:

### A. Subscriptions (`Subscriptions`)

| Subscription ID | Base Plan ID | Billing Period | Free Trial | Default USD | Default INR | Benefits |
|---|---|---|---|---|---|---|
| `vibekit_pro_weekly` | `weekly-standard` | 1 Week | None | $1.99 | ₹49 | 200 monthly credits, 100% ad-free, pro card templates |
| `vibekit_pro_monthly` | `monthly-standard` | 1 Month | None | $3.99 | ₹99 | 200 monthly credits, 100% ad-free, pro card templates |
| `vibekit_pro_yearly` | `yearly-standard` | 1 Year | 3 Days | $24.99 | ₹699 | 200 monthly credits, 100% ad-free, pro card templates, priority AI queue |

*Note: In Google Play Console, create a subscription for each ID, then create a **Base Plan** set to "Auto-renewing". For `vibekit_pro_yearly`, add an **Offer** with a 3-day free trial.*

---

### B. In-App Products (`In-app products`)

| Product ID | Type | Default USD | Default INR | Title | Description |
|---|---|---|---|---|---|
| `vibekit_pro_lifetime` | **Non-consumable** (One-time) | $49.99 | ₹1,499 | Lifetime VIP Pass | Perpetual Pro access, unlimited card templates & zero ads forever. |
| `vibekit_credits_50` | **Consumable** (Repeatable) | $0.99 | ₹29 | 50 AI Generation Credits | Instantly adds 50 credits for clever replies, captions & bio generations. |

---

## 2. Google Cloud Service Account Setup (Server-Side Verification)

To enable server-side validation of purchases on your Cloudflare Workers edge backend:

1. Go to the [Google Cloud Console](https://console.cloud.google.com).
2. Select your Google Play Developer Project.
3. Enable the **Google Play Android Developer API**.
4. Go to **IAM & Admin > Service Accounts > Create Service Account**:
   - Name: `vibekit-play-verifier`
   - Role: `Viewer` or Project Member.
5. Create a **JSON Key** for this Service Account and download it.
6. In **Google Play Console > Users & permissions > Invite new users**:
   - Add the service account email.
   - Permissions:
     -  **View app information and download bulk reports (read-only)**
     -  **View financial data, orders, and cancellation survey responses**
     -  **Manage orders and subscriptions**
7. Store the JSON key in Cloudflare Workers secrets:
   ```bash
   cd backend
   npx wrangler secret put PLAY_SERVICE_ACCOUNT_JSON
   # Paste the full minified contents of the service account JSON file
   ```

---

## 3. Real-Time Developer Notifications (RTDN) Setup (Optional for Auto-Cancellation)

1. Create a Google Cloud Pub/Sub topic: `projects/<your-project-id>/topics/play-subs-notifications`.
2. Grant publisher permissions to Google Play: `google-play-developer-notifications@system.gserviceaccount.com` with role **Pub/Sub Publisher**.
3. In **Play Console > Monetize > Monetization setup**:
   - Paste topic name: `projects/<your-project-id>/topics/play-subs-notifications`.
   - Send test notification.
4. Point Pub/Sub push subscription to your deployed Cloudflare endpoint:
   `https://<your-worker-domain>/v1/purchases/rtdn`
