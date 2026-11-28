import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import '../storage/preferences_service.dart';
import '../storage/local_database.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';
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
  final client = ApiClient(prefs: prefs, baseUrl: prefs.getCustomApiUrl());
  ref.onDispose(client.close);
  return client;
});

final adMobServiceProvider = Provider<AdMobService>((ref) {
  return AdMobService();
});

final billingServiceProvider = ChangeNotifierProvider<BillingService>((ref) {
  final service = BillingService(ref.read(apiClientProvider));
  ref.listen<ApiClient>(apiClientProvider, (_, next) {
    service.updateApiClient(next);
  });
  return service;
});

final reviewServiceProvider = Provider<ReviewService>((ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  return ReviewService(prefs);
});

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService.instance;
});

/// Incremented whenever LocalDatabase history items are added, modified, or cleared.
final historyRevisionProvider = StateProvider<int>((ref) => 0);

// Quota State Notifier
class QuotaNotifier extends StateNotifier<QuotaModel> {
  final ApiClient _apiClient;
  final PreferencesService _prefs;

  QuotaNotifier(this._apiClient, this._prefs) : super(QuotaModel.initial()) {
    // Check and perform daily local reset immediately on initialization
    final didReset = _prefs.checkAndPerformDailyLocalReset();
    final cachedCredits = _prefs.getCachedCredits();
    final cachedRewarded = _prefs.getCachedRewardedCredits().clamp(0, cachedCredits);
    final cachedFree = didReset
        ? AppConfig.defaultDailyCredits
        : (cachedCredits - cachedRewarded).clamp(0, 999);

    state = state.copyWith(
      totalCreditsRemaining: cachedCredits,
      freeCreditsRemaining: cachedFree,
      rewardedCreditsRemaining: cachedRewarded,
      isPro: _prefs.getCachedIsPro(),
      proCreditsRemaining: _prefs.getCachedProCredits(),
      rewardedAdsWatchedToday: didReset ? 0 : _prefs.getCachedRewardedAdsWatchedToday(),
    );
    refresh();
  }

  Future<void> refresh() async {
    try {
      if (_prefs.checkAndPerformDailyLocalReset()) {
        final rewarded = _prefs.getCachedRewardedCredits();
        if (!mounted) return;
        state = state.copyWith(
          totalCreditsRemaining: AppConfig.defaultDailyCredits + rewarded,
          freeCreditsRemaining: AppConfig.defaultDailyCredits,
          rewardedCreditsRemaining: rewarded,
          rewardedAdsWatchedToday: 0,
        );
      }
      final quota = await _apiClient.getUsage();
      if (!mounted) return;
      state = quota;
      await _prefs.setCachedCredits(quota.totalCreditsRemaining);
      await _prefs.setCachedRewardedCredits(quota.rewardedCreditsRemaining);
      await _prefs.setCachedIsPro(quota.isPro);
      await _prefs.setCachedProCredits(quota.proCreditsRemaining);
      await _prefs.setCachedRewardedAdsWatchedToday(quota.rewardedAdsWatchedToday);
    } catch (_) {
      // Retain cached state on network failure
    }
  }

  void syncCredits(int remaining) {
    if (!mounted) return;
    final clamped = remaining.clamp(0, 9999);
    if (state.isPro) {
      if (state.proCreditsRemaining > 0) {
        state = state.copyWith(proCreditsRemaining: clamped);
        _prefs.setCachedProCredits(clamped);
      } else if (state.rewardedCreditsRemaining > 0) {
        final newRewarded = clamped.clamp(0, state.rewardedCreditsRemaining);
        state = state.copyWith(
          rewardedCreditsRemaining: newRewarded,
          totalCreditsRemaining: clamped,
        );
        _prefs.setCachedCredits(clamped);
        _prefs.setCachedRewardedCredits(newRewarded);
      }
    } else {
      final delta = state.totalCreditsRemaining - clamped;
      final newFree = delta > 0
          ? (state.freeCreditsRemaining - delta).clamp(0, state.freeCreditsRemaining)
          : state.freeCreditsRemaining.clamp(0, clamped);
      final newRewarded = (clamped - newFree).clamp(0, 9999);
      state = state.copyWith(
        totalCreditsRemaining: clamped,
        freeCreditsRemaining: newFree,
        rewardedCreditsRemaining: newRewarded,
      );
      _prefs.setCachedCredits(clamped);
      _prefs.setCachedRewardedCredits(newRewarded);
    }
  }

