import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_durations.dart';
import '../../core/constants/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/card_export_service.dart';
import '../../core/services/share_service.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/achievement_service.dart';
import '../../core/widgets/app_bottom_nav.dart';
import '../../core/widgets/motion_widgets.dart';
import '../../models/history_item.dart';
import '../../models/streak_model.dart';
import '../streaks/providers/streak_provider.dart';
import 'card_canvas.dart';
import 'card_templates.dart';

class CardMakerScreen extends ConsumerStatefulWidget {
  final String? initialText;

  const CardMakerScreen({super.key, this.initialText});

  @override
  ConsumerState<CardMakerScreen> createState() => _CardMakerScreenState();
}

class _CardMakerScreenState extends ConsumerState<CardMakerScreen> {
  final GlobalKey _repaintKey = GlobalKey();
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _authorController = TextEditingController();

  CardTemplate _selectedTemplate = CardTemplates.all.first;
  CardStyle _selectedStyle = CardStyle.quote;
  CardFontFamily _selectedFont = CardFontFamily.modernSans;
  double _aspectRatio = 1.0; // 1:1 Square default
  TextAlign _textAlign = TextAlign.center;
  double _fontSize = 20.0;
  bool _isExporting = false;
  bool _isSavingFavorite = false;
  int _activeEditorTab = 0; // 0: Content, 1: Style & Templates, 2: Typography & Ratio

  final List<Map<String, dynamic>> _aspectRatios = [
    {
      'name': '1:1',
      'label': 'Square',
      'ratio': 1.0,
      'icon': Icons.crop_square_rounded,
    },
    {
      'name': '9:16',
      'label': 'Story / Reel',
      'ratio': 9 / 16,
      'icon': Icons.stay_current_portrait_rounded,
    },
    {
      'name': '4:5',
      'label': 'Portrait Feed',
      'ratio': 4 / 5,
      'icon': Icons.crop_portrait_rounded,
    },
    {
      'name': '16:9',
      'label': 'Landscape',
      'ratio': 16 / 9,
      'icon': Icons.crop_16_9_rounded,
    },
  ];

