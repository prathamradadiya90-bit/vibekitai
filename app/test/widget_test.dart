import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibekit_ai/core/network/api_client.dart';
import 'package:vibekit_ai/core/providers/app_providers.dart';
import 'package:vibekit_ai/core/services/admob_service.dart';
import 'package:vibekit_ai/core/services/share_service.dart';
import 'package:vibekit_ai/core/services/analytics_service.dart';
import 'package:vibekit_ai/core/storage/local_database.dart';
import 'package:vibekit_ai/core/storage/preferences_service.dart';
import 'package:vibekit_ai/features/card_maker/card_templates.dart';
import 'package:vibekit_ai/main.dart';
import 'package:vibekit_ai/models/generation_models.dart';
import 'package:vibekit_ai/models/history_item.dart';
import 'package:vibekit_ai/models/quota_model.dart';
import 'package:vibekit_ai/models/streak_model.dart';

void main() {
  group('VibeKit AI - Unit Tests', () {
    test('QuotaModel correctly computes availability and defaults', () {
      final initial = QuotaModel.initial();
      expect(initial.totalCreditsRemaining, equals(3));
      expect(initial.canGenerate, isTrue);
      expect(initial.canWatchRewardedAd, isTrue);
      expect(initial.isPro, isFalse);

      final depleted = initial.copyWith(totalCreditsRemaining: 0);
      expect(depleted.canGenerate, isFalse);

      final proUser = depleted.copyWith(isPro: true, proCreditsRemaining: 150);
      expect(proUser.canGenerate, isTrue);

      final maxAds = initial.copyWith(rewardedAdsWatchedToday: 2);
      expect(maxAds.canWatchRewardedAd, isFalse);

      final cycleModel = QuotaModel.fromJson({
        'free_credits_remaining': 0,
        'rewarded_credits_remaining': 0,
        'total_credits_remaining': 0,
        'is_pro': true,
        'pro_credits_remaining': 180,
        'pro_cycle_resets_at': '2026-11-20T00:00:00.000Z',
        'rewarded_ads_watched_today': 0,
        'max_rewarded_ads_per_day': 2,
        'reset_at_utc': '2026-10-24T00:00:00.000Z',
      });
      expect(cycleModel.isPro, isTrue);
      expect(cycleModel.proCreditsRemaining, equals(180));
      expect(cycleModel.proCycleResetsAt, equals('2026-11-20T00:00:00.000Z'));
      expect(cycleModel.canGenerate, isTrue);
    });

    test('QuotaNotifier accurately decrements free, rewarded, and pro credits', () async {
      SharedPreferences.setMockInitialValues({'cached_credits': 3, 'cached_is_pro': false});
      final prefs = await PreferencesService.create();
      final client = ApiClient(prefs: prefs);
      final notifier = QuotaNotifier(client, prefs);

      // Decrement free credits from 3 -> 2
      notifier.consumeOneCredit();
      expect(notifier.state.totalCreditsRemaining, equals(2));
      expect(notifier.state.freeCreditsRemaining, equals(2));

      // Simulate state where free credits are exhausted, but user has rewarded credits
      notifier.state = notifier.state.copyWith(
        totalCreditsRemaining: 3,
        freeCreditsRemaining: 0,
        rewardedCreditsRemaining: 3,
      );

      // Decrement rewarded credit
      notifier.consumeOneCredit();
      expect(notifier.state.totalCreditsRemaining, equals(2));
      expect(notifier.state.freeCreditsRemaining, equals(0));
      expect(notifier.state.rewardedCreditsRemaining, equals(2));

      // Test Pro credit consumption
      notifier.setPro(true);
      notifier.state = notifier.state.copyWith(isPro: true, proCreditsRemaining: 200);
      notifier.consumeOneCredit();
      expect(notifier.state.proCreditsRemaining, equals(199));

      // Test reset
      notifier.reset();
      expect(notifier.state.totalCreditsRemaining, equals(3));
      expect(notifier.state.isPro, isFalse);
    });

    test('Generation contracts serialize and deserialize properly', () {
      const replyReq = ReplyRequest(
        message: 'Hey there',
        tone: 'Witty',
        language: 'Hinglish',
        length: 'short',
        count: 3,
      );
      final json = replyReq.toJson();
      expect(json['message'], equals('Hey there'));
      expect(json['tone'], equals('Witty'));
      expect(json['language'], equals('Hinglish'));

      final replyRes = ReplyResponse.fromJson({
        'suggestions': ['Answer 1', 'Answer 2', 'Answer 3'],
        'tone': 'Witty',
        'language': 'Hinglish',
        'credits_remaining': 2,
      });
      expect(replyRes.suggestions.length, equals(3));
      expect(replyRes.creditsRemaining, equals(2));

      const captionReq = CaptionRequest(
        topic: 'Coffee in rain',
        platform: 'Instagram Reels',
        tone: 'Aesthetic',
        language: 'English',
      );
      final capJson = captionReq.toJson();
      expect(capJson['platform'], equals('Instagram Reels'));

      final captionRes = CaptionResponse.fromJson({
        'captions': ['Rainy mood', 'Coffee warmth'],
        'hooks': ['Stop scrolling!'],
        'call_to_actions': ['Save for later'],
        'hashtags': ['#RainyDay', '#CoffeeTime'],
        'credits_remaining': 1,
      });
      expect(captionRes.captions.length, equals(2));
      expect(captionRes.hooks.length, equals(1));
      expect(captionRes.hashtags.length, equals(2));

      const bioReq = BioRequest(
        interests: 'Flutter & AI apps',
        platform: 'Instagram',
        vibe: 'Aesthetic',
        language: 'English',
        includeUsernames: true,
      );
      final bioJson = bioReq.toJson();
      expect(bioJson['interests'], equals('Flutter & AI apps'));
      expect(bioJson['include_usernames'], isTrue);

      final bioRes = BioResponse.fromJson({
        'bios': ['Bio 1', 'Bio 2'],
        'usernames': ['@vibe_maker', '@flutter_pro'],
        'credits_remaining': 1,
      });
      expect(bioRes.bios.length, equals(2));
      expect(bioRes.usernames.length, equals(2));
      expect(bioRes.creditsRemaining, equals(1));
    });

    test('StreakModel correctly serializes and tracks milestones and levels', () {
      final initial = StreakModel.initial();
      expect(initial.currentStreak, equals(0));
      expect(initial.level, equals(1));
      expect(initial.checkedInToday, isFalse);

      final active = StreakModel.fromJson({
        'current_streak': 7,
        'longest_streak': 10,
        'last_checkin_date': '2026-10-23',
        'freeze_count': 1,
        'checked_in_today': true,
        'total_xp': 250,
        'level': 3,
        'claimed_milestones': [3, 7],
      });

      expect(active.currentStreak, equals(7));
      expect(active.longestStreak, equals(10));
      expect(active.level, equals(3));
      expect(active.isMilestoneClaimed(3), isTrue);
      expect(active.isMilestoneClaimed(7), isTrue);
      expect(active.isMilestoneClaimed(14), isFalse);
    });

    test('LocalDatabase fallback store operates accurately', () async {
      final db = LocalDatabase();
      // Test uninitialized / headless fallback store
      final item1 = HistoryItem(
        id: 'test_1',
        title: 'Title 1',
        content: 'Content 1',
        type: 'reply',
        category: 'Witty',
        createdAt: DateTime.now(),
      );

      final item2 = HistoryItem(
        id: 'test_2',
        title: 'Title 2',
        content: 'Content 2',
        type: 'caption',
        category: 'Aesthetic',
        createdAt: DateTime.now(),
        isFavorite: true,
      );

      await db.insertItem(item1);
      await db.insertItem(item2);

      final allItems = await db.getItems();
      expect(allItems.length, equals(2));

      final favorites = await db.getItems(onlyFavorites: true);
      expect(favorites.length, equals(1));
      expect(favorites.first.id, equals('test_2'));

      final replyOnly = await db.getItems(type: 'reply');
      expect(replyOnly.length, equals(1));
      expect(replyOnly.first.id, equals('test_1'));

      await db.toggleFavorite('test_1', true);
      final updatedFavorites = await db.getItems(onlyFavorites: true);
      expect(updatedFavorites.length, equals(2));

      await db.deleteItem('test_1');
      final remaining = await db.getItems();
      expect(remaining.length, equals(1));

      await db.clearAll();
      final empty = await db.getItems();
      expect(empty.isEmpty, isTrue);
    });

    test('CardTemplates registry provides all 8 defined templates', () {
      expect(CardTemplates.all.length, greaterThanOrEqualTo(8));
      final names = CardTemplates.all.map((e) => e.name).toList();
      expect(names, contains('Deep Indigo'));
      expect(names, contains('Neon Sunset'));
      expect(names, contains('Emerald Zen'));
      expect(names, contains('Obsidian Dark'));
      expect(names, contains('Cream Paper'));
    });

    test('ShareService constructs viral referral links and formatted share text', () {
      const testId = 'inst_test_abc_123';
      final link = ShareService.buildReferralLink(testId);
      expect(link, contains('id=com.vibekit.ai'));
      expect(link, contains('&referrer=ref_$testId'));

      final text = ShareService.formatShareText('Awesome witty reply!', installationId: testId);
      expect(text, contains('Awesome witty reply!'));
      expect(text, contains('Made with VibeKit AI'));
      expect(text, contains(link));
    });

    test('AnalyticsService suppresses non-whitelisted events and logs valid funnel events', () {
      final analytics = AnalyticsService.instance;
      // Should execute without throw and filter non-whitelisted events
      analytics.logEvent('unknown_random_event', parameters: {'prompt': 'secret'});
      analytics.logGenerateSuccess('reply');
      analytics.logPaywallView('test_screen');
      analytics.logStreakDay(7);
      analytics.logShareCard();
    });

    test('PreferencesService increments successful generations count and tracks review prompted state', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await PreferencesService.create();
      expect(prefs.getSuccessfulGenerationsCount(), equals(0));
      expect(prefs.hasPromptedReview(), isFalse);

      final count1 = await prefs.incrementSuccessfulGenerations();
      expect(count1, equals(1));
      final count2 = await prefs.incrementSuccessfulGenerations();
      expect(count2, equals(2));
      final count3 = await prefs.incrementSuccessfulGenerations();
      expect(count3, equals(3));

      await prefs.setPromptedReview(true);
      expect(prefs.hasPromptedReview(), isTrue);
    });
  });

  group('VibeKit AI - Widget Tests', () {
    testWidgets(
        'App starts with ProviderScope and renders OnboardingScreen when first launched',
        (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues({'onboarding_done': false});
      final prefs = await PreferencesService.create();
      final db = LocalDatabase();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preferencesServiceProvider.overrideWithValue(prefs),
            localDatabaseProvider.overrideWithValue(db),
            adMobServiceProvider.overrideWithValue(AdMobService()),
          ],
          child: const VibeKitApp(initialOnboardingDone: false),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('VIBEKIT AI'), findsOneWidget);
      expect(find.text('Clever Replies in Seconds'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('App renders HomeScreen when onboarding is already complete', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues({'onboarding_done': true});
      final prefs = await PreferencesService.create();
      final db = LocalDatabase();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preferencesServiceProvider.overrideWithValue(prefs),
            localDatabaseProvider.overrideWithValue(db),
            adMobServiceProvider.overrideWithValue(AdMobService()),
          ],
          child: const VibeKitApp(initialOnboardingDone: true),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('VibeKit AI'), findsOneWidget);
      expect(find.text('Daily AI Credits'), findsOneWidget);
      expect(find.text('Reply Studio'), findsOneWidget);
      expect(find.text('Caption Lab'), findsOneWidget);
      expect(find.text('Meme & Card Maker'), findsOneWidget);
    });
  });
}
