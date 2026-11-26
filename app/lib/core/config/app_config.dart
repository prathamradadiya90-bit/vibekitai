import 'package:flutter/foundation.dart';

/// Central application configuration.
/// Provides default development and production endpoints,
/// product IDs for Google Play Billing, and official AdMob test unit IDs.
class AppConfig {
  AppConfig._();

  static const String appName = 'ReplyVibe AI';
  static const String appTagline =
      'Create your next reply, caption and shareable card.';
  static const String appVersion = '1.0.3+4';

  static bool get isDev => kDebugMode;

  // Production Backend API URL deployed on Vercel Edge
  static String get defaultApiUrl {
    const fromEnv = String.fromEnvironment('API_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    return 'https://replyvibe-api.vercel.app';
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

  // Optional Direct Production Ad Unit IDs:
  // Paste your real ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY IDs below for production release,
  // or pass them via --dart-define (e.g. --dart-define=ADMOB_BANNER_ID=...).
  // While running in debug mode (kDebugMode), official test IDs are automatically used to protect your account.
  static const String prodBannerAdUnitId = 'ca-app-pub-2168884661772447/4264617323';
  static const String prodRewardedAdUnitId = 'ca-app-pub-2168884661772447/3469897059';
  static const String prodInterstitialAdUnitId = '';

  // Active AdMob Unit IDs. Release builds strictly avoid falling back to Google Test Ad IDs.
  static String get bannerAdUnitId {
    const fromEnv = String.fromEnvironment('ADMOB_BANNER_ID');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (!kDebugMode) return prodBannerAdUnitId;
    return testBannerAdUnitId;
  }

  static String get rewardedAdUnitId {
    const fromEnv = String.fromEnvironment('ADMOB_REWARDED_ID');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (!kDebugMode) return prodRewardedAdUnitId;
    return testRewardedAdUnitId;
  }

  static String get interstitialAdUnitId {
    const fromEnv = String.fromEnvironment('ADMOB_INTERSTITIAL_ID');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (!kDebugMode) return prodInterstitialAdUnitId;
    return testInterstitialAdUnitId;
  }

  /// Verifies adherence to Google AdMob policy on environment separation:
  /// Test IDs in debug, production IDs (via --dart-define or direct constants) in release.
  static void validateAdEnvironment() {
    const isRelease = kReleaseMode;
    final hasBanner = const String.fromEnvironment('ADMOB_BANNER_ID').isNotEmpty ||
        prodBannerAdUnitId.isNotEmpty;
    final hasRewarded = const String.fromEnvironment('ADMOB_REWARDED_ID').isNotEmpty ||
        prodRewardedAdUnitId.isNotEmpty;
    final hasInterstitial =
        const String.fromEnvironment('ADMOB_INTERSTITIAL_ID').isNotEmpty ||
            prodInterstitialAdUnitId.isNotEmpty;

    if (isRelease) {
      if (!hasBanner || !hasRewarded || !hasInterstitial) {
        debugPrint(
          '[AdMob Safety Notice] Release mode has unconfigured optional ad unit(s) '
          '(banner=$hasBanner, rewarded=$hasRewarded, interstitial=$hasInterstitial). '
          'Unconfigured placements are disabled in release.',
        );
      }
    } else {
      if (const String.fromEnvironment('ADMOB_BANNER_ID').isNotEmpty ||
          const String.fromEnvironment('ADMOB_REWARDED_ID').isNotEmpty ||
          const String.fromEnvironment('ADMOB_INTERSTITIAL_ID').isNotEmpty) {
        debugPrint(
          '[AdMob Safety Warning] Debug build has custom --dart-define ad unit IDs. '
          'Use official test IDs during local testing to prevent policy violations.',
        );
      }
    }
  }

  static const String androidPackageId = 'com.vibekit.vibekit_ai';

  // Feature limits
  static const int maxInputCharacters = 500;
  static const int defaultDailyCredits = 3;
  static const int rewardedAdCreditBonus = 3;
  static const int maxDailyRewardedAds = 2;
  static const int monthlyProCreditAllowance = 200;

  // Deep Link for Google Play Subscriptions management
  static const String playSubscriptionsUrl =
      'https://play.google.com/store/account/subscriptions?package=$androidPackageId';
}