  static const List<Map<String, String>> _viralIdeaPrompts = [
    {
      'category': 'Dating',
      'quote': 'Texted first, immediately put phone in refrigerator.',
      'author': 'unbothered',
    },
    {
      'category': 'Dating',
      'quote': 'My love language is matching my energy without asking.',
      'author': 'rizz_god',
    },
    {
      'category': 'Relatable',
      'quote': 'My day is 10% productivity and 90% contemplating life choices.',
      'author': 'vibekit',
    },
    {
      'category': 'Relatable',
      'quote': 'Holding it all together with iced coffee and sheer willpower.',
      'author': 'aesthetic',
    },
    {
      'category': 'Meme',
      'quote': 'I’m not arguing, I’m just passionately explaining why I’m right.',
      'author': 'savage_quotes',
    },
    {
      'category': 'Meme',
      'quote': 'My wallet is like an onion. When I open it, it makes me cry.',
      'author': 'daily_banter',
    },
    {
      'category': 'Grind',
      'quote': 'Quiet ambition. Let the results make all the noise.',
      'author': 'visionary',
    },
    {
      'category': 'Grind',
      'quote': 'In a world of fast trends, build something that lasts forever.',
      'author': 'founder_vibe',
    },
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialText != null && widget.initialText!.isNotEmpty) {
      _textController.text = widget.initialText!;
    } else {
      _textController.text = 'Late night coffee & big dreams.';
      _authorController.text = 'vibekit';
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  bool _isTemplateUnlocked(
    CardTemplate template,
    bool isPro,
    StreakModel streak,
  ) {
    if (!template.isProOnly || isPro) return true;
    if (template.id == 'aura_glow' && streak.isMilestoneClaimed(7)) return true;
    if (template.id == 'cyberpunk_neon' && streak.isMilestoneClaimed(14)) return true;
    return false;
  }

  void _shuffleInspiration() {
    HapticFeedback.lightImpact();
    final random = Random();
    final prompt = _viralIdeaPrompts[random.nextInt(_viralIdeaPrompts.length)];
    final isPro = ref.read(quotaProvider).isPro;
    final streak = ref.read(streakProvider);
    final unlockedTemplates = CardTemplates.all
        .where((t) => _isTemplateUnlocked(t, isPro, streak))
        .toList();
    final template = unlockedTemplates.isNotEmpty
        ? unlockedTemplates[random.nextInt(unlockedTemplates.length)]
        : CardTemplates.all.first;
    const styles = CardStyle.values;
    final style = styles[random.nextInt(styles.length)];

    setState(() {
      _textController.text = prompt['quote']!;
      _authorController.text = prompt['author']!;
      _selectedTemplate = template;
      _selectedStyle = style;
      _textAlign = style == CardStyle.socialPost ? TextAlign.left : TextAlign.center;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✨ Shuffled: ${prompt['category']} style loaded!'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _copyTextToClipboard() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.selectionClick();
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copied card text to clipboard!'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _exportAndShare() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter text for your card.')),
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      final pngBytes = await CardExportService.captureCardBytes(_repaintKey);
      final filePath = pngBytes != null
          ? await CardExportService.saveCardBytes(pngBytes, persistent: true)
          : null;
      if (!mounted) return;
      setState(() => _isExporting = false);

      if (filePath != null || pngBytes != null) {
        HapticFeedback.mediumImpact();
        final db = ref.read(localDatabaseProvider);
        await db.insertItem(
          HistoryItem(
            id: const Uuid().v4(),
            title: text.length > 30 ? '${text.substring(0, 30)}...' : text,
            content: text,
            type: 'card',
            category: _selectedTemplate.name,
            createdAt: DateTime.now(),
            extraData: _encodeExtraData(filePath, pngBytes),
          ),
        );
        ref.read(historyRevisionProvider.notifier).state++;
        final instId = ref.read(preferencesServiceProvider).getAppInstanceId();
        await ShareService.shareImage(
          filePath ?? '',
          text: text,
          installationId: instId,
          imageBytes: pngBytes,
        );
        AnalyticsService.instance.logShareCard();
        ref.read(streakProvider.notifier).recordAction('card_export');

        await ref.read(preferencesServiceProvider).incrementCardsExported();
        if (mounted) {
          await ref.read(achievementServiceProvider).checkAndUnlockAchievements(context: context);
        }

        ref.read(adMobServiceProvider).showInterstitialAd();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to render image card.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isExporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting card: $e')),
      );
    }
  }

  String? _encodeExtraData(String? filePath, Uint8List? pngBytes) {
    if (kIsWeb && pngBytes != null && pngBytes.lengthInBytes <= 180000) {
      return 'data:image/png;base64,${base64Encode(pngBytes)}';
    }
    return filePath;
  }

