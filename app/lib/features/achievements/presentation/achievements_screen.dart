import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/achievement_service.dart';
import '../../streaks/providers/streak_provider.dart';

class AchievementsScreen extends ConsumerStatefulWidget {
  const AchievementsScreen({super.key});

  @override
  ConsumerState<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends ConsumerState<AchievementsScreen> {
  String _selectedFilter = 'all'; // all, unlocked, in_progress

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(achievementServiceProvider).checkAndUnlockAchievements(context: context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final streak = ref.watch(streakProvider);
    final service = ref.watch(achievementServiceProvider);
    final allAchievements = service.getAllAchievements();

    final unlockedCount = allAchievements.where((a) => a.isUnlocked).length;
    final totalCount = allAchievements.length;

    final filteredList = allAchievements.where((a) {
      if (_selectedFilter == 'unlocked') return a.isUnlocked;
      if (_selectedFilter == 'in_progress') return !a.isUnlocked;
      return true;
    }).toList();

    final currentXpInLevel = streak.totalXp % 100;
    final progressToNextLevel = (currentXpInLevel / 100.0).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text(
          'Achievements & Badges',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Level & Badges Banner
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2E0854), Color(0xFF1E1B4B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.primaryLight.withOpacity(0.3)),
                boxShadow: kIsWeb
                    ? null
                    : [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.3),
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.primaryLight, width: 2),
                            ),
                            child: Center(
                              child: Text(
                                streak.level >= 5 ? '👑' : streak.level >= 3 ? '⭐' : '⚡',
                                style: const TextStyle(fontSize: 26),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Level ${streak.level} Creator',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$unlockedCount of $totalCount Badges Unlocked',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${streak.totalXp} XP Total',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progressToNextLevel,
                      minHeight: 10,
                      backgroundColor: Colors.white.withOpacity(0.12),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryLight),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$currentXpInLevel / 100 XP to Level ${streak.level + 1}',
                        style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.6)),
                      ),
                      Text(
                        '${((unlockedCount / totalCount) * 100).round()}% Completed',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryLight,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 2. Filter Pills
            Row(
              children: [
                _buildFilterChip('All ($totalCount)', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Unlocked ($unlockedCount)', 'unlocked'),
                const SizedBox(width: 8),
                _buildFilterChip('In Progress (${totalCount - unlockedCount})', 'in_progress'),
              ],
            ),

            const SizedBox(height: 16),

            // 3. Achievement Badges List
            ...filteredList.map((ach) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ach.isUnlocked
                      ? AppColors.surfaceElevatedDark
                      : AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: ach.isUnlocked
                        ? AppColors.primary.withOpacity(0.5)
                        : Colors.white.withOpacity(0.06),
                    width: ach.isUnlocked ? 1.5 : 1.0,
                  ),
                  boxShadow: (ach.isUnlocked && !kIsWeb)
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.12),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: ach.isUnlocked
                            ? AppColors.primary.withOpacity(0.2)
                            : Colors.white.withOpacity(0.04),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: ach.isUnlocked
                              ? AppColors.primaryLight
                              : Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          ach.icon,
                          style: TextStyle(
                            fontSize: 24,
                            color: ach.isUnlocked ? null : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                ach.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: ach.isUnlocked ? Colors.white : Colors.white70,
                                ),
                              ),
                              if (ach.isUnlocked)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'UNLOCKED ✓',
                                    style: TextStyle(
                                      color: Colors.greenAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ach.description,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.65),
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '+${ach.xpReward} XP',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryLight,
                                  ),
                                ),
                              ),
                              if (ach.bonusCredits > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '+${ach.bonusCredits} AI Credit',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amberAccent,
                                    ),
                                  ),
                                ),
                              ],
                              const Spacer(),
                              Text(
                                ach.progressText,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: ach.isUnlocked ? Colors.greenAccent : Colors.white54,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          if (!ach.isUnlocked) ...[
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: ach.progress,
                                minHeight: 5,
                                backgroundColor: Colors.white.withOpacity(0.08),
                                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 16),

            // Share Showcase Card Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surfaceElevatedDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.borderDark),
                ),
              ),
              icon: const Icon(Icons.share_rounded, size: 18),
              label: const Text(
                'Share Creator Achievements Card 📸',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                final text =
                    'Level ${streak.level} Creator on VibeKit AI! Unlocked $unlockedCount achievements and earned ${streak.totalXp} XP ⚡✨';
                context.push('/card-maker', extra: text);
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String filterKey) {
    final isSelected = _selectedFilter == filterKey;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedFilter = filterKey),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primaryLight : Colors.white.withOpacity(0.08),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.white70,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
