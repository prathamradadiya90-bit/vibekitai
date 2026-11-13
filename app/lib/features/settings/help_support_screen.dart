import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/app_providers.dart';

class HelpSupportScreen extends ConsumerStatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  ConsumerState<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends ConsumerState<HelpSupportScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<Map<String, String>> _faqs = [
    {
      'category': 'Credits & Free Tier',
      'question': 'How do daily AI credits work?',
      'answer':
          'Every user receives 3 free AI credits every day at 00:00 UTC. Each credit allows you to generate context-aware replies, viral captions, or creative bios. Unused daily credits do not roll over.',
    },
    {
      'category': 'Credits & Free Tier',
      'question': 'How do I unlock bonus credits for free?',
      'answer':
          'You can watch up to 2 voluntary rewarded video ads per day to unlock +3 bonus AI credits each time (+6 extra credits daily). You can also refer friends to earn +2 bonus credits per referral!',
    },
    {
      'category': 'VibeKit Pro & Lifetime',
      'question': 'What are the benefits of VibeKit Pro & Lifetime VIP?',
      'answer':
          'Pro and Lifetime VIP members enjoy a 100% ad-free experience, watermark-free high-resolution card exports, 200 monthly AI credits, full access to all designer card templates, and priority AI edge processing.',
    },
    {
      'category': 'VibeKit Pro & Lifetime',
      'question': 'How do I manage or cancel my Google Play subscription?',
      'answer':
          'You can manage or cancel your subscription at any time via the Google Play Store app > Profile Icon > Payments & subscriptions > Subscriptions. Cancellation takes effect at the end of the current billing cycle.',
    },
    {
      'category': 'VibeKit Pro & Lifetime',
      'question': 'Can I restore my purchase on a new phone?',
      'answer':
          'Yes! Log in with the same Google Play account on your new device and tap "Restore Purchases" in Settings or on the Pro Paywall screen. Your entitlements will synchronize automatically.',
    },
    {
      'category': 'Streaks & Gamification',
      'question': 'What keeps my creative streak alive?',
      'answer':
          'Generating a reply/caption, completing a Daily Creative Challenge, or exporting a card before 00:00 UTC extends your daily streak. You also earn XP to level up your Creator Rank!',
    },
    {
      'category': 'Streaks & Gamification',
      'question': 'What is a Streak Freeze?',
      'answer':
          'A Streak Freeze automatically protects your consecutive days if you miss a day. Free users can hold up to 2 freezes, and Pro members get automatic weekly freeze refills.',
    },
    {
      'category': 'Privacy & Data Protection',
      'question': 'Are my private messages or generated cards stored on your servers?',
      'answer':
          'No! VibeKit operates under a privacy-first pseudonymous architecture. Prompts are processed ephemerally at edge nodes and immediately returned. Past creations are saved only on your local device SQLite storage.',
    },
    {
      'category': 'Privacy & Data Protection',
      'question': 'How can I permanently delete all my data?',
      'answer':
          'Navigate to Settings > Support & Data Controls > "Delete My Data". This clears your local history, cached tokens, and dispatches a permanent purge request to our server to erase your installation record.',
    },
  ];

  Future<void> _openPlaySubscriptions() async {
    final uri = Uri.parse(AppConfig.playSubscriptionsUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showFeedbackModal() {
    final controller = TextEditingController();
    bool isSending = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('Contact Support'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Need assistance or have a bug to report? Send a message directly to our engineering team.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 4,
                maxLength: 500,
                decoration: const InputDecoration(
                  hintText: 'Describe your issue or question...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSending ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSending
                  ? null
                  : () async {
                      final text = controller.text.trim();
                      if (text.length < 5) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please provide at least 5 characters.'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                        return;
                      }
                      setModalState(() => isSending = true);
                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(dialogCtx);
                      try {
                        final client = ref.read(apiClientProvider);
                        await client.sendFeedback(text);
                        navigator.pop();
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Message sent! Our team will review your report.'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      } catch (e) {
                        try {
                          setModalState(() => isSending = false);
                        } catch (_) {}
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Failed to deliver message: $e'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    },
              child: isSending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Send Message'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchQuery.toLowerCase().trim();
    final filteredFaqs = query.isEmpty
        ? _faqs
        : _faqs.where((f) {
            return f['question']!.toLowerCase().contains(query) ||
                f['answer']!.toLowerCase().contains(query) ||
                f['category']!.toLowerCase().contains(query);
          }).toList();

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text(
          'Help & Support',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search Input
            TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search answers, billing, credits...',
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primaryLight),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
            ),

            const SizedBox(height: 20),

            // Quick Support Actions Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.headset_mic_rounded,
                            color: AppColors.primaryLight, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Need Direct Help?',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Text(
                            'Our support team is ready to assist you.',
                            style: TextStyle(fontSize: 12, color: Colors.white60),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: AppColors.borderDark),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.mail_outline_rounded, size: 16),
                          label: const Text('Contact Support', style: TextStyle(fontSize: 12)),
                          onPressed: _showFeedbackModal,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryLight,
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.shop_two_rounded, size: 16),
                          label: const Text('Manage Billing', style: TextStyle(fontSize: 12)),
                          onPressed: _openPlaySubscriptions,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // FAQs List Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Frequently Asked Questions',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${filteredFaqs.length} topics',
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (filteredFaqs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.search_off_rounded, size: 48, color: Colors.white30),
                      const SizedBox(height: 10),
                      Text('No matching questions found for "$_searchQuery"',
                          style: const TextStyle(color: Colors.white60, fontSize: 13)),
                    ],
                  ),
                ),
              )
            else
              ...filteredFaqs.map((faq) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCardDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderDark),
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      title: Text(
                        faq['question']!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        faq['category']!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.primaryLight,
                        ),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                          child: Text(
                            faq['answer']!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.8),
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

            const SizedBox(height: 20),

            // Legal & Transparency Links
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Policies & Declarations',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.shield_outlined, size: 20, color: AppColors.primaryLight),
                    title: const Text('Privacy Policy'),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: () => context.push('/privacy-policy'),
                  ),
                  const Divider(height: 1, color: AppColors.borderDark),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.description_outlined, size: 20, color: AppColors.primaryLight),
                    title: const Text('Terms of Service'),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: () => context.push('/terms-of-service'),
                  ),
                  const Divider(height: 1, color: AppColors.borderDark),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.auto_awesome_outlined, size: 20, color: AppColors.primaryLight),
                    title: const Text('AI Processing & Accuracy Disclosure'),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: () => context.push('/ai-disclosure'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
