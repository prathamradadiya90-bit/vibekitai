import { Hono } from 'hono';
import { Env } from '../types';
import { PurchaseVerifySchema, RtdnNotificationSchema } from '../schemas/validation';
import { QuotaManager } from '../quota/quota_manager';
import { PurchasesRepository } from '../db/purchases.repo';
import {
  CREDIT_PACK_PRODUCTS,
  EntitlementStatus,
  LIFETIME_PRODUCTS,
  SUBSCRIPTION_PRODUCTS,
  isUnverifiedBillingAllowed,
  verifyProductPurchase,
  verifySubscriptionPurchase,
} from '../security/google_play';

export const purchasesRoute = new Hono<{ Bindings: Env }>();

// 1. Authoritative Purchase Verification & Acknowledgment
purchasesRoute.post('/purchases/verify', async (c) => {
  const installationId = c.req.header('X-App-Instance-Id') || 'anonymous_default';
  const bodyResult = PurchaseVerifySchema.safeParse(await c.req.json());

  if (!bodyResult.success) {
    return c.json(
      {
        error: {
          code: 'VALIDATION_ERROR',
          message: 'Invalid purchase verification payload.',
          details: bodyResult.error.format(),
        },
      },
      400
    );
  }

  const { product_id, purchase_token } = bodyResult.data;
  const quotaManager = new QuotaManager(c.env);

  const isSubscription = SUBSCRIPTION_PRODUCTS.has(product_id);
  const isLifetime = LIFETIME_PRODUCTS.has(product_id);
  if (!isSubscription && !isLifetime) {
    return c.json(
      { error: { code: 'INVALID_PRODUCT', message: 'This product does not grant a Pro entitlement.' } },
      400
    );
  }

  if (isLifetime) {
    const result = await verifyProductPurchase(c.env, product_id, purchase_token, { acknowledge: true });
    if (!result.ok) return verificationFailure(c, result);
    if (!result.purchased) {
      return c.json({ is_verified: false, product_id, status: 'NOT_PURCHASED' }, 402);
    }
    await quotaManager.activatePro(installationId, product_id, purchase_token, result.orderId, null);
    return c.json({
      is_verified: true,
      product_id,
      status: 'ACTIVE',
      message: 'Lifetime pass verified, acknowledged, and activated.',
    });
  }

  const result = await verifySubscriptionPurchase(c.env, product_id, purchase_token);
  if (!result.ok) return verificationFailure(c, result);
  if (!result.entitled) {
    return c.json({ is_verified: false, product_id, status: result.status }, 402);
  }

  await quotaManager.activatePro(
    installationId,
    product_id,
    purchase_token,
    result.orderId,
    result.expiresAt,
    result.status as 'ACTIVE' | 'IN_GRACE_PERIOD' | 'CANCELED'
  );

  return c.json({
    is_verified: true,
    product_id,
    status: result.status,
    expires_at: result.expiresAt,
    message: 'Subscription successfully verified, acknowledged, and activated.',
  });
});

function verificationFailure(c: any, result: { reason: string; retryable: boolean }) {
  return c.json(
    {
      is_verified: false,
      error: {
        code: result.retryable ? 'VERIFICATION_UNAVAILABLE' : 'PURCHASE_INVALID',
        message: result.reason,
        retryable: result.retryable,
      },
    },
    result.retryable ? 503 : 400
  );
}

// Dev/test-only mapping of RTDN notification types when Google Play cannot be queried.
// 1: RECOVERED, 2: RENEWED, 3: CANCELED, 4: PURCHASED, 5: ON_HOLD,
// 6: IN_GRACE_PERIOD, 7: RESTARTED, 10: PAUSED, 12: REVOKED, 13: EXPIRED
function mapNotificationTypeForDev(
  notificationType: number
): { status: EntitlementStatus; expiresAt?: string } | null {
  const nowIso = new Date().toISOString();
  switch (notificationType) {
    case 1:
    case 2:
    case 4:
    case 7:
      return { status: 'ACTIVE', expiresAt: new Date(Date.now() + 30 * 86400000).toISOString() };
    case 3:
      return { status: 'CANCELED' };
    case 5:
      return { status: 'ON_HOLD' };
    case 6:
      return { status: 'IN_GRACE_PERIOD' };
    case 10:
      return { status: 'PAUSED' };
    case 12:
      return { status: 'REVOKED', expiresAt: nowIso };
    case 13:
      return { status: 'EXPIRED', expiresAt: nowIso };
    default:
      return null;
  }
}

