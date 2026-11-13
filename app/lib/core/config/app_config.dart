import 'package:flutter/foundation.dart';

/// Central application configuration.
/// Provides default development and production endpoints,
/// product IDs for Google Play Billing, and official AdMob test unit IDs.
class AppConfig {
  AppConfig._();

  static const String appName = 'VibeKit AI';
  static const String appTagline =
      'Create your next reply, caption and shareable card.';
  static const String appVersion = '1.0.0+1';

  static bool get isDev => kDebugMode;

  // Backend API URL
  // Automatically points to 127.0.0.1 on Web/Desktop, or 10.0.2.2 on Android emulator
  static String get defaultApiUrl {
    const fromEnv = String.fromEnvironment('API_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return 'http://127.0.0.1:8787';
    }
    return 'http://10.0.2.2:8787';
  }

  // Play Billing Product IDs
  static const String proWeeklyId = 'vibekit_pro_weekly';
  static const String proMonthlyId = 'vibekit_pro_monthly';
  static const String proYearlyId = 'vibekit_pro_yearly';
  static const String proLifetimeId = 'vibekit_pro_lifetime';
  static const String creditPack50Id = 'vibekit_credits_50';

  // AdMob Official Google Test IDs (Safe for test & verification)
  static const String testBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String testRewardedAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';
  static const String testInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';

  // Active AdMob Unit IDs (falls back to test IDs if not passed via --dart-define)
  static String get bannerAdUnitId {
    const fromEnv = String.fromEnvironment('ADMOB_BANNER_ID');
    return fromEnv.isNotEmpty ? fromEnv : testBannerAdUnitId;
  }

  static String get rewardedAdUnitId {
    const fromEnv = String.fromEnvironment('ADMOB_REWARDED_ID');
    return fromEnv.isNotEmpty ? fromEnv : testRewardedAdUnitId;
  }

  static String get interstitialAdUnitId {
    const fromEnv = String.fromEnvironment('ADMOB_INTERSTITIAL_ID');
    return fromEnv.isNotEmpty ? fromEnv : testInterstitialAdUnitId;
  }

  /// Verifies adherence to Google AdMob policy on environment separation:
  /// Test IDs in debug, production IDs via build flags in release.
  static void validateAdEnvironment() {
    const isRelease = kReleaseMode;
    final hasBanner = const String.fromEnvironment('ADMOB_BANNER_ID').isNotEmpty;
    final hasRewarded = const String.fromEnvironment('ADMOB_REWARDED_ID').isNotEmpty;
    final hasInterstitial = const String.fromEnvironment('ADMOB_INTERSTITIAL_ID').isNotEmpty;

    if (isRelease) {
      if (!hasBanner || !hasRewarded || !hasInterstitial) {
        debugPrint(
          '[AdMob Safety Assertion] Release mode active with Google Test IDs. '
          'Provide real production IDs via --dart-define before publishing to Google Play.',
        );
      }
    } else {
      if (hasBanner || hasRewarded || hasInterstitial) {
        debugPrint(
          '[AdMob Safety Warning] Debug build is using custom ad unit IDs. '
          'Use official test IDs during local testing to prevent policy violations.',
        );
      }
    }
  }

  // Feature limits
  static const int maxInputCharacters = 500;
  static const int defaultDailyCredits = 3;
  static const int rewardedAdCreditBonus = 3;
  static const int maxDailyRewardedAds = 2;
  static const int monthlyProCreditAllowance = 200;

  // Deep Link for Google Play Subscriptions management
  static const String playSubscriptionsUrl =
      'https://play.google.com/store/account/subscriptions?package=com.vibekit.vibekit_ai';
}
