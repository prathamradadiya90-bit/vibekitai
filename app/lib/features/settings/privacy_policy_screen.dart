import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
      ),
      body: const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'VibeKit AI Privacy Policy',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6),
              Text(
                'Effective Date: October 10, 2026',
                style:
                    TextStyle(fontSize: 12, color: AppColors.textSecondaryDark),
              ),
              Divider(height: 28, color: AppColors.borderDark),
              Text(
                '1. Overview',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6),
              Text(
                'VibeKit AI ("we", "our", or "app") is designed with a strict privacy-first architecture. We do not require account registration, email addresses, phone numbers, or social media logins to use our services.',
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
              SizedBox(height: 16),
              Text(
                '2. Information We Process',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6),
              Text(
                '• Pseudonymous Installation ID: A randomly generated UUID stored on your device to maintain daily free credit limits and prevent automated abuse.\n'
                '• Temporary AI Prompts: Text you submit in Reply Studio or Caption Lab is sent over secure TLS encryption to our edge backend and Google Gemini to generate suggestions. Prompts and responses are not permanently saved on our servers.\n'
                '• Local Data: Your creation history, favorites, and saved cards are stored solely on your local device storage.',
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
              SizedBox(height: 16),
              Text(
                '3. Third-Party Services',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6),
              Text(
                '• Google Gemini API: Processes short text prompts to generate creative replies and captions.\n'
                '• Google AdMob: Displays advertisements for free users and serves rewarded video ads.\n'
                '• Google Play In-App Billing: Processes subscription payments securely.',
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
              SizedBox(height: 16),
              Text(
                '4. Your Rights & Data Deletion',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6),
              Text(
                'You retain full control over your data. You may wipe all local history or delete your server installation record at any time via the Settings screen ("Delete My Data").',
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
              SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
