import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_durations.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/review_prompt_service.dart';
import '../../../core/widgets/motion_widgets.dart';
import '../providers/streak_provider.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService();
  service.init();
  return service;
});

final notificationEnabledProvider = StateProvider<bool>((ref) {
  return ref.read(preferencesServiceProvider).getNotificationsEnabled();
});

final _freezeAdBusyProvider = StateProvider.autoDispose<bool>((ref) => false);

class StreakScreen extends ConsumerWidget {
  const StreakScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(streakProvider);
    final quota = ref.watch(quotaProvider);
    final notifsEnabled = ref.watch(notificationEnabledProvider);
    final isFreezeBusy = ref.watch(_freezeAdBusyProvider);

    final currentXpInLevel = streak.totalXp % 100;
    final progressToNextLevel = currentXpInLevel / 100.0;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final textCol = isDark ? Colors.white : AppColors.textPrimaryLight;
    final textSecCol = isDark ? Colors.white.withOpacity(0.6) : AppColors.textSecondaryLight;
    final borderCol = isDark ? Colors.white.withOpacity(0.08) : AppColors.borderLight;
    final activeAccent = isDark ? AppColors.accentWarm : AppColors.primary;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textCol, size: 20),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: Text(
          'Vibe Streaks & Rewards',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textCol),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Flame & Streak Status Card + 7-Day Rhythm Strip
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.4), width: 1.5),
                boxShadow: kIsWeb
                    ? null
                    : [
                        BoxShadow(
                          color: AppColors.warning.withValues(alpha: 0.16),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text('🔥', style: TextStyle(fontSize: 36)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${streak.currentStreak} Day Streak',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      fontFeatures: AppTypography.tabularFigures,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    streak.checkedInToday
                        ? 'You completed today\'s activity! Streak secured ✨'
                        : 'Generate, export a card, or solve today\'s challenge to keep it alive!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.8),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: streak.checkedInToday
                          ? AppColors.success.withValues(alpha: 0.25)
                          : AppColors.warning.withValues(alpha: 0.24),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      streak.checkedInToday ? 'Checked in today ✓' : 'Pending today ⏳',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: streak.checkedInToday
                            ? const Color(0xFF9AE6B4)
                            : AppColors.accentWarm,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildWeekStreakStrip(streak.currentStreak, streak.checkedInToday),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 2. Vibe Points (XP) & Level Progress
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderCol),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text('⚡', style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 8),
                          Text(
                            'Level ${streak.level} Creator',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textCol,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${streak.totalXp} XP Total',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFeatures: AppTypography.tabularFigures,
                          color: activeAccent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AnimatedProgressBar(
                    value: progressToNextLevel,
                    minHeight: 10,
                    backgroundColor: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.06),
                    color: activeAccent,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$currentXpInLevel / 100 XP to Level ${streak.level + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      fontFeatures: AppTypography.tabularFigures,
                      color: textSecCol,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 3. Streak Freeze Counter & Protection (Warm Sage Harmony)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.sageGreen.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.sageGreen.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text('❄️', style: TextStyle(fontSize: 24)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${streak.freezeCount} Freeze Available',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            fontFeatures: AppTypography.tabularFigures,
                            color: textCol,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          quota.isPro
                              ? 'Pro Perk: Refilled 1x weekly'
                              : 'Protects your streak if you miss a day',
                          style: TextStyle(
                            fontSize: 12,
                            color: textSecCol,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!quota.isPro && streak.freezeCount < 2 && (!kIsWeb || AppConfig.isDev))
                    TactileScale(
                      child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.info.withValues(alpha: isDark ? 0.28 : 0.14),
                        foregroundColor: activeAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: isFreezeBusy
                          ? null
                          : () async {
                              ref.read(_freezeAdBusyProvider.notifier).state = true;
                              try {
                                final adMob = ref.read(adMobServiceProvider);
                                final apiClient = ref.read(apiClientProvider);
                                final instId = ref.read(preferencesServiceProvider).getAppInstanceId();
                                final notifier = ref.read(streakProvider.notifier);

                                final nonce = await apiClient.requestAdNonce();
                                final rewardId = 'freeze_${DateTime.now().millisecondsSinceEpoch}';
                                final customData = jsonEncode({
                                  'userId': instId,
                                  if (nonce != null) 'nonce': nonce,
                                  'rewardId': rewardId,
                                  'timestamp': DateTime.now().millisecondsSinceEpoch,
                                });

                                bool failureNotified = false;
                                final showed = await adMob.showRewardedAd(
                                  userId: instId,
                                  customData: customData,
                                  onRewardEarned: (_) async {
                                    final success = await notifier.earnFreeze(retryForSsv: true);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            success
                                                ? '+1 Streak Freeze earned! ❄️'
                                                : (notifier.lastError ??
                                                    'Could not unlock a Streak Freeze right now.'),
                                          ),
                                          backgroundColor:
                                              success ? AppColors.success : AppColors.error,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  },
                                  onAdFailed: () {
                                    failureNotified = true;
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Rewarded ad is loading. Please try again in a moment.'),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  },
                                );
                                if (!showed && !failureNotified && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Rewarded ad unavailable right now. Please try again shortly.'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              } finally {
                                ref.read(_freezeAdBusyProvider.notifier).state = false;
                              }
                            },
                      child: isFreezeBusy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('+1 Freeze', style: TextStyle(fontSize: 12)),
                    ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 4. Milestone Rewards
            Text(
              'Milestone Rewards',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textCol,
              ),
            ),
            const SizedBox(height: 12),
            _buildMilestoneCard(
              context: context,
              ref: ref,
              day: 3,
              title: '3-Day Spark',
              rewardDesc: '+1 Bonus Generation Credit',
              icon: '🥉',
              currentStreak: streak.currentStreak,
              isClaimed: streak.isMilestoneClaimed(3),
            ),
            const SizedBox(height: 10),
            _buildMilestoneCard(
              context: context,
              ref: ref,
              day: 7,
              title: '7-Day Blaze',
              rewardDesc: 'Aura Card Template + 1 Credit',
              icon: '🥈',
              currentStreak: streak.currentStreak,
              isClaimed: streak.isMilestoneClaimed(7),
            ),
            const SizedBox(height: 10),
            _buildMilestoneCard(
              context: context,
              ref: ref,
              day: 14,
              title: '14-Day Inferno',
              rewardDesc: 'Cyberpunk Template Pack Unlocked',
              icon: '🥇',
              currentStreak: streak.currentStreak,
              isClaimed: streak.isMilestoneClaimed(14),
            ),
            const SizedBox(height: 10),
            _buildMilestoneCard(
              context: context,
              ref: ref,
              day: 30,
              title: '30-Day Legend',
              rewardDesc: 'Legendary Badge + 2 Bonus Credits',
              icon: '👑',
              currentStreak: streak.currentStreak,
              isClaimed: streak.isMilestoneClaimed(30),
            ),
            const SizedBox(height: 24),

            // 5. Weekly Recap Card Share Action
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.share, size: 20),
              label: const Text(
                'Generate Weekly Recap Card 📸',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              onPressed: () {
                final recapText =
                    'My week on VibeKit: ${streak.currentStreak}-Day Streak 🔥 | ${streak.totalXp} XP Earned ⚡ | Level ${streak.level} Creator';
                context.push('/card-maker', extra: recapText);
              },
            ),
            const SizedBox(height: 16),

            // 6. Notification Settings Toggle
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Daily Streak Reminders',
                style: TextStyle(color: textCol, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Receive an evening reminder if your streak is about to break',
                style: TextStyle(color: textSecCol, fontSize: 12),
              ),
              value: notifsEnabled,
              activeColor: AppColors.primary,
              onChanged: (val) async {
                ref.read(notificationEnabledProvider.notifier).state = val;
                await ref.read(preferencesServiceProvider).setNotificationsEnabled(val);
                final notifs = ref.read(notificationServiceProvider);
                if (val) {
                  await notifs.requestPermission();
                  await notifs.showStreakNotification(
                    title: 'Streak Reminders Active! 🔥',
                    body: 'We will notify you to keep your creative streak safe.',
                  );
                } else {
                  await notifs.cancelAll();
                }
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekStreakStrip(int currentStreak, bool checkedInToday) {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final todayIdx = (DateTime.now().weekday - 1).clamp(0, 6);
    final activeCount = currentStreak.clamp(0, 7);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(7, (i) {
        final daysBack = (todayIdx - i + 7) % 7;
        final isActive = checkedInToday
            ? daysBack < activeCount
            : (daysBack >= 1 && daysBack <= activeCount);
        final isToday = i == todayIdx;

        return Column(
          children: [
            AnimatedContainer(
              duration: AppDurations.normal,
              curve: AppCurves.espressoPour,
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? AppColors.amberGold.withValues(alpha: 0.92)
                    : Colors.white.withValues(alpha: 0.12),
                border: Border.all(
                  color: isToday
                      ? Colors.white
                      : (isActive ? AppColors.accentWarm : Colors.white24),
                  width: isToday ? 1.8 : 1.0,
                ),
              ),
              child: Center(
                child: Icon(
                  isActive ? Icons.local_fire_department_rounded : Icons.circle,
                  size: isActive ? 15 : 6,
                  color: isActive ? const Color(0xFF2E1A11) : Colors.white38,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              labels[i],
              style: TextStyle(
                fontSize: 10,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                color: isToday ? Colors.white : Colors.white60,
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildMilestoneCard({
    required BuildContext context,
    required WidgetRef ref,
    required int day,
    required String title,
    required String rewardDesc,
    required String icon,
    required int currentStreak,
    required bool isClaimed,
  }) {
    final isUnlocked = currentStreak >= day;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final textCol = isDark ? Colors.white : AppColors.textPrimaryLight;
    final textSecCol = isDark ? Colors.white.withOpacity(0.6) : AppColors.textSecondaryLight;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isClaimed
              ? Colors.green.withOpacity(0.3)
              : isUnlocked
                  ? AppColors.primary.withOpacity(0.4)
                  : (isDark ? Colors.white.withOpacity(0.06) : AppColors.borderLight),
        ),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: textCol,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '($day Days)',
                      style: TextStyle(
                        fontSize: 12,
                        color: textSecCol,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  rewardDesc,
                  style: TextStyle(
                    fontSize: 12,
                    color: textSecCol,
                  ),
                ),
              ],
            ),
          ),
          if (isClaimed)
            Text(
              'Claimed ✓',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFF69F0AE) : AppColors.success,
              ),
            )
          else if (isUnlocked)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final success =
                    await ref.read(streakProvider.notifier).claimMilestone(day);
                if (context.mounted) {
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Claimed milestone reward for Day $day! 🎉')),
                    );
                    await ReviewPromptService.instance.onStreakMilestoneClaimed(context, day);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Could not claim Day $day reward right now. Please try again.'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
              child: const Text('Claim', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            )
          else
            Text(
              '$currentStreak / $day',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: textSecCol,
              ),
            ),
        ],
      ),
    );
  }
}
