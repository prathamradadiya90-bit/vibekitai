import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedCol =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final borderCol = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ReplyVibe AI (VibeKit AI) Privacy Policy',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Effective Date: November 15, 2026',
                style: TextStyle(fontSize: 12, color: mutedCol),
              ),
              Divider(height: 28, color: borderCol),
              const Text(
                '1. Overview',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'ReplyVibe AI / VibeKit AI ("we", "our", or "app") is designed with a privacy-first architecture. We do not require account registration, email addresses, phone numbers, or social media logins.',
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 16),
              const Text(
                '2. Information We Process',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                '• Pseudonymous Installation ID: A random UUID stored locally on your device to manage daily credits, streaks, referral bonuses, subscriptions, and abuse prevention.\n'
                '• AI Input & Retry Cache: Text prompts submitted to Studio features are sent via TLS encryption to Google Gemini (and configured AI fallback providers). We do not store personal chat logs; temporary idempotency retry responses expire and are purged automatically within 24 hours. Anonymized non-text telemetry (category, tone, latency, status) and voluntary feedback/content reports are recorded for service reliability and safety moderation.\n'
                '• Local Storage: Your saved creations, favorites, and exported cards stay locally on your device.\n'
                '• Advertising & Billing: Free-tier ads use Google AdMob (which may process Advertising ID and Server-Side Verification tokens). In-app purchases are handled via Google Play Billing.',
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 16),
              const Text(
                '3. Third-Party Services',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                '• Google Gemini & AI Inference Providers: Process short user prompts to generate replies, captions, bios, and vibe checks.\n'
                '• Google AdMob: Displays banner and optional rewarded ads to free users.\n'
                '• Google Play Billing & Play Integrity: Processes purchases, subscription status, and device integrity checks.',
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 16),
              const Text(
                '4. Your Rights, Data Deletion & Contact',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'You can clear all local history and immediately delete all associated cloud installation, streak, feedback, and usage records anytime via Settings -> "Delete My Data", or by emailing privacy@vibekit.ai.',
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