// 2. Query Subscription Status & Billing Cycle
purchasesRoute.get('/subscription/status', async (c) => {
  const installationId = c.req.header('X-App-Instance-Id') || 'anonymous_default';
  const quotaManager = new QuotaManager(c.env);
  const quota = await quotaManager.getQuotaStatus(installationId);

  return c.json({
    is_pro: quota.is_pro,
    pro_credits_remaining: quota.pro_credits_remaining,
    pro_cycle_resets_at: quota.pro_cycle_resets_at,
  });
});

// 3. Google Play Real-Time Developer Notifications (RTDN) via Cloud Pub/Sub
purchasesRoute.post('/purchases/rtdn', async (c) => {
  const bodyResult = RtdnNotificationSchema.safeParse(await c.req.json().catch(() => ({})));

  if (!bodyResult.success) {
    return c.json(
      {
        error: {
          code: 'INVALID_RTDN_PAYLOAD',
          message: 'The request does not match the Google Cloud Pub/Sub push schema.',
        },
      },
      400
    );
  }

  try {
    const rawData = atob(bodyResult.data.message.data);
    const parsedData = JSON.parse(rawData);

    const eventTimeMillis = parseInt(parsedData.eventTimeMillis || `${Date.now()}`, 10);
    const messageId =
      bodyResult.data.message.messageId || `rtdn_${Date.now()}_${Math.random().toString(36).substring(7)}`;
    const devMode = isUnverifiedBillingAllowed(c.env);
    const quotaManager = new QuotaManager(c.env);

    const subNotice = parsedData.subscriptionNotification;
    const voidedNotice = parsedData.voidedPurchaseNotification;

    if (subNotice) {
      const { notificationType, purchaseToken, subscriptionId } = subNotice;
      let status: EntitlementStatus;
      let expiresAt: string | undefined;

      if (devMode) {
        const mapped = mapNotificationTypeForDev(notificationType);
        if (!mapped) return c.json({ success: true, processed: false, reason: 'UNHANDLED_TYPE' });
        ({ status, expiresAt } = mapped);
      } else {
        // This endpoint is publicly reachable, so the notification body is never trusted:
        // re-read the authoritative state and expiry from Google Play.
        const verified = await verifySubscriptionPurchase(c.env, subscriptionId, purchaseToken);
        if (!verified.ok) {
          if (verified.retryable) {
            return c.json({ error: { code: 'VERIFICATION_UNAVAILABLE', message: verified.reason } }, 503);
          }
          return c.json({ success: true, processed: false, reason: verified.reason });
        }
        status = verified.status;
        expiresAt = verified.expiresAt ?? undefined;
      }

      // Check event ordering to prevent out-of-order race conditions
      if (c.env.DB) {
        const purchasesRepo = new PurchasesRepository(c.env.DB);
        const isOutdated = await purchasesRepo.isRtdnEventOutdated(purchaseToken, eventTimeMillis);
        if (isOutdated) {
          return c.json({ success: true, processed: false, reason: 'OUT_OF_ORDER_EVENT' });
        }

        await purchasesRepo.recordRtdnEvent({
          eventId: messageId,
          purchaseToken,
          notificationType,
          eventTimeMillis,
          status,
        });
      }

      await quotaManager.handleSubscriptionLifecycleUpdate({ purchaseToken, status, expiresAt });
    } else if (voidedNotice?.purchaseToken) {
      // Refund / chargeback (covers the one-time lifetime pass, which has no subscription events)
      const purchaseToken: string = voidedNotice.purchaseToken;
      const entitlement = c.env.DB
        ? await c.env.DB.prepare('SELECT product_id FROM subscription_entitlements WHERE purchase_token = ?')
            .bind(purchaseToken)
            .first<{ product_id: string }>()
        : null;

      if (!entitlement && c.env.DB) {
        return c.json({ success: true, processed: false, reason: 'UNKNOWN_TOKEN' });
      }

      let revoke = devMode;
      if (!devMode && entitlement) {
        if (LIFETIME_PRODUCTS.has(entitlement.product_id)) {
          const v = await verifyProductPurchase(c.env, entitlement.product_id, purchaseToken, { acknowledge: false });
          if (!v.ok && v.retryable) {
            return c.json({ error: { code: 'VERIFICATION_UNAVAILABLE', message: v.reason } }, 503);
          }
          revoke = !v.ok || !v.purchased;
        } else {
          const v = await verifySubscriptionPurchase(c.env, entitlement.product_id, purchaseToken);
          if (!v.ok && v.retryable) {
            return c.json({ error: { code: 'VERIFICATION_UNAVAILABLE', message: v.reason } }, 503);
          }
          revoke = !v.ok || !v.entitled;
        }
      }

      if (revoke) {
        await quotaManager.handleSubscriptionLifecycleUpdate({
          purchaseToken,
          status: 'REVOKED',
          expiresAt: new Date().toISOString(),
        });
      }
    }

    return c.json({ success: true, processed: true });
  } catch (err: any) {
    console.error('Failed to parse Pub/Sub RTDN payload:', err);
    return c.json(
      {
        error: {
          code: 'RTDN_DECODE_ERROR',
          message: err.message || 'Failed to decode RTDN payload.',
        },
      },
      400
    );
  }
});