  void consumeOneCredit() {
    if (!mounted) return;
    if (state.isPro) {
      if (state.proCreditsRemaining > 0) {
        final remaining = (state.proCreditsRemaining - 1).clamp(0, 9999);
        state = state.copyWith(proCreditsRemaining: remaining);
        _prefs.setCachedProCredits(remaining);
      } else if (state.rewardedCreditsRemaining > 0) {
        final newRewarded = (state.rewardedCreditsRemaining - 1).clamp(0, 9999);
        final newTotal = (state.totalCreditsRemaining - 1).clamp(0, 9999);
        state = state.copyWith(
          rewardedCreditsRemaining: newRewarded,
          totalCreditsRemaining: newTotal,
        );
        _prefs.setCachedCredits(newTotal);
        _prefs.setCachedRewardedCredits(newRewarded);
      }
      return;
    }
    final remaining = (state.totalCreditsRemaining - 1).clamp(0, 9999);
    final free = (state.freeCreditsRemaining - 1).clamp(0, 9999);
    final rewarded = state.freeCreditsRemaining > 0
        ? state.rewardedCreditsRemaining
        : (state.rewardedCreditsRemaining - 1).clamp(0, 9999);
    state = state.copyWith(
      totalCreditsRemaining: remaining,
      freeCreditsRemaining: free,
      rewardedCreditsRemaining: rewarded,
    );
    _prefs.setCachedCredits(remaining);
    _prefs.setCachedRewardedCredits(rewarded);
  }

  void reset() {
    if (!mounted) return;
    state = QuotaModel.initial();
  }

  void updateLocally(QuotaModel updated) {
    if (!mounted) return;
    state = updated;
    _prefs.setCachedCredits(updated.totalCreditsRemaining);
    _prefs.setCachedRewardedCredits(updated.rewardedCreditsRemaining);
    _prefs.setCachedIsPro(updated.isPro);
    _prefs.setCachedProCredits(updated.proCreditsRemaining);
  }

  Future<bool> grantRewardCredit({String? nonce, String? transactionId, String? rewardId}) async {
    if (!state.canWatchRewardedAd) return false;
    final effectiveRewardId = rewardId ?? 'rew_${DateTime.now().millisecondsSinceEpoch}';

    // Poll up to 4 times with progressive backoff to allow Google AdMob SSV webhook to arrive
    for (int attempt = 0; attempt < 4; attempt++) {
      if (attempt > 0) {
        await Future.delayed(Duration(milliseconds: 1000 * attempt));
      }
      if (!mounted) return false;
      try {
        final res = await _apiClient.verifyRewardedAd(
          rewardId: effectiveRewardId,
          transactionId: transactionId,
          nonce: nonce,
          adNetwork: 'admob',
        );
        if (!mounted) return false;
        if (res['verified'] == true) {
          final creditsAdded = (res['credits_added'] as num?)?.toInt() ?? 3;
          final remaining = (res['credits_remaining'] as num?)?.toInt() ??
              (state.totalCreditsRemaining + creditsAdded);
          final watched = (res['rewarded_ads_watched_today'] as num?)?.toInt() ??
              (state.rewardedAdsWatchedToday + 1);
          final computedRewarded = (remaining - state.freeCreditsRemaining).clamp(0, 9999);
          final updated = state.copyWith(
            totalCreditsRemaining: remaining,
            rewardedCreditsRemaining: computedRewarded,
            rewardedAdsWatchedToday: watched,
          );
          state = updated;
          await _prefs.setCachedCredits(remaining);
          await _prefs.setCachedRewardedCredits(updated.rewardedCreditsRemaining);
          await _prefs.setCachedRewardedAdsWatchedToday(watched);
          return true;
        }
      } on ApiException catch (e) {
        // Authoritative client/quota rejection (e.g. daily ad limit reached) must fail immediately
        if (e.statusCode == 400 || e.statusCode == 403 || e.statusCode == 429) {
          return false;
        }
      } catch (_) {
        // Network error; retry polling
      }
    }

    // Debug-only offline fallback for local development when backend is unreachable
    if (AppConfig.isDev && mounted && state.canWatchRewardedAd) {
      final updated = state.copyWith(
        totalCreditsRemaining: state.totalCreditsRemaining + 3,
        rewardedCreditsRemaining: state.rewardedCreditsRemaining + 3,
        rewardedAdsWatchedToday: state.rewardedAdsWatchedToday + 1,
      );
      state = updated;
      await _prefs.setCachedCredits(updated.totalCreditsRemaining);
      await _prefs.setCachedRewardedCredits(updated.rewardedCreditsRemaining);
      await _prefs.setCachedRewardedAdsWatchedToday(updated.rewardedAdsWatchedToday);
      return true;
    }
    return false;
  }

  void setPro(bool isPro) {
    if (!mounted) return;
    state = state.copyWith(isPro: isPro);
    _prefs.setCachedIsPro(isPro);
    if (isPro) {
      refresh();
    }
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

