import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/review_prompt_service.dart';
import '../providers/streak_provider.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService();
  service.init();
  return service;
});

final notificationEnabledProvider = StateProvider<bool>((ref) => true);

class StreakScreen extends ConsumerWidget {
  const StreakScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(streakProvider);
    final quota = ref.watch(quotaProvider);
    final notifsEnabled = ref.watch(notificationEnabledProvider);

    final currentXpInLevel = streak.totalXp % 100;
    final progressToNextLevel = currentXpInLevel / 100.0;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Vibe Streaks & Rewards',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Flame & Streak Status Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF31102F), Color(0xFF1E1B4B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.orange.withOpacity(0.3), width: 1.5),
                boxShadow: kIsWeb
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.15),
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
                      color: Colors.orange.withOpacity(0.2),
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
                          ? Colors.green.withOpacity(0.2)
                          : Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      streak.checkedInToday ? 'Checked in today ✓' : 'Pending today ⏳',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: streak.checkedInToday ? Colors.greenAccent : Colors.amberAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 2. Vibe Points (XP) & Level Progress
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
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
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${streak.totalXp} XP Total',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progressToNextLevel,
                      minHeight: 10,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$currentXpInLevel / 100 XP to Level ${streak.level + 1}',
                    style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.6)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 3. Streak Freeze Counter & Protection
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.cyan.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.cyan.withOpacity(0.15),
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
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          quota.isPro
                              ? 'Pro Perk: Refilled 1x weekly'
                              : 'Protects your streak if you miss a day',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!quota.isPro && streak.freezeCount < 2)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyan.withOpacity(0.3),
                        foregroundColor: Colors.cyanAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        final success = await ref.read(streakProvider.notifier).earnFreeze();
                        if (context.mounted && success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('+1 Streak Freeze earned! ❄️')),
                          );
                        }
                      },
                      child: const Text('+1 Freeze', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 4. Milestone Rewards
            const Text(
              'Milestone Rewards',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
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
              title: const Text(
                'Daily Streak Reminders',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Receive an evening reminder if your streak is about to break',
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
              ),
              value: notifsEnabled,
              activeColor: AppColors.primary,
              onChanged: (val) async {
                ref.read(notificationEnabledProvider.notifier).state = val;
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isClaimed
              ? Colors.green.withOpacity(0.3)
              : isUnlocked
                  ? AppColors.primary.withOpacity(0.4)
                  : Colors.white.withOpacity(0.06),
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
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '($day Days)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  rewardDesc,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          if (isClaimed)
            const Text(
              'Claimed ✓',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.greenAccent,
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
                    await ref.read(streakProvider.notifier).claimMilestone(day, ref);
                if (context.mounted && success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Claimed milestone reward for Day $day! 🎉')),
                  );
                  await ReviewPromptService.instance.onStreakMilestoneClaimed(context, day);
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
                color: Colors.white.withOpacity(0.4),
              ),
            ),
        ],
      ),
    );
  }
}
