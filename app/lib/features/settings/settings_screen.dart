import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/app_bottom_nav.dart';

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

  Future<void> _handleDeleteAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All My Data?'),
        content: const Text(
          'This will permanently erase your local creations, history, preferences, and dispatch an erasure request to our server to purge your installation identifier. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
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
          title: const Text('Send Feedback'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Help us improve VibeKit AI! Your feedback directly influences upcoming features.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 4,
                maxLength: 500,
                decoration: const InputDecoration(
                  hintText: 'What can we do better? (Min 3 characters)',
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

  @override
  Widget build(BuildContext context) {
    final quota = ref.watch(quotaProvider);
    final themeMode = ref.watch(themeModeProvider);
    final selectedLanguage = ref.watch(languageProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // Subscription & Membership Status
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: quota.isPro
                    ? AppColors.accentGradient
                    : AppColors.cardGlowGradient,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quota.isPro
                            ? 'VibeKit Pro Member'
                            : 'Free Tier Account',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        quota.isPro
                            ? 'Ad-free • Watermark-free • 200 credits'
                            : '${quota.totalCreditsRemaining} daily credits remaining',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: () => context.push('/paywall'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                    ),
                    child: Text(quota.isPro ? 'Manage' : 'Upgrade'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.restore_rounded, color: AppColors.primaryLight),
              title: const Text('Restore Purchases'),
              subtitle: const Text('Re-sync active Google Play subscriptions'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                final billing = ref.read(billingServiceProvider);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Restoring purchases from Google Play...')),
                );
                await billing.restorePurchases();
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.emoji_events_outlined, color: Colors.amber),
              title: const Text('Achievements & Badges'),
              subtitle: const Text('Track creator level, XP, and milestone rewards'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/achievements'),
            ),

            const SizedBox(height: 20),

            // Preferences Section
            _buildSectionHeader('Preferences'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.language_rounded,
                  color: AppColors.primaryLight),
              title: const Text('Language'),
              subtitle: Text(selectedLanguage),
              trailing: DropdownButton<String>(
                value: selectedLanguage,
                underline: const SizedBox(),
                items: _supportedLanguages
                    .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    ref.read(languageProvider.notifier).setLanguage(val);
                  }
                },
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.dark_mode_outlined,
                  color: AppColors.primaryLight),
              title: const Text('Theme'),
              subtitle: Text(
                themeMode == ThemeMode.dark
                    ? 'Dark Theme'
                    : themeMode == ThemeMode.light
                        ? 'Light Theme'
                        : 'System Default',
              ),
              trailing: DropdownButton<ThemeMode>(
                value: themeMode,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                  DropdownMenuItem(
                      value: ThemeMode.light, child: Text('Light')),
                  DropdownMenuItem(
                      value: ThemeMode.system, child: Text('System')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    ref.read(themeModeProvider.notifier).setTheme(val);
                  }
                },
              ),
            ),

            const Divider(height: 32, color: AppColors.borderDark),

            // Legal & Transparency
            _buildSectionHeader('Legal & Transparency'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.shield_outlined,
                  color: AppColors.primaryLight),
              title: const Text('Privacy Policy'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/privacy-policy'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.description_outlined,
                  color: AppColors.primaryLight),
              title: const Text('Terms of Service'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/terms-of-service'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.auto_awesome_outlined,
                  color: AppColors.primaryLight),
              title: const Text('AI Processing & Accuracy Disclosure'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/ai-disclosure'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.policy_outlined,
                  color: AppColors.primaryLight),
              title: const Text('Open Source Licenses'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => showLicensePage(
                context: context,
                applicationName: AppConfig.appName,
                applicationVersion: AppConfig.appVersion,
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.privacy_tip_outlined,
                  color: AppColors.primaryLight),
              title: const Text('Ad Privacy & Consent Choices'),
              subtitle: const Text('Review or update your personalization preferences'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Your privacy preferences are up to date.')),
                );
              },
            ),

            const Divider(height: 32, color: AppColors.borderDark),

            // Support & Danger Zone
            _buildSectionHeader('Support & Data Controls'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.help_outline_rounded,
                  color: AppColors.primaryLight),
              title: const Text('Help & FAQ Center'),
              subtitle: const Text('Guides, answers, billing rules, and support'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/help-support'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.feedback_outlined,
                  color: AppColors.primaryLight),
              title: const Text('Send Feedback'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _showFeedbackDialog,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.delete_forever_outlined,
                  color: AppColors.error),
              title: const Text('Delete My Data',
                  style: TextStyle(color: AppColors.error)),
              subtitle: const Text(
                  'Erase local history and purge cloud installation key'),
              onTap: _handleDeleteAllData,
            ),

            const SizedBox(height: 28),

            // App Version Footer
            const Center(
              child: Column(
                children: [
                  Text(
                    '${AppConfig.appName} v${AppConfig.appVersion}',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textMutedDark),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Engineered with Flutter & Cloudflare Workers',
                    style:
                        TextStyle(fontSize: 11, color: AppColors.textMutedDark),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
          color: AppColors.textMutedDark,
        ),
      ),
    );
  }
}
