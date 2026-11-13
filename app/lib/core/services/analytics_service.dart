import 'package:flutter/foundation.dart';

/// Privacy-safe Analytics Service.
/// ZERO user text, prompt content, or sensitive identifiers are ever recorded.
/// Only discrete numeric funnel progression events are logged.
class AnalyticsService {
  AnalyticsService._();

  static final AnalyticsService instance = AnalyticsService._();

  /// Logs a privacy-safe funnel step
  void logEvent(String eventName, {Map<String, dynamic>? parameters}) {
    // Whitelist allowed event names
    const allowedEvents = {
      'onboarding_complete',
      'generate_success',
      'quota_exceeded',
      'ad_load_success',
      'ad_load_fail',
      'ad_impression',
      'ad_reward_granted',
      'ad_dismissed_early',
      'paywall_view',
      'paywall_cta_tap',
      'purchase_success',
      'streak_day_n',
      'share_card',
      'referral_claimed',
      'referral_shared',
      'in_app_review_prompt_shown',
      'in_app_review_dismissed',
      'in_app_review_accepted',
    };

    if (!allowedEvents.contains(eventName)) {
      debugPrint('[Analytics] Suppressed non-whitelisted event: $eventName');
      return;
    }

    // Filter parameters to ensure no text/prompts are attached
    final sanitizedParams = <String, dynamic>{};
    if (parameters != null) {
      for (final entry in parameters.entries) {
        // Only accept numbers, booleans, or safe enum tags
        if (entry.value is num || entry.value is bool) {
          sanitizedParams[entry.key] = entry.value;
        } else if (entry.value is String) {
          // Allow only known non-sensitive enum identifiers
          const safeKeys = {
            'ad_type',
            'plan_id',
            'action_type',
            'source',
            'variant',
            'error_code'
          };
          if (safeKeys.contains(entry.key)) {
            sanitizedParams[entry.key] = entry.value;
          }
        }
      }
    }

    if (kDebugMode) {
      debugPrint('[Analytics Event] $eventName: $sanitizedParams');
    }
  }

  void logOnboardingComplete() => logEvent('onboarding_complete');

  void logGenerateSuccess(String actionType) =>
      logEvent('generate_success', parameters: {'action_type': actionType});

  void logQuotaExceeded() => logEvent('quota_exceeded');

  void logAdLoadSuccess(String adType) =>
      logEvent('ad_load_success', parameters: {'ad_type': adType});

  void logAdLoadFail(String adType, int errorCode) => logEvent(
        'ad_load_fail',
        parameters: {'ad_type': adType, 'error_code': errorCode.toString()},
      );

  void logAdImpression(String adType) =>
      logEvent('ad_impression', parameters: {'ad_type': adType});

  void logAdRewardGranted() => logEvent('ad_reward_granted');

  void logAdDismissedEarly(String adType) =>
      logEvent('ad_dismissed_early', parameters: {'ad_type': adType});

  void logPaywallView(String source, {String variant = 'default'}) =>
      logEvent('paywall_view', parameters: {'source': source, 'variant': variant});

  void logPaywallCtaTap(String planId) =>
      logEvent('paywall_cta_tap', parameters: {'plan_id': planId});

  void logPurchaseSuccess(String planId) =>
      logEvent('purchase_success', parameters: {'plan_id': planId});

  void logStreakDay(int day) =>
      logEvent('streak_day_n', parameters: {'day_count': day});

  void logShareCard() => logEvent('share_card');
}
