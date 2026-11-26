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
import '../../core/widgets/report_ai_dialog.dart';
import '../../models/generation_models.dart';
import '../../models/history_item.dart';
import '../../core/services/achievement_service.dart';
import '../streaks/providers/streak_provider.dart';

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
  final Set<String> _favoritedTexts = {};
  final Set<String> _reportedContents = {};

  // Mode/Tone state per tab
  String _replyTone = 'Funny';
  final String _replyLength = 'medium';

  String _vibeMode = 'roast';

  String _captionVibe = 'Aesthetic';
  final String _captionPlatform = 'Instagram Reels';

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
    'Unbothered',
    'Opener',
  ];

  static const List<Map<String, String>> _vibeModes = [
    {'id': 'flags', 'label': '🚩 Flag Scanner'},
    {'id': 'story', 'label': '📸 Story Slider'},
    {'id': 'chemistry', 'label': '✨ Chemistry Match'},
    {'id': 'roast', 'label': '🔥 Roast Me'},
    {'id': 'polish', 'label': '✨ Vibe Polish'},
    {'id': 'dating', 'label': '💘 Date Doctor'},
    {'id': 'work', 'label': '💼 Boss Mode'},
    {'id': 'decoder', 'label': '🕵️ Text Decrypter'},
    {'id': 'excuse', 'label': '🏃 Excuse Studio'},
    {'id': 'revival', 'label': '🧟 Ghosting Revival'},
    {'id': 'apology', 'label': '🤝 Conflict Defuser'},
    {'id': 'overthinking', 'label': '🧠 Overthinking Fix'},
  ];

  static const List<String> _captionVibes = [
    'Aesthetic',
    'Trendy',
    'Witty',
    'Confident',
    'Humorous',
    'Savage',
    'Inspirational',
    'Professional',
    'Chill',
    'Poetic',
    'Hustle',
    'Minimalist',
  ];

  static const List<String> _bioVibes = [
    'Aesthetic',
    'Witty',
    'Professional',
    'Minimalist',
    'Creative',
    'Bold',
  ];

  static const Map<StudioTab, List<Map<String, String>>> _sampleChips = {
    StudioTab.reply: [
      {'label': '💬 Reply to "k."', 'text': 'k.'},
      {'label': '⚡ Savage Comeback', 'text': 'You took 6 hours to reply with "cool".'},
      {'label': '👀 Left on Read', 'text': 'Seen 4 hours ago. Guess you\'re practicing typing a masterpiece.'},
      {'label': '🥂 Smooth Rizz', 'text': 'How do you manage to look this effortlessly stunning on a random Tuesday?'},
      {'label': '🕶️ Unbothered Peace', 'text': 'Leaving me on delivered all day? I respect the mystery.'},
      {'label': '🌙 1 AM "u up?"', 'text': 'u up?'},
      {'label': '🎯 Hinge Opener', 'text': 'Matched on Hinge: loves iced matcha, indie vinyl, and golden retrievers'},
      {'label': '☕ Low-Pressure Invite', 'text': 'Are you free to grab coffee or drinks sometime this week?'},
      {'label': '🤝 Polite Raincheck', 'text': 'Hey, really sorry but feeling completely exhausted. Can we reschedule for this weekend?'},
      {'label': '💼 Professional Follow-up', 'text': 'Following up on our discussion regarding scope expansion and compensation review.'},
    ],
    StudioTab.vibeCheck: [
      {'label': '🚩 Red Flag Scanner', 'text': 'My ex was totally crazy, you are the only one who gets me so don\'t let me down.'},
      {'label': '📸 Story Reply Check', 'text': 'They posted a late-night rooftop cocktail story with no caption.'},
      {'label': '✨ Mixed Signals Check', 'text': 'Texts me all night, but takes 8 hours to reply during the day and never makes plans.'},
      {'label': '🕵️ Decrypt "fine."', 'text': 'It\'s totally fine. Do whatever you want.'},
      {'label': '🧟 Ghosting Revival', 'text': 'Conversation died 3 weeks ago after great chemistry. Want a witty, zero-pressure text to reignite.'},
      {'label': '🧠 Stop Overthinking', 'text': 'Hey sorry to bother you I know you are super busy and probably do not want to talk but if you have five minutes maybe we could call? If not totally fine no pressure!'},
      {'label': '🤝 Sincere Apology', 'text': 'I lost my temper and snapped during our argument yesterday. Want a sincere, emotionally mature apology without excuses.'},
      {'label': '🏃 Cancel Gracefully', 'text': 'Hey sorry I really cannot make it tonight my social battery is at zero. Can we do Sunday instead?'},
      {'label': '💘 Crush DM Check', 'text': 'Hey are you free tonight? Just wondering what you are doing lol'},
      {'label': '💼 Raise Request', 'text': 'Hey boss, I have been taking on additional team leadership and delivered strong results this quarter. I would love to discuss a compensation review.'},
    ],
    StudioTab.caption: [
      {'label': '☕ Cozy Coffee Dump', 'text': 'Slow Sunday morning with an oat flat white, warm rain, and chapter four.'},
      {'label': '🌅 Golden Hour Glow', 'text': 'Sunsets are proof that endings can often be beautiful too.'},
      {'label': '💪 Gym Grind & PR', 'text': '5 AM discipline over motivation. New personal best in the books.'},
      {'label': '✈️ Travel & Airport Dump', 'text': 'Window seat, noise-canceling headphones, and a boarding pass to somewhere new.'},
      {'label': '👗 Streetwear Fit Check', 'text': 'Effortless monochrome aesthetic for a chilly autumn afternoon.'},
      {'label': '🍕 Midnight Food Run', 'text': 'Good food, better company, and midnight street tacos.'},
    ],
    StudioTab.bio: [
      {'label': '📸 Visual Storyteller', 'text': 'Visual artist & storyteller. Documenting quiet moments and urban architecture across the globe.'},
      {'label': '💼 Tech Founder', 'text': 'Building next-gen AI tools for creators and modern thinkers. Obsessed with clean typography & coffee.'},
      {'label': '✨ Witty & Self-Aware', 'text': 'Professional overthinker, semi-professional meme curator, full-time matcha enthusiast.'},
      {'label': '🌿 Minimalist Vibe', 'text': 'Living simply, reading deeply, chasing golden hour light. Based in SF / NYC.'},
      {'label': '🎧 Music & Culture', 'text': 'Curating late-night playlists, scouring vinyl bins, and finding the best hidden ramen spots.'},
    ],
  };

  @override
  void initState() {
    super.initState();
    _activeTab = StudioTab.fromId(widget.initialTabId);
    final savedLang = ref.read(languageProvider);
    if (_languages.contains(savedLang)) {
      _selectedLanguage = savedLang;
    }

    if (widget.initialPrompt != null && widget.initialPrompt!.isNotEmpty) {
      _textController.text = widget.initialPrompt!;
    } else {
      _textController.text = _sampleChips[_activeTab]?.first['text'] ?? '';
    }

    if (widget.initialOption != null) {
      if (_replyTones.contains(widget.initialOption)) _replyTone = widget.initialOption!;
      if (_vibeModes.any((m) => m['id'] == widget.initialOption)) _vibeMode = widget.initialOption!;
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
    if (widget.initialPrompt != null && widget.initialPrompt != oldWidget.initialPrompt) {
      _textController.text = widget.initialPrompt!;
    }
    if (widget.initialOption != null && widget.initialOption != oldWidget.initialOption) {
      if (_replyTones.contains(widget.initialOption)) _replyTone = widget.initialOption!;
      if (_vibeModes.any((m) => m['id'] == widget.initialOption)) _vibeMode = widget.initialOption!;
      if (_captionVibes.contains(widget.initialOption)) _captionVibe = widget.initialOption!;
      if (_bioVibes.contains(widget.initialOption)) _bioVibe = widget.initialOption!;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _switchTab(StudioTab tab) {
    if (_activeTab == tab) return;
    final currentText = _textController.text.trim();
    final isCurrentSampleOrEmpty = currentText.isEmpty ||
        (_sampleChips[_activeTab]?.any((s) => s['text']!.trim() == currentText) ?? false);
    setState(() {
      _activeTab = tab;
      if (isCurrentSampleOrEmpty) {
        _textController.text = _sampleChips[tab]?.first['text'] ?? '';
      }
    });
  }

  Future<void> _toggleFavorite(String text) async {
    final db = ref.read(localDatabaseProvider);
    final category = switch (_activeTab) {
      StudioTab.reply => '$_replyTone • $_selectedLanguage',
      StudioTab.vibeCheck => '$_vibeMode • $_selectedLanguage',
      StudioTab.caption => '$_captionVibe • $_captionPlatform',
      StudioTab.bio => '$_bioVibe • $_bioPlatform',
    };
    final newFav = await db.toggleFavoriteByContent(
      content: text,
      type: _activeTab.id,
      category: category,
      title: text.length > 35 ? '${text.substring(0, 35)}...' : text,
    );
    ref.read(historyRevisionProvider.notifier).state++;
    if (mounted) {
      HapticFeedback.selectionClick();
      setState(() {
        if (newFav) {
          _favoritedTexts.add(text);
        } else {
          _favoritedTexts.remove(text);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newFav ? 'Saved to Favorites' : 'Removed from Favorites'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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

    if (mounted) {
      final isQuotaExceeded = switch (_activeTab) {
        StudioTab.reply => ref.read(replyGenerationProvider).isQuotaExceeded,
        StudioTab.vibeCheck => ref.read(vibeCheckGenerationProvider).isQuotaExceeded,
        StudioTab.caption => ref.read(captionGenerationProvider).isQuotaExceeded,
        StudioTab.bio => ref.read(bioGenerationProvider).isQuotaExceeded,
      };
      if (isQuotaExceeded) {
        context.push('/paywall');
        return;
      }
      if (success) {
        HapticFeedback.lightImpact();
        ref.read(streakProvider.notifier).recordAction('generate');
        final activeOption = switch (_activeTab) {
          StudioTab.reply => _replyTone,
          StudioTab.vibeCheck => _vibeMode,
          StudioTab.caption => _captionVibe,
          StudioTab.bio => _bioVibe,
        };
        final prefs = ref.read(preferencesServiceProvider);
        await prefs.recordToneUsed(activeOption);
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
                      final isSelected = _textController.text.trim() == sample['text']!.trim();
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text(
                            sample['label']!,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected
                                  ? (isDark ? AppColors.accentWarm : AppColors.primary)
                                  : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                            ),
                          ),
                          backgroundColor: isSelected
                              ? (isDark
                                  ? AppColors.primary.withValues(alpha: 0.25)
                                  : AppColors.primary.withValues(alpha: 0.12))
                              : (isDark ? AppColors.surfaceCardDark : AppColors.surfaceCardLight),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected
                                  ? (isDark ? AppColors.accentWarm : AppColors.primary)
                                  : (isDark ? AppColors.borderDark : AppColors.borderLight),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          onPressed: () {
                            HapticFeedback.selectionClick();
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
                          filled: false,
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
                      border: Border.all(
                        color: isDark ? AppColors.accentWarm : AppColors.primary,
                        width: 3,
                      ),
                      color: (isDark ? AppColors.accentWarm : AppColors.primary).withOpacity(0.1),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${res.score}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: isDark ? AppColors.accentWarm : AppColors.primary,
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
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppColors.accentWarm : AppColors.primary,
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
                  IconButton(
                    tooltip: _reportedContents.contains(res.verdict) ? 'Reported' : 'Report content',
                    onPressed: _reportedContents.contains(res.verdict)
                        ? null
                        : () => _reportContent('${res.title}: ${res.verdict}', 'studio_vibe_check_verdict'),
                    icon: Icon(
                      _reportedContents.contains(res.verdict)
                          ? Icons.flag_rounded
                          : Icons.flag_outlined,
                      size: 18,
                      color: _reportedContents.contains(res.verdict)
                          ? AppColors.accentPink
                          : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
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
            ...res.hooks.asMap().entries.map((e) {
              return _buildOutputCard(
                context: context,
                title: 'Reel Hook ${e.key + 1}',
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

  Future<void> _reportContent(String content, String category) async {
    final reported = await showReportAiContentDialog(
      context,
      category: category,
      content: content,
    );
    if (reported && mounted) {
      setState(() => _reportedContents.add(content));
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
                  color: (isDark ? AppColors.accentWarm : AppColors.primary).withOpacity(0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.accentWarm : AppColors.primary,
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
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              runSpacing: 2,
              children: [
                TextButton.icon(
                  onPressed: () => _toggleFavorite(content),
                  icon: Icon(
                    _favoritedTexts.contains(content)
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 15,
                    color: _favoritedTexts.contains(content) ? AppColors.accentPink : null,
                  ),
                  label: Text(
                    _favoritedTexts.contains(content) ? 'Saved' : 'Save',
                    style: TextStyle(
                      fontSize: 12,
                      color: _favoritedTexts.contains(content) ? AppColors.accentPink : null,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: isDark ? AppColors.textPrimaryDark : AppColors.primary,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
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
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    context.push('/card-maker', extra: {'text': content});
                  },
                  icon: const Icon(Icons.style_outlined, size: 15),
                  label: const Text('Card', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: isDark ? AppColors.textPrimaryDark : AppColors.primary,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Share.share(content);
                  },
                  icon: const Icon(Icons.share_outlined, size: 15),
                  label: const Text('Share', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: isDark ? AppColors.textPrimaryDark : AppColors.primary,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                TextButton.icon(
                  onPressed: _reportedContents.contains(content)
                      ? null
                      : () => _reportContent(content, 'studio_${_activeTab.id}'),
                  icon: Icon(
                    _reportedContents.contains(content)
                        ? Icons.flag_rounded
                        : Icons.flag_outlined,
                    size: 15,
                    color: _reportedContents.contains(content) ? AppColors.accentPink : null,
                  ),
                  label: Text(
                    _reportedContents.contains(content) ? 'Reported' : 'Report',
                    style: TextStyle(
                      fontSize: 12,
                      color: _reportedContents.contains(content) ? AppColors.accentPink : null,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
