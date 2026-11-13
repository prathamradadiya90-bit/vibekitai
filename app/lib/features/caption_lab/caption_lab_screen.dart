import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/app_bottom_nav.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/language_picker.dart';
import '../../core/widgets/loading_shimmer.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/quota_badge.dart';
import '../../core/widgets/result_card.dart';
import '../../core/widgets/tone_chips.dart';
import '../../models/generation_models.dart';
import '../../models/history_item.dart';
import '../../core/services/achievement_service.dart';

class CaptionLabScreen extends ConsumerStatefulWidget {
  final String? initialPrompt;
  final String? initialTone;

  const CaptionLabScreen({
    super.key,
    this.initialPrompt,
    this.initialTone,
  });

  @override
  ConsumerState<CaptionLabScreen> createState() => _CaptionLabScreenState();
}

class _CaptionLabScreenState extends ConsumerState<CaptionLabScreen> {
  final TextEditingController _topicController = TextEditingController();
  final int _maxChars = 400;

  String _selectedPlatform = 'Instagram Reels';
  String _selectedTone = 'Trendy';
  String _selectedLanguage = 'English';
  String _selectedLength = 'medium';
  bool _includeHooks = true;
  bool _includeHashtags = true;

  static const List<String> _platforms = [
    'Instagram Reels',
    'Instagram Post',
    'WhatsApp Status',
    'YouTube Shorts',
    'General Social Media',
  ];

  static const List<String> _tones = [
    'Trendy',
    'Witty',
    'Aesthetic',
    'Confident',
    'Professional',
    'Inspirational',
    'Humorous',
  ];

  static const List<String> _languages = [
    'English',
    'Hindi',
    'Hinglish',
    'Gujarati',
  ];

  static const List<Map<String, String>> _lengths = [
    {'id': 'short', 'label': 'Punchy'},
    {'id': 'medium', 'label': 'Standard'},
    {'id': 'detailed', 'label': 'Story/Long'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialPrompt != null) {
      _topicController.text = widget.initialPrompt!;
    }
    if (widget.initialTone != null && _tones.contains(widget.initialTone)) {
      _selectedTone = widget.initialTone!;
    }
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _generateCaptions() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please describe your photo, video, or topic.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final request = CaptionRequest(
      topic: topic,
      platform: _selectedPlatform,
      tone: _selectedTone,
      language: _selectedLanguage,
      length: _selectedLength,
      includeHooks: _includeHooks,
      includeHashtags: _includeHashtags,
    );

    final success = await ref.read(captionGenerationProvider.notifier).execute(
      request: request,
      caller: () => ref.read(apiClientProvider).generateCaption(request),
      getCreditsRemaining: (res) => res.creditsRemaining,
      buildHistoryItems: (res) {
        final items = <HistoryItem>[];
        if (res.captions.isNotEmpty) {
          items.add(
            HistoryItem(
              id: const Uuid().v4(),
              title: topic.length > 40 ? '${topic.substring(0, 40)}...' : topic,
              content: res.captions.first,
              type: 'caption',
              category: '$_selectedPlatform • $_selectedTone',
              createdAt: DateTime.now(),
            ),
          );
        }
        return items;
      },
      actionType: 'caption',
    );

    if (mounted) {
      final genState = ref.read(captionGenerationProvider);
      if (genState.isQuotaExceeded) {
        _showOutOfCreditsDialog();
      } else if (success) {
        HapticFeedback.lightImpact();
        ref.read(reviewServiceProvider).checkAndPromptReview(context);
        final prefs = ref.read(preferencesServiceProvider);
        await prefs.recordToneUsed(_selectedTone);
        await prefs.recordLanguageUsed(_selectedLanguage);
        if (mounted) {
          await ref.read(achievementServiceProvider).checkAndUnlockAchievements(context: context);
        }
      }
    }
  }

