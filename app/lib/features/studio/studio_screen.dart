import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_durations.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/app_bottom_nav.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_shimmer.dart';
import '../../core/widgets/motion_widgets.dart';
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
  final GlobalKey _resultsAnchorKey = GlobalKey();
  final Set<String> _favoritedTexts = {};
  final Set<String> _reportedContents = {};
  final Set<String> _copiedContents = {};

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
    'Chill',
  ];

  int get _maxChars => switch (_activeTab) {
        StudioTab.reply => 500,
        StudioTab.vibeCheck => 600,
        StudioTab.caption => 400,
        StudioTab.bio => 300,
      };

  String _reportKey(String category, String content) => '$category::$content';

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

    if (widget.initialPrompt != null) {
      final incoming = widget.initialPrompt!;
      _textController.text =
          incoming.length > _maxChars ? incoming.substring(0, _maxChars) : incoming;
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
      final nextTab = StudioTab.fromId(widget.initialTabId);
      final currentText = _textController.text.trim();
      final isCurrentSampleOrEmpty = currentText.isEmpty ||
          (_sampleChips[_activeTab]?.any((s) => s['text']!.trim() == currentText) ?? false);
      _activeTab = nextTab;
      if (isCurrentSampleOrEmpty && widget.initialPrompt == null) {
        _textController.text = _sampleChips[nextTab]?.first['text'] ?? '';
      }
    }
    if (widget.initialPrompt != null && widget.initialPrompt != oldWidget.initialPrompt) {
      final incoming = widget.initialPrompt!;
      _textController.text = incoming.length > _maxChars ? incoming.substring(0, _maxChars) : incoming;
    } else if (_textController.text.length > _maxChars) {
      _textController.text = _textController.text.substring(0, _maxChars);
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
    final nextMax = switch (tab) {
      StudioTab.reply => 500,
      StudioTab.vibeCheck => 600,
      StudioTab.caption => 400,
      StudioTab.bio => 300,
    };
    setState(() {
      _activeTab = tab;
      if (isCurrentSampleOrEmpty) {
        _textController.text = _sampleChips[tab]?.first['text'] ?? '';
      } else if (_textController.text.length > nextMax) {
        _textController.text = _textController.text.substring(0, nextMax);
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
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final resultsCtx = _resultsAnchorKey.currentContext;
            if (resultsCtx != null) {
              Scrollable.ensureVisible(
                resultsCtx,
                duration: AppDurations.slow,
                curve: AppCurves.espressoPour,
                alignment: 0.08,
              );
            }
          });
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
                // Top Gliding Segmented Mode Switcher
                SlidingSegmentedPill<StudioTab>(
                  items: StudioTab.values,
                  selectedItem: _activeTab,
                  labelBuilder: (tab) => tab.label,
                  onSelected: _switchTab,
                ),
                const SizedBox(height: AppSpacing.md),

                // Description Banner
                AnimatedSwitcher(
                  duration: AppDurations.fast,
                  child: Container(
                    key: ValueKey<StudioTab>(_activeTab),
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
                ),
                const SizedBox(height: AppSpacing.md),

                // Quick Inspiration Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: (_sampleChips[_activeTab] ?? []).map((sample) {
                      final isSelected = _textController.text.trim() == sample['text']!.trim();
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: TactileScale(
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
                        maxLength: _maxChars,
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
                            '${_textController.text.length}/$_maxChars',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontFeatures: AppTypography.tabularFigures,
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

                // Language Selector Pill
                Row(
                  children: [
                    Icon(
                      Icons.translate_rounded,
                      size: 15,
                      color: isDark ? AppColors.accentWarm : AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Language:',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceCardDark : AppColors.surfaceCardLight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedLanguage,
                          isDense: true,
                          borderRadius: BorderRadius.circular(14),
                          dropdownColor: isDark ? AppColors.surfaceCardDark : AppColors.surfaceCardLight,
                          items: _languages.map((l) {
                            return DropdownMenuItem<String>(
                              value: l,
                              child: Text(
                                l,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedLanguage = val);
                              ref.read(languageProvider.notifier).setLanguage(val);
                            }
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

                // Output Rendering (Result Skeleton Theater → Staggered Cards)
                KeyedSubtree(
                  key: _resultsAnchorKey,
                  child: isGenerating
                      ? const Column(
                          children: [
                            ResultCardSkeleton(),
                            ResultCardSkeleton(),
                            ResultCardSkeleton(),
                          ],
                        )
                      : _buildResultsForActiveTab(isDark, theme),
                ),
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
        return _buildChipSelector<String>(
          title: 'Select Tone',
          items: _replyTones,
          isSelectedFn: (tone) => _replyTone == tone,
          labelFn: (tone) => tone,
          onSelectedFn: (tone) => setState(() => _replyTone = tone),
          isDark: isDark,
          theme: theme,
        );

      case StudioTab.vibeCheck:
        return _buildChipSelector<Map<String, String>>(
          title: 'Vibe Check Mode',
          items: _vibeModes,
          isSelectedFn: (m) => _vibeMode == m['id'],
          labelFn: (m) => m['label']!,
          onSelectedFn: (m) => setState(() => _vibeMode = m['id']!),
          isDark: isDark,
          theme: theme,
        );

      case StudioTab.caption:
        return _buildChipSelector<String>(
          title: 'Caption Vibe',
          items: _captionVibes,
          isSelectedFn: (vibe) => _captionVibe == vibe,
          labelFn: (vibe) => vibe,
          onSelectedFn: (vibe) => setState(() => _captionVibe = vibe),
          isDark: isDark,
          theme: theme,
        );

      case StudioTab.bio:
        return _buildChipSelector<String>(
          title: 'Bio Vibe',
          items: _bioVibes,
          isSelectedFn: (vibe) => _bioVibe == vibe,
          labelFn: (vibe) => vibe,
          onSelectedFn: (vibe) => setState(() => _bioVibe = vibe),
          isDark: isDark,
          theme: theme,
        );
    }
  }

  Widget _buildChipSelector<T>({
    required String title,
    required List<T> items,
    required bool Function(T item) isSelectedFn,
    required String Function(T item) labelFn,
    required ValueChanged<T> onSelectedFn,
    required bool isDark,
    required ThemeData theme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items.map((item) {
            final isSelected = isSelectedFn(item);
            return TactileScale(
              pressedScale: 0.94,
              child: ChoiceChip(
                selected: isSelected,
                label: Text(labelFn(item)),
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
                    HapticFeedback.selectionClick();
                    onSelectedFn(item);
                  }
                },
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildResultsForActiveTab(bool isDark, ThemeData theme) {
    switch (_activeTab) {
      case StudioTab.reply:
        final res = ref.watch(replyGenerationProvider).result;
        if (res == null) return const SizedBox.shrink();
        return Column(
          children: res.suggestions.asMap().entries.map((e) {
            return StaggeredEntrance(
              key: ValueKey('reply_${e.key}_${e.value.hashCode}'),
              index: e.key,
              child: _buildOutputCard(
                context: context,
                title: 'Option ${e.key + 1}',
                content: e.value,
                isDark: isDark,
                theme: theme,
              ),
            );
          }).toList(),
        );

      case StudioTab.vibeCheck:
        final res = ref.watch(vibeCheckGenerationProvider).result;
        if (res == null) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Score & Roast Summary with Animated Score Dial
            StaggeredEntrance(
              key: ValueKey('vc_summary_${res.title}_${res.score}'),
              index: 0,
              child: Container(
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
                      child: TweenAnimationBuilder<int>(
                        tween: IntTween(begin: 0, end: res.score),
                        duration: AppDurations.chart,
                        curve: AppCurves.espressoPour,
                        builder: (context, val, _) => Text(
                          '$val',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            fontFeatures: AppTypography.tabularFigures,
                            color: isDark ? AppColors.accentWarm : AppColors.primary,
                          ),
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
                      tooltip: _reportedContents.contains(_reportKey('studio_vibe_check_verdict', '${res.title}: ${res.verdict}'))
                          ? 'Reported'
                          : 'Report content',
                      onPressed: _reportedContents.contains(_reportKey('studio_vibe_check_verdict', '${res.title}: ${res.verdict}'))
                          ? null
                          : () => _reportContent('${res.title}: ${res.verdict}', 'studio_vibe_check_verdict'),
                      icon: Icon(
                        _reportedContents.contains(_reportKey('studio_vibe_check_verdict', '${res.title}: ${res.verdict}'))
                            ? Icons.flag_rounded
                            : Icons.flag_outlined,
                        size: 18,
                        color: _reportedContents.contains(_reportKey('studio_vibe_check_verdict', '${res.title}: ${res.verdict}'))
                            ? AppColors.accentPink
                            : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (res.tags.isNotEmpty) ...[
              StaggeredEntrance(
                index: 1,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: res.tags.map((tag) {
                    final cleanTag = tag.startsWith('#') ? tag : '#$tag';
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceCardLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        ),
                      ),
                      child: Text(
                        cleanTag,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.accentWarm : AppColors.primary,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
            ],
            ...res.rewrites.asMap().entries.map((e) {
              return StaggeredEntrance(
                key: ValueKey('vc_rewrite_${e.key}_${e.value.hashCode}'),
                index: e.key + 2,
                child: _buildOutputCard(
                  context: context,
                  title: 'Rewrite ${e.key + 1}',
                  content: e.value,
                  isDark: isDark,
                  theme: theme,
                ),
              );
            }),
          ],
        );

      case StudioTab.caption:
        final res = ref.watch(captionGenerationProvider).result;
        if (res == null) return const SizedBox.shrink();
        final cards = <Widget>[
          ...res.captions.asMap().entries.map(
                (e) => _buildOutputCard(
                  context: context,
                  title: 'Caption ${e.key + 1}',
                  content: e.value,
                  isDark: isDark,
                  theme: theme,
                ),
              ),
          ...res.hooks.asMap().entries.map(
                (e) => _buildOutputCard(
                  context: context,
                  title: 'Reel Hook ${e.key + 1}',
                  content: e.value,
                  isDark: isDark,
                  theme: theme,
                ),
              ),
          ...res.callToActions.asMap().entries.map(
                (e) => _buildOutputCard(
                  context: context,
                  title: 'Call to Action ${e.key + 1}',
                  content: e.value,
                  isDark: isDark,
                  theme: theme,
                ),
              ),
          if (res.hashtags.isNotEmpty)
            _buildOutputCard(
              context: context,
              title: 'Viral Hashtags',
              content: res.hashtags.map((h) => h.startsWith('#') ? h : '#$h').join(' '),
              isDark: isDark,
              theme: theme,
            ),
        ];
        return Column(
          children: [
            for (int i = 0; i < cards.length; i++)
              StaggeredEntrance(
                key: ValueKey('cap_${i}_${res.captions.hashCode}'),
                index: i,
                child: cards[i],
              ),
          ],
        );

      case StudioTab.bio:
        final res = ref.watch(bioGenerationProvider).result;
        if (res == null) return const SizedBox.shrink();
        final cards = <Widget>[
          ...res.bios.asMap().entries.map(
                (e) => _buildOutputCard(
                  context: context,
                  title: 'Bio ${e.key + 1}',
                  content: e.value,
                  isDark: isDark,
                  theme: theme,
                ),
              ),
          if (res.usernames.isNotEmpty)
            _buildOutputCard(
              context: context,
              title: 'Suggested Handles',
              content: res.usernames.join('   •   '),
              isDark: isDark,
              theme: theme,
            ),
        ];
        return Column(
          children: [
            for (int i = 0; i < cards.length; i++)
              StaggeredEntrance(
                key: ValueKey('bio_${i}_${res.bios.hashCode}'),
                index: i,
                child: cards[i],
              ),
          ],
        );
    }
  }

  Future<void> _reportContent(String content, String category) async {
    final key = _reportKey(category, content);
    final reported = await showReportAiContentDialog(
      context,
      category: category,
      content: content,
    );
    if (reported && mounted) {
      setState(() => _reportedContents.add(key));
    }
  }

  Widget _buildOutputCard({
    required BuildContext context,
    required String title,
    required String content,
    required bool isDark,
    required ThemeData theme,
  }) {
    final isCopied = _copiedContents.contains(content);
    final isFav = _favoritedTexts.contains(content);

    return AnimatedContainer(
      duration: AppDurations.fast,
      curve: AppCurves.espressoPour,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCopied
            ? AppColors.success.withValues(alpha: isDark ? 0.10 : 0.05)
            : (isDark ? AppColors.surfaceCardDark : AppColors.surfaceCardLight),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCopied
              ? AppColors.success
              : (isDark ? AppColors.borderDark : AppColors.borderLight),
          width: isCopied ? 1.5 : 1.0,
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
                TactileScale(
                  child: TextButton.icon(
                    onPressed: () => _toggleFavorite(content),
                    icon: AnimatedSwitcher(
                      duration: AppDurations.normal,
                      switchInCurve: AppCurves.cremaSpring,
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: Icon(
                        isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        key: ValueKey<bool>(isFav),
                        size: 15,
                        color: isFav ? AppColors.accentPink : null,
                      ),
                    ),
                    label: Text(
                      isFav ? 'Saved' : 'Save',
                      style: TextStyle(
                        fontSize: 12,
                        color: isFav ? AppColors.accentPink : null,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? AppColors.textPrimaryDark : AppColors.primary,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                TactileScale(
                  child: TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: content));
                      HapticFeedback.lightImpact();
                      setState(() => _copiedContents.add(content));
                      Future.delayed(const Duration(seconds: 2), () {
                        if (mounted) {
                          setState(() => _copiedContents.remove(content));
                        }
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Copied to clipboard!'),
                          duration: Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: AnimatedSwitcher(
                      duration: AppDurations.fast,
                      switchInCurve: AppCurves.cremaSpring,
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: Icon(
                        isCopied ? Icons.check_rounded : Icons.copy_rounded,
                        key: ValueKey<bool>(isCopied),
                        size: 15,
                        color: isCopied ? AppColors.success : null,
                      ),
                    ),
                    label: Text(
                      isCopied ? 'Copied' : 'Copy',
                      style: TextStyle(
                        fontSize: 12,
                        color: isCopied ? AppColors.success : null,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? AppColors.textPrimaryDark : AppColors.primary,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                TactileScale(
                  child: TextButton.icon(
                    onPressed: () {
                      context.push('/card-maker', extra: {'text': content});
                    },
                    icon: const Icon(Icons.style_outlined, size: 15),
                    label: const Text('Card', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    style: TextButton.styleFrom(
                      backgroundColor: (isDark ? AppColors.accent : AppColors.primary)
                          .withValues(alpha: 0.12),
                      foregroundColor: isDark ? AppColors.accentWarm : AppColors.primary,
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppSpacing.roundedFull,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                TactileScale(
                  child: TextButton.icon(
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
                ),
                TactileScale(
                  child: TextButton.icon(
                    onPressed: _reportedContents.contains(_reportKey('studio_${_activeTab.id}', content))
                        ? null
                        : () => _reportContent(content, 'studio_${_activeTab.id}'),
                    icon: Icon(
                      _reportedContents.contains(_reportKey('studio_${_activeTab.id}', content))
                          ? Icons.flag_rounded
                          : Icons.flag_outlined,
                      size: 15,
                      color: _reportedContents.contains(_reportKey('studio_${_activeTab.id}', content)) ? AppColors.accentPink : null,
                    ),
                    label: Text(
                      _reportedContents.contains(_reportKey('studio_${_activeTab.id}', content)) ? 'Reported' : 'Report',
                      style: TextStyle(
                        fontSize: 12,
                        color: _reportedContents.contains(_reportKey('studio_${_activeTab.id}', content)) ? AppColors.accentPink : null,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      visualDensity: VisualDensity.compact,
                    ),
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
