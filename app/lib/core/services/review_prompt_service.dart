import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../constants/app_colors.dart';
import 'analytics_service.dart';

/// Privacy-Preserving In-App Review Prompt Service.
///
/// Follows ADR 0007:
/// - Only prompts at positive delight moments (2nd generation or Day 3 streak).
/// - 90-day cooldown between prompts.
/// - Never gates reviews behind fake feedback forms.
class ReviewPromptService {
  static const String _kKeyTotalGenerations = 'vibekit_total_successful_gens';
  static const String _kKeyLastPromptTime = 'vibekit_last_review_prompt_ms';
  static const String _kKeyHasInteracted = 'vibekit_review_interacted';
  static const int _kCooldownDays = 90;

  static ReviewPromptService? _instance;
  static ReviewPromptService get instance => _instance ??= ReviewPromptService._();
  ReviewPromptService._();

  /// Increments successful generation counter and checks if review should be prompted.
  Future<void> onGenerationCompleted(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt(_kKeyTotalGenerations) ?? 0) + 1;
    await prefs.setInt(_kKeyTotalGenerations, count);

    // Prompt specifically on the 2nd successful generation
    if (count == 2) {
      final shouldPrompt = await _canPrompt(prefs);
      if (shouldPrompt && context.mounted) {
        // Small delay so user sees their output first
        await Future.delayed(const Duration(milliseconds: 600));
        if (context.mounted) {
          await showReviewDialog(context, source: '2nd_generation');
        }
      }
    }
  }

  /// Called when user claims a streak milestone (e.g. Day 3 or Day 7).
  Future<void> onStreakMilestoneClaimed(BuildContext context, int day) async {
    if (day < 3) return;
    final prefs = await SharedPreferences.getInstance();
    final shouldPrompt = await _canPrompt(prefs);
    if (shouldPrompt && context.mounted) {
      await showReviewDialog(context, source: 'streak_day_$day');
    }
  }

  Future<bool> _canPrompt(SharedPreferences prefs) async {
    final hasInteracted = prefs.getBool(_kKeyHasInteracted) ?? false;
    if (hasInteracted) return false;

    final lastPromptMs = prefs.getInt(_kKeyLastPromptTime) ?? 0;
    if (lastPromptMs > 0) {
      final elapsed = DateTime.now().millisecondsSinceEpoch - lastPromptMs;
      const cooldownMs = _kCooldownDays * 24 * 60 * 60 * 1000;
      if (elapsed < cooldownMs) return false;
    }

    return true;
  }

  /// Displays the review prompt modal.
  Future<void> showReviewDialog(BuildContext context, {required String source}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kKeyLastPromptTime, DateTime.now().millisecondsSinceEpoch);

    AnalyticsService.instance.logEvent('in_app_review_prompt_shown', parameters: {'source': source});

    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final sheetBg = isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceLight;
        final borderCol = isDark ? AppColors.borderDark : AppColors.borderLight;
        final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
        final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

        return Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: borderCol),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  gradient: AppColors.accentGradient,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('⭐', style: TextStyle(fontSize: 32)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Enjoying VibeKit AI?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Your honest review on Google Play helps fellow creators find the best AI captions and replies!',
                style: TextStyle(
                  fontSize: 14,
                  color: textSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textSecondary,
                        side: BorderSide(color: borderCol),
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        AnalyticsService.instance.logEvent('in_app_review_dismissed');
                        Navigator.of(ctx).pop();
                      },
                      child: const Text('Maybe Later'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        await prefs.setBool(_kKeyHasInteracted, true);
                        AnalyticsService.instance.logEvent('in_app_review_accepted');
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        await _launchPlayStore();
                      },
                      child: const Text('Rate on Google Play', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Future<void> _launchPlayStore() async {
    const marketUrl = 'market://details?id=${AppConfig.androidPackageId}';
    const webUrl = 'https://play.google.com/store/apps/details?id=${AppConfig.androidPackageId}';

    final marketUri = Uri.parse(marketUrl);
    final webUri = Uri.parse(webUrl);

    try {
      if (!kIsWeb && await canLaunchUrl(marketUri)) {
        await launchUrl(marketUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // Graceful fallback if no browser or market handler
    }
  }
}
