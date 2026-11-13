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

enum StudioTab {
  reply('reply', '💬 Reply', 'Smart response to any text or DM'),
  vibeCheck('vibe_check', '🔥 Vibe Check', 'Roast, rating & leveled rewrites'),
  caption('caption', '✨ Captions', 'Viral captions, hooks & hashtags'),
  bio('bio', '👤 Bio Lab', 'Aesthetic profile bios & handles');

  final String id;
  final String label;
  final String description;
  const StudioTab(this.id, this.label, this.description);

  static StudioTab fromId(String? id) {
    if (id == null) return StudioTab.reply;
    return StudioTab.values.firstWhere(
      (t) => t.id == id,
      orElse: () => StudioTab.reply,
    );
  }
}

class StudioScreen extends ConsumerStatefulWidget {
  final String? initialTabId;
  final String? initialPrompt;
  final String? initialOption;

  const StudioScreen({
    super.key,
    this.initialTabId,
    this.initialPrompt,
    this.initialOption,
  });

  @override
  ConsumerState<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends ConsumerState<StudioScreen> {
  late StudioTab _activeTab;
  final TextEditingController _textController = TextEditingController();

  // Mode/Tone state per tab
  String _replyTone = 'Funny';
  final String _replyLength = 'medium';

  String _vibeMode = 'roast';

  String _captionVibe = 'Aesthetic';
  final String _captionPlatform = 'Instagram';

  String _bioVibe = 'Aesthetic';
  final String _bioPlatform = 'Instagram';

  String _selectedLanguage = 'English';

  static const List<String> _languages = [
    'English',
    'Hindi',
    'Hinglish',
    'Gujarati',
  ];

  static const List<String> _replyTones = [
    'Funny',
    'Friendly',
    'Flirty',
    'Confident',
    'Professional',
    'Polite',
    'Supportive',
    'Witty',
    'Rizz',
    'Savage',
  ];

  static const List<Map<String, String>> _vibeModes = [
    {'id': 'roast', 'label': '🔥 Roast Me'},
    {'id': 'polish', 'label': '✨ Vibe Polish'},
    {'id': 'dating', 'label': '💘 Date Doctor'},
    {'id': 'work', 'label': '💼 Boss Mode'},
    {'id': 'decoder', 'label': '🕵️ Text Decrypter'},
    {'id': 'excuse', 'label': '🏃 Excuse Studio'},
  ];

  static const List<String> _captionVibes = [
    'Aesthetic',
    'Trendy',
    'Savage',
    'Chill',
    'Poetic',
    'Hustle',
    'Minimalist',
  ];

  static const List<String> _bioVibes = [
    'Aesthetic',
    'Witty',
    'Minimal',
    'Professional',
    'Creative',
  ];

  static const Map<StudioTab, List<Map<String, String>>> _sampleChips = {
    StudioTab.reply: [
      {'label': '💬 Reply to "k."', 'text': 'k.'},
      {'label': '⚡ Savage Comeback', 'text': 'You took 6 hours to reply with "cool".'},
      {'label': '🥂 Magnetic Rizz', 'text': 'How do you look this good on a random Tuesday?'},
      {'label': '☕ Coffee tonight?', 'text': 'Are you free for coffee tonight?'},
      {'label': '📅 Reschedule meeting', 'text': 'Can we push our meeting to tomorrow morning?'},
    ],
    StudioTab.vibeCheck: [
      {'label': '🕵️ Decrypt "fine."', 'text': 'fine.'},
      {'label': '🏃 Cancel Plans', 'text': 'Hey sorry I really cannot make it tonight I am too tired.'},
      {'label': '💘 Crush DM', 'text': 'Hey are you free tonight? Just wondering what you are doing lol'},
      {'label': '💼 Raise Request', 'text': 'Hey boss, I have been working really hard lately and feel I deserve a raise.'},
    ],
    StudioTab.caption: [
      {'label': '☕ Sunday Cafe', 'text': 'Slow Sunday morning with warm latte and favorite book'},
      {'label': '✈️ Goa Trip', 'text': 'Sunset beach walks and ocean breeze with best friends'},
      {'label': '💪 Gym Grind', 'text': 'Consistent workouts paying off, new personal best today'},
      {'label': '🌅 Golden Hour', 'text': 'Sunsets are proof that endings can often be beautiful too'},
    ],
    StudioTab.bio: [
      {'label': '📸 Travel Creator', 'text': 'Travel filmmaker, exploring hidden coffee shops and mountain peaks'},
      {'label': '☕ Coffee Lover', 'text': 'Obsessed with pour-overs, cozy bookstores, and late night thoughts'},
      {'label': '💻 Tech Founder', 'text': 'Building next-gen AI tools for creators and modern thinkers'},
      {'label': '✨ Minimalist', 'text': 'Living simply, writing daily, chasing golden hour light'},
    ],
  };

  @override
  void initState() {
    super.initState();
    _activeTab = StudioTab.fromId(widget.initialTabId);

    if (widget.initialPrompt != null && widget.initialPrompt!.isNotEmpty) {
      _textController.text = widget.initialPrompt!;
    } else {
      _textController.text = _sampleChips[_activeTab]?.first['text'] ?? '';
    }

    if (widget.initialOption != null) {
      if (_replyTones.contains(widget.initialOption)) _replyTone = widget.initialOption!;
      if (_captionVibes.contains(widget.initialOption)) _captionVibe = widget.initialOption!;
      if (_bioVibes.contains(widget.initialOption)) _bioVibe = widget.initialOption!;
    }
  }

  @override
  void didUpdateWidget(covariant StudioScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTabId != null && widget.initialTabId != oldWidget.initialTabId) {
      _switchTab(StudioTab.fromId(widget.initialTabId));
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _switchTab(StudioTab tab) {
    if (_activeTab == tab) return;
    setState(() {
      _activeTab = tab;
      _textController.text = _sampleChips[tab]?.first['text'] ?? '';
    });
  }

  Future<void> _handleGenerate() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter text or pick an example'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    bool success = false;

    switch (_activeTab) {
      case StudioTab.reply:
        final req = ReplyRequest(
          message: text,
          tone: _replyTone,
          language: _selectedLanguage,
          length: _replyLength,
          count: 3,
        );
        success = await ref.read(replyGenerationProvider.notifier).execute(
          request: req,
          caller: () => ref.read(apiClientProvider).generateReply(req),
          getCreditsRemaining: (res) => res.creditsRemaining,
          buildHistoryItems: (res) => res.suggestions
              .map((s) => HistoryItem(
                    id: const Uuid().v4(),
                    title: text.length > 35 ? '${text.substring(0, 35)}...' : text,
                    content: s,
                    type: 'reply',
                    category: '$_replyTone • $_selectedLanguage',
                    createdAt: DateTime.now(),
                  ))
              .toList(),
          actionType: 'reply',
        );
        break;

      case StudioTab.vibeCheck:
        final req = VibeCheckRequest(
          text: text,
          mode: _vibeMode,
          language: _selectedLanguage,
        );
        success = await ref.read(vibeCheckGenerationProvider.notifier).execute(
          request: req,
          caller: () => ref.read(apiClientProvider).checkVibe(req),
          getCreditsRemaining: (res) => res.creditsRemaining,
          buildHistoryItems: (res) => [
            HistoryItem(
              id: const Uuid().v4(),
              title: 'Vibe Check: ${res.score}/100 (${res.title})',
              content: '${res.verdict}\n\nTop Rewrite:\n${res.rewrites.isNotEmpty ? res.rewrites.first : ''}',
              type: 'vibe_check',
              category: '$_vibeMode • $_selectedLanguage',
              createdAt: DateTime.now(),
            ),
          ],
          actionType: 'vibe_check',
        );
        break;

      case StudioTab.caption:
        final req = CaptionRequest(
          topic: text,
          tone: _captionVibe,
          language: _selectedLanguage,
          platform: _captionPlatform,
        );
        success = await ref.read(captionGenerationProvider.notifier).execute(
          request: req,
          caller: () => ref.read(apiClientProvider).generateCaption(req),
          getCreditsRemaining: (res) => res.creditsRemaining,
          buildHistoryItems: (res) => res.captions
              .map((c) => HistoryItem(
                    id: const Uuid().v4(),
                    title: text.length > 35 ? '${text.substring(0, 35)}...' : text,
                    content: '$c\n\n${res.hashtags.join(' ')}',
                    type: 'caption',
                    category: '$_captionVibe • $_captionPlatform',
                    createdAt: DateTime.now(),
                  ))
              .toList(),
          actionType: 'caption',
        );
        break;

      case StudioTab.bio:
        final req = BioRequest(
          interests: text,
          platform: _bioPlatform,
          vibe: _bioVibe,
          language: _selectedLanguage,
          includeUsernames: true,
        );
        success = await ref.read(bioGenerationProvider.notifier).execute(
          request: req,
          caller: () => ref.read(apiClientProvider).generateBio(req),
          getCreditsRemaining: (res) => res.creditsRemaining,
          buildHistoryItems: (res) => res.bios
              .map((b) => HistoryItem(
                    id: const Uuid().v4(),
                    title: 'Bio for $_bioPlatform',
                    content: b,
                    type: 'bio',
                    category: '$_bioVibe • $_bioPlatform',
                    createdAt: DateTime.now(),
                  ))
              .toList(),
          actionType: 'bio',
        );
        break;
    }

    if (mounted && success) {
      HapticFeedback.lightImpact();
      ref.read(reviewServiceProvider).checkAndPromptReview(context);
      final prefs = ref.read(preferencesServiceProvider);
      await prefs.recordLanguageUsed(_selectedLanguage);
      if (mounted) {
        await ref.read(achievementServiceProvider).checkAndUnlockAchievements(context: context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isGenerating = _getIsGenerating();
    final errorMessage = _getErrorMessage();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'AI Studio',
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
                // Top Segmented Mode Switcher
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceCardDark : AppColors.surfaceCardLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    ),
                  ),
                  child: Row(
                    children: StudioTab.values.map((tab) {
                      final isSelected = _activeTab == tab;
                      return Expanded(
                        child: InkWell(
                          onTap: () => _switchTab(tab),
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark ? AppColors.surfaceElevatedDark : Colors.white)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: isSelected && !isDark
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.04),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                tab.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected
                                      ? (isDark ? AppColors.accentWarm : AppColors.primary)
                                      : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Description Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceCardDark : AppColors.surfaceCardLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: isDark ? AppColors.accentWarm : AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _activeTab.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Quick Inspiration Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: (_sampleChips[_activeTab] ?? []).map((sample) {
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

                // Input Text Box
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
                        maxLength: 500,
                        style: theme.textTheme.bodyMedium,
                        decoration: InputDecoration(
                          hintText: _getInputPlaceholder(),
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
                            '${_textController.text.length}/500',
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

                // Mode / Tone Option Chips
                _buildModeOptions(isDark, theme),
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

                // Primary Generate Button
                PrimaryButton(
                  label: _getButtonLabel(),
                  icon: Icons.auto_awesome,
                  isLoading: isGenerating,
                  onPressed: isGenerating ? null : _handleGenerate,
                ),
                const SizedBox(height: AppSpacing.lg),

                // Error View
                if (errorMessage != null) ...[
                  ErrorView(
                    message: errorMessage,
                    onRetry: _handleGenerate,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // Output Rendering
                if (isGenerating) ...[
                  const Column(
                    children: [
                      LoadingShimmer(height: 100),
                      SizedBox(height: 12),
                      LoadingShimmer(height: 80),
                      SizedBox(height: 12),
                      LoadingShimmer(height: 80),
                    ],
                  ),
                ] else ...[
                  _buildResultsForActiveTab(isDark, theme),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getInputPlaceholder() {
    switch (_activeTab) {
      case StudioTab.reply:
        return 'Paste the message or text you received...';
      case StudioTab.vibeCheck:
        return 'Paste your draft text, DM, email, or bio to vibe check...';
      case StudioTab.caption:
        return 'What is your photo, reel, or story about?...';
      case StudioTab.bio:
        return 'Enter your passions, keywords, or niche for bio suggestions...';
    }
  }

  String _getButtonLabel() {
    switch (_activeTab) {
      case StudioTab.reply:
        return 'Generate Replies';
      case StudioTab.vibeCheck:
        return 'Check Vibe';
      case StudioTab.caption:
        return 'Create Captions & Hooks';
      case StudioTab.bio:
        return 'Craft Bios & Handles';
    }
  }

  bool _getIsGenerating() {
    switch (_activeTab) {
      case StudioTab.reply:
        return ref.watch(replyGenerationProvider).isGenerating;
      case StudioTab.vibeCheck:
        return ref.watch(vibeCheckGenerationProvider).isGenerating;
      case StudioTab.caption:
        return ref.watch(captionGenerationProvider).isGenerating;
      case StudioTab.bio:
        return ref.watch(bioGenerationProvider).isGenerating;
    }
  }

  String? _getErrorMessage() {
    switch (_activeTab) {
      case StudioTab.reply:
        final s = ref.watch(replyGenerationProvider);
        return !s.isQuotaExceeded ? s.errorMessage : null;
      case StudioTab.vibeCheck:
        final s = ref.watch(vibeCheckGenerationProvider);
        return !s.isQuotaExceeded ? s.errorMessage : null;
      case StudioTab.caption:
        final s = ref.watch(captionGenerationProvider);
        return !s.isQuotaExceeded ? s.errorMessage : null;
      case StudioTab.bio:
        final s = ref.watch(bioGenerationProvider);
        return !s.isQuotaExceeded ? s.errorMessage : null;
    }
  }

  Widget _buildModeOptions(bool isDark, ThemeData theme) {
    switch (_activeTab) {
      case StudioTab.reply:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Tone',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _replyTones.map((tone) {
                final isSelected = _replyTone == tone;
                return ChoiceChip(
                  selected: isSelected,
                  label: Text(tone),
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
                    if (val) setState(() => _replyTone = tone);
                  },
                );
              }).toList(),
            ),
          ],
        );

      case StudioTab.vibeCheck:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
              children: _vibeModes.map((m) {
                final isSelected = _vibeMode == m['id'];
                return ChoiceChip(
                  selected: isSelected,
                  label: Text(m['label']!),
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
                    if (val) setState(() => _vibeMode = m['id']!);
                  },
                );
              }).toList(),
            ),
          ],
        );

      case StudioTab.caption:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Caption Vibe',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _captionVibes.map((vibe) {
                final isSelected = _captionVibe == vibe;
                return ChoiceChip(
                  selected: isSelected,
                  label: Text(vibe),
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
                    if (val) setState(() => _captionVibe = vibe);
                  },
                );
              }).toList(),
            ),
          ],
        );

      case StudioTab.bio:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bio Vibe',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _bioVibes.map((vibe) {
                final isSelected = _bioVibe == vibe;
                return ChoiceChip(
                  selected: isSelected,
                  label: Text(vibe),
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
                    if (val) setState(() => _bioVibe = vibe);
                  },
                );
              }).toList(),
            ),
          ],
        );
    }
  }

  Widget _buildResultsForActiveTab(bool isDark, ThemeData theme) {
    switch (_activeTab) {
      case StudioTab.reply:
        final res = ref.watch(replyGenerationProvider).result;
        if (res == null) return const SizedBox.shrink();
        return Column(
          children: res.suggestions.asMap().entries.map((e) {
            return _buildOutputCard(
              context: context,
              title: 'Option ${e.key + 1}',
              content: e.value,
              isDark: isDark,
              theme: theme,
            );
          }).toList(),
        );

      case StudioTab.vibeCheck:
        final res = ref.watch(vibeCheckGenerationProvider).result;
        if (res == null) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Score & Roast Summary
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 12),
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
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 3),
                      color: AppColors.primary.withOpacity(0.1),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${res.score}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          res.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          res.verdict,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ...res.rewrites.asMap().entries.map((e) {
              return _buildOutputCard(
                context: context,
                title: 'Rewrite ${e.key + 1}',
                content: e.value,
                isDark: isDark,
                theme: theme,
              );
            }),
          ],
        );

      case StudioTab.caption:
        final res = ref.watch(captionGenerationProvider).result;
        if (res == null) return const SizedBox.shrink();
        return Column(
          children: [
            ...res.captions.asMap().entries.map((e) {
              return _buildOutputCard(
                context: context,
                title: 'Caption ${e.key + 1}',
                content: e.value,
                isDark: isDark,
                theme: theme,
              );
            }),
            if (res.hashtags.isNotEmpty) ...[
              _buildOutputCard(
                context: context,
                title: 'Viral Hashtags',
                content: res.hashtags.map((h) => h.startsWith('#') ? h : '#$h').join(' '),
                isDark: isDark,
                theme: theme,
              ),
            ],
          ],
        );

      case StudioTab.bio:
        final res = ref.watch(bioGenerationProvider).result;
        if (res == null) return const SizedBox.shrink();
        return Column(
          children: [
            ...res.bios.asMap().entries.map((e) {
              return _buildOutputCard(
                context: context,
                title: 'Bio ${e.key + 1}',
                content: e.value,
                isDark: isDark,
                theme: theme,
              );
            }),
            if (res.usernames.isNotEmpty) ...[
              _buildOutputCard(
                context: context,
                title: 'Suggested Handles',
                content: res.usernames.join('   •   '),
                isDark: isDark,
                theme: theme,
              ),
            ],
          ],
        );
    }
  }

  Widget _buildOutputCard({
    required BuildContext context,
    required String title,
    required String content,
    required bool isDark,
    required ThemeData theme,
  }) {
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
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  title,
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
            content,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: content));
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
              TextButton.icon(
                onPressed: () {
                  context.push('/card-maker', extra: {'text': content});
                },
                icon: const Icon(Icons.style_outlined, size: 15),
                label: const Text('Card', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: isDark ? AppColors.textPrimaryDark : AppColors.primary,
                ),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: () {
                  Share.share(content);
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
  }
}
