import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibekit_ai/core/network/api_client.dart';
import 'package:vibekit_ai/core/providers/app_providers.dart';
import 'package:vibekit_ai/core/storage/preferences_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Daily Free Credit Auto-Reset & Quota Verification', () {
    test('Credits properly decrement and automatically reset when calendar day changes', () async {
      SharedPreferences.setMockInitialValues({
        'cached_credits': 3,
        'cached_is_pro': false,
        'last_credit_reset_date': '2026-11-20',
        'rewarded_ads_watched_today': 1,
      });

      final prefs = await PreferencesService.create();
      final client = ApiClient(prefs: prefs);
      final notifier = QuotaNotifier(client, prefs);

      // Verify initial day 1 credits
      expect(notifier.state.totalCreditsRemaining, equals(3));
      expect(notifier.state.freeCreditsRemaining, equals(3));
      expect(notifier.state.canGenerate, isTrue);

      // Consume 1 credit: 3 -> 2
      notifier.consumeOneCredit();
      expect(notifier.state.totalCreditsRemaining, equals(2));
      expect(notifier.state.freeCreditsRemaining, equals(2));

      // Consume 2nd credit: 2 -> 1
      notifier.consumeOneCredit();
      expect(notifier.state.totalCreditsRemaining, equals(1));
      expect(notifier.state.freeCreditsRemaining, equals(1));

      // Consume 3rd credit: 1 -> 0 (exhausted for today)
      notifier.consumeOneCredit();
      expect(notifier.state.totalCreditsRemaining, equals(0));
      expect(notifier.state.freeCreditsRemaining, equals(0));
      expect(notifier.state.canGenerate, isFalse);

      // Verify cached value stored in preferences is 0
      expect(await prefs.getCachedCredits(), equals(0));

      // Simulate overnight date change: last reset was 2026-11-20, user opens app on 2026-11-21
      await prefs.setLastCreditResetDate('2026-11-20');
      // When getCachedCredits or checkAndPerformDailyLocalReset is called on a new day:
      // (today in real time is >= 2026-11-20, so setting last reset to a past date '2026-01-01' guarantees reset)
      await prefs.setLastCreditResetDate('2026-01-01');

      final didReset = prefs.checkAndPerformDailyLocalReset(defaultDailyCredits: 3);
      expect(didReset, isTrue);

      // Free credits must be 3 again!
      expect(prefs.getCachedCredits(), equals(3));

      // Refresh notifier state on new day
      await notifier.refresh();
      expect(notifier.state.totalCreditsRemaining, equals(3));
      expect(notifier.state.freeCreditsRemaining, equals(3));
      expect(notifier.state.canGenerate, isTrue);
    });

    test('syncCredits properly decrements credit count on generation', () async {
      SharedPreferences.setMockInitialValues({
        'cached_credits': 3,
        'cached_is_pro': false,
      });

      final prefs = await PreferencesService.create();
      final client = ApiClient(prefs: prefs);
      final notifier = QuotaNotifier(client, prefs);

      expect(notifier.state.totalCreditsRemaining, equals(3));

      // Server returns remaining: 2
      notifier.syncCredits(2);
      expect(notifier.state.totalCreditsRemaining, equals(2));

      // Server returns remaining: 1
      notifier.syncCredits(1);
      expect(notifier.state.totalCreditsRemaining, equals(1));

      // Server returns remaining: 0
      notifier.syncCredits(0);
      expect(notifier.state.totalCreditsRemaining, equals(0));
      expect(notifier.state.canGenerate, isFalse);
    });
  });
}
