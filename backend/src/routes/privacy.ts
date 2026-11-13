import { Hono } from 'hono';
import { Env } from '../types';
import { QuotaManager } from '../quota/quota_manager';

export const privacyRoute = new Hono<{ Bindings: Env }>();

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
    <p>VibeKit AI ("we", "our") is engineered with an uncompromising privacy architecture. We do not require account registration, passwords, email addresses, or phone numbers to use the application.</p>

    <h2>2. Data Collection and Usage</h2>
    <ul>
      <li><strong>Device / Pseudonymous Installation ID:</strong> An anonymous UUID generated on your device is used strictly to account for daily free AI quota allowances (3 daily requests), prevent automated service abuse, and synchronize active subscriptions.</li>
      <li><strong>Transient AI Processing:</strong> Text inputs entered to generate replies, captions, or cards are transmitted securely via TLS 1.3 to our edge processing workers and enterprise AI inference endpoints (Google Gemini / Groq). Under our production commercial tier, prompts are processed transiently in volatile RAM and are never stored in our database, written to persistent disk, or used to train third-party foundation models.</li>
      <li><strong>Card & Meme Studio:</strong> 100% offline. Visual cards and memes are rendered locally on your device hardware canvas via Flutter. Image exports never touch our servers.</li>
      <li><strong>Purchases:</strong> Handled authoritatively through Google Play In-App Billing. We never receive, process, or store credit card numbers or financial credentials.</li>
    </ul>

    <h2>3. Advertising & Third-Party SDKs</h2>
    <p>VibeKit AI integrates Google Mobile Ads (AdMob) to provide free daily credits via rewarded video ads. AdMob utilizes Google Server-Side Verification (SSV) to prevent fraud and may process advertising identifiers in compliance with Google Play Developer policies.</p>

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
      <li><strong>Zero Prompt Retention:</strong> User chat messages, context, and prompts are processed transiently in memory and are <em>never</em> permanently stored in our databases or used for training foundation models.</li>
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

privacyRoute.get('/privacy', (c) => {
  return c.html(privacyHtml);
});

privacyRoute.get('/privacy-policy', (c) => {
  return c.html(privacyHtml);
});

privacyRoute.get('/terms', (c) => {
  return c.html(privacyHtml);
});

privacyRoute.get('/delete-account', (c) => {
  return c.html(deleteDataHtml);
});

privacyRoute.get('/delete-data', (c) => {
  return c.html(deleteDataHtml);
});

privacyRoute.get('/privacy/delete-data', (c) => {
  return c.html(deleteDataHtml);
});

privacyRoute.post('/privacy/delete-data', async (c) => {
  const installationId = c.req.header('X-App-Instance-Id') || 'anonymous_default';
  const quotaManager = new QuotaManager(c.env);

  await quotaManager.deleteUserData(installationId);

  return c.json({
    success: true,
    message: 'All cloud data associated with this installation has been permanently purged.',
  });
});
