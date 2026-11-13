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

class ReplyStudioScreen extends ConsumerStatefulWidget {
  final String? initialPrompt;
  final String? initialTone;

  const ReplyStudioScreen({
    super.key,
    this.initialPrompt,
    this.initialTone,
  });

  @override
  ConsumerState<ReplyStudioScreen> createState() => _ReplyStudioScreenState();
}

class _ReplyStudioScreenState extends ConsumerState<ReplyStudioScreen> {
  final TextEditingController _textController = TextEditingController();
  final int _maxChars = 500;

  String _selectedTone = 'Funny';
  String _selectedLanguage = 'English';
  String _selectedLength = 'medium';

  static const List<String> _tones = [
    'Funny',
    'Friendly',
    'Flirty',
    'Confident',
    'Professional',
    'Polite',
    'Supportive',
    'Witty',
  ];

  static const List<String> _languages = [
    'English',
    'Hindi',
    'Hinglish',
    'Gujarati',
  ];

  static const List<Map<String, String>> _lengths = [
    {'id': 'short', 'label': 'Short'},
    {'id': 'medium', 'label': 'Medium'},
    {'id': 'detailed', 'label': 'Detailed'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialPrompt != null) {
      _textController.text = widget.initialPrompt!;
    }
    if (widget.initialTone != null && _tones.contains(widget.initialTone)) {
      _selectedTone = widget.initialTone!;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _generateReplies() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a message to reply to.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final request = ReplyRequest(
      message: text,
      tone: _selectedTone,
      language: _selectedLanguage,
      length: _selectedLength,
      count: 3,
    );

    final success = await ref.read(replyGenerationProvider.notifier).execute(
      request: request,
      caller: () => ref.read(apiClientProvider).generateReply(request),
      getCreditsRemaining: (res) => res.creditsRemaining,
      buildHistoryItems: (res) => res.suggestions
          .map(
            (suggestion) => HistoryItem(
              id: const Uuid().v4(),
              title: text.length > 40 ? '${text.substring(0, 40)}...' : text,
              content: suggestion,
              type: 'reply',
              category: '$_selectedTone • $_selectedLanguage',
              createdAt: DateTime.now(),
            ),
          )
          .toList(),
      actionType: 'reply',
    );

    if (mounted) {
      final genState = ref.read(replyGenerationProvider);
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

  Future<void> _saveFavorite(String text) async {
    final db = ref.read(localDatabaseProvider);
    await db.insertItem(
      HistoryItem(
        id: const Uuid().v4(),
        title: 'Favorite Reply',
        content: text,
        type: 'reply',
        category: _selectedTone,
        createdAt: DateTime.now(),
        isFavorite: true,
      ),
    );

    HapticFeedback.selectionClick();
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
    final genState = ref.watch(replyGenerationProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final quickExamples = [
      {'prompt': 'Someone replied with just "k."', 'tone': 'Funny', 'label': 'Reply to "k."'},
      {'prompt': 'Hey, are you free to grab coffee tonight?', 'tone': 'Flirty', 'label': 'Coffee tonight?'},
      {'prompt': 'Can we reschedule our meeting to tomorrow morning?', 'tone': 'Professional', 'label': 'Reschedule meeting'},
      {'prompt': 'Thanks so much for helping out today, really appreciate it!', 'tone': 'Friendly', 'label': 'Say thanks'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Reply Studio',
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
            // 1. Message Input Field
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
                    controller: _textController,
                    maxLines: 4,
                    maxLength: _maxChars,
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Paste the message you want to reply to...',
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

            // Quick Example Chips (Prevents user confusion & writer's block)
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 14,
                  color: isDark ? AppColors.accentWarm : AppColors.primary,
                ),
                const SizedBox(width: 5),
                Text(
                  'Quick examples to try:',
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
                children: quickExamples.map((ex) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _textController.text = ex['prompt']!;
                          _selectedTone = ex['tone']!;
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
                          ex['label']!,
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

            // 2. Tone Selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Tone',
                  style: TextStyle(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Changes voice & banter',
                  style: TextStyle(
                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ToneChips(
              tones: _tones,
              selectedTone: _selectedTone,
              onSelected: (tone) => setState(() => _selectedTone = tone),
            ),
            const SizedBox(height: AppSpacing.md),

            // 3. Language & Length Row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Language',
                        style: TextStyle(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
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
            const SizedBox(height: AppSpacing.lg),

            // 4. Generate Button
            PrimaryButton(
              label: 'Generate Replies',
              icon: Icons.auto_awesome,
              isLoading: genState.isGenerating,
              onPressed: _generateReplies,
            ),
            const SizedBox(height: AppSpacing.lg),

            // 5. Error View
            if (genState.errorMessage != null) ...[
              ErrorView(
                message: genState.errorMessage!,
                onRetry: _generateReplies,
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // 6. Loading Shimmer Placeholders
            if (genState.isGenerating) ...[
              const LoadingShimmer(height: 100),
              const SizedBox(height: AppSpacing.md),
              const LoadingShimmer(height: 100),
              const SizedBox(height: AppSpacing.md),
              const LoadingShimmer(height: 100),
            ],

            // 7. Results
            if (genState.result != null && !genState.isGenerating) ...[
              Text(
                'Suggestions',
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ...genState.result!.suggestions.map(
                (suggestion) => ResultCard(
                  content: suggestion,
                  category: '$_selectedTone • $_selectedLanguage',
                  onFavoriteToggle: () => _saveFavorite(suggestion),
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }
}
