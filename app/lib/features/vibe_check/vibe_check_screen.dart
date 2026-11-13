import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/app_bottom_nav.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_shimmer.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/quota_badge.dart';
import '../../models/generation_models.dart';
import '../../models/history_item.dart';
import '../../core/services/achievement_service.dart';

class VibeCheckScreen extends ConsumerStatefulWidget {
  final String? initialText;

  const VibeCheckScreen({super.key, this.initialText});

  @override
  ConsumerState<VibeCheckScreen> createState() => _VibeCheckScreenState();
}

class _VibeCheckScreenState extends ConsumerState<VibeCheckScreen> {
  final TextEditingController _textController = TextEditingController();
  final int _maxChars = 600;

  String _selectedMode = 'roast';
  String _selectedLanguage = 'English';

  static const List<Map<String, String>> _modes = [
    {'id': 'roast', 'label': '🔥 Roast Me', 'desc': 'Brutally honest feedback'},
    {'id': 'polish', 'label': '✨ Vibe Polish', 'desc': 'Make it warm & charismatic'},
    {'id': 'dating', 'label': '💘 Date Doctor', 'desc': 'Flirty, playful, zero cringe'},
    {'id': 'work', 'label': '💼 Boss Mode', 'desc': 'Assertive & professional'},
  ];

  static const List<String> _languages = [
    'English',
    'Hindi',
    'Hinglish',
    'Gujarati',
  ];

  static const List<Map<String, String>> _sampleDrafts = [
    {
      'label': '💘 Crush DM',
      'text': 'Hey are you free tonight? Just wondering what you are doing lol',
    },
    {
      'label': '💼 Raise Request',
      'text': 'Hey boss, I have been working really hard lately and feel I deserve a raise.',
    },
    {
      'label': '🤝 Cold Outreach',
      'text': 'Hi, I saw your profile and want to connect. Are there any open roles at your company?',
    },
    {
      'label': '☕ Late Apology',
      'text': 'Hey sorry running like 20 mins late traffic is so crazy!',
    },
  ];

  @override
  void initState() {
    super.initState();
    _textController.text = (widget.initialText != null && widget.initialText!.isNotEmpty)
        ? widget.initialText!
        : _sampleDrafts.first['text']!;
  }

  @override
  void didUpdateWidget(covariant VibeCheckScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialText != null && widget.initialText != oldWidget.initialText) {
      _textController.text = widget.initialText!;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _checkVibe() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please paste or write a message to vibe check'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final request = VibeCheckRequest(
      text: text,
      mode: _selectedMode,
      language: _selectedLanguage,
    );

    final success = await ref.read(vibeCheckGenerationProvider.notifier).execute(
      request: request,
      caller: () => ref.read(apiClientProvider).checkVibe(request),
      getCreditsRemaining: (res) => res.creditsRemaining,
      buildHistoryItems: (res) => [
        HistoryItem(
          id: const Uuid().v4(),
          title: 'Vibe Check: ${res.score}/100 (${res.title})',
          content: '${res.verdict}\n\nTop Rewrite:\n${res.rewrites.isNotEmpty ? res.rewrites.first : ''}',
          type: 'vibe_check',
          category: '$_selectedMode • $_selectedLanguage',
          createdAt: DateTime.now(),
        ),
      ],
      actionType: 'vibe_check',
    );

