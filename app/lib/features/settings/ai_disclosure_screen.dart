import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class AiDisclosureScreen extends StatelessWidget {
  const AiDisclosureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedCol =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final borderCol = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI & Safety Disclosure'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AI Processing & Safety Disclosures',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'How AI works inside ReplyVibe AI / VibeKit AI',
                style: TextStyle(fontSize: 12, color: mutedCol),
              ),
              Divider(height: 28, color: borderCol),
              const Text(
                '1. Generative AI Technology',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'ReplyVibe AI (VibeKit AI) utilizes Large Language Models (Google Gemini and configured reliability fallbacks) to analyze your inputs and propose creative replies, captions, bios, and vibe checks.',
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 16),
              const Text(
                '2. Accuracy & Hallucinations',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'AI models generate synthetic text probabilistically. As a result, suggestions may contain factual inaccuracies, unintended tones, or contextual misinterpretations. Always review and edit suggested replies or captions before sending them to colleagues, friends, or posting them online.',
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 16),
              const Text(
                '3. Safety Filters & Moderation',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'To maintain a safe environment, our backend applies automated content safety filters that block harmful, harassing, discriminatory, sexually explicit, and abusive content. Requests that violate safety policies will be declined automatically.',
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 16),
              const Text(
                '4. Confidentiality & Privacy Warning',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Never paste confidential credentials, banking information, passwords, secret keys, or private medical details into the app. Prompts are transmitted for processing and should not contain sensitive personal identifiers.',
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 16),
              const Text(
                '5. In-App Reporting & Moderation',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'In full compliance with Google Play Generative AI policies, every generated suggestion card includes an in-app flag/report button. If you encounter any output that is offensive, harmful, sexually explicit, or misleading, tap the flag icon to report it immediately. Reports directly inform our continuous safety filtering.',
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
