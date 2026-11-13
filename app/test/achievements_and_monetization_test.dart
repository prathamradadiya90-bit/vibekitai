import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibekit_ai/core/config/app_config.dart';
import 'package:vibekit_ai/core/network/api_endpoints.dart';
import 'package:vibekit_ai/core/storage/preferences_service.dart';
import 'package:vibekit_ai/models/achievement_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Achievements & Monetization Architecture Tests', () {
    test('AchievementModel serializes to and from Map correctly', () {
      final now = DateTime.now();
      final model = AchievementModel(
        id: 'first_spark',
        title: 'First Spark',
        description: 'First generation',
        icon: '⚡',
        xpReward: 50,
        bonusCredits: 1,
        category: 'Creation',
        isUnlocked: true,
        unlockedAt: now,
        progress: 1.0,
        progressText: 'Completed',
      );

      final map = model.toMap();
      expect(map['id'], equals('first_spark'));
      expect(map['xp_reward'], equals(50));
      expect(map['bonus_credits'], equals(1));
      expect(map['is_unlocked'], equals(1));

      final restored = AchievementModel.fromMap(map);
      expect(restored.id, equals('first_spark'));
      expect(restored.isUnlocked, isTrue);
      expect(restored.xpReward, equals(50));
      expect(restored.bonusCredits, equals(1));
      expect(restored.progressText, equals('Completed'));
    });

    test('AppConfig exposes Lifetime VIP and Consumable product IDs', () {
      expect(AppConfig.proLifetimeId, equals('vibekit_pro_lifetime'));
      expect(AppConfig.creditPack50Id, equals('vibekit_credits_50'));
      expect(AppConfig.proYearlyId, equals('vibekit_pro_yearly'));
      expect(AppConfig.proMonthlyId, equals('vibekit_pro_monthly'));
    });

    test('ApiEndpoints includes credit pack verification endpoint', () {
      expect(ApiEndpoints.verifyCreditPack, equals('/v1/purchases/credit-pack'));
      expect(ApiEndpoints.verifyPurchase, equals('/v1/purchases/verify'));
      expect(ApiEndpoints.deleteData, equals('/v1/privacy/delete-data'));
    });

    test('PreferencesService tracks achievements, tones, and card exports', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await PreferencesService.create();

      // Test achievement storage
      expect(prefs.getUnlockedAchievements(), isEmpty);
      await prefs.saveUnlockedAchievement('first_spark');
      expect(prefs.getUnlockedAchievements(), contains('first_spark'));

      // Test duplicate prevention
      await prefs.saveUnlockedAchievement('first_spark');
      expect(prefs.getUnlockedAchievements().length, equals(1));

      // Test tone and language tracking
      expect(prefs.getTonesUsed(), isEmpty);
      await prefs.recordToneUsed('Funny');
      await prefs.recordToneUsed('Flirty');
      expect(prefs.getTonesUsed(), hasLength(2));
      expect(prefs.getTonesUsed(), containsAll(['Funny', 'Flirty']));

      expect(prefs.getLanguagesUsed(), isEmpty);
      await prefs.recordLanguageUsed('Hindi');
      expect(prefs.getLanguagesUsed(), contains('Hindi'));

      // Test cards and challenges counter
      expect(prefs.getCardsExportedCount(), equals(0));
      final newCardCount = await prefs.incrementCardsExported();
      expect(newCardCount, equals(1));
      expect(prefs.getCardsExportedCount(), equals(1));

      expect(prefs.getChallengesSolvedCount(), equals(0));
      final newChallengeCount = await prefs.incrementChallengesSolved();
      expect(newChallengeCount, equals(1));
      expect(prefs.getChallengesSolvedCount(), equals(1));
    });
  });
}

