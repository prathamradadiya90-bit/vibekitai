import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../constants/app_colors.dart';
import '../storage/preferences_service.dart';

class ReviewService {
  final PreferencesService _prefs;

  ReviewService(this._prefs);

  /// Called after a successful generation. Prompts once after the 3rd generation
  /// only if the user hasn't already interacted with a review prompt within the cooldown.
  Future<void> checkAndPromptReview(BuildContext context) async {
    final count = await _prefs.incrementSuccessfulGenerations();
    if (count == 3 && !_prefs.hasPromptedReview()) {
      await _prefs.setPromptedReview(true);
      final rawPrefs = await SharedPreferences.getInstance();
      final alreadyInteracted = rawPrefs.getBool('vibekit_review_interacted') ?? false;
      final lastPromptMs = rawPrefs.getInt('vibekit_last_review_prompt_ms') ?? 0;
      const cooldownMs = 90 * 24 * 60 * 60 * 1000;
      final inCooldown = lastPromptMs > 0 &&
          (DateTime.now().millisecondsSinceEpoch - lastPromptMs) < cooldownMs;
      if (alreadyInteracted || inCooldown) return;

      await rawPrefs.setInt(
        'vibekit_last_review_prompt_ms',
        DateTime.now().millisecondsSinceEpoch,
      );
      if (context.mounted) {
        _showReviewDialog(context);
      }
    }
  }

  void _showReviewDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('✨ Enjoying ${AppConfig.appName}?'),
          ],
        ),
        content: const Text(
          'You just created 3 great vibes! If ${AppConfig.appName} is helpful, leaving an honest review on Google Play really helps our indie team.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final rawPrefs = await SharedPreferences.getInstance();
              await rawPrefs.setBool('vibekit_review_interacted', true);
              final marketUrl = Uri.parse(
                'market://details?id=${AppConfig.androidPackageId}',
              );
              final playUrl = Uri.parse(
                'https://play.google.com/store/apps/details?id=${AppConfig.androidPackageId}',
              );
              if (!kIsWeb && await canLaunchUrl(marketUrl)) {
                await launchUrl(marketUrl, mode: LaunchMode.externalApplication);
              } else if (await canLaunchUrl(playUrl)) {
                await launchUrl(playUrl, mode: LaunchMode.externalApplication);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Rate on Google Play'),
          ),
        ],
      ),
    );
  }
}
