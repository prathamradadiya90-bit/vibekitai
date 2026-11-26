import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedCol =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final borderCol = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Service'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ReplyVibe AI (VibeKit AI) Terms of Service',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Last Updated: November 15, 2026',
                style: TextStyle(fontSize: 12, color: mutedCol),
              ),
              Divider(height: 28, color: borderCol),
              const Text(
                '1. Acceptance of Terms',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'By downloading, accessing, or using ReplyVibe AI / VibeKit AI, you agree to be bound by these Terms. If you do not agree, do not use the application.',
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 16),
              const Text(
                '2. Acceptable Use',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'You agree not to use ReplyVibe AI / VibeKit AI to generate hate speech, threats, targeted harassment, sexually explicit materials, child sexual abuse material, deceptive impersonation, fraud, or illegal content. You remain solely responsible for any content you copy, post, or publish to third-party platforms.',
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 16),
              const Text(
                '3. AI Disclaimer & Content Accuracy',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Content generated in the app is created using artificial intelligence. Outputs may occasionally be inaccurate, humorous, or inappropriate for specific real-world contexts. We do not guarantee engagement, followers, views, or business outcomes.',
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 16),
              const Text(
                '4. Subscriptions, One-Time Passes & Support',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Pro subscriptions (auto-renewing) and one-time passes are billed through Google Play in accordance with Google Play Billing terms. You may cancel subscriptions anytime via your Google Play account settings. Support inquiries: support@vibekit.ai.',
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
