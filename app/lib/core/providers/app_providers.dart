import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import '../storage/preferences_service.dart';
import '../storage/local_database.dart';
import '../network/api_client.dart';
import '../services/admob_service.dart';
import '../services/billing_service.dart';
import '../services/review_service.dart';
import '../services/analytics_service.dart';
import '../../models/quota_model.dart';
import '../../models/generation_models.dart';
import '../controllers/generation_controller.dart';

// Singletons / Dependencies injected at startup
final preferencesServiceProvider = Provider<PreferencesService>((ref) {
  throw UnimplementedError('preferencesService must be initialized in main()');
});

final localDatabaseProvider = Provider<LocalDatabase>((ref) {
  throw UnimplementedError('localDatabase must be initialized in main()');
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  return ApiClient(prefs: prefs);
});

final adMobServiceProvider = Provider<AdMobService>((ref) {
  return AdMobService();
});

final billingServiceProvider = Provider<BillingService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return BillingService(apiClient);
});

final reviewServiceProvider = Provider<ReviewService>((ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  return ReviewService(prefs);
});

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService.instance;
});

// Quota State Notifier
class QuotaNotifier extends StateNotifier<QuotaModel> {
  final ApiClient _apiClient;
  final PreferencesService _prefs;

  QuotaNotifier(this._apiClient, this._prefs) : super(QuotaModel.initial()) {
    // Initialise with cached values immediately for fast startup
    state = state.copyWith(
      totalCreditsRemaining: _prefs.getCachedCredits(),
      freeCreditsRemaining: _prefs.getCachedCredits(),
      isPro: _prefs.getCachedIsPro(),
    );
    refresh();
  }

  Future<void> refresh() async {
    try {
      final quota = await _apiClient.getUsage();
      state = quota;
      await _prefs.setCachedCredits(quota.totalCreditsRemaining);
      await _prefs.setCachedIsPro(quota.isPro);
    } catch (_) {
      // Retain cached state on network failure
    }
  }

  void syncCredits(int remaining) {
    if (state.isPro) {
      state = state.copyWith(proCreditsRemaining: remaining);
    } else {
      final free = remaining.clamp(0, state.freeCreditsRemaining);
      final rewarded = (remaining - free).clamp(0, 999);
      state = state.copyWith(
        totalCreditsRemaining: remaining,
        freeCreditsRemaining: free,
        rewardedCreditsRemaining: rewarded,
      );
      _prefs.setCachedCredits(remaining);
    }
  }

  void consumeOneCredit() {
    if (state.isPro) {
      final remaining = (state.proCreditsRemaining - 1).clamp(0, 999);
      state = state.copyWith(proCreditsRemaining: remaining);
      return;
    }
    final remaining = (state.totalCreditsRemaining - 1).clamp(0, 999);
    final free = (state.freeCreditsRemaining - 1).clamp(0, 999);
    final rewarded = state.freeCreditsRemaining > 0
        ? state.rewardedCreditsRemaining
        : (state.rewardedCreditsRemaining - 1).clamp(0, 999);
    state = state.copyWith(
      totalCreditsRemaining: remaining,
      freeCreditsRemaining: free,
      rewardedCreditsRemaining: rewarded,
    );
    _prefs.setCachedCredits(remaining);
  }

  void reset() {
    state = QuotaModel.initial();
  }

  void updateLocally(QuotaModel updated) {
    state = updated;
    _prefs.setCachedCredits(updated.totalCreditsRemaining);
    _prefs.setCachedIsPro(updated.isPro);
  }

