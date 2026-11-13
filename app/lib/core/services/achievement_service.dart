import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/achievement_model.dart';
import '../constants/app_colors.dart';
import '../storage/preferences_service.dart';
import '../providers/app_providers.dart';
import '../../features/streaks/providers/streak_provider.dart';

class AchievementService {
  final PreferencesService _prefs;
  final Ref _ref;

  AchievementService(this._prefs, this._ref);

  List<AchievementModel> getAllAchievements() {
    final unlocked = _prefs.getUnlockedAchievements();
    final genCount = _prefs.getSuccessfulGenerationsCount();
    final tonesUsed = _prefs.getTonesUsed();
    final langsUsed = _prefs.getLanguagesUsed();
    final cardsCount = _prefs.getCardsExportedCount();
    final challengesCount = _prefs.getChallengesSolvedCount();
    final isPro = _prefs.getCachedIsPro();

    final streakState = _ref.read(streakProvider);
    final streak = streakState.currentStreak;

    return [
      AchievementModel(
        id: 'first_spark',
        title: 'First Spark',
        description: 'Generate your first social reply, caption or bio with AI.',
        icon: '⚡',
        xpReward: 50,
        bonusCredits: 1,
        category: 'Creation',
        isUnlocked: unlocked.contains('first_spark') || genCount >= 1,
        progress: (genCount / 1).clamp(0.0, 1.0),
        progressText: genCount >= 1 ? 'Completed' : '0/1 Generations',
      ),
      AchievementModel(
        id: 'tone_master',
        title: 'Tone Master',
        description: 'Experiment across 3 different conversation tones.',
        icon: '🎭',
        xpReward: 75,
        bonusCredits: 1,
        category: 'Exploration',
        isUnlocked: unlocked.contains('tone_master') || tonesUsed.length >= 3,
        progress: (tonesUsed.length / 3).clamp(0.0, 1.0),
        progressText: '${tonesUsed.length.clamp(0, 3)}/3 Tones',
      ),
      AchievementModel(
        id: 'polyglot',
        title: 'Multilingual Voice',
        description: 'Create content in 2 or more languages (Hindi, Hinglish, Gujarati).',
        icon: '🌐',
        xpReward: 100,
        bonusCredits: 1,
        category: 'Exploration',
        isUnlocked: unlocked.contains('polyglot') || langsUsed.length >= 2,
        progress: (langsUsed.length / 2).clamp(0.0, 1.0),
        progressText: '${langsUsed.length.clamp(0, 2)}/2 Languages',
      ),
      AchievementModel(
        id: 'card_artisan',
        title: 'Card Artisan',
        description: 'Design, render and export your first shareable quote card.',
        icon: '🎨',
        xpReward: 80,
        bonusCredits: 1,
        category: 'Creation',
        isUnlocked: unlocked.contains('card_artisan') || cardsCount >= 1,
        progress: (cardsCount / 1).clamp(0.0, 1.0),
        progressText: cardsCount >= 1 ? 'Completed' : '0/1 Cards',
      ),
      AchievementModel(
        id: 'challenge_solver',
        title: 'Challenge Champion',
        description: 'Complete a Daily Creative Challenge prompt.',
        icon: '🎯',
        xpReward: 120,
        bonusCredits: 2,
        category: 'Daily',
        isUnlocked: unlocked.contains('challenge_solver') || challengesCount >= 1,
        progress: (challengesCount / 1).clamp(0.0, 1.0),
        progressText: challengesCount >= 1 ? 'Completed' : '0/1 Challenges',
      ),
      AchievementModel(
        id: 'streak_warrior',
        title: '3-Day Spark',
        description: 'Maintain a 3-day continuous daily creative streak.',
        icon: '🥉',
        xpReward: 100,
        bonusCredits: 1,
        category: 'Streaks',
        isUnlocked: unlocked.contains('streak_warrior') || streak >= 3,
        progress: (streak / 3).clamp(0.0, 1.0),
        progressText: '${streak.clamp(0, 3)}/3 Days',
      ),
      AchievementModel(
        id: 'streak_champion',
        title: '7-Day Blaze',
        description: 'Maintain a 7-day continuous daily creative streak.',
        icon: '🥈',
        xpReward: 250,
        bonusCredits: 2,
        category: 'Streaks',
        isUnlocked: unlocked.contains('streak_champion') || streak >= 7,
        progress: (streak / 7).clamp(0.0, 1.0),
        progressText: '${streak.clamp(0, 7)}/7 Days',
      ),
      AchievementModel(
        id: 'vip_creator',
        title: 'VIP Creator',
        description: 'Upgrade to VibeKit Pro or Lifetime VIP status.',
        icon: '👑',
        xpReward: 500,
        bonusCredits: 0,
        category: 'Status',
        isUnlocked: unlocked.contains('vip_creator') || isPro,
        progress: isPro ? 1.0 : 0.0,
        progressText: isPro ? 'Active VIP' : 'Unlock Pro',
      ),
    ];
  }

  /// Checks if any achievements qualify for unlocking and triggers rewards
  Future<List<AchievementModel>> checkAndUnlockAchievements({BuildContext? context}) async {
    final unlockedIds = _prefs.getUnlockedAchievements();
    final all = getAllAchievements();
    final newlyUnlocked = <AchievementModel>[];

    for (final a in all) {
      if (a.progress >= 1.0 && !unlockedIds.contains(a.id)) {
        await _prefs.saveUnlockedAchievement(a.id);
        newlyUnlocked.add(a);

        // Grant XP to streak notifier
        try {
          final streakNotifier = _ref.read(streakProvider.notifier);
          final currentStreak = _ref.read(streakProvider);
          streakNotifier.updateStreakLocally(
            currentStreak.copyWith(
              totalXp: currentStreak.totalXp + a.xpReward,
              level: (currentStreak.totalXp + a.xpReward) ~/ 100 + 1,
            ),
          );
        } catch (_) {}

        // Grant bonus credits if applicable
        if (a.bonusCredits > 0) {
          try {
            final quotaNotifier = _ref.read(quotaProvider.notifier);
            final currentQuota = _ref.read(quotaProvider);
            quotaNotifier.updateLocally(
              currentQuota.copyWith(
                totalCreditsRemaining: currentQuota.totalCreditsRemaining + a.bonusCredits,
                freeCreditsRemaining: currentQuota.freeCreditsRemaining + a.bonusCredits,
              ),
            );
          } catch (_) {}
        }
      }
    }

    if (context != null && newlyUnlocked.isNotEmpty && context.mounted) {
      HapticFeedback.heavyImpact();
      for (final ach in newlyUnlocked) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Text(ach.icon, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Achievement Unlocked: ${ach.title}!',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        '+${ach.xpReward} XP${ach.bonusCredits > 0 ? " • +${ach.bonusCredits} AI Credit" : ""}',
                        style: const TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }

    return newlyUnlocked;
  }
}

final achievementServiceProvider = Provider<AchievementService>((ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  return AchievementService(prefs, ref);
});

