import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/share_service.dart';
import '../../core/widgets/app_bottom_nav.dart';
import '../streaks/providers/streak_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final List<String> _supportedLanguages = [
    'English',
    'Hindi',
    'Hinglish',
    'Gujarati',
  ];

  int _versionTapCount = 0;
  bool _developerModeUnlocked = false;

  void _onVersionTapped() {
    setState(() {
      _versionTapCount++;
      if (_versionTapCount >= 7 && !_developerModeUnlocked) {
        _developerModeUnlocked = true;
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🛠️ Developer Options Unlocked!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  Future<void> _handleDeleteAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete All Data & History?'),
        content: const Text(
          'This will permanently erase your local creations, favorites, history, cached credits, and submit a data erasure request to our server. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final client = ref.read(apiClientProvider);
        await client.deleteUserData();
      } catch (_) {
        // Continue even if network is offline
      }

      final db = ref.read(localDatabaseProvider);
      await db.clearAll();

      final prefs = ref.read(preferencesServiceProvider);
      await prefs.clearAll();

      ref.read(quotaProvider.notifier).reset();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data successfully deleted.')),
        );
        context.go('/onboarding');
      }
    }
  }

  void _showFeedbackDialog() {
    final controller = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Send Feedback'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'We read every piece of feedback to make ReplyVibe AI better for you!',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 4,
                maxLength: 500,
                decoration: const InputDecoration(
                  hintText: 'What can we improve or add next? (Min 3 characters)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final message = controller.text.trim();
                      if (message.length < 3) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(
                            content: Text('Feedback must be at least 3 characters long.'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isSubmitting = true);
                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(dialogContext);

                      try {
                        final client = ref.read(apiClientProvider);
                        await client.sendFeedback(message);
                        navigator.pop();
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Thank you! Your feedback has been received.'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      } catch (e) {
                        try {
                          setDialogState(() => isSubmitting = false);
                        } catch (_) {}
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Failed to submit feedback: $e'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Submit'),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      controller.dispose();
    });
  }

  void _showThemePickerModal(ThemeMode currentTheme, bool isDark) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: context.surfaceCard,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose App Theme',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 14),
                _buildThemeOption(
                  title: 'Dark Theme',
                  subtitle: 'Velvet roasted espresso & glowing accents',
                  icon: Icons.nightlight_round,
                  isSelected: currentTheme == ThemeMode.dark,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(themeModeProvider.notifier).setTheme(ThemeMode.dark);
                    Navigator.pop(context);
                  },
                ),
                _buildThemeOption(
                  title: 'Light Theme',
                  subtitle: 'Silky warm oat latte & clean cream',
                  icon: Icons.wb_sunny_rounded,
                  isSelected: currentTheme == ThemeMode.light,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(themeModeProvider.notifier).setTheme(ThemeMode.light);
                    Navigator.pop(context);
                  },
                ),
                _buildThemeOption(
                  title: 'System Default',
                  subtitle: 'Match your device operating system setting',
                  icon: Icons.brightness_auto_rounded,
                  isSelected: currentTheme == ThemeMode.system,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(themeModeProvider.notifier).setTheme(ThemeMode.system);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildThemeOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : AppColors.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }

  void _showLanguagePickerModal(String currentLanguage, bool isDark) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: context.surfaceCard,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose Primary Language',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 14),
                ..._supportedLanguages.map((lang) {
                  final isSelected = lang == currentLanguage;
                  return InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref.read(languageProvider.notifier).setLanguage(lang);
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            lang,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? AppColors.primary : null,
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showServerEndpointDialog() {
    final prefs = ref.read(preferencesServiceProvider);
    final current = prefs.getCustomApiUrl() ?? ref.read(apiClientProvider).baseUrl;
    final controller = TextEditingController(text: current);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Developer Server Endpoint'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Custom API backend URL for development & testing.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'https://replyvibe-api.vercel.app',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await prefs.setCustomApiUrl(null);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              setState(() {});
            },
            child: const Text('Reset Default'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newUrl = controller.text.trim();
              if (newUrl.isNotEmpty) {
                await prefs.setCustomApiUrl(newUrl);
              }
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              setState(() {});
            },
            child: const Text('Save & Apply'),
          ),
        ],
      ),
    ).whenComplete(() {
      controller.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final quota = ref.watch(quotaProvider);
    final themeMode = ref.watch(themeModeProvider);
    final selectedLanguage = ref.watch(languageProvider);
    final streak = ref.watch(streakProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderCol = isDark ? AppColors.borderDark : AppColors.borderLight;
    final mutedTextCol = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: const Text('Account & Settings'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          children: [
            // 1. Hero Membership / Account Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: quota.isPro
                    ? const LinearGradient(
                        colors: [Color(0xFF8B5A36), Color(0xFF472814)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF2B1D15), const Color(0xFF19110B)]
                            : [const Color(0xFFFFFFFF), const Color(0xFFF7F2EB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: quota.isPro ? AppColors.accent : borderCol,
                  width: quota.isPro ? 1.5 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Avatar Badge
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: quota.isPro
                                ? [AppColors.accent, AppColors.primary]
                                : [AppColors.primary, AppColors.secondary],
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            quota.isPro ? Icons.star_rounded : Icons.person_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  quota.isPro ? 'VibeKit Pro' : 'Free Member',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: quota.isPro ? Colors.white : (isDark ? Colors.white : AppColors.textPrimaryLight),
                                  ),
                                ),
                                if (quota.isPro) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.accent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'PRO',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              quota.isPro
                                  ? 'Unlimited generations • Watermark-free'
                                  : '${quota.totalCreditsRemaining} credits left today • Resets midnight',
                              style: TextStyle(
                                fontSize: 12,
                                color: quota.isPro ? Colors.white70 : mutedTextCol,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          context.push('/paywall');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: quota.isPro ? Colors.white : AppColors.primary,
                          foregroundColor: quota.isPro ? AppColors.primary : Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          quota.isPro ? 'Plan' : 'Upgrade',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Divider(
                    color: quota.isPro ? Colors.white24 : borderCol,
                    height: 1,
                  ),
                  const SizedBox(height: 12),
                  // Stats Sub-bar (Streak & Credits)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      InkWell(
                        onTap: () => context.push('/streaks'),
                        child: Row(
                          children: [
                            const Text('🔥', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 6),
                            Text(
                              '${streak.currentStreak} Day Streak',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: quota.isPro ? Colors.white : (isDark ? Colors.white : AppColors.textPrimaryLight),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 16,
                        color: quota.isPro ? Colors.white24 : borderCol,
                      ),
                      InkWell(
                        onTap: () => context.push('/achievements'),
                        child: Row(
                          children: [
                            const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Badges & XP',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: quota.isPro ? Colors.white : (isDark ? Colors.white : AppColors.textPrimaryLight),
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

            const SizedBox(height: 22),

            // 2. Preferences Group Card
            _buildSectionLabel('Preferences', isDark),
            _buildSettingsGroup(
              isDark: isDark,
              borderCol: borderCol,
              children: [
                _buildSettingTile(
                  icon: Icons.palette_outlined,
                  iconColor: const Color(0xFF8B5A36),
                  title: 'App Theme',
                  subtitle: themeMode == ThemeMode.dark
                      ? 'Dark Theme'
                      : themeMode == ThemeMode.light
                          ? 'Light Theme'
                          : 'System Default',
                  trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                  onTap: () => _showThemePickerModal(themeMode, isDark),
                ),
                _buildDivider(borderCol),
                _buildSettingTile(
                  icon: Icons.language_rounded,
                  iconColor: const Color(0xFF2E7D32),
                  title: 'Primary Language',
                  subtitle: selectedLanguage,
                  trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                  onTap: () => _showLanguagePickerModal(selectedLanguage, isDark),
                ),
                _buildDivider(borderCol),
                _buildSettingTile(
                  icon: Icons.restore_rounded,
                  iconColor: const Color(0xFF0284C7),
                  title: 'Restore Purchases',
                  subtitle: 'Sync previous Google Play Pro subscription',
                  trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    final billing = ref.read(billingServiceProvider);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Checking Google Play for active subscriptions...')),
                    );
                    await billing.restorePurchases();
                  },
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 3. Support & Community Group Card
            _buildSectionLabel('Support & Community', isDark),
            _buildSettingsGroup(
              isDark: isDark,
              borderCol: borderCol,
              children: [
                _buildSettingTile(
                  icon: Icons.share_rounded,
                  iconColor: const Color(0xFFD97706),
                  title: 'Share with Friends',
                  subtitle: 'Spread the vibe & earn streak bonuses',
                  trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    final instId = ref.read(preferencesServiceProvider).getAppInstanceId();
                    final link = ShareService.buildReferralLink(instId);
                    ShareService.shareText(
                      'I use ReplyVibe AI to craft witty replies and fire captions in seconds! Try it free: $link',
                    );
                  },
                ),
                _buildDivider(borderCol),
                _buildSettingTile(
                  icon: Icons.help_outline_rounded,
                  iconColor: const Color(0xFF7C3AED),
                  title: 'Help & FAQ Center',
                  subtitle: 'Usage guides, billing questions, and tips',
                  trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                  onTap: () => context.push('/help-support'),
                ),
                _buildDivider(borderCol),
                _buildSettingTile(
                  icon: Icons.chat_bubble_outline_rounded,
                  iconColor: const Color(0xFF059669),
                  title: 'Send Feedback',
                  subtitle: 'Request a feature or report an issue',
                  trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                  onTap: _showFeedbackDialog,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 4. Privacy & Data Controls Group Card
            _buildSectionLabel('Privacy & Legal', isDark),
            _buildSettingsGroup(
              isDark: isDark,
              borderCol: borderCol,
              children: [
                _buildSettingTile(
                  icon: Icons.shield_outlined,
                  iconColor: const Color(0xFF475569),
                  title: 'Privacy Policy',
                  trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                  onTap: () => context.push('/privacy-policy'),
                ),
                _buildDivider(borderCol),
                _buildSettingTile(
                  icon: Icons.description_outlined,
                  iconColor: const Color(0xFF475569),
                  title: 'Terms of Service',
                  trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                  onTap: () => context.push('/terms-of-service'),
                ),
                _buildDivider(borderCol),
                _buildSettingTile(
                  icon: Icons.auto_awesome_outlined,
                  iconColor: const Color(0xFF475569),
                  title: 'AI Processing Disclosure',
                  trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                  onTap: () => context.push('/ai-disclosure'),
                ),
                _buildDivider(borderCol),
                _buildSettingTile(
                  icon: Icons.policy_outlined,
                  iconColor: const Color(0xFF475569),
                  title: 'Open Source Licenses',
                  trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: AppConfig.appName,
                    applicationVersion: AppConfig.appVersion,
                  ),
                ),
                _buildDivider(borderCol),
                _buildSettingTile(
                  icon: Icons.delete_outline_rounded,
                  iconColor: AppColors.error,
                  title: 'Delete My Data',
                  titleColor: AppColors.error,
                  subtitle: 'Clear all local history and erase server install key',
                  onTap: _handleDeleteAllData,
                ),
              ],
            ),

            // 5. Developer Options (Hidden Easter Egg, unlocked with 7 taps)
            if (_developerModeUnlocked) ...[
              const SizedBox(height: 20),
              _buildSectionLabel('Developer Options (Debug)', isDark),
              _buildSettingsGroup(
                isDark: isDark,
                borderCol: borderCol,
                children: [
                  _buildSettingTile(
                    icon: Icons.developer_mode_rounded,
                    iconColor: Colors.amber,
                    title: 'API Server Endpoint',
                    subtitle: ref.watch(apiClientProvider).baseUrl,
                    trailing: const Icon(Icons.edit_outlined, size: 18),
                    onTap: _showServerEndpointDialog,
                  ),
                ],
              ),
            ],

            const SizedBox(height: 28),

            // 6. Clean App Footer
            GestureDetector(
              key: const Key('version_footer_gesture'),
              behavior: HitTestBehavior.opaque,
              onTap: _onVersionTapped,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    Text(
                      '${AppConfig.appName} v${AppConfig.appVersion}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: mutedTextCol,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Crafted with ❤️ for creators',
                      style: TextStyle(
                        fontSize: 11,
                        color: mutedTextCol,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
    );
  }

  Widget _buildSectionLabel(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
        ),
      ),
    );
  }

  Widget _buildSettingsGroup({
    required bool isDark,
    required Color borderCol,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceCardDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Color? titleColor,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(icon, color: iconColor, size: 18),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(Color color) {
    return Divider(
      height: 1,
      thickness: 0.8,
      indent: 64,
      endIndent: 16,
      color: color.withValues(alpha: 0.5),
    );
  }
}