  Future<void> _saveToFavorites() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSavingFavorite) return;

    setState(() => _isSavingFavorite = true);
    try {
      final pngBytes = await CardExportService.captureCardBytes(_repaintKey);
      final filePath = pngBytes != null
          ? await CardExportService.saveCardBytes(pngBytes, persistent: true)
          : null;
      if (!mounted) return;

      if (pngBytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not capture card preview. Please try again.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final db = ref.read(localDatabaseProvider);
      await db.insertItem(
        HistoryItem(
          id: const Uuid().v4(),
          title: text.length > 30 ? '${text.substring(0, 30)}...' : text,
          content: text,
          type: 'card',
          category: _selectedTemplate.name,
          createdAt: DateTime.now(),
          isFavorite: true,
          extraData: _encodeExtraData(filePath, pngBytes),
        ),
      );
      if (!mounted) return;
      ref.read(historyRevisionProvider.notifier).state++;

      HapticFeedback.selectionClick();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Card saved to Favorites & History!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save favorite card: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingFavorite = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quota = ref.watch(quotaProvider);
    final streak = ref.watch(streakProvider);
    final showWatermark = !quota.isPro;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: const Text('Meme & Card Studio'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.shuffle_rounded),
            tooltip: 'Surprise Me (Shuffle)',
            onPressed: _shuffleInspiration,
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Copy Text',
            onPressed: _copyTextToClipboard,
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_add_outlined),
            tooltip: 'Save to Favorites',
            onPressed: _saveToFavorites,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Live Interactive Canvas Area (Ambient Darkroom Stage + Morph)
              AnimatedContainer(
                duration: AppDurations.normal,
                curve: AppCurves.espressoPour,
                constraints: const BoxConstraints(maxHeight: 340),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.95,
                    colors: [
                      _selectedTemplate.accentColor.withValues(alpha: isDark ? 0.16 : 0.11),
                      isDark
                          ? AppColors.surfaceElevatedDark.withValues(alpha: 0.35)
                          : const Color(0xFFF3EDE2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    width: 1.2,
                  ),
                ),
                child: Center(
                  child: CardCanvas(
                    repaintKey: _repaintKey,
                    text: _textController.text,
                    author: _authorController.text,
                    template: _selectedTemplate,
                    aspectRatio: _aspectRatio,
                    textAlign: _textAlign,
                    fontSize: _fontSize,
                    showWatermark: showWatermark,
                    style: _selectedStyle,
                    fontFamily: _selectedFont,
                  ),
                ),
              ),

              // 2. Editor Gliding Segmented Tab Bar
              SlidingSegmentedPill<int>(
                items: const [0, 1, 2],
                selectedItem: _activeEditorTab,
                labelBuilder: (idx) => switch (idx) {
                  0 => 'Content',
                  1 => 'Style',
                  _ => 'Layout',
                },
                iconBuilder: (idx) => switch (idx) {
                  0 => Icons.edit_note_rounded,
                  1 => Icons.palette_outlined,
                  _ => Icons.tune_rounded,
                },
                onSelected: (idx) => setState(() => _activeEditorTab = idx),
              ),
              const SizedBox(height: 12),

              // 3. Tab Contents
              AnimatedSwitcher(
                duration: AppDurations.fast,
                switchInCurve: AppCurves.espressoPour,
                child: KeyedSubtree(
                  key: ValueKey<int>(_activeEditorTab),
                  child: _buildActiveTabContent(isDark, quota.isPro, streak),
                ),
              ),

              const SizedBox(height: 16),

              // 4. Modern Primary Action Bar
              _buildBottomActionBar(isDark),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
    );
  }

  Widget _buildActiveTabContent(bool isDark, bool isPro, StreakModel streak) {
    switch (_activeEditorTab) {
      case 0:
        return _buildContentTab(isDark);
      case 1:
        return _buildStyleTab(isDark, isPro, streak);
      case 2:
      default:
        return _buildLayoutTab(isDark, isPro);
    }
  }

  // TAB 0: CONTENT & VIRAL CHIPS
  Widget _buildContentTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quick Viral Inspiration Chips
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Instant Inspiration',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
            InkWell(
              onTap: _shuffleInspiration,
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  children: [
                    Icon(Icons.refresh_rounded, size: 13, color: AppColors.accent),
                    SizedBox(width: 3),
                    Text(
                      'More ideas',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: _viralIdeaPrompts.take(6).map((item) {
              return Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 4),
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _textController.text = item['quote']!;
                      _authorController.text = item['author']!;
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceCardLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '#${item['category']}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          item['quote']!.length > 25
                              ? '${item['quote']!.substring(0, 25)}...'
                              : item['quote']!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),

        // Main Text Field
        TextField(
          controller: _textController,
          maxLines: 3,
          maxLength: 300,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
          decoration: InputDecoration(
            hintText: 'Enter your quote, funny text, tweet or meme...',
            suffixIcon: _textController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () {
                      _textController.clear();
                      setState(() {});
                    },
                  )
                : null,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),

        // Author / Handle Field
        TextField(
          controller: _authorController,
          maxLength: 40,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
          decoration: const InputDecoration(
            hintText: 'Author, handle, or meme setup (e.g. @username)',
            prefixIcon: Icon(Icons.alternate_email_rounded, size: 16),
            counterText: '',
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  // TAB 1: CARD STYLE & TEMPLATES
  Widget _buildStyleTab(bool isDark, bool isPro, StreakModel streak) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Card Layout Selector
        Text(
          'Format Preset',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: CardStyle.values.map((style) {
            final isSelected = _selectedStyle == style;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: TactileScale(
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedStyle = style;
                        if (style == CardStyle.socialPost) {
                          _textAlign = TextAlign.left;
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: AppDurations.fast,
                      curve: AppCurves.espressoPour,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : (isDark ? AppColors.surfaceCardDark : AppColors.surfaceCardLight),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : (isDark ? AppColors.borderDark : AppColors.borderLight),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            style.icon,
                            size: 18,
                            color: isSelected ? Colors.white : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            style.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? Colors.white : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),

        // 2. Templates Carousel
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Aesthetic Palettes',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
            if (!isPro)
              const Text(
                '👑 Pro unlocked templates',
                style: TextStyle(fontSize: 11, color: AppColors.accent),
              ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 85,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: CardTemplates.all.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final t = CardTemplates.all[index];
              final isUnlocked = _isTemplateUnlocked(t, isPro, streak);
              final isSelected = _selectedTemplate.id == t.id;
              return TactileScale(
                child: InkWell(
                  onTap: () {
                    if (!isUnlocked) {
                      context.push('/paywall');
                      return;
                    }
                    HapticFeedback.selectionClick();
                    setState(() => _selectedTemplate = t);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: AppDurations.fast,
                    curve: AppCurves.espressoPour,
                    width: 82,
                    decoration: BoxDecoration(
                      gradient: t.backgroundGradient,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppColors.accent : Colors.white.withValues(alpha: 0.15),
                        width: isSelected ? 2.8 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                  child: Stack(
                    children: [
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            t.name,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: t.textColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      if (!isUnlocked)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.black87,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.lock, size: 10, color: Colors.amber),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              );
            },
          ),
        ),
      ],
    );
  }

  TextStyle _previewFontStyle(
    CardFontFamily font,
    bool isSelected,
    bool isDark,
  ) {
    final color = isSelected
        ? Colors.white
        : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight);
    final weight = isSelected ? FontWeight.bold : FontWeight.w500;
    return switch (font) {
      CardFontFamily.modernSans =>
        GoogleFonts.outfit(fontSize: 11, fontWeight: weight, color: color),
      CardFontFamily.editorialSerif =>
        GoogleFonts.playfairDisplay(fontSize: 11, fontWeight: weight, color: color),
      CardFontFamily.boldImpact =>
        GoogleFonts.anton(fontSize: 11, fontWeight: weight, color: color, letterSpacing: 0.4),
      CardFontFamily.techMono =>
        GoogleFonts.spaceMono(fontSize: 10.5, fontWeight: weight, color: color),
    };
  }

  // TAB 2: TYPOGRAPHY, ALIGNMENT & RATIOS
  Widget _buildLayoutTab(bool isDark, bool isPro) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Font Family Picker (rendered in each typeface!)
        Text(
          'Font Family',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: CardFontFamily.values.map((font) {
            final isSelected = _selectedFont == font;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: TactileScale(
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedFont = font);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: AppDurations.fast,
                      curve: AppCurves.espressoPour,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : (isDark ? AppColors.surfaceCardDark : AppColors.surfaceCardLight),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : (isDark ? AppColors.borderDark : AppColors.borderLight),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          font.label.split(' ').last,
                          style: _previewFontStyle(font, isSelected, isDark),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // 2. Alignment & Size Row
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Alignment',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildAlignButton(TextAlign.left, Icons.format_align_left_rounded, isDark),
                      const SizedBox(width: 4),
                      _buildAlignButton(TextAlign.center, Icons.format_align_center_rounded, isDark),
                      const SizedBox(width: 4),
                      _buildAlignButton(TextAlign.right, Icons.format_align_right_rounded, isDark),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Font Size',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        ),
                      ),
                      Text(
                        '${_fontSize.toInt()}pt',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          fontFeatures: AppTypography.tabularFigures,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _fontSize,
                    min: 14.0,
                    max: 34.0,
                    divisions: 10,
                    activeColor: isDark ? AppColors.accentWarm : AppColors.primary,
                    onChanged: (val) => setState(() => _fontSize = val),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 3. Aspect Ratio Selector
        Text(
          'Format & Aspect Ratio',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: _aspectRatios.map((ar) {
            final ratio = ar['ratio'] as double;
            final isSelected = _aspectRatio == ratio;
            final selectedAccent = isDark ? AppColors.accentWarm : AppColors.primary;
            final frameColor = isSelected
                ? selectedAccent
                : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight);
            final Size boxSize = ratio == 1.0
                ? const Size(15, 15)
                : (ratio < 0.7
                    ? const Size(10, 17)
                    : (ratio < 1.0
                        ? const Size(13, 16)
                        : const Size(18, 11)));

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: TactileScale(
                  child: OutlinedButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() => _aspectRatio = ratio);
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: isSelected
                            ? selectedAccent
                            : (isDark ? AppColors.borderDark : AppColors.borderLight),
                        width: isSelected ? 1.5 : 1,
                      ),
                      backgroundColor:
                          isSelected ? selectedAccent.withValues(alpha: 0.14) : null,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 18,
                          child: Center(
                            child: AnimatedContainer(
                              duration: AppDurations.fast,
                              width: boxSize.width,
                              height: boxSize.height,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(
                                  color: frameColor,
                                  width: isSelected ? 1.8 : 1.3,
                                ),
                                color: isSelected
                                    ? selectedAccent.withValues(alpha: 0.2)
                                    : Colors.transparent,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          ar['name'] as String,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontFeatures: AppTypography.tabularFigures,
                            color: isSelected ? selectedAccent : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        // 4. Pro Watermark Badge
        Container(
          margin: const EdgeInsets.only(top: 14, bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceCardDark : AppColors.surfaceCardLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
          ),
          child: Row(
            children: [
              Icon(
                isPro ? Icons.verified_rounded : Icons.info_outline_rounded,
                size: 16,
                color: isPro ? AppColors.success : AppColors.accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isPro
                      ? 'Pro Active: Export cards in crisp high-dpi without watermarks.'
                      : 'Free exports include subtle watermark. Upgrade to Pro for watermark-free cards.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAlignButton(TextAlign align, IconData icon, bool isDark) {
    final isSelected = _textAlign == align;
    return TactileScale(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _textAlign = align);
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: AppDurations.fast,
          curve: AppCurves.espressoPour,
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : (isDark ? AppColors.surfaceCardDark : AppColors.surfaceCardLight),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.primary : (isDark ? AppColors.borderDark : AppColors.borderLight),
            ),
          ),
          child: Icon(
            icon,
            size: 16,
            color: isSelected ? Colors.white : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
          ),
        ),
      ),
    );
  }

  // 4. Modern Primary Action Bar
  Widget _buildBottomActionBar(bool isDark) {
    return TactileScale(
      enabled: !_isExporting,
      child: SizedBox(
        height: 48,
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isExporting ? null : _exportAndShare,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 2,
          ),
          icon: _isExporting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.share_rounded, size: 18),
          label: Text(
            _isExporting ? 'Exporting High-Res...' : 'Export & Share Card',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
      ),
    );
  }
}