// 4. One-time Consumable Credit Pack Verification (Feature-Flagged & Idempotent)
purchasesRoute.post('/purchases/credit-pack', async (c) => {
  const installationId = c.req.header('X-App-Instance-Id') || 'anonymous_default';
  const bodyResult = PurchaseVerifySchema.safeParse(await c.req.json());

  if (!bodyResult.success) {
    return c.json(
      {
        error: {
          code: 'VALIDATION_ERROR',
          message: 'Invalid credit pack purchase payload.',
          details: bodyResult.error.format(),
        },
      },
      400
    );
  }

  const { product_id, purchase_token, order_id } = bodyResult.data;

  // Feature Flag Guard
  const isEnabled = c.env.ENABLE_CREDIT_PACKS === 'true' || c.env.ENVIRONMENT === 'test';
  if (!isEnabled) {
    return c.json(
      {
        error: {
          code: 'FEATURE_DISABLED',
          message: 'Consumable credit packs are currently inactive.',
        },
      },
      403
    );
  }

  const creditsPerPack = CREDIT_PACK_PRODUCTS[product_id];
  if (!creditsPerPack) {
    return c.json(
      { error: { code: 'INVALID_PRODUCT', message: 'This product is not a credit pack.' } },
      400
    );
  }

  // Verify with Google; the client is consuming the purchase, so we don't acknowledge here.
  const verified = await verifyProductPurchase(c.env, product_id, purchase_token, {
    acknowledge: false,
    mockOrderId: order_id,
  });
  if (!verified.ok) return verificationFailure(c, verified);
  if (!verified.purchased) {
    return c.json(
      { success: false, error: { code: 'NOT_PURCHASED', message: 'Purchase is pending or was canceled.' } },
      402
    );
  }

  const creditsToGrant = creditsPerPack * verified.quantity;
  // Idempotency key comes from Google (orderId) or the token itself, never a client-chosen value.
  const effectiveOrderId = verified.orderId || purchase_token;
  const db = c.env.DB;

  if (!db) {
    return c.json({
      success: true,
      credits_granted: creditsToGrant,
      order_id: effectiveOrderId,
      message: `${creditsToGrant} credits added to your balance.`,
    });
  }

  const purchasesRepo = new PurchasesRepository(db);

  // Idempotency check: Ensure order_id has not already been processed
  const alreadyProcessed = await purchasesRepo.isCreditPackProcessed(effectiveOrderId, purchase_token);
  if (alreadyProcessed) {
    return c.json({
      success: true,
      credits_granted: 0,
      already_processed: true,
      order_id: effectiveOrderId,
      message: 'This credit pack purchase was already credited.',
    });
  }

  // Atomic batch: record purchase and grant credits to daily_usage
  await purchasesRepo.recordCreditPackAndGrantCredits({
    orderId: effectiveOrderId,
    installationId,
    productId: product_id,
    creditsGranted: creditsToGrant,
    purchaseToken: purchase_token,
  });

  return c.json({
    success: true,
    credits_granted: creditsToGrant,
    order_id: effectiveOrderId,
    message: `Successfully credited ${creditsToGrant} AI credits!`,
  });
});

