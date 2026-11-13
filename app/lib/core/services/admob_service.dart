import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../config/app_config.dart';
import 'analytics_service.dart';

/// Single authoritative service managing the lifecycle, frequency caps,
/// exponential backoff preloading, and UMP consent for all Google AdMob units.
class AdMobService {
  bool _isInitialized = false;

  // Rewarded Ad State
  RewardedAd? _rewardedAd;
  bool _isRewardedAdLoading = false;
  bool _isShowingRewardedAd = false;
  int _rewardedRetryCount = 0;
  static const int _maxRetries = 3;

  // Interstitial Ad State
  InterstitialAd? _interstitialAd;
  bool _isInterstitialLoading = false;
  int _interstitialRetryCount = 0;
  DateTime? _lastInterstitialShownAt;
  int _interstitialsShownToday = 0;
  String _todayDateStr = DateTime.now().toUtc().toIso8601String().substring(0, 10);

  // Pro status cache
  bool _isProUser = false;

  bool get isInitialized => _isInitialized;
  bool get isRewardedAdReady => _rewardedAd != null && !_isShowingRewardedAd;
  bool get isShowingAd => _isShowingRewardedAd;

  void updateProStatus(bool isPro) {
    _isProUser = isPro;
    if (_isProUser) {
      // Free memory on Pro upgrade
      dispose();
    }
  }

  /// Non-blocking initialization executed after the first frame
  Future<void> init() async {
    if (kIsWeb) {
      debugPrint('AdMobService: Web platform detected. MobileAds skipped.');
      return;
    }
    AppConfig.validateAdEnvironment();

    try {
      // 1. Policy Compliance: Child-directed and family audience declaration
      final configuration = RequestConfiguration(
        tagForChildDirectedTreatment: TagForChildDirectedTreatment.no,
        tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.no,
        maxAdContentRating: MaxAdContentRating.t, // Teen (non-child app)
      );
      await MobileAds.instance.updateRequestConfiguration(configuration);

      // 2. Request UMP Consent for GDPR/EEA/UK compliance
      await _requestConsent();

      // 3. Initialize Mobile Ads SDK
      await MobileAds.instance.initialize();
      _isInitialized = true;

      // 4. Preload initial ads only if free user
      if (!_isProUser) {
        loadRewardedAd();
        loadInterstitialAd();
      }
    } catch (e) {
      debugPrint('AdMobService: Initialization failed ($e). Ads disabled.');
      _isInitialized = false;
    }
  }

