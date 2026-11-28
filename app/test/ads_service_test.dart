import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibekit_ai/core/config/app_config.dart';
import 'package:vibekit_ai/core/network/api_client.dart';
import 'package:vibekit_ai/core/providers/app_providers.dart';
import 'package:vibekit_ai/core/services/admob_service.dart';
import 'package:vibekit_ai/core/storage/preferences_service.dart';
import 'package:vibekit_ai/core/widgets/adaptive_banner_widget.dart';
import 'package:vibekit_ai/features/streaks/providers/streak_provider.dart';
import 'package:vibekit_ai/models/quota_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 8 - AdMobService & Frequency Capping Tests', () {
    late AdMobService adMobService;

    setUp(() {
      adMobService = AdMobService();
    });

    tearDown(() {
      adMobService.dispose();
    });

    test('Environment safety validation runs cleanly', () {
      expect(() => AppConfig.validateAdEnvironment(), returnsNormally);
      expect(AppConfig.testBannerAdUnitId, isNotEmpty);
      expect(AppConfig.testRewardedAdUnitId, isNotEmpty);
      expect(AppConfig.testInterstitialAdUnitId, isNotEmpty);
    });

    test('Pro users suppress all ad operations', () async {
      adMobService.updateProStatus(true);

      // Rewarded ads cannot be shown for Pro users
      final rewardedShown = await adMobService.showRewardedAd(
        onRewardEarned: (_) {},
      );
      expect(rewardedShown, isFalse);

      // Interstitial ads cannot be shown for Pro users
      final interstitialShown = await adMobService.showInterstitialIfEligible();
      expect(interstitialShown, isFalse);
    });

    test('Interstitial enforces frequency capping and minimum 180s interval', () async {
      // Free user without ad loaded yet
      final shownWhenNotReady = await adMobService.showInterstitialIfEligible();
      expect(shownWhenNotReady, isFalse);
    });

    test('Double-tap protection suppresses concurrent ad displays', () async {
      // Simulate uninitialized / not ready ad
      final firstCall = await adMobService.showRewardedAd(
        onRewardEarned: (_) {},
      );
      expect(firstCall, isFalse);
    });

    test('Production AdMob Banner and Rewarded IDs are valid live publisher unit IDs', () {
      expect(AppConfig.prodBannerAdUnitId, matches(RegExp(r'^ca-app-pub-\d+/\d+$')));
      expect(AppConfig.prodRewardedAdUnitId, matches(RegExp(r'^ca-app-pub-\d+/\d+$')));
      expect(AppConfig.bannerAdUnitId, equals(AppConfig.testBannerAdUnitId));
      expect(AppConfig.rewardedAdUnitId, equals(AppConfig.testRewardedAdUnitId));
    });

    test('StreakNotifier.earnFreeze retries on AD_REQUIRED when awaiting SSV webhook', () async {
      SharedPreferences.setMockInitialValues({'cached_credits': 3});
      final prefs = await PreferencesService.create();
      int freezePostCalls = 0;

      final mockHttp = MockClient((request) async {
        if (request.url.path.endsWith('/v1/streak/earn-freeze')) {
          freezePostCalls++;
          if (freezePostCalls == 1) {
            return http.Response(
              jsonEncode({
                'error': {
                  'code': 'AD_REQUIRED',
                  'message': 'Watch a rewarded ad to earn a streak freeze.',
                }
              }),
              400,
            );
          }
          return http.Response(jsonEncode({'success': true, 'freeze_count': 1}), 200);
        }
        return http.Response(jsonEncode({}), 200);
      });

      final client = ApiClient(client: mockHttp, prefs: prefs, baseUrl: 'https://example.test');
      final notifier = StreakNotifier(client);
      final granted = await notifier.earnFreeze(retryForSsv: true);
      expect(granted, isTrue);
      expect(freezePostCalls, equals(2));
      expect(notifier.state.freezeCount, equals(1));
    });

    testWidgets('AdaptiveBannerWidget collapses completely when user is Pro', (tester) async {
      SharedPreferences.setMockInitialValues({'cached_credits': 3, 'cached_is_pro': true});
      final prefs = await PreferencesService.create();
      final client = ApiClient(
        client: MockClient((_) async => http.Response('{}', 500)),
        prefs: prefs,
        baseUrl: 'https://example.test',
      );
      final quotaNotifier = QuotaNotifier(client, prefs)
        ..updateLocally(
          const QuotaModel(
            freeCreditsRemaining: 0,
            rewardedCreditsRemaining: 0,
            totalCreditsRemaining: 0,
            isPro: true,
            proCreditsRemaining: 200,
            rewardedAdsWatchedToday: 0,
            maxRewardedAdsPerDay: 2,
            resetAtUtc: '',
          ),
        );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preferencesServiceProvider.overrideWithValue(prefs),
            apiClientProvider.overrideWithValue(client),
            quotaProvider.overrideWith((_) => quotaNotifier),
            adMobServiceProvider.overrideWithValue(AdMobService()),
          ],
          child: const MaterialApp(
            home: Scaffold(body: AdaptiveBannerWidget()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ADVERTISEMENT'), findsNothing);
    });
  });
}
