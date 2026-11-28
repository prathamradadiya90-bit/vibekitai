import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_durations.dart';
import '../../core/constants/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/adaptive_banner_widget.dart';
import '../../core/widgets/app_bottom_nav.dart';
import '../../core/widgets/motion_widgets.dart';
import '../../models/challenge_model.dart';
import '../../models/history_item.dart';
import '../streaks/providers/streak_provider.dart';
import '../referrals/presentation/referral_modal.dart';
import '../../core/services/achievement_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  ChallengeModel? _todaysChallenge;
  List<HistoryItem> _recentCreations = [];
  int _sparkIndex = 0;
  int _sparkDirection = 1;
  bool _showAllShortcuts = false;
  bool _isStartingRewardedAd = false;

  static const List<Map<String, String>> _viralSparks = [
    {
      'title': 'Check a message for red flags',
      'subtitle': 'Spot guilt-tripping, love bombing, or genuine green flags in seconds.',
      'prompt': "My ex was totally crazy, you are the only one who gets me so don't let me down.",
      'buttonText': 'Check Red Flags',
      'option': 'flags',
      'tab': 'vibe_check',
    },
    {
      'title': 'Reply to a silent story post',
      'subtitle': 'Send a natural opener to an Instagram or Snapchat story without sounding forced.',
      'prompt': "Reacting to an aesthetic late night ramen story with no caption",
      'buttonText': 'Get Story Replies',
      'option': 'story',
      'tab': 'vibe_check',
    },
    {
      'title': 'Check your texting chemistry',
      'subtitle': 'See how your conversation reads and get balanced, witty reply ideas.',
      'prompt': "Him: you have good music taste. Her: only took you 3 months to notice.",
      'buttonText': 'Check Chemistry',
      'option': 'chemistry',
      'tab': 'vibe_check',
    },
    {
      'title': 'Reply to a one-word "k." text',
      'subtitle': 'Turn a dry one-word text into a confident, funny, or playful reply.',
      'prompt': "Replying to 'k' after 6 hours of silence",
      'buttonText': 'See Reply Ideas',
      'option': 'Savage',
      'tab': 'reply',
    },
    {
      'title': 'Handle a late-night "wyd?" text',
      'subtitle': 'Choose between smooth charm or setting a clear, relaxed boundary.',
      'prompt': "Replying to 'wyd' at 1:47 AM",
      'buttonText': 'See Reply Ideas',
      'option': 'Rizz',
      'tab': 'reply',
    },
    {
      'title': 'Reply calmly to "we need to talk"',
      'subtitle': 'Keep your cool with calm, direct responses that stay composed.',
      'prompt': "Responding calmly to 'we need to talk'",
      'buttonText': 'See Calm Replies',
      'option': 'Confident',
      'tab': 'reply',
    },
    {
      'title': 'Restart a quiet conversation',
      'subtitle': 'Reach back out naturally after weeks of silence with zero awkwardness.',
      'prompt': "Re-ignite a conversation that went cold 3 weeks ago",
      'buttonText': 'Get Icebreakers',
      'option': 'revival',
      'tab': 'vibe_check',
    },
    {
      'title': 'Shorten an overthought draft',
      'subtitle': 'Trim a nervous long paragraph into a clear, confident message.',
      'prompt': "Overthinking what to text without sounding desperate or anxious",
      'buttonText': 'Polish This Draft',
      'option': 'overthinking',
      'tab': 'vibe_check',
    },
    {
      'title': 'Write a sincere apology text',
      'subtitle': 'Say sorry thoughtfully and calm an argument without making excuses.',
      'prompt': "Sincere apology after losing my temper and sending a harsh text",
      'buttonText': 'Write Apology',
      'option': 'apology',
      'tab': 'vibe_check',
    },
    {
      'title': 'Send a better dating app opener',
      'subtitle': 'Skip boring "hey" messages with playful openers based on their profile.',
      'prompt': "Creative icebreaker opening line for dating app match who loves hiking and dogs",
      'buttonText': 'Get Openers',
      'option': 'Opener',
      'tab': 'reply',
    },
    {
      'title': 'Respond when left on delivered',
      'subtitle': 'Reply casually without sounding annoyed or overly eager.',
      'prompt': "Replying to someone who left me on delivered for 18 hours",
      'buttonText': 'See Chill Replies',
      'option': 'Unbothered',
      'tab': 'reply',
    },
    {
      'title': 'Cancel plans politely',
      'subtitle': 'Turn down plans kindly when you need rest without feeling guilty.',
      'prompt': "Polite excuse to cancel plans tonight because social battery is zero",
      'buttonText': 'Get Polite Excuses',
      'option': 'excuse',
      'tab': 'vibe_check',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      // 1. Load bundled daily challenge
      final jsonString =
          await rootBundle.loadString('assets/data/challenges.json');
      final list = jsonDecode(jsonString) as List<dynamic>;
      ChallengeModel? challenge;
      if (list.isNotEmpty) {
        // Pick challenge based on day of year
        final dayOfYear = DateTime.now()
            .difference(DateTime(DateTime.now().year, 1, 1))
            .inDays;
        final index = dayOfYear % list.length;
        challenge =
            ChallengeModel.fromJson(list[index] as Map<String, dynamic>);
      }

      // 2. Load recent items from LocalDatabase
      final db = ref.read(localDatabaseProvider);
      final recent = await db.getItems(limit: 5);

      if (mounted) {
        setState(() {
          _todaysChallenge = challenge;
          _recentCreations = recent;
        });
        ref.read(achievementServiceProvider).checkAndUnlockAchievements(context: context);
      }
    } catch (e) {
      debugPrint('HomeScreen: Error loading data: $e');
    }
  }

  Future<void> _reloadRecentCreations() async {
    try {
      final db = ref.read(localDatabaseProvider);
      final recent = await db.getItems(limit: 5);
      if (mounted) {
        setState(() => _recentCreations = recent);
      }
    } catch (_) {}
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _watchRewardedAd() async {
    if (_isStartingRewardedAd) return;
    if (!ref.read(quotaProvider).canWatchRewardedAd) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Daily rewarded ads limit reached.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    _isStartingRewardedAd = true;
    try {
      final adMob = ref.read(adMobServiceProvider);
      final quotaNotifier = ref.read(quotaProvider.notifier);
      final apiClient = ref.read(apiClientProvider);
      final instId = ref.read(preferencesServiceProvider).getAppInstanceId();

      final nonce = await apiClient.requestAdNonce();
      final rewardId = 'rew_${DateTime.now().millisecondsSinceEpoch}';
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
        onRewardEarned: (reward) async {
          final verified = await quotaNotifier.grantRewardCredit(
            nonce: nonce,
            rewardId: rewardId,
          );
          if (mounted) {
            if (verified) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🎉 +3 Bonus AI Credits unlocked!'),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Could not verify reward. Please try again.'),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        },
        onAdFailed: () {
          failureNotified = true;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Ad is loading. Please try again in a moment.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      );

      if (!showed && !failureNotified && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ad is loading. Please try again in a moment.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      _isStartingRewardedAd = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(historyRevisionProvider, (_, __) => _reloadRecentCreations());
    final quota = ref.watch(quotaProvider);
    final streak = ref.watch(streakProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(quotaProvider.notifier).refresh();
            await ref.read(streakProvider.notifier).fetchStreak();
            await _loadDashboardData();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header: Clean greeting, App Title, Responsive Actions (Zero Overflow)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _getGreeting(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  AppConfig.appName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.6,
                                    color: isDark
                                        ? AppColors.textPrimaryDark
                                        : AppColors.textPrimaryLight,
                                  ),
                                ),
                              ),
                              if (quota.isPro) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    gradient: AppColors.accentGradient,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'PRO',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Quick Light / Dark Theme Switcher
                            TactileScale(
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  ref.read(themeModeProvider.notifier).toggleTheme();
                                },
                                icon: AnimatedSwitcher(
                                  duration: AppDurations.fast,
                                  switchInCurve: AppCurves.cremaSpring,
                                  transitionBuilder: (child, animation) =>
                                      ScaleTransition(scale: animation, child: child),
                                  child: Icon(
                                    isDark
                                        ? Icons.wb_sunny_rounded
                                        : Icons.nightlight_round,
                                    key: ValueKey<bool>(isDark),
                                    color: AppColors.accent,
                                    size: 20,
                                  ),
                                ),
                                tooltip: 'Toggle Theme',
                              ),
                            ),
                            const SizedBox(width: 4),
                            TactileScale(
                              child: InkWell(
                                onTap: () => context.push('/streaks'),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: AppColors.warning.withValues(alpha: 0.38)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('🔥',
                                          style: TextStyle(fontSize: 14)),
                                      const SizedBox(width: 3),
                                      Text(
                                        '${streak.currentStreak}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          fontFeatures: AppTypography.tabularFigures,
                                          color: isDark
                                              ? AppColors.amberGold
                                              : const Color(0xFFB45309),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // 1. Hero Daily Vibe Spark Card (Swipeable, Clean, Engaging)
                Builder(
                  builder: (context) {
                    final currentSpark = _viralSparks[_sparkIndex % _viralSparks.length];
                    void stepSpark(int delta) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _sparkDirection = delta >= 0 ? 1 : -1;
                        _sparkIndex =
                            (_sparkIndex + delta) % _viralSparks.length;
                      });
                    }

                    return GestureDetector(
                      onHorizontalDragEnd: (details) {
                        final vx = details.primaryVelocity ?? 0;
                        if (vx < -220) {
                          stepSpark(1);
                        } else if (vx > 220) {
                          stepSpark(-1);
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF221710) : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark ? AppColors.borderDark : const Color(0xFFEDE4D8),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (isDark ? Colors.black : const Color(0xFF6B4226))
                                  .withOpacity(isDark ? 0.35 : 0.05),
                              blurRadius: 18,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Clean Top Row: Clear Demo Badge & Next Button
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF382315) : const Color(0xFFFFF3E8),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.auto_awesome_rounded,
                                        size: 13,
                                        color: isDark ? AppColors.accent : AppColors.primary,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        'EXAMPLE TO TRY',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.7,
                                          color: isDark
                                              ? AppColors.accentWarm
                                              : AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TactileScale(
                                  child: InkWell(
                                    onTap: () => stepSpark(1),
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: isDark ? AppColors.surfaceElevatedDark : const Color(0xFFF7F1E8),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.refresh_rounded,
                                            size: 13,
                                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Next',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Clear Example Content with Directional Pour Transition
                            AnimatedSwitcher(
                              duration: AppDurations.normal,
                              switchInCurve: AppCurves.espressoPour,
                              switchOutCurve: Curves.easeInQuad,
                              transitionBuilder: (child, animation) => FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: Offset(0.03 * _sparkDirection, 0),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              ),
                              child: Column(
                                key: ValueKey<int>(_sparkIndex),
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Plain-English Title
                                  Text(
                                    currentSpark['title']!,
                                    style: GoogleFonts.outfit(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                      height: 1.25,
                                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    currentSpark['subtitle']!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.4,
                                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Clear Sample Quote Box
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1B110A) : const Color(0xFFFBF6EF),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isDark ? AppColors.borderDark : const Color(0xFFE5DDD0),
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Sample text',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? AppColors.textSecondaryDark
                                                : AppColors.textSecondaryLight,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '"${currentSpark['prompt']!}"',
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: isDark
                                                ? const Color(0xFFFFD199)
                                                : const Color(0xFF4A2A14),
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Subtle Swipeable Deck Progress Dots
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(_viralSparks.length, (i) {
                                final active = i == _sparkIndex % _viralSparks.length;
                                return AnimatedContainer(
                                  duration: AppDurations.normal,
                                  curve: AppCurves.espressoPour,
                                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                                  height: 4,
                                  width: active ? 16 : 4,
                                  decoration: BoxDecoration(
                                    color: active
                                        ? (isDark ? AppColors.accent : AppColors.primary)
                                        : (isDark ? AppColors.borderDark : AppColors.borderLight),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 12),

                            // Primary CTA Button: Try This Example
                            TactileScale(
                              child: InkWell(
                                onTap: () {
                                  HapticFeedback.mediumImpact();
                                  final targetTab = currentSpark['tab'] ?? 'reply';
                                  context.push(
                                    '/studio?tab=$targetTab&prompt=${Uri.encodeComponent(currentSpark['prompt']!)}&option=${currentSpark['option']!}',
                                  );
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  decoration: BoxDecoration(
                                    gradient: isDark
                                        ? const LinearGradient(
                                            colors: [Color(0xFFD07A39), Color(0xFF9C4D1E)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          )
                                        : AppColors.primaryGradient,
                                    borderRadius: BorderRadius.circular(16),
                                    border: isDark
                                        ? Border.all(
                                            color: AppColors.accent.withValues(alpha: 0.45),
                                          )
                                        : null,
                                    boxShadow: !kIsWeb
                                        ? [
                                            BoxShadow(
                                              color: AppColors.primary.withValues(alpha: 0.22),
                                              blurRadius: 12,
                                              offset: const Offset(0, 3),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.bolt_rounded,
                                        size: 18,
                                        color: Color(0xFFFFD199),
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          '${currentSpark['buttonText']!} →',
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.1,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),

                            // Clear Secondary Link: Write/Paste Your Own Message
                            Center(
                              child: TactileScale(
                                child: TextButton.icon(
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    final targetTab = currentSpark['tab'] ?? 'reply';
                                    context.push('/studio?tab=$targetTab&prompt=');
                                  },
                                  icon: Icon(
                                    Icons.edit_outlined,
                                    size: 14,
                                    color: isDark ? AppColors.accentWarm : AppColors.primary,
                                  ),
                                  label: Text(
                                    'Or paste your own message instead',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppColors.accentWarm : AppColors.primary,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 22),

                // Core Studio Action Cards Grid (Front & Center)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Creative Studios',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                    ),
                    InkWell(
                      onTap: () => context.push('/paywall'),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceElevatedLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? AppColors.borderDark : AppColors.borderLight,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bolt_rounded, size: 14, color: AppColors.accent),
                            const SizedBox(width: 4),
                            Text(
                              quota.isPro ? 'Pro Active' : '${quota.totalCreditsRemaining} Credits',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.accentWarm : AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStudioCard(
                        context,
                        title: 'Reply Studio',
                        subtitle: 'Smart responses',
                        icon: Icons.chat_bubble_outline_rounded,
                        color: AppColors.primary,
                        badgeText: '🔥 HOT',
                        route: '/studio?tab=reply',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStudioCard(
                        context,
                        title: 'Vibe Check',
                        subtitle: 'Roast & rating',
                        icon: Icons.local_fire_department_outlined,
                        color: AppColors.emberOrange,
                        badgeText: '⚡ VIRAL',
                        route: '/studio?tab=vibe_check',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStudioCard(
                        context,
                        title: 'Caption Lab',
                        subtitle: 'Reels & Hashtags',
                        icon: Icons.auto_awesome_rounded,
                        color: AppColors.accent,
                        badgeText: '✨ TREND',
                        route: '/studio?tab=caption',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStudioCard(
                        context,
                        title: 'Bio Lab',
                        subtitle: 'Bios & handles',
                        icon: Icons.badge_outlined,
                        color: AppColors.sageGreen,
                        badgeText: '🌿 FRESH',
                        route: '/studio?tab=bio',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildStudioCard(
                  context,
                  title: 'Meme & Card Maker',
                  subtitle:
                      'Design high-res quote & meme cards locally without cloud API',
                  icon: Icons.brush_outlined,
                  color: AppColors.accentPink,
                  badgeText: '🎨 100% OFFLINE',
                  route: '/card-maker',
                  isWide: true,
                ),
                const SizedBox(height: 12),
                _buildStudioCard(
                  context,
                  title: 'Vibe Radar & Aura Quiz',
                  subtitle:
                      'Take the 60s quiz, discover your texting archetype & get your custom Aura card',
                  icon: Icons.radar_rounded,
                  color: const Color(0xFFE28743),
                  badgeText: '✨ NEW VIRAL',
                  route: '/aura-radar',
                  isWide: true,
                ),

                const SizedBox(height: 24),

                // Quick Vibe Shortcuts (Curated top 6 + expandable toggle)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Quick Vibe Shortcuts',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() => _showAllShortcuts = !_showAllShortcuts);
                      },
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      child: Text(
                        _showAllShortcuts ? 'Show top 6' : 'All 18',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.accentWarm : AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    final allShortcuts = [
                      _buildQuickShortcut(
                        icon: '🚩',
                        label: 'Flag Scanner',
                        onTap: () => _openStudioShortcut(
                          tab: 'vibe_check',
                          option: 'flags',
                          prompt: "My ex was totally crazy, you are the only one who gets me so don't let me down.",
                        ),
                      ),
                      _buildQuickShortcut(
                        icon: '📸',
                        label: 'Story Reply',
                        onTap: () => _openStudioShortcut(
                          tab: 'vibe_check',
                          option: 'story',
                          prompt: "They posted a late-night rooftop cocktail story with no caption.",
                        ),
                      ),
                      _buildQuickShortcut(
                        icon: '✨',
                        label: 'Chemistry Match',
                        onTap: () => _openStudioShortcut(
                          tab: 'vibe_check',
                          option: 'chemistry',
                          prompt: "Him: you have surprisingly good music taste. Her: only took you 3 months to notice.",
                        ),
                      ),
                      _buildQuickShortcut(
                        icon: '🧟',
                        label: 'Ghosting Revival',
                        onTap: () => _openStudioShortcut(
                          tab: 'vibe_check',
                          option: 'revival',
                          prompt: "Conversation died 3 weeks ago after great chemistry. Want a witty, zero-pressure text to reignite.",
                        ),
                      ),
                      _buildQuickShortcut(
                        icon: '🧠',
                        label: 'Overthinking Fix',
                        onTap: () => _openStudioShortcut(
                          tab: 'vibe_check',
                          option: 'overthinking',
                          prompt: "Hey sorry to bother you I know you are super busy and probably do not want to talk but if you have five minutes maybe we could call? If not totally fine no pressure!",
                        ),
                      ),
                      _buildQuickShortcut(
                        icon: '🎯',
                        label: 'Dating Opener',
                        onTap: () => _openStudioShortcut(
                          tab: 'reply',
                          option: 'Witty',
                          prompt: "Matched on Hinge: loves iced matcha, indie vinyl, and golden retrievers",
                        ),
                      ),
                      _buildQuickShortcut(
                        icon: '🕶️',
                        label: 'Unbothered',
                        onTap: () => _openStudioShortcut(
                          tab: 'reply',
                          option: 'Unbothered',
                          prompt: "Leaving me on delivered all day? I respect the mystery.",
                        ),
                      ),
                      _buildQuickShortcut(
                        icon: '🤝',
                        label: 'Conflict Defuser',
                        onTap: () => _openStudioShortcut(
                          tab: 'vibe_check',
                          option: 'apology',
                          prompt: "I lost my temper and snapped during our argument yesterday. Want a sincere, mature apology.",
                        ),
                      ),
                      _buildQuickShortcut(
                        icon: '⚡',
                        label: 'Magnetic Rizz',
                        onTap: () => _openStudioShortcut(
                          tab: 'reply',
                          option: 'Rizz',
                          prompt: "How do you manage to look this effortlessly stunning on a random Tuesday?",
                        ),
                      ),
                      _buildQuickShortcut(
                        icon: '🕵️',
                        label: 'Text Decrypter',
                        onTap: () => _openStudioShortcut(
                          tab: 'vibe_check',
                          option: 'decoder',
                          prompt: "It's totally fine. Do whatever you want.",
                        ),
                      ),
                      _buildQuickShortcut(
                        icon: '🏃',
                        label: 'Cancel Plans',
                        onTap: () => _openStudioShortcut(
                          tab: 'vibe_check',
                          option: 'excuse',
                          prompt: "Hey sorry I really cannot make it tonight my social battery is at zero. Can we do Sunday instead?",
                        ),
                      ),
                      _buildQuickShortcut(
                        icon: '🔥',
                        label: 'Savage Roast',
                        onTap: () => _openStudioShortcut(
                          tab: 'vibe_check',
                          option: 'roast',
                          prompt: "You took 6 hours to reply with 'cool'.",
                        ),
                      ),
                      _buildQuickShortcut(
                        icon: '💬',
                        label: 'Funny Reply',
                        onTap: () => _openStudioShortcut(
                          tab: 'reply',
                          option: 'Funny',
                          prompt: "Are you free this weekend or should I book an appointment with your secretary?",
                        ),
                      ),
                      _buildQuickShortcut(
                        icon: '💘',
                        label: 'Flirty Text',
                        onTap: () => _openStudioShortcut(
                          tab: 'reply',
                          option: 'Flirty',
                          prompt: "Stop looking at my story and just text me already.",
                        ),
                      ),
                      _buildQuickShortcut(
                        icon: '✨',
                        label: 'Reel Hook',
                        onTap: () => _openStudioShortcut(
                          tab: 'caption',
                          option: 'Trendy',
                          prompt: "3 harsh truths nobody tells you about moving to a new city alone.",
                        ),
                      ),
                      _buildQuickShortcut(
                        icon: '🎨',
                        label: 'Meme Card',
                        onTap: () => context.push('/card-maker'),
                      ),
                      _buildQuickShortcut(
                        icon: '👤',
                        label: 'Aesthetic Bio',
                        onTap: () => _openStudioShortcut(
                          tab: 'bio',
                          option: 'Aesthetic',
                          prompt: "Living simply, reading deeply, chasing golden hour light. Based in SF / NYC.",
                        ),
                      ),
                      _buildQuickShortcut(
                        icon: '💼',
                        label: 'Boss Mode',
                        onTap: () => _openStudioShortcut(
                          tab: 'vibe_check',
                          option: 'work',
                          prompt: "Following up on my scope expansion and compensation review from last quarter.",
                        ),
                      ),
                    ];
                    final visibleShortcuts = _showAllShortcuts
                        ? allShortcuts
                        : allShortcuts.take(6).toList();
                    return AnimatedSize(
                      duration: AppDurations.normal,
                      curve: AppCurves.espressoPour,
                      alignment: Alignment.topLeft,
                      child: _showAllShortcuts
                          ? Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: visibleShortcuts,
                            )
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                children: [
                                  for (int i = 0; i < visibleShortcuts.length; i++) ...[
                                    visibleShortcuts[i],
                                    if (i < visibleShortcuts.length - 1)
                                      const SizedBox(width: 8),
                                  ],
                                ],
                              ),
                            ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Daily Creator Perks & Credit Balance
                Text(
                  'Daily Creator Perks',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 10),

                // Credit Balance & Status Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceCardDark : AppColors.surfaceCardLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                      width: 1.2,
                    ),
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
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.18),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.bolt_rounded,
                                      color: AppColors.accent, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        quota.isPro
                                            ? 'Pro Active'
                                            : 'Daily AI Credits',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: isDark
                                              ? AppColors.textPrimaryDark
                                              : AppColors.textPrimaryLight,
                                        ),
                                      ),
                                      Text(
                                        quota.isPro
                                            ? '${quota.proCreditsRemaining} credits available'
                                            : '${quota.totalCreditsRemaining} remaining today',
                                        style: TextStyle(
                                          color: isDark
                                              ? AppColors.textSecondaryDark
                                              : AppColors.textSecondaryLight,
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (!quota.isPro)
                            TactileScale(
                              child: OutlinedButton(
                                onPressed: () => context.push('/paywall'),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                      color: isDark ? AppColors.accent : AppColors.primary),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                ),
                                child: Text('Get Pro',
                                    style: TextStyle(
                                        color: isDark ? AppColors.accent : AppColors.primary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                        ],
                      ),
                      if (!quota.isPro && quota.canWatchRewardedAd && (!kIsWeb || AppConfig.isDev)) ...[
                        Divider(
                          height: 24,
                          color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        ),
                        TactileScale(
                          child: InkWell(
                            onTap: _watchRewardedAd,
                            borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.surfaceElevatedDark
                                  : AppColors.surfaceElevatedLight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.play_circle_fill_rounded,
                                    color: AppColors.accent, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Watch video ad to get +3 free AI credits',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? AppColors.textPrimaryDark
                                          : AppColors.textPrimaryLight,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${quota.rewardedAdsWatchedToday}/${quota.maxRewardedAdsPerDay}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? AppColors.textMutedDark
                                        : AppColors.textMutedLight,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                const AdaptiveBannerWidget(),

                const SizedBox(height: 14),

                // Refer & Earn Promo Banner
                TactileScale(
                  child: InkWell(
                    onTap: () => ReferralModal.show(context),
                    borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceCardDark : AppColors.surfaceCardLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Text('🎁', style: TextStyle(fontSize: 22)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Invite a friend, get +2 credits',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isDark
                                      ? AppColors.textPrimaryDark
                                      : AppColors.textPrimaryLight,
                                ),
                              ),
                              Text(
                                'Both of you get bonus credits instantly',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            'Invite',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ),

                const SizedBox(height: 14),

                // Creator Level & Daily Streak Pulse (Gamified Retention Card)
                TactileScale(
                  child: InkWell(
                    onTap: () => context.push('/streaks'),
                    borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceCardLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? AppColors.accent.withOpacity(0.3)
                            : AppColors.accent.withOpacity(0.2),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(alpha: 0.16),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                streak.level >= 5 ? '👑' : streak.level >= 3 ? '⭐' : '⚡',
                                style: const TextStyle(fontSize: 20),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Level ${streak.level} Creator',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: isDark
                                              ? AppColors.textPrimaryDark
                                              : AppColors.textPrimaryLight,
                                        ),
                                      ),
                                      Text(
                                        '${streak.totalXp % 100} / 100 XP',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.accent,
                                          fontWeight: FontWeight.bold,
                                          fontFeatures: AppTypography.tabularFigures,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  AnimatedProgressBar(
                                    value: (streak.totalXp % 100) / 100.0,
                                    minHeight: 6,
                                    backgroundColor: isDark
                                        ? Colors.white.withOpacity(0.08)
                                        : AppColors.borderLight,
                                    color: AppColors.accent,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 13,
                              color: isDark ? Colors.white38 : AppColors.textSecondaryLight,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Text('🔥', style: TextStyle(fontSize: 15)),
                                const SizedBox(width: 5),
                                Text(
                                  '${streak.currentStreak}-Day Active Streak',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    fontFeatures: AppTypography.tabularFigures,
                                    color: isDark
                                        ? AppColors.amberGold
                                        : const Color(0xFFB45309),
                                  ),
                                ),
                              ],
                            ),
                            if (!streak.checkedInToday)
                              InkWell(
                                onTap: () async {
                                  HapticFeedback.mediumImpact();
                                  final awardedXp = await ref.read(streakProvider.notifier).recordAction('checkin');
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          awardedXp > 0
                                              ? '🎉 Daily Streak checked in! +$awardedXp XP awarded!'
                                              : awardedXp == 0
                                                  ? '✓ Already checked in today!'
                                                  : 'Could not sync check-in right now. Please try again.',
                                        ),
                                        backgroundColor: awardedXp >= 0 ? AppColors.success : AppColors.error,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    gradient: AppColors.accentGradient,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.bolt_rounded, size: 14, color: Colors.white),
                                      SizedBox(width: 3),
                                      Text(
                                        'Check In (+10 XP)',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.success.withOpacity(0.3)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle_rounded, size: 13, color: AppColors.success),
                                    SizedBox(width: 4),
                                    Text(
                                      'Checked in today',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.success,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                ),

                const SizedBox(height: 24),

                // Rotating Daily Creative Challenge
                if (_todaysChallenge != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Daily Creative Challenge',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push('/challenge'),
                        child: Text(
                          'All Challenges',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.accentWarm : AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TactileScale(
                    child: InkWell(
                      onTap: () {
                        final c = _todaysChallenge!;
                        if (c.targetFeature == 'reply') {
                          context.push(
                              '/studio?tab=reply&prompt=${Uri.encodeComponent(c.prompt)}&option=${c.tone}');
                        } else if (c.targetFeature == 'caption') {
                          context.push(
                              '/studio?tab=caption&prompt=${Uri.encodeComponent(c.prompt)}&option=${c.tone}');
                        } else {
                          context.push(
                              '/card-maker?initialPrompt=${Uri.encodeComponent(c.prompt)}');
                        }
                      },
                      borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceCardDark : AppColors.surfaceCardLight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? AppColors.primary.withOpacity(0.35) : AppColors.borderLight,
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.18),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.star_rounded,
                                color: AppColors.accent, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _todaysChallenge!.title,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.accent.withOpacity(0.18),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                                      ),
                                      child: const Text(
                                        '+25 XP BONUS',
                                        style: TextStyle(
                                            color: AppColors.accent,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  _todaysChallenge!.prompt,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.arrow_forward_ios_rounded,
                              size: 13, color: isDark ? AppColors.textMutedDark : AppColors.textSecondaryLight),
                        ],
                      ),
                    ),
                  ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Recent Creations Section
                if (_recentCreations.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Creations',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push('/history'),
                        child: Text(
                          'View All',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.accentWarm : AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 125,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _recentCreations.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final item = _recentCreations[index];
                        return TactileScale(
                          child: InkWell(
                            onTap: () => context.push('/history'),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              width: 200,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.surfaceCardDark : AppColors.surfaceCardLight,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        item.type == 'reply'
                                            ? Icons.chat_bubble_outline_rounded
                                            : item.type == 'caption'
                                                ? Icons.auto_awesome_rounded
                                                : item.type == 'bio'
                                                    ? Icons.badge_outlined
                                                    : item.type == 'vibe_check'
                                                        ? Icons.local_fire_department_rounded
                                                        : Icons.brush_outlined,
                                        size: 14,
                                        color: item.type == 'bio'
                                            ? AppColors.sageGreen
                                            : item.type == 'vibe_check'
                                                ? AppColors.emberOrange
                                                : AppColors.primaryLight,
                                      ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        item.category.toUpperCase(),
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (item.isFavorite)
                                      const Icon(Icons.favorite,
                                          size: 12,
                                          color: AppColors.accentPink),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: Text(
                                    item.content,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }

  Widget _buildStudioCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String route,
    String? badgeText,
    Color? badgeColor,
    bool isWide = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.surfaceCardDark : AppColors.surfaceCardLight;
    final cardBorder = isDark ? color.withOpacity(0.35) : color.withOpacity(0.25);
    final badgeCol = badgeColor ?? color;

    return TactileScale(
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          context.push(route);
        },
        borderRadius: BorderRadius.circular(22),
        child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: cardBorder,
            width: 1.2,
          ),
          gradient: LinearGradient(
            colors: [
              color.withOpacity(isDark ? 0.14 : 0.08),
              cardBg,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                if (badgeText != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeCol.withOpacity(isDark ? 0.2 : 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: badgeCol.withOpacity(isDark ? 0.4 : 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                        color: isDark ? AppColors.accentWarm : AppColors.primary,
                      ),
                    ),
                  )
                else
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: isDark ? Colors.white38 : AppColors.textSecondaryLight,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: isWide ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  void _openStudioShortcut({
    required String tab,
    required String option,
    required String prompt,
  }) {
    final encodedPrompt = Uri.encodeComponent(prompt);
    final encodedOption = Uri.encodeComponent(option);
    context.push('/studio?tab=$tab&option=$encodedOption&prompt=$encodedPrompt');
  }

  Widget _buildQuickShortcut({
    required String icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return TactileScale(
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceCardDark : AppColors.surfaceCardLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(icon, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