  void _showOutOfCreditsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Daily Credits Used'),
        content: const Text(
          'You have reached your daily free generation limit. Upgrade to VibeKit Pro or watch a rewarded video ad to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/paywall');
            },
            child: const Text('Upgrade to Pro'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveFavorite(String text, String title) async {
    final db = ref.read(localDatabaseProvider);
    await db.insertItem(
      HistoryItem(
        id: const Uuid().v4(),
        title: title,
        content: text,
        type: 'caption',
        category: _selectedPlatform,
        createdAt: DateTime.now(),
        isFavorite: true,
      ),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved to Favorites!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final genState = ref.watch(captionGenerationProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final quickScenarios = [
      {'prompt': 'Sunday morning aesthetic coffee dump with books and quiet vibes', 'vibe': 'Aesthetic', 'label': '☕ Sunday Cafe'},
      {'prompt': 'Goa beach trip with best friends, sunset cocktails and road trip', 'vibe': 'Trendy', 'label': '✈️ Goa Trip'},
      {'prompt': 'Monday morning gym workout, building discipline and personal bests', 'vibe': 'Confident', 'label': '💪 Gym Grind'},
      {'prompt': 'Golden hour sunset selfie with minimal vibes', 'vibe': 'Witty', 'label': '🌅 Golden Hour'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Caption Lab',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: AppSpacing.md),
            child: Center(child: QuotaBadge()),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: AppSpacing.paddingScreen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Topic Input Field
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceCardDark : AppColors.surfaceCardLight,
                borderRadius: AppSpacing.roundedMd,
                border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
              ),
              padding: AppSpacing.paddingMd,
              child: Column(
                children: [
                  TextField(
                    controller: _topicController,
                    maxLines: 4,
                    maxLength: _maxChars,
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText: 'What is your photo, reel, or status about? (e.g. Goa trip with friends, new cafe launch)...',
                      hintStyle: TextStyle(
                        color: isDark ? AppColors.textMutedDark : AppColors.textSecondaryLight,
                      ),
                      border: InputBorder.none,
                      counterStyle: TextStyle(
                        color: isDark ? AppColors.textMutedDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Quick Scenario Chips (Prevents user confusion & writer's block)
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 14,
                  color: isDark ? AppColors.accentWarm : AppColors.primary,
                ),
                const SizedBox(width: 5),
                Text(
                  'Quick scenarios to try:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: quickScenarios.map((sc) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _topicController.text = sc['prompt']!;
                          _selectedTone = sc['vibe']!;
                        });
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.surfaceElevatedDark
                              : AppColors.surfaceCardLight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? AppColors.borderDark : AppColors.borderLight,
                          ),
                        ),
                        child: Text(
                          sc['label']!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.accentWarm : AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 2. Platform Selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Target Platform',
                  style: TextStyle(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Formats hooks & hashtags',
                  style: TextStyle(
                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 2),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceCardDark : AppColors.surfaceCardLight,
                borderRadius: AppSpacing.roundedMd,
                border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedPlatform,
                  isExpanded: true,
                  dropdownColor: isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceCardLight,
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                  items: _platforms.map((p) {
                    return DropdownMenuItem<String>(
                      value: p,
                      child: Text(
                        p,
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                          fontSize: 14,
                        ),
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

            // 3. Tone Selector
            const Text(
              'Select Vibe',
              style: TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ToneChips(
              tones: _tones,
              selectedTone: _selectedTone,
              onSelected: (tone) => setState(() => _selectedTone = tone),
            ),
            const SizedBox(height: AppSpacing.md),

            // 4. Language & Length Row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Language',
                        style: TextStyle(
                          color: AppColors.textSecondaryDark,
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
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Length',
                        style: TextStyle(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceCardDark : AppColors.surfaceCardLight,
                          borderRadius: AppSpacing.roundedMd,
                          border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedLength,
                            isExpanded: true,
                            dropdownColor: isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceCardLight,
                            icon: Icon(
                              Icons.arrow_drop_down,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                            items: _lengths.map((len) {
                              return DropdownMenuItem<String>(
                                value: len['id'],
                                child: Text(
                                  len['label']!,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                    fontSize: 14,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedLength = val);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // 5. Options Checkboxes (Responsive wrap, zero overflow)
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 8,
              children: [
                InkWell(
                  onTap: () => setState(() => _includeHooks = !_includeHooks),
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: _includeHooks,
                        onChanged: (val) => setState(() => _includeHooks = val ?? true),
                        activeColor: AppColors.primary,
                      ),
                      Text(
                        'Include Reel Hooks',
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => setState(() => _includeHashtags = !_includeHashtags),
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: _includeHashtags,
                        onChanged: (val) => setState(() => _includeHashtags = val ?? true),
                        activeColor: AppColors.primary,
                      ),
                      Text(
                        'Include Hashtags',
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // 6. Generate Button
            PrimaryButton(
              label: 'Generate Captions & Hooks',
              icon: Icons.auto_awesome,
              isLoading: genState.isGenerating,
              onPressed: _generateCaptions,
            ),
            const SizedBox(height: AppSpacing.lg),

            // 7. Error View
            if (genState.errorMessage != null) ...[
              ErrorView(
                message: genState.errorMessage!,
                onRetry: _generateCaptions,
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // 8. Loading Shimmer Placeholders
            if (genState.isGenerating) ...[
              const LoadingShimmer(height: 120),
              const SizedBox(height: AppSpacing.md),
              const LoadingShimmer(height: 100),
            ],

            // 9. Results
            if (genState.result != null && !genState.isGenerating) ...[
              // Captions
              const Text(
                'Captions',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ...genState.result!.captions.map(
                (caption) => ResultCard(
                  content: caption,
                  category: '$_selectedPlatform • $_selectedTone',
                  onFavoriteToggle: () => _saveFavorite(caption, 'Caption: ${_topicController.text}'),
                ),
              ),

              // Hooks
              if (genState.result!.hooks.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'Reel & Video Hooks',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ...genState.result!.hooks.map(
                  (hook) => ResultCard(
                    content: hook,
                    subtitle: 'HOOK',
                    category: 'Reel Hook',
                    onFavoriteToggle: () => _saveFavorite(hook, 'Hook'),
                  ),
                ),
              ],

              // Hashtags
              if (genState.result!.hashtags.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Hashtags',
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ResultCard(
                  content: genState.result!.hashtags.join(' '),
                  subtitle: 'CATEGORIZED HASHTAGS',
                  category: 'Hashtags',
                ),
              ],
            ],
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }
}
