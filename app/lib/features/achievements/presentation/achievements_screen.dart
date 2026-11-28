import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_durations.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/services/achievement_service.dart';
import '../../../core/widgets/motion_widgets.dart';
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final textCol = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subtitleCol = isDark ? Colors.white70 : AppColors.textSecondaryLight;
    final descCol = isDark ? Colors.white.withOpacity(0.65) : AppColors.textSecondaryLight;
    final cardBgUnlocked = isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceCardLight;
    final cardBgLocked = isDark ? AppColors.surfaceDark : const Color(0xFFF3ECE1);
    final borderLocked = isDark ? Colors.white.withOpacity(0.06) : AppColors.borderLight;
    final iconCircleLocked = isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFE8DFD3);
    final iconBorderLocked = isDark ? Colors.white.withOpacity(0.1) : AppColors.borderLight;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: Text(
          'Achievements & Badges',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Level & Badges Banner (Harmonized Warm Espresso & Caramel Gold)
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: isDark
                    ? AppColors.cardGlowGradient
                    : AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.45),
                  width: 1.2,
                ),
                boxShadow: kIsWeb
                    ? null
                    : [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
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
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.22),
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.accent, width: 2),
                              ),
                              child: Center(
                                child: Text(
                                  streak.level >= 5 ? '👑' : streak.level >= 3 ? '⭐' : '⚡',
                                  style: const TextStyle(fontSize: 26),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Level ${streak.level} Creator',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$unlockedCount of $totalCount Badges Unlocked',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withOpacity(0.75),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
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
                            fontFeatures: AppTypography.tabularFigures,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  AnimatedProgressBar(
                    value: progressToNextLevel,
                    minHeight: 10,
                    backgroundColor: Colors.white.withOpacity(0.14),
                    color: AppColors.accentWarm,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$currentXpInLevel / 100 XP to Level ${streak.level + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontFeatures: AppTypography.tabularFigures,
                          color: Colors.white.withOpacity(0.65),
                        ),
                      ),
                      Text(
                        '${((unlockedCount / totalCount) * 100).round()}% Completed',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          fontFeatures: AppTypography.tabularFigures,
                          color: AppColors.accentWarm,
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
                _buildFilterChip('All ($totalCount)', 'all', isDark),
                const SizedBox(width: 8),
                _buildFilterChip('Unlocked ($unlockedCount)', 'unlocked', isDark),
                const SizedBox(width: 8),
                _buildFilterChip('In Progress (${totalCount - unlockedCount})', 'in_progress', isDark),
              ],
            ),

            const SizedBox(height: 16),

            // 3. Achievement Badges List
            ...filteredList.asMap().entries.map((entry) {
              final idx = entry.key;
              final ach = entry.value;
              return StaggeredEntrance(
                key: ValueKey<String>('${_selectedFilter}_${ach.id}'),
                index: idx,
                child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ach.isUnlocked ? cardBgUnlocked : cardBgLocked,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: ach.isUnlocked
                        ? AppColors.primary.withOpacity(0.5)
                        : borderLocked,
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
                            : iconCircleLocked,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: ach.isUnlocked
                              ? AppColors.primaryLight
                              : iconBorderLocked,
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
                              Expanded(
                                child: Text(
                                  ach.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: ach.isUnlocked ? textCol : subtitleCol,
                                  ),
                                ),
                              ),
                              if (ach.isUnlocked) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withValues(alpha: isDark ? 0.22 : 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'UNLOCKED ✓',
                                    style: TextStyle(
                                      color: isDark ? const Color(0xFF69F0AE) : AppColors.success,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ach.description,
                            style: TextStyle(
                              fontSize: 12,
                              color: descCol,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '+${ach.xpReward} XP',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? AppColors.primaryLight : AppColors.primary,
                                        ),
                                      ),
                                    ),
                                    if (ach.bonusCredits > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.amberGold.withValues(alpha: 0.16),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '+${ach.bonusCredits} AI Credit',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? AppColors.amberGold : const Color(0xFF9A6700),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                ach.progressText,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: ach.isUnlocked
                                      ? (isDark ? const Color(0xFF69F0AE) : AppColors.success)
                                      : (isDark ? Colors.white54 : AppColors.textMutedLight),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          if (!ach.isUnlocked) ...[
                            const SizedBox(height: 8),
                            AnimatedProgressBar(
                              value: ach.progress,
                              minHeight: 5,
                              backgroundColor: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFDDD2C4),
                              color: isDark ? AppColors.accentWarm : AppColors.primary,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              );
            }),

            const SizedBox(height: 16),

            // Share Showcase Card Button
            TactileScale(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceCardLight,
                  foregroundColor: isDark ? Colors.white : AppColors.textPrimaryLight,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                  ),
                ),
                icon: Icon(Icons.share_rounded, size: 18, color: isDark ? Colors.white : AppColors.textPrimaryLight),
                label: Text(
                  'Share Creator Achievements Card 📸',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                ),
                onPressed: () {
                  final text =
                      'Level ${streak.level} Creator on VibeKit AI! Unlocked $unlockedCount achievements and earned ${streak.totalXp} XP ⚡✨';
                  context.push('/card-maker', extra: text);
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String filterKey, bool isDark) {
    final isSelected = _selectedFilter == filterKey;
    final unselectedBg = isDark ? AppColors.surfaceDark : AppColors.surfaceCardLight;
    final unselectedBorder = isDark ? Colors.white.withOpacity(0.08) : AppColors.borderLight;
    final unselectedText = isDark ? Colors.white70 : AppColors.textSecondaryLight;
    return Expanded(
      child: TactileScale(
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _selectedFilter = filterKey);
          },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: AppDurations.fast,
            curve: AppCurves.espressoPour,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : unselectedBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.accent : unselectedBorder,
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : unselectedText,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
