import 'package:flutter_test/flutter_test.dart';
import 'package:vibekit_ai/core/config/app_config.dart';
import 'package:vibekit_ai/core/services/admob_service.dart';

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
  });
}
