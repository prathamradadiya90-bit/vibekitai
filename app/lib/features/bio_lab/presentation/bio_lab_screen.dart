import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/language_picker.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/quota_badge.dart';
import '../../../core/widgets/result_card.dart';
import '../../../core/widgets/tone_chips.dart';
import '../../../models/generation_models.dart';
import '../../../models/history_item.dart';
import '../../../core/services/achievement_service.dart';
import '../../streaks/providers/streak_provider.dart';

class BioLabScreen extends ConsumerStatefulWidget {
  const BioLabScreen({super.key});

  @override
  ConsumerState<BioLabScreen> createState() => _BioLabScreenState();
}

class _BioLabScreenState extends ConsumerState<BioLabScreen> {
  final TextEditingController _interestsController = TextEditingController();
  final int _maxChars = 300;

  String _selectedPlatform = 'Instagram';
  String _selectedVibe = 'Aesthetic';
  String _selectedLanguage = 'English';
  bool _includeUsernames = true;

  static const List<String> _platforms = [
    'Instagram',
    'WhatsApp',
    'LinkedIn',
    'Twitter/X',
    'General Profile',
  ];

  static const List<String> _vibes = [
    'Aesthetic',
    'Witty',
    'Professional',
    'Minimalist',
    'Creative',
    'Bold',
  ];

  static const List<String> _languages = [
    'English',
    'Hindi',
    'Hinglish',
    'Gujarati',
  ];

  @override
  void dispose() {
    _interestsController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final interests = _interestsController.text.trim();
    if (interests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please describe your interests or profession.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final req = BioRequest(
      interests: interests,
      platform: _selectedPlatform,
      vibe: _selectedVibe,
      language: _selectedLanguage,
      includeUsernames: _includeUsernames,
    );

    final success = await ref.read(bioGenerationProvider.notifier).execute(
      request: req,
      caller: () => ref.read(apiClientProvider).generateBio(req),
      getCreditsRemaining: (res) => res.creditsRemaining,
      buildHistoryItems: (res) {
        final items = <HistoryItem>[];
        for (final bio in res.bios) {
          items.add(
            HistoryItem(
              id: const Uuid().v4(),
              title: 'Bio: $_selectedPlatform • $_selectedVibe',
              content: bio,
              type: 'bio',
              category: _selectedPlatform,
              createdAt: DateTime.now(),
            ),
          );
        }
        return items;
      },
      actionType: 'bio',
    );

    if (mounted) {
      final genState = ref.read(bioGenerationProvider);
      if (genState.isQuotaExceeded) {
        context.push('/paywall');
      } else if (success) {
        HapticFeedback.lightImpact();
        ref.read(streakProvider.notifier).recordAction('generate');
        final prefs = ref.read(preferencesServiceProvider);
        await prefs.recordToneUsed(_selectedVibe);
        await prefs.recordLanguageUsed(_selectedLanguage);
        if (mounted) {
          ref.read(reviewServiceProvider).checkAndPromptReview(context);
          await ref.read(achievementServiceProvider).checkAndUnlockAchievements(context: context);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final genState = ref.watch(bioGenerationProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.surfaceCardDark : AppColors.surfaceCardLight;
    final borderCol = isDark ? AppColors.borderDark : AppColors.borderLight;
    final textCol = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecCol = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final dropdownBg = isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceCardLight;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Bio & Username Lab',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: AppSpacing.md),
            child: Center(child: QuotaBadge()),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: AppSpacing.paddingScreen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Description Field
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: AppSpacing.roundedMd,
                border: Border.all(color: borderCol),
              ),
              padding: AppSpacing.paddingMd,
              child: Column(
                children: [
                  TextField(
                    controller: _interestsController,
                    maxLines: 3,
                    maxLength: _maxChars,
                    style: TextStyle(color: textCol, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Describe yourself, interests, role (e.g. Flutter dev, coffee enthusiast, traveler)...',
                      hintStyle: TextStyle(color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                      border: InputBorder.none,
                      counterStyle: TextStyle(color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 2. Platform Selector
            Text(
              'Target Profile',
              style: TextStyle(
                color: textSecCol,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 2),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: AppSpacing.roundedMd,
                border: Border.all(color: borderCol),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedPlatform,
                  isExpanded: true,
                  dropdownColor: dropdownBg,
                  icon: Icon(Icons.arrow_drop_down, color: textSecCol),
                  items: _platforms.map((p) {
                    return DropdownMenuItem<String>(
                      value: p,
                      child: Text(
                        p,
                        style: TextStyle(color: textCol, fontSize: 14),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedPlatform = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 3. Vibe Selector
            Text(
              'Profile Vibe',
              style: TextStyle(
                color: textSecCol,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ToneChips(
              tones: _vibes,
              selectedTone: _selectedVibe,
              onSelected: (vibe) => setState(() => _selectedVibe = vibe),
            ),
            const SizedBox(height: AppSpacing.md),

            // 4. Language Selector
            Text(
              'Language',
              style: TextStyle(
                color: textSecCol,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            LanguagePicker(
              languages: _languages,
              selectedLanguage: _selectedLanguage,
              onChanged: (lang) => setState(() => _selectedLanguage = lang),
            ),
            const SizedBox(height: AppSpacing.md),

            // 5. Usernames Checkbox
            InkWell(
              onTap: () => setState(() => _includeUsernames = !_includeUsernames),
              borderRadius: BorderRadius.circular(8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: _includeUsernames,
                    onChanged: (val) => setState(() => _includeUsernames = val ?? true),
                    activeColor: AppColors.primary,
                  ),
                  Text(
                    'Include Handle / Username Ideas',
                    style: TextStyle(color: textCol, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 6. Generate Button
            PrimaryButton(
              label: 'Generate Bios & Handles',
              icon: Icons.auto_awesome,
              isLoading: genState.isGenerating,
              onPressed: _generate,
            ),
            const SizedBox(height: AppSpacing.lg),

            // 7. Error View
            if (genState.errorMessage != null) ...[
              ErrorView(
                message: genState.errorMessage!,
                onRetry: _generate,
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // 8. Loading Shimmers
            if (genState.isGenerating) ...[
              const LoadingShimmer(height: 100),
              const SizedBox(height: AppSpacing.md),
              const LoadingShimmer(height: 100),
            ],

            // 9. Results
            if (genState.result != null && !genState.isGenerating) ...[
              Text(
                'Bio Suggestions',
                style: TextStyle(
                  color: textCol,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ...genState.result!.bios.map(
                (bio) => ResultCard(
                  content: bio,
                  category: '$_selectedPlatform Bio',
                ),
              ),

              if (genState.result!.usernames.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Username & Handle Ideas',
                  style: TextStyle(
                    color: textCol,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: genState.result!.usernames.map(
                    (username) => Chip(
                      label: Text(username),
                      backgroundColor: cardBg,
                      side: BorderSide(color: borderCol),
                      labelStyle: TextStyle(
                        color: isDark ? AppColors.accentWarm : AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ).toList(),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
