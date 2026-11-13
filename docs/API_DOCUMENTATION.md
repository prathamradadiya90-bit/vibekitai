# VibeKit AI — API Specification (v1.0.0)

**Base URL:** `https://api.vibekit.ai` (Production) / `http://127.0.0.1:8787` (Local Desktop/Web Dev) / `http://10.0.2.2:8787` (Android Emulator)  
**Protocol:** HTTPS with TLS 1.3  
**Content-Type:** `application/json`  
**Authentication & Identity:** Zero mandatory account creation in v1. Client requests provide pseudonymous installation identifier via header:  
`X-App-Instance-Id: <UUIDv4>`  
`X-Idempotency-Key: <UUIDv4>` (Optional, protects generation requests against duplicate billing on network retry)

---

## 1. System & Configuration

### `GET /v1/health`
Health check and edge availability verification.
- **Request Headers:** None required.
- **Response `200 OK`:**
```json
{
  "status": "healthy",
  "timestamp": "2026-10-10T11:15:00.000Z",
  "version": "1.0.0"
}
```

### `GET /v1/config`
Returns active feature flags, model identifiers, daily credit allowances, and product IDs.
- **Response `200 OK`:**
```json
{
  "app_name": "VibeKit AI",
  "version": "1.0.0",
  "model": "gemini-1.5-flash",
  "daily_free_credits": 3,
  "reward_credits_per_ad": 3,
  "max_daily_rewards": 2,
  "monthly_pro_credits": 200,
  "pricing": {
    "monthly": { "id": "vibekit_pro_monthly", "default_inr": 99 },
    "yearly": { "id": "vibekit_pro_yearly", "default_inr": 699 }
  },
  "privacy_policy_url": "https://vibekit.ai/privacy",
  "terms_of_service_url": "https://vibekit.ai/terms"
}
```

### `GET /v1/usage`
Fetches current daily credit balance, rewarded ad allowances, and Pro subscription state.
- **Headers:** `X-App-Instance-Id: string`
- **Response `200 OK`:**
```json
{
  "free_credits_remaining": 3,
  "rewarded_credits_remaining": 0,
  "total_credits_remaining": 3,
  "is_pro": false,
  "pro_credits_remaining": 0,
  "rewarded_ads_watched_today": 0,
  "max_rewarded_ads_per_day": 2,
  "reset_at_utc": "2026-10-11T00:00:00.000Z"
}
```

---

## 2. Creative Generations

### `POST /v1/generations/reply`
Generates 3 distinct, context-aware suggestions in the selected tone and language. Consumes 1 credit upon success.
- **Headers:**
  - `X-App-Instance-Id: string` (required)
  - `X-Idempotency-Key: string` (optional)
- **Request Body:**
```json
{
  "message": "Hey! Are you free this Saturday evening?",
  "tone": "Witty",
  "language": "English",
  "length": "short",
  "count": 3
}
```
*Tones:* `Funny`, `Friendly`, `Flirty`, `Confident`, `Professional`, `Polite`, `Supportive`, `Witty`  
*Languages:* `English`, `Hindi`, `Hinglish`, `Gujarati`  
*Lengths:* `short`, `medium`, `detailed`  
- **Response `200 OK`:**
```json
{
  "suggestions": [
    "Depends... is this an interrogation or are you buying tacos? 😉",
    "Only if there's good food involved. What are we doing?",
    "Free as a bird! Count me in."
  ],
  "tone": "Witty",
  "language": "English",
  "credits_remaining": 2
}
```
- **Error `400 Bad Request`:** Payload validation failed (e.g. empty or >500 character message).
- **Error `429 Too Many Requests`:** Daily credits exhausted (`QUOTA_EXCEEDED`).

---

### `POST /v1/generations/caption`
Generates social captions, scroll-stopping hooks, CTAs, and relevant hashtags. Consumes 1 credit.
- **Request Body:**
```json
{
  "topic": "Solo road trip through the Himalayas on a vintage Royal Enfield",
  "platform": "Instagram Reels",
  "tone": "Aesthetic",
  "language": "Hinglish",
  "length": "medium",
  "include_hooks": true,
  "include_hashtags": true
}
```
- **Response `200 OK`:**
```json
{
  "captions": [
    "Pahadon ki hawa aur Bullet ki thumping sound... Life feels complete. 🏔️✨",
    "Raste anjaan the, par sukoon har mod par mil gaya."
  ],
  "hooks": [
    "Yeh video dekh kar aapka bhi bag pack karne ka mann karega... 🧳",
    "Solo trip ke baare mein log yeh kabhi nahi batate 👇"
  ],
  "call_to_actions": [
    "Share with your favorite travel partner! 🏍️",
    "Save this reel for your next mountain itinerary 📌"
  ],
  "hashtags": [
    "#HimalayanDiaries", "#RoyalEnfieldRider", "#SoloTripVibes", "#PahadiLife", "#TravelReelsIndia"
  ],
  "credits_remaining": 1
}
```

---

## 3. Monetisation & Quota Management

### `POST /v1/purchases/verify`
Authoritative backend verification of Google Play Billing purchases.
- **Request Body:**
```json
{
  "product_id": "vibekit_pro_monthly",
  "purchase_token": "in_app_purchase_token_from_google_play",
  "order_id": "GPA.3321-4456-7890"
}
```
- **Response `200 OK`:**
```json
{
  "is_verified": true,
  "product_id": "vibekit_pro_monthly",
  "status": "ACTIVE",
  "message": "Subscription successfully verified and activated."
}
```

### `GET /v1/subscription/status`
Fetches current Pro subscription entitlement status and remaining Pro credits.
- **Headers:** `X-App-Instance-Id: string`
- **Response `200 OK`:**
```json
{
  "is_pro": true,
  "pro_credits_remaining": 200
}
```

### `POST /v1/ads/verify-reward`
Grants 3 bonus credits upon validated completion of an AdMob rewarded ad. Maximum 2 rewarded claims per calendar day.
- **Request Body:**
```json
{
  "reward_id": "unique_reward_event_uuid",
  "ad_network": "admob"
}
```
- **Response `200 OK`:**
```json
{
  "success": true,
  "credits_added": 3,
  "credits_remaining": 5
}
```
- **Error `400 Bad Request`:** `REWARD_REJECTED` (Replay attack or daily cap reached).

---

## 4. Privacy & Compliance

### `POST /v1/privacy/delete-data`
Purges all cloud installation records, daily usage rows, and entitlements for the calling client.
- **Response `200 OK`:**
```json
{
  "success": true,
  "message": "All cloud data associated with this installation has been permanently purged."
}
```

### `POST /v1/feedback`
Submits optional user feedback.
- **Request Body:**
```json
{
  "message": "Please add more Gujarati festive quote templates!"
}
```
- **Response `200 OK`:**
```json
{
  "success": true,
  "message": "Feedback received. Thank you for helping us improve VibeKit AI!"
}
```

---

## 5. Standard Error Format
All non-2xx responses follow a predictable JSON contract:
```json
{
  "error": {
    "code": "ERROR_CODE_STRING",
    "message": "Human-friendly explanation.",
    "details": null
  }
}
```
No database credentials, provider API keys, or raw stack traces are ever emitted in error responses.
