import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { AppHonoEnv } from './types';
import { installationMiddleware } from './middleware/installation';
import { structuredLoggerMiddleware } from './middleware/logger';
import { rateLimiterMiddleware } from './middleware/rate_limit';
import { bodyLimitMiddleware } from './middleware/body_limit';
import { globalErrorHandler } from './middleware/error_handler';
import { healthRoute } from './routes/health';
import { configRoute } from './routes/config';
import { usageRoute } from './routes/usage';
import { generationsRoute } from './routes/generations';
import { purchasesRoute } from './routes/purchases';
import { adsRoute } from './routes/ads';
import { privacyRoute } from './routes/privacy';
import { feedbackRoute } from './routes/feedback';
import { streakRoute } from './routes/streak';
import { referralsRoute } from './routes/referrals';
import { adminRoute } from './routes/admin';
import { authRoute } from './routes/auth';
import { getAdminHtml } from './admin/ui';
import { handleScheduledTask } from './cron/nightly_stats';

const app = new Hono<AppHonoEnv>();

// 1. Strict Security Headers Middleware (OWASP ASVS Level 2)
app.use('*', async (c, next) => {
  c.header('X-Content-Type-Options', 'nosniff');
  c.header('X-Frame-Options', 'DENY');
  c.header('Strict-Transport-Security', 'max-age=31536000; includeSubDomains; preload');
  c.header('Referrer-Policy', 'strict-origin-when-cross-origin');
  c.header('Permissions-Policy', 'camera=(), microphone=(), geolocation=(), payment=()');
  c.header(
    'Content-Security-Policy',
    "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; connect-src 'self' https:; frame-ancestors 'none'; object-src 'none'; base-uri 'self'"
  );
  await next();
});

// 2. Body Size Limiter (16 KB payload cap to mitigate Zod CVE and isolate OOM)
app.use('/v1/*', bodyLimitMiddleware(16384));

// 3. CORS Middleware with Strict Origin Allowlist
app.use(
  '*',
  cors({
    origin: (origin) => {
      // Mobile app native clients do not send Origin header
      if (!origin) return '*';
      const isLocalhost = /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin);
      if (
        isLocalhost ||
        origin.endsWith('.vibekit.ai') ||
        origin === 'https://vibekit.ai'
      ) {
        return origin;
      }
      return null;
    },
    allowMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowHeaders: [
      'Content-Type',
      'Accept',
      'Authorization',
      'X-App-Instance-Id',
      'X-App-Version',
      'X-Idempotency-Key',
      'Idempotency-Key',
      'X-Session-Token',
      'X-Request-Id',
      'X-Admin-Action',
      'Cf-Access-Jwt-Assertion',
    ],
    maxAge: 86400,
  })
);

// 4. Shared Installation & RequestId Extraction
app.use('/v1/*', installationMiddleware());

// 5. Structured Logging Middleware with Zero Prompt Retention Redaction
app.use('/v1/*', structuredLoggerMiddleware());

// 6. Shared Edge Rate Limiting Middleware across isolates
app.use('/v1/*', rateLimiterMiddleware({ generalLimit: 60, generationLimit: 15, windowSeconds: 60 }));

// 7. Global Error Handler Boundary
app.onError(globalErrorHandler);

// 6. Admin Panel UI & Admin API Routes
app.get('/admin', (c) => c.html(getAdminHtml()));
app.get('/admin/*', (c) => c.html(getAdminHtml()));
app.route('/v1/admin', adminRoute as any);

// 7. Route Mounts under /v1
app.route('/v1', healthRoute as any);
app.route('/v1', authRoute as any);
app.route('/v1', configRoute as any);
app.route('/v1', usageRoute as any);
app.route('/v1', generationsRoute as any);
app.route('/v1', purchasesRoute as any);
app.route('/v1', adsRoute as any);
app.route('/v1', privacyRoute as any);
app.route('/v1', feedbackRoute as any);
app.route('/v1', streakRoute as any);
app.route('/v1', referralsRoute as any);
app.route('/', privacyRoute as any);

// Root Fallback
app.get('/', (c) => {
  return c.text('VibeKit AI Edge API v1.0.0 is operational.');
});

export { app };

export default Object.assign(app, {
  scheduled: handleScheduledTask,
});
