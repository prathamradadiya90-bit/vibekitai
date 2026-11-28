import { Hono } from 'hono';
import { AppHonoEnv } from '../types';
import { QuotaManager } from '../quota/quota_manager';

export const privacyPublicRoute = new Hono<AppHonoEnv>();
export const privacyRoute = new Hono<AppHonoEnv>();

const privacyHtml = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>VibeKit AI — Privacy Policy & Terms</title>
  <style>
    :root { --bg: #0f172a; --card: #1e293b; --text: #f8fafc; --muted: #94a3b8; --accent: #6366f1; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background: var(--bg); color: var(--text); line-height: 1.6; margin: 0; padding: 20px; }
    .container { max-width: 800px; margin: 0 auto; background: var(--card); padding: 32px; border-radius: 16px; border: 1px solid #334155; }
    h1 { color: #818cf8; font-size: 28px; margin-top: 0; }
    h2 { color: #c7d2fe; font-size: 20px; margin-top: 24px; border-bottom: 1px solid #334155; padding-bottom: 8px; }
    p, li { color: var(--muted); font-size: 15px; }
    ul { padding-left: 20px; }
    .badge { display: inline-block; background: rgba(99, 102, 241, 0.2); color: #818cf8; padding: 4px 12px; border-radius: 9999px; font-size: 13px; font-weight: 600; margin-bottom: 16px; }
    .footer { margin-top: 32px; padding-top: 16px; border-top: 1px solid #334155; font-size: 13px; color: #64748b; text-align: center; }
  </style>
</head>
<body>
  <div class="container">
    <div class="badge">Official Google Play Disclosure</div>
    <h1>VibeKit AI — Privacy Policy</h1>
    <p>Last updated: October 2026</p>
    
    <h2>1. Overview & Privacy-First Architecture</h2>
    <p>ReplyVibe AI (also known as VibeKit AI) is engineered with a privacy-first architecture. We do not require account registration, passwords, email addresses, or phone numbers to use the application.</p>

    <h2>2. Data Collection and Usage</h2>
    <ul>
      <li><strong>Device / Pseudonymous Installation ID:</strong> An anonymous UUID generated on your device is used strictly to manage daily AI credit allowances, streaks, referrals, subscriptions, and abuse prevention.</li>
      <li><strong>Transient AI Processing &amp; Retry Cache:</strong> Text inputs entered in Studio features are transmitted via HTTPS to our backend and AI inference providers (Google Gemini and configured fallback models). We do not store persistent chat transcripts; short-lived idempotency retry responses automatically expire and are purged within 24 hours.</li>
      <li><strong>Operational Telemetry &amp; Safety Reports:</strong> Non-text generation metadata (category, tone, latency, status) and voluntary user-submitted feedback or flagged AI content reports are stored to maintain reliability and safety moderation.</li>
      <li><strong>Card &amp; Meme Studio:</strong> 100% offline. Visual cards and memes are rendered locally on your device canvas via Flutter. Image exports never touch our servers.</li>
      <li><strong>Purchases:</strong> Handled authoritatively through Google Play In-App Billing. We never receive, process, or store credit card numbers or financial credentials.</li>
    </ul>

    <h2>3. Advertising & Third-Party SDKs</h2>
    <p>ReplyVibe AI / VibeKit AI integrates Google Mobile Ads (AdMob) for free-tier banners and optional rewarded video ads. AdMob uses Google Server-Side Verification (SSV) and Advertising Identifiers in compliance with Google Play policies.</p>

    <h2>4. Data Retention & Deletion ("Right to be Forgotten")</h2>
    <p>Users have complete sovereignty over their data. You can trigger an instant, permanent deletion of all cloud quota records directly inside the app settings under <em>"Delete My Data"</em>, or by invoking our automated deletion endpoint.</p>

    <h2>5. Contact Us</h2>
    <p>For any privacy inquiries, reach our team at <strong>privacy@vibekit.ai</strong>.</p>

    <div class="footer">
      &copy; 2026 VibeKit AI. Built with Flutter, Cloudflare Workers & Google Gemini.
    </div>
  </div>
</body>
</html>`;

const deleteDataHtml = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>VibeKit AI — Account & Data Deletion Request</title>
  <style>
    :root { --bg: #0f172a; --card: #1e293b; --text: #f8fafc; --muted: #94a3b8; --accent: #6366f1; --danger: #ef4444; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background: var(--bg); color: var(--text); line-height: 1.6; margin: 0; padding: 20px; }
    .container { max-width: 800px; margin: 0 auto; background: var(--card); padding: 32px; border-radius: 16px; border: 1px solid #334155; }
    h1 { color: #818cf8; font-size: 28px; margin-top: 0; }
    h2 { color: #c7d2fe; font-size: 20px; margin-top: 24px; border-bottom: 1px solid #334155; padding-bottom: 8px; }
    p, li { color: var(--muted); font-size: 15px; }
    ul, ol { padding-left: 20px; }
    .badge { display: inline-block; background: rgba(99, 102, 241, 0.2); color: #818cf8; padding: 4px 12px; border-radius: 9999px; font-size: 13px; font-weight: 600; margin-bottom: 16px; }
    .box { background: rgba(15, 23, 42, 0.6); border: 1px solid #334155; border-radius: 12px; padding: 20px; margin: 16px 0; }
    .footer { margin-top: 32px; padding-top: 16px; border-top: 1px solid #334155; font-size: 13px; color: #64748b; text-align: center; }
    a { color: #818cf8; text-decoration: none; }
    a:hover { text-decoration: underline; }
  </style>
</head>
<body>
  <div class="container">
    <div class="badge">Google Play Data Safety & Deletion</div>
    <h1>VibeKit AI — Account & Data Deletion</h1>
    <p>Last updated: November 2026</p>

    <h2>1. Data Minimization & Zero Prompt Retention</h2>
    <p>VibeKit AI is built with privacy-by-design principles:</p>
    <ul>
      <li><strong>No Account Required:</strong> We do not require account registration, passwords, email, or telephone numbers to use VibeKit AI.</li>
      <li><strong>Zero Chat Logs:</strong> User chat messages and prompts are never saved as persistent conversation history or used by us to train foundation models; 24-hour idempotency retry caches are automatically purged.</li>
      <li><strong>Offline Cards:</strong> Meme and quote cards are rendered 100% locally on your device via Flutter canvas.</li>
      <li><strong>Pseudonymous Device ID:</strong> An anonymous UUID is stored solely to manage daily free quotas, anti-abuse protections, and active subscription entitlements.</li>
    </ul>

    <h2>2. How to Delete Your Data</h2>
    <div class="box">
      <h3 style="margin-top:0; color:#38bdf8;">Option A: In-App Immediate Deletion (Recommended)</h3>
      <ol>
        <li>Open the <strong>VibeKit AI</strong> app on your Android device.</li>
        <li>Tap the <strong>Settings</strong> icon (gear icon) in the top bar.</li>
        <li>Scroll down to the <em>Data & Privacy</em> section and tap <strong>"Delete All My Data"</strong>.</li>
        <li>Confirm the prompt. This immediately purges all local SQLite history, favorites, cached preferences on your device, and sends an automated request to permanently erase all associated cloud installation records from our Cloudflare D1 database.</li>
      </ol>
    </div>

    <div class="box">
      <h3 style="margin-top:0; color:#38bdf8;">Option B: Web-Based Deletion Request (If App is Uninstalled)</h3>
      <p>If you have uninstalled the app or are unable to access the in-app settings, you can submit a manual deletion request:</p>
      <p>Send an email to <a href="mailto:privacy@vibekit.ai">privacy@vibekit.ai</a> with:</p>
      <ul>
        <li>Subject: <code>VibeKit AI Data Deletion Request</code></li>
        <li>Body: Your anonymous Installation ID (found in Settings > About, if available) or approximate date and timezone of last app usage.</li>
      </ul>
      <p>Our engineering team will permanently purge any associated quota or billing transaction records within <strong>48 hours</strong>.</p>
    </div>

    <h2>3. Types of Data Deleted vs. Retained</h2>
    <ul>
      <li><strong>Deleted immediately:</strong> Installation records, streak tracking, daily usage counters, and feedback logs.</li>
      <li><strong>Play Store Subscriptions:</strong> Active subscription billing and cancellations are managed directly by Google Play. Deleting your app data does not automatically cancel an active Google Play subscription; please cancel active recurring subscriptions via <a href="https://play.google.com/store/account/subscriptions" target="_blank" rel="noopener">Google Play Subscriptions</a>.</li>
    </ul>

    <div class="footer">
      &copy; 2026 VibeKit AI. <a href="/privacy">Privacy Policy</a> &bull; <a href="/terms">Terms of Service</a>
    </div>
  </div>
</body>
</html>`;

const termsHtml = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>ReplyVibe AI — Terms of Service</title>
  <style>
    :root { --bg: #0f172a; --card: #1e293b; --text: #f8fafc; --muted: #94a3b8; --accent: #6366f1; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background: var(--bg); color: var(--text); line-height: 1.6; margin: 0; padding: 20px; }
    .container { max-width: 800px; margin: 0 auto; background: var(--card); padding: 32px; border-radius: 16px; border: 1px solid #334155; }
    h1 { color: #818cf8; font-size: 28px; margin-top: 0; }
    h2 { color: #c7d2fe; font-size: 20px; margin-top: 24px; border-bottom: 1px solid #334155; padding-bottom: 8px; }
    p, li { color: var(--muted); font-size: 15px; }
    ul { padding-left: 20px; }
    .badge { display: inline-block; background: rgba(99, 102, 241, 0.2); color: #818cf8; padding: 4px 12px; border-radius: 9999px; font-size: 13px; font-weight: 600; margin-bottom: 16px; }
    .footer { margin-top: 32px; padding-top: 16px; border-top: 1px solid #334155; font-size: 13px; color: #64748b; text-align: center; }
    a { color: #818cf8; }
  </style>
</head>
<body>
  <div class="container">
    <div class="badge">Terms of Service</div>
    <h1>ReplyVibe AI — Terms of Service</h1>
    <p>Effective Date: November 15, 2026</p>

    <h2>1. Acceptance of Terms</h2>
    <p>By downloading, installing, accessing, or using ReplyVibe AI (also referred to as VibeKit AI), you agree to be bound by these Terms of Service. If you do not agree, please do not use the service.</p>

    <h2>2. Description of Service & Acceptable Use</h2>
    <p>ReplyVibe AI provides AI-assisted conversational reply suggestions, social media captions, profile bios, and offline quote/meme card design tools. You agree not to use the service to generate harassment, threats, hate speech, CSAM, fraud, deceptive impersonation, or unlawful content.</p>

    <h2>3. Content Ownership & AI Disclaimer</h2>
    <p>You retain ownership of the text you input and the creative outputs generated for your personal or commercial use. AI-generated text is probabilistic and provided on an "AS IS" basis; please review outputs before sharing or publishing.</p>

    <h2>4. Subscriptions, Rewards & In-App Purchases</h2>
    <p>Pro subscriptions and one-time passes are billed and managed through Google Play Billing. Auto-renewing subscriptions can be canceled anytime via <a href="https://play.google.com/store/account/subscriptions">Google Play Subscriptions</a>. Refund requests follow Google Play policies.</p>

    <h2>5. Contact Us</h2>
    <p>Questions about these Terms? Contact <a href="mailto:support@vibekit.ai">support@vibekit.ai</a>.</p>

    <div class="footer">
      &copy; 2026 ReplyVibe AI &bull; <a href="/privacy">Privacy Policy</a> &bull; <a href="/delete-data">Data Deletion</a>
    </div>
  </div>
</body>
</html>`;

privacyRoute.get('/privacy', (c) => {
  return c.html(privacyHtml);
});

privacyPublicRoute.get('/privacy-policy', (c) => {
  return c.html(privacyHtml);
});

privacyPublicRoute.get('/terms', (c) => {
  return c.html(termsHtml);
});

privacyPublicRoute.get('/terms-of-service', (c) => {
  return c.html(termsHtml);
});

privacyPublicRoute.get('/delete-account', (c) => {
  return c.html(deleteDataHtml);
});

privacyPublicRoute.get('/delete-data', (c) => {
  return c.html(deleteDataHtml);
});

privacyPublicRoute.get('/privacy/delete-data', (c) => {
  return c.html(deleteDataHtml);
});

privacyRoute.route('/', privacyPublicRoute as any);

privacyRoute.post('/privacy/delete-data', async (c) => {
  const installationId = c.get('installationId');
  if (!installationId || installationId === 'anonymous_default') {
    return c.json({ error: { code: 'UNAUTHORIZED', message: 'Valid installation ID required.' } }, 401);
  }
  const quotaManager = new QuotaManager(c.env);

  await quotaManager.deleteUserData(installationId);

  return c.json({
    success: true,
    message: 'All cloud data associated with this installation has been permanently purged.',
  });
});