    if (mounted) {
      final genState = ref.read(vibeCheckGenerationProvider);
      if (genState.isQuotaExceeded) {
        _showOutOfCreditsDialog();
      } else if (success) {
        HapticFeedback.lightImpact();
        ref.read(reviewServiceProvider).checkAndPromptReview(context);
        final prefs = ref.read(preferencesServiceProvider);
        await prefs.recordToneUsed(_selectedMode);
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

  Color _getScoreColor(int score, bool isDark) {
    if (score >= 80) return const Color(0xFF2E7D32); // Deep green
    if (score >= 60) return const Color(0xFFC77700); // Warm Amber
    if (score >= 40) return const Color(0xFFD9531E); // Warm terracotta
    return const Color(0xFFC62828); // Crimson
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final genState = ref.watch(vibeCheckGenerationProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Vibe Check & Roaster',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(child: QuotaBadge()),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Banner / Description
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceCardDark : AppColors.surfaceCardLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Text('🎯', style: TextStyle(fontSize: 22)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Test before you hit send',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Get an AI vibe rating, witty critique, and 3 leveled-up rewrites ready to copy.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Quick Scenario Chips
                Row(
                  children: [
                    Text(
                      'Try an example',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.touch_app_outlined,
                      size: 14,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _sampleDrafts.map((sample) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          avatar: const Icon(Icons.flash_on, size: 14, color: AppColors.primary),
                          label: Text(sample['label']!),
                          backgroundColor: isDark ? AppColors.surfaceCardDark : AppColors.surfaceCardLight,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isDark ? AppColors.borderDark : AppColors.borderLight,
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _textController.text = sample['text']!;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Draft Input Field
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceCardDark : AppColors.surfaceCardLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      TextField(
                        controller: _textController,
                        maxLines: 4,
                        maxLength: _maxChars,
                        style: theme.textTheme.bodyMedium,
                        decoration: InputDecoration(
                          hintText: 'Paste your draft text, DM, email, or bio here...',
                          hintStyle: TextStyle(
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          counterText: '',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (_textController.text.isNotEmpty)
                            TextButton.icon(
                              onPressed: () {
                                _textController.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.clear, size: 14),
                              label: const Text('Clear', style: TextStyle(fontSize: 12)),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            )
                          else
                            const SizedBox.shrink(),
                          Text(
                            '${_textController.text.length}/$_maxChars',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Mode Selector
                Text(
                  'Vibe Check Mode',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _modes.map((mode) {
                    final isSelected = _selectedMode == mode['id'];
                    return ChoiceChip(
                      selected: isSelected,
                      label: Text(mode['label']!),
                      selectedColor: isDark ? AppColors.surfaceCardLight : AppColors.primary,
                      backgroundColor: isDark ? AppColors.surfaceCardDark : AppColors.surfaceCardLight,
                      labelStyle: TextStyle(
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? (isDark ? AppColors.textPrimaryLight : Colors.white)
                            : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected
                              ? (isDark ? AppColors.surfaceCardLight : AppColors.primary)
                              : (isDark ? AppColors.borderDark : AppColors.borderLight),
                        ),
                      ),
                      onSelected: (val) {
                        if (val) {
                          setState(() => _selectedMode = mode['id']!);
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.md),

                // Language Selector
                Row(
                  children: [
                    Text(
                      'Language:',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceCardDark : AppColors.surfaceCardLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedLanguage,
                          isDense: true,
                          dropdownColor: isDark ? AppColors.surfaceCardDark : AppColors.surfaceCardLight,
                          items: _languages.map((l) {
                            return DropdownMenuItem<String>(
                              value: l,
                              child: Text(
                                l,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedLanguage = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // Submit Action Button
                PrimaryButton(
                  label: 'Check Vibe',
                  icon: Icons.auto_awesome,
                  isLoading: genState.isGenerating,
                  onPressed: genState.isGenerating ? null : _checkVibe,
                ),
                const SizedBox(height: AppSpacing.lg),

                // Error View
                if (genState.errorMessage != null && !genState.isQuotaExceeded) ...[
                  ErrorView(
                    message: genState.errorMessage!,
                    onRetry: _checkVibe,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // Loading State
                if (genState.isGenerating) ...[
                  const Column(
                    children: [
                      LoadingShimmer(height: 120),
                      SizedBox(height: 12),
                      LoadingShimmer(height: 80),
                      SizedBox(height: 12),
                      LoadingShimmer(height: 80),
                    ],
                  ),
                ] else if (genState.result != null) ...[
                  // Results Display
                  _buildResultsView(context, genState.result!, isDark),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultsView(BuildContext context, VibeCheckResponse result, bool isDark) {
    final theme = Theme.of(context);
    final scoreColor = _getScoreColor(result.score, isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Score & Title Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceCardDark : AppColors.surfaceCardLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: scoreColor, width: 4),
                      color: scoreColor.withValues(alpha: 0.1),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${result.score}',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: scoreColor,
                            height: 1.0,
                          ),
                        ),
                        Text(
                          '/100',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: scoreColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: scoreColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            result.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: scoreColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          result.verdict,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontStyle: FontStyle.italic,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (result.tags.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: result.tags.map((tag) {
                    final displayTag = tag.startsWith('#') ? tag : '#$tag';
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black26 : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        ),
                      ),
                      child: Text(
                        displayTag,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.primary,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Section Title: Leveled-Up Rewrites
        Row(
          children: [
            const Icon(Icons.auto_fix_high, size: 18, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              'Leveled-Up Rewrites',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        ...result.rewrites.asMap().entries.map((entry) {
          final index = entry.key;
          final rewrite = entry.value;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceCardDark : AppColors.surfaceCardLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Option ${index + 1}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SelectableText(
                  rewrite,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Copy Action
                    TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: rewrite));
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Copied to clipboard!'),
                            duration: Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 15),
                      label: const Text('Copy', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: isDark ? AppColors.textPrimaryDark : AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Make Card Action
                    TextButton.icon(
                      onPressed: () {
                        context.push('/card-maker', extra: {'text': rewrite});
                      },
                      icon: const Icon(Icons.style_outlined, size: 15),
                      label: const Text('Card', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: isDark ? AppColors.textPrimaryDark : AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Share Action
                    TextButton.icon(
                      onPressed: () {
                        Share.share(rewrite);
                      },
                      icon: const Icon(Icons.share_outlined, size: 15),
                      label: const Text('Share', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: isDark ? AppColors.textPrimaryDark : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
