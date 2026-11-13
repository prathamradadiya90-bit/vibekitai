import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/adaptive_banner_widget.dart';
import '../../core/widgets/app_bottom_nav.dart';
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

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _watchRewardedAd() async {
    final adMob = ref.read(adMobServiceProvider);
    final quotaNotifier = ref.read(quotaProvider.notifier);
    final apiClient = ref.read(apiClientProvider);
    final instId = ref.read(preferencesServiceProvider).getAppInstanceId();

    final nonce = await apiClient.requestAdNonce();
    final customData = jsonEncode({
      'userId': instId,
      if (nonce != null) 'nonce': nonce,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    final showed = await adMob.showRewardedAd(
      userId: instId,
      customData: customData,
      onRewardEarned: (reward) async {
        final verified = await quotaNotifier.grantRewardCredit(nonce: nonce);
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ad not ready yet. Please try again in a moment.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );

    if (!showed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ad is loading. Please try again in a moment.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                                  'VibeKit AI',
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
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                ref.read(themeModeProvider.notifier).toggleTheme();
                              },
                              icon: Icon(
                                isDark
                                    ? Icons.wb_sunny_rounded
                                    : Icons.nightlight_round,
                                color: AppColors.accent,
                                size: 20,
                              ),
                              tooltip: 'Toggle Theme',
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () => context.push('/streaks'),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: Colors.orange.withOpacity(0.4)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('🔥',
                                        style: TextStyle(fontSize: 14)),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${streak.currentStreak}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: Colors.orange),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              onPressed: () => context.push('/history'),
                              icon: Icon(
                                Icons.bookmark_border_rounded,
                                size: 20,
                                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                              ),
                              tooltip: 'Favorites & History',
                            ),
                            const SizedBox(width: 2),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              onPressed: () => context.push('/settings'),
                              icon: Icon(
                                Icons.settings_outlined,
                                size: 20,
                                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                              ),
                              tooltip: 'Settings',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // 1. Hero Daily Vibe Spark Interactive Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isDark
                          ? AppColors.accent.withOpacity(0.35)
                          : AppColors.accent.withOpacity(0.25),
                      width: 1.3,
                    ),
                    gradient: LinearGradient(
                      colors: isDark
                          ? [
                              const Color(0xFF382315),
                              const Color(0xFF1E140E),
                            ]
                          : [
                              const Color(0xFFFBF5ED),
                              const Color(0xFFF3ECE2),
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
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: AppColors.accentGradient,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.bolt_rounded, size: 13, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'DAILY VIBE SPARK',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: () => context.push('/studio'),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Text(
                                'Explore all',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? AppColors.accentWarm : AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '“Replying to ‘k’ after 6 hours of silence”',
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Generate savage, flirty, or diplomatic comeback options in 1 tap.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                context.push(
                                  '/studio?tab=reply&prompt=${Uri.encodeComponent("Replying to 'k' after 6 hours of silence")}&option=Savage',
                                );
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.local_fire_department_rounded, size: 16, color: Colors.white),
                                    SizedBox(width: 6),
                                    Text(
                                      'Spark Savage Comeback',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          InkWell(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              context.push(
                                '/studio?tab=vibe_check&prompt=${Uri.encodeComponent("k")}&option=roast',
                              );
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceElevatedLight,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                                ),
                              ),
                              child: const Icon(
                                Icons.radar_rounded,
                                size: 19,
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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
                        color: const Color(0xFFD9531E),
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
                        color: Colors.cyan,
                        badgeText: '💎 POPULAR',
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

                // Quick Vibe Shortcuts
                Text(
                  'Quick Vibe Shortcuts',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildQuickShortcut(
                        icon: '⚡',
                        label: 'Magnetic Rizz',
                        onTap: () => context.push('/studio?tab=reply&option=Rizz'),
                      ),
                      const SizedBox(width: 8),
                      _buildQuickShortcut(
                        icon: '🕵️',
                        label: 'Text Decrypter',
                        onTap: () => context.push('/studio?tab=vibe_check&option=decoder'),
                      ),
                      const SizedBox(width: 8),
                      _buildQuickShortcut(
                        icon: '🏃',
                        label: 'Cancel Plans',
                        onTap: () => context.push('/studio?tab=vibe_check&option=excuse'),
                      ),
                      const SizedBox(width: 8),
                      _buildQuickShortcut(
                        icon: '🔥',
                        label: 'Savage Roast',
                        onTap: () => context.push('/studio?tab=vibe_check&option=roast'),
                      ),
                      const SizedBox(width: 8),
                      _buildQuickShortcut(
                        icon: '💬',
                        label: 'Funny Reply',
                        onTap: () => context.push('/studio?tab=reply&option=Funny'),
                      ),
                      const SizedBox(width: 8),
                      _buildQuickShortcut(
                        icon: '💘',
                        label: 'Flirty Text',
                        onTap: () => context.push('/studio?tab=reply&option=Flirty'),
                      ),
                      const SizedBox(width: 8),
                      _buildQuickShortcut(
                        icon: '✨',
                        label: 'Reel Hook',
                        onTap: () => context.push('/studio?tab=caption&option=Trendy'),
                      ),
                      const SizedBox(width: 8),
                      _buildQuickShortcut(
                        icon: '🎨',
                        label: 'Meme Card',
                        onTap: () => context.push('/card-maker'),
                      ),
                      const SizedBox(width: 8),
                      _buildQuickShortcut(
                        icon: '👤',
                        label: 'Aesthetic Bio',
                        onTap: () => context.push('/studio?tab=bio&option=Aesthetic'),
                      ),
                      const SizedBox(width: 8),
                      _buildQuickShortcut(
                        icon: '💼',
                        label: 'Boss Mode',
                        onTap: () => context.push('/studio?tab=vibe_check&option=work'),
                      ),
                      const SizedBox(width: 8),
                      _buildQuickShortcut(
                        icon: '☕',
                        label: 'Late Apology',
                        onTap: () => context.push(
                          '/studio?tab=reply&prompt=${Uri.encodeComponent("Hey sorry running 20 mins late traffic is so crazy!")}&option=Polite',
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Daily Creator Perks & Credit Balance
                Text(
                  'Daily Creator Perks',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
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
                            OutlinedButton(
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
                        ],
                      ),
                      if (!quota.isPro && quota.canWatchRewardedAd) ...[
                        Divider(
                          height: 24,
                          color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        ),
                        InkWell(
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
                                  '${quota.rewardedAdsWatchedToday}/2',
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
                      ],
                    ],
                  ),
                ),

                const AdaptiveBannerWidget(),

                const SizedBox(height: 14),

                // Refer & Earn Promo Banner
                InkWell(
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

                const SizedBox(height: 14),

                // Creator Level & Daily Streak Pulse (Gamified Retention Card)
                InkWell(
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
                                color: Colors.orange.withOpacity(0.18),
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
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: ((streak.totalXp % 100) / 100.0).clamp(0.0, 1.0),
                                      minHeight: 6,
                                      backgroundColor: isDark
                                          ? Colors.white.withOpacity(0.08)
                                          : AppColors.borderLight,
                                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                                    ),
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
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                            if (!streak.checkedInToday)
                              InkWell(
                                onTap: () async {
                                  HapticFeedback.mediumImpact();
                                  await ref.read(streakProvider.notifier).recordAction('checkin');
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('🎉 Daily Streak checked in! +10 XP awarded!'),
                                        backgroundColor: AppColors.success,
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
                  InkWell(
                    onTap: () {
                      final c = _todaysChallenge!;
                      if (c.targetFeature == 'reply') {
                        context.push(
                            '/reply-studio?initialPrompt=${Uri.encodeComponent(c.prompt)}&initialTone=${c.tone}');
                      } else if (c.targetFeature == 'caption') {
                        context.push(
                            '/caption-lab?initialPrompt=${Uri.encodeComponent(c.prompt)}&initialTone=${c.tone}');
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
                  const SizedBox(height: 24),
                ],

                // Recent Creations Section
                if (_recentCreations.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Creations',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () => context.push('/history'),
                        child: const Text('View All',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 125,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _recentCreations.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final item = _recentCreations[index];
                        return InkWell(
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
                                                  : Icons.brush_outlined,
                                      size: 14,
                                      color: item.type == 'bio' ? Colors.cyan : AppColors.primaryLight,
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

    return InkWell(
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
    );
  }

  Widget _buildQuickShortcut({
    required String icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return InkWell(
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
        );
      },
    );
  }
}