  Future<bool> grantRewardCredit({String? nonce, String? transactionId}) async {
    final rewardId = 'rew_${DateTime.now().millisecondsSinceEpoch}';
    try {
      final res = await _apiClient.verifyRewardedAd(
        rewardId: rewardId,
        transactionId: transactionId,
        nonce: nonce,
        adNetwork: 'admob',
      );
      if (res['verified'] == true) {
        final remaining = (res['credits_remaining'] as num?)?.toInt() ??
            (state.totalCreditsRemaining + 3);
        final watched = (res['rewarded_ads_watched_today'] as num?)?.toInt() ??
            (state.rewardedAdsWatchedToday + 1);
        final updated = state.copyWith(
          totalCreditsRemaining: remaining,
          rewardedCreditsRemaining: state.rewardedCreditsRemaining + 3,
          rewardedAdsWatchedToday: watched,
        );
        state = updated;
        await _prefs.setCachedCredits(remaining);
        return true;
      }
    } catch (_) {
      // Verification failed
    }

    // Dev mode fallback
    if (AppConfig.isDev) {
      final updated = state.copyWith(
        totalCreditsRemaining: state.totalCreditsRemaining + 3,
        rewardedCreditsRemaining: state.rewardedCreditsRemaining + 3,
        rewardedAdsWatchedToday: state.rewardedAdsWatchedToday + 1,
      );
      state = updated;
      await _prefs.setCachedCredits(updated.totalCreditsRemaining);
      return true;
    }
    return false;
  }

  void setPro(bool isPro) {
    state = state.copyWith(isPro: isPro);
    _prefs.setCachedIsPro(isPro);
  }
}

final quotaProvider = StateNotifierProvider<QuotaNotifier, QuotaModel>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final prefs = ref.watch(preferencesServiceProvider);
  return QuotaNotifier(apiClient, prefs);
});

// Theme Mode Notifier
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final PreferencesService _prefs;

  ThemeModeNotifier(this._prefs) : super(ThemeMode.light) {
    final saved = _prefs.getThemeMode();
    if (saved == 'dark') {
      state = ThemeMode.dark;
    } else if (saved == 'light') {
      state = ThemeMode.light;
    } else {
      // Default to warm latte cream theme matching the user's reference mockup
      state = ThemeMode.light;
    }
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    final str = mode == ThemeMode.light
        ? 'light'
        : mode == ThemeMode.dark
            ? 'dark'
            : 'system';
    await _prefs.setThemeMode(str);
  }

  Future<void> toggleTheme() async {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setTheme(next);
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  return ThemeModeNotifier(prefs);
});

// Selected Language Notifier
class LanguageNotifier extends StateNotifier<String> {
  final PreferencesService _prefs;

  LanguageNotifier(this._prefs) : super('English') {
    state = _prefs.getLanguage();
  }

  Future<void> setLanguage(String lang) async {
    state = lang;
    await _prefs.setLanguage(lang);
  }
}

final languageProvider = StateNotifierProvider<LanguageNotifier, String>((ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  return LanguageNotifier(prefs);
});

// Auto-dispose Generic Generation Providers
final replyGenerationProvider = StateNotifierProvider.autoDispose<
    GenerationNotifier<ReplyRequest, ReplyResponse>,
    GenerationState<ReplyResponse>>((ref) {
  return GenerationNotifier<ReplyRequest, ReplyResponse>(ref);
});

final captionGenerationProvider = StateNotifierProvider.autoDispose<
    GenerationNotifier<CaptionRequest, CaptionResponse>,
    GenerationState<CaptionResponse>>((ref) {
  return GenerationNotifier<CaptionRequest, CaptionResponse>(ref);
});

final bioGenerationProvider = StateNotifierProvider.autoDispose<
    GenerationNotifier<BioRequest, BioResponse>,
    GenerationState<BioResponse>>((ref) {
  return GenerationNotifier<BioRequest, BioResponse>(ref);
});

final vibeCheckGenerationProvider = StateNotifierProvider.autoDispose<
    GenerationNotifier<VibeCheckRequest, VibeCheckResponse>,
    GenerationState<VibeCheckResponse>>((ref) {
  return GenerationNotifier<VibeCheckRequest, VibeCheckResponse>(ref);
});

