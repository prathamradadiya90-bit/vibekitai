import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../storage/preferences_service.dart';

class ReviewService {
  final PreferencesService _prefs;

  ReviewService(this._prefs);

  /// Called after a successful generation. On the 3rd generation, triggers a positive feedback dialog once.
  Future<void> checkAndPromptReview(BuildContext context) async {
    final count = await _prefs.incrementSuccessfulGenerations();
    if (count == 3 && !_prefs.hasPromptedReview()) {
      await _prefs.setPromptedReview(true);
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
            Text('✨ Loving VibeKit AI?'),
          ],
        ),
        content: const Text(
          'You just created 3 great vibes! If VibeKit is helping you express yourself, a quick 5-star review on Google Play would mean the world to our indie team.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final playUrl = Uri.parse(
                'https://play.google.com/store/apps/details?id=com.vibekit.ai',
              );
              if (await canLaunchUrl(playUrl)) {
                await launchUrl(playUrl, mode: LaunchMode.externalApplication);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C5CE7),
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