  Future<void> _requestConsent() async {
    try {
      final params = ConsentRequestParameters();
      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () async {
          if (await ConsentInformation.instance.isConsentFormAvailable()) {
            ConsentForm.loadAndShowConsentFormIfRequired((formError) {
              if (formError != null) {
                debugPrint('Consent form error: ${formError.message}');
              }
            });
          }
        },
        (formError) {
          debugPrint('Consent info update failed: ${formError.message}');
        },
      );
    } catch (e) {
      debugPrint('Consent error: $e');
    }
  }

  // ==========================================
  // REWARDED ADS
  // ==========================================

  /// Preloads a rewarded ad with exponential backoff on failure
  void loadRewardedAd() {
    if (!_isInitialized || _isRewardedAdLoading || _rewardedAd != null || _isProUser) return;

    _isRewardedAdLoading = true;
    RewardedAd.load(
      adUnitId: AppConfig.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedAdLoading = false;
          _rewardedRetryCount = 0;
          AnalyticsService.instance.logAdLoadSuccess('rewarded');
        },
        onAdFailedToLoad: (error) {
          debugPrint('RewardedAd failed to load: ${error.message} (${error.code})');
          _rewardedAd = null;
          _isRewardedAdLoading = false;
          AnalyticsService.instance.logAdLoadFail('rewarded', error.code);

          // Retry with exponential backoff (capped at _maxRetries)
          if (_rewardedRetryCount < _maxRetries) {
            _rewardedRetryCount++;
            final delaySec = math.pow(2, _rewardedRetryCount).toInt();
            Timer(Duration(seconds: delaySec), () {
              if (!_isProUser) loadRewardedAd();
            });
          }
        },
      ),
    );
  }

  /// Displays the rewarded ad with strict double-tap mutex protection,
  /// server-side verification options, and early dismissal tracking.
  Future<bool> showRewardedAd({
    String? userId,
    String? customData,
    required Function(RewardItem reward) onRewardEarned,
    VoidCallback? onAdClosed,
    VoidCallback? onAdFailed,
  }) async {
    if (_isProUser) return false;

    // Double-tap mutex lock
    if (_isShowingRewardedAd) {
      debugPrint('[AdMob] Rewarded ad already showing. Suppressing double invocation.');
      return false;
    }

    if (_rewardedAd == null) {
      debugPrint('[AdMob] Rewarded ad not ready. Triggering preload.');
      onAdFailed?.call();
      loadRewardedAd();
      return false;
    }

    _isShowingRewardedAd = true;
    bool userEarnedReward = false;

    // Set Server-Side Verification (SSV) parameters if provided
    if (userId != null || customData != null) {
      try {
        _rewardedAd!.setServerSideOptions(
          ServerSideVerificationOptions(
            userId: userId,
            customData: customData,
          ),
        );
      } catch (e) {
        debugPrint('[AdMob] Error configuring SSV options: $e');
      }
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        AnalyticsService.instance.logAdImpression('rewarded');
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _isShowingRewardedAd = false;

        if (!userEarnedReward) {
          AnalyticsService.instance.logAdDismissedEarly('rewarded');
        }

        // Preload next ad
        loadRewardedAd();
        onAdClosed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('[AdMob] Failed to show rewarded ad: $error');
        ad.dispose();
        _rewardedAd = null;
        _isShowingRewardedAd = false;
        loadRewardedAd();
        onAdFailed?.call();
      },
    );

    await _rewardedAd!.show(
      onUserEarnedReward: (adWithoutView, reward) {
        userEarnedReward = true;
        AnalyticsService.instance.logAdRewardGranted();
        onRewardEarned(reward);
      },
    );

    return true;
  }

  // ==========================================
  // INTERSTITIAL ADS
  // ==========================================

  /// Preloads an interstitial ad with exponential backoff on failure
  void loadInterstitialAd() {
    if (!_isInitialized || _isInterstitialLoading || _interstitialAd != null || _isProUser) return;

    _isInterstitialLoading = true;
    InterstitialAd.load(
      adUnitId: AppConfig.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialLoading = false;
          _interstitialRetryCount = 0;
          AnalyticsService.instance.logAdLoadSuccess('interstitial');
        },
        onAdFailedToLoad: (error) {
          debugPrint('InterstitialAd failed to load: ${error.message} (${error.code})');
          _interstitialAd = null;
          _isInterstitialLoading = false;
          AnalyticsService.instance.logAdLoadFail('interstitial', error.code);

          if (_interstitialRetryCount < _maxRetries) {
            _interstitialRetryCount++;
            final delaySec = math.pow(2, _interstitialRetryCount).toInt();
            Timer(Duration(seconds: delaySec), () {
              if (!_isProUser) loadInterstitialAd();
            });
          }
        },
      ),
    );
  }

  /// Convenience alias for showInterstitialIfEligible
  Future<bool> showInterstitialAd({VoidCallback? onDismissed}) =>
      showInterstitialIfEligible(onDismissed: onDismissed);

  /// Evaluates frequency capping rules and policy constraints:
  /// - Pro users: never shown
  /// - Max 3 interstitials per UTC day
  /// - Minimum 180s (3 minute) interval between shows
  /// - Must be at natural breaks (caller's responsibility)
  Future<bool> showInterstitialIfEligible({
    VoidCallback? onDismissed,
  }) async {
    if (_isProUser) return false;

    // Reset daily count if UTC day changed
    final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    if (today != _todayDateStr) {
      _todayDateStr = today;
      _interstitialsShownToday = 0;
    }

    if (_interstitialsShownToday >= 3) {
      debugPrint('[AdMob] Interstitial suppressed: Daily frequency cap reached (3/3).');
      return false;
    }

    if (_lastInterstitialShownAt != null) {
      final elapsedSeconds = DateTime.now().difference(_lastInterstitialShownAt!).inSeconds;
      if (elapsedSeconds < 180) {
        debugPrint('[AdMob] Interstitial suppressed: Cooldown active ($elapsedSeconds / 180s).');
        return false;
      }
    }

    if (_interstitialAd == null) {
      loadInterstitialAd();
      return false;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        AnalyticsService.instance.logAdImpression('interstitial');
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _lastInterstitialShownAt = DateTime.now();
        _interstitialsShownToday++;
        loadInterstitialAd();
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd();
        onDismissed?.call();
      },
    );

    await _interstitialAd!.show();
    return true;
  }

  // ==========================================
  // ADAPTIVE BANNER ADS
  // ==========================================

  /// Creates a BannerAd instance configured with screen width for adaptive layout
  BannerAd createBannerAd({
    required Function() onAdLoaded,
    Function(LoadAdError)? onAdFailed,
  }) {
    return BannerAd(
      adUnitId: AppConfig.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          AnalyticsService.instance.logAdLoadSuccess('banner');
          AnalyticsService.instance.logAdImpression('banner');
          onAdLoaded();
        },
        onAdFailedToLoad: (ad, error) {
          AnalyticsService.instance.logAdLoadFail('banner', error.code);
          ad.dispose();
          onAdFailed?.call(error);
        },
      ),
    );
  }

  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isShowingRewardedAd = false;
  }
}
