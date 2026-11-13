# VibeKit AI — Google Play Billing Setup Guide

**Package:** `in_app_purchase: ^3.2.0` (Play Billing Library v6/v7 compatible)  
**Target Products:**
1. `vibekit_pro_monthly` (Monthly recurring subscription)
2. `vibekit_pro_yearly` (Yearly recurring subscription with 41% discount)

---

## 1. Setting up Subscriptions in Google Play Console

1. Navigate to Google Play Console -> Select your app (`VibeKit AI`).
2. Go to **Monetize** -> **Products** -> **Subscriptions**.
3. Click **Create subscription**:
   - **Product ID:** `vibekit_pro_monthly`
   - **Name:** VibeKit Pro (Monthly)
   - **Description:** Ad-free, watermark-free cards, 200 monthly AI credits.
   - Add a Base Plan:
     - Billing period: **1 month**
     - Renewal type: **Auto-renewing**
     - Price: **₹99.00 INR** (or local currency equivalent in target countries)
   - Activate the base plan.
4. Repeat for Annual Subscription:
   - **Product ID:** `vibekit_pro_yearly`
   - **Name:** VibeKit Pro (Annual)
   - Billing period: **1 year**
   - Renewal type: **Auto-renewing**
   - Price: **₹699.00 INR**
   - Activate the base plan.

---

## 2. Server-Side Purchase Verification (Google Cloud Service Account)

To verify purchases authoritatively on the Cloudflare backend:
1. Open Google Cloud Console -> **IAM & Admin** -> **Service Accounts**.
2. Create Service Account: `vibekit-play-billing@<project-id>.iam.gserviceaccount.com`.
3. Grant Role: **Google Play Developer API Client**.
4. Create and download the private JSON key.
5. In Google Play Console -> **Users and permissions** -> Invite user -> Add the service account email with **View financial data** and **Manage orders and subscriptions** permissions.
6. Set the JSON string on Cloudflare Workers:
   ```bash
   npx wrangler secret put GOOGLE_PLAY_SERVICE_ACCOUNT_JSON
   ```

---

## 3. Real-Time Developer Notifications (RTDN)

- Create a Google Cloud Pub/Sub topic: `play-billing-notifications`.
- In Google Play Console -> **Monetization setup** -> Enter Pub/Sub topic name.
- Configure Cloudflare Worker webhook: `POST /v1/webhooks/google-play` to receive cancellation and expiration events in real time.
