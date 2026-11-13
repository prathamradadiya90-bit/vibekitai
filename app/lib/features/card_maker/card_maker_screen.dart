import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/card_export_service.dart';
import '../../core/services/share_service.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/achievement_service.dart';
import '../../core/widgets/app_bottom_nav.dart';
import '../../models/history_item.dart';
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
  double _aspectRatio = 1.0; // 1:1 Square
  TextAlign _textAlign = TextAlign.center;
  double _fontSize = 20.0;
  bool _isExporting = false;

  final List<Map<String, dynamic>> _aspectRatios = [
    {'name': '1:1 Square', 'ratio': 1.0, 'icon': Icons.crop_square_rounded},
    {
      'name': '9:16 Story',
      'ratio': 9 / 16,
      'icon': Icons.stay_current_portrait_rounded
    },
    {
      'name': '4:5 Portrait',
      'ratio': 4 / 5,
      'icon': Icons.crop_portrait_rounded
    },
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialText != null) {
      _textController.text = widget.initialText!;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _authorController.dispose();
    super.dispose();
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
      final filePath = await CardExportService.captureAndSaveCard(_repaintKey);
      if (!mounted) return;
      setState(() => _isExporting = false);

      if (filePath != null || pngBytes != null) {
        HapticFeedback.mediumImpact();
        // Save to local database
        final db = ref.read(localDatabaseProvider);
        await db.insertItem(
          HistoryItem(
            id: const Uuid().v4(),
            title: text.length > 30 ? '${text.substring(0, 30)}...' : text,
            content: text,
            type: 'card',
            category: _selectedTemplate.name,
            createdAt: DateTime.now(),
            extraData: filePath ?? 'web_export',
          ),
        );
        final instId = ref.read(preferencesServiceProvider).getAppInstanceId();
        await ShareService.shareImage(
          filePath ?? '',
          text: text,
          installationId: instId,
          imageBytes: pngBytes,
        );
        AnalyticsService.instance.logShareCard();

        // Increment cards exported count & verify achievements
        await ref.read(preferencesServiceProvider).incrementCardsExported();
        if (mounted) {
          await ref.read(achievementServiceProvider).checkAndUnlockAchievements(context: context);
        }

        // Natural transition: Display interstitial ad if eligible (frequency-capped, suppressed for Pro)
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

  Future<void> _saveToHistoryOnly() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final filePath = await CardExportService.captureAndSaveCard(_repaintKey);
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
        extraData: filePath,
      ),
    );

    HapticFeedback.selectionClick();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Card saved to Favorites!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final quota = ref.watch(quotaProvider);
    final showWatermark = !quota.isPro;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meme & Card Maker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_add_outlined),
            tooltip: 'Save to Favorites',
            onPressed: _saveToHistoryOnly,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Live Interactive Canvas Preview
              Container(
                constraints: const BoxConstraints(maxHeight: 380),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevatedDark.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.borderDark),
                ),
                padding: const EdgeInsets.all(16),
                child: CardCanvas(
                  repaintKey: _repaintKey,
                  text: _textController.text,
                  author: _authorController.text,
                  template: _selectedTemplate,
                  aspectRatio: _aspectRatio,
                  textAlign: _textAlign,
                  fontSize: _fontSize,
                  showWatermark: showWatermark,
                ),
              ),

              const SizedBox(height: 16),

              // Export & Share Action Buttons
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isExporting ? null : _exportAndShare,
                        icon: _isExporting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.share_rounded),
                        label: Text(
                          _isExporting ? 'Exporting...' : 'Share High-Res Card',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Text Editing Inputs
              const Text('Text & Content',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),

              // Quick Quote Idea Chips (Instant inspiration for new users)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    {'quote': 'Late night coffee & big dreams.', 'author': 'vibekit'},
                    {'quote': 'Peace over drama every single day.', 'author': 'aesthetic'},
                    {'quote': 'Work in silence, let the vibe speak.', 'author': 'creator'},
                    {'quote': 'In a world of trends, remain a classic.', 'author': 'vintage'},
                  ].map((item) {
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8, bottom: 8),
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
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceCardLight,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? AppColors.borderDark : AppColors.borderLight,
                            ),
                          ),
                          child: Text(
                            item['quote']!,
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

              TextField(
                controller: _textController,
                maxLines: 3,
                maxLength: 250,
                decoration: const InputDecoration(
                  hintText:
                      'Enter your quote, funny text, or status thought...',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _authorController,
                maxLength: 40,
                decoration: const InputDecoration(
                  hintText: 'Author or handle (optional)...',
                  counterText: '',
                ),
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 20),

              // Template Palette Carousel
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Templates',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  if (!quota.isPro)
                    const Text('Pro templates locked',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textMutedDark)),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 75,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: CardTemplates.all.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final t = CardTemplates.all[index];
                    final isSelected = _selectedTemplate.id == t.id;
                    return InkWell(
                      onTap: () {
                        if (t.isProOnly && !quota.isPro) {
                          context.push('/paywall');
                          return;
                        }
                        setState(() => _selectedTemplate = t);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 75,
                        decoration: BoxDecoration(
                          gradient: t.backgroundGradient,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: Stack(
                          children: [
                            Center(
                              child: Text(
                                t.name.split(' ').first,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: t.textColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (t.isProOnly && !quota.isPro)
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.lock,
                                      size: 10, color: Colors.amber),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              // Aspect Ratio Selector
              const Text('Format / Aspect Ratio',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              Row(
                children: _aspectRatios.map((ar) {
                  final isSelected = _aspectRatio == ar['ratio'];
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _aspectRatio = ar['ratio'] as double;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.borderDark,
                            width: isSelected ? 1.5 : 1,
                          ),
                          backgroundColor: isSelected
                              ? AppColors.primary.withOpacity(0.12)
                              : null,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: Icon(ar['icon'] as IconData, size: 16),
                        label: Text(
                          (ar['name'] as String).split(' ').first,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // Layout & Typography Controls
              Row(
                children: [
                  const Text('Alignment:',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      Icons.format_align_left_rounded,
                      color: _textAlign == TextAlign.left
                          ? AppColors.primary
                          : AppColors.textMutedDark,
                    ),
                    onPressed: () =>
                        setState(() => _textAlign = TextAlign.left),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.format_align_center_rounded,
                      color: _textAlign == TextAlign.center
                          ? AppColors.primary
                          : AppColors.textMutedDark,
                    ),
                    onPressed: () =>
                        setState(() => _textAlign = TextAlign.center),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.format_align_right_rounded,
                      color: _textAlign == TextAlign.right
                          ? AppColors.primary
                          : AppColors.textMutedDark,
                    ),
                    onPressed: () =>
                        setState(() => _textAlign = TextAlign.right),
                  ),
                ],
              ),

              Row(
                children: [
                  const Text('Font Size:',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Expanded(
                    child: Slider(
                      value: _fontSize,
                      min: 14.0,
                      max: 32.0,
                      divisions: 9,
                      activeColor: AppColors.primary,
                      onChanged: (val) => setState(() => _fontSize = val),
                    ),
                  ),
                  Text('${_fontSize.toInt()}pt',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondaryDark)),
                ],
              ),

              // Watermark info for free vs pro
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceCardDark : AppColors.surfaceCardLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                ),
                child: Row(
                  children: [
                    Icon(
                      quota.isPro
                          ? Icons.check_circle_rounded
                          : Icons.info_outline_rounded,
                      size: 18,
                      color: quota.isPro ? AppColors.success : AppColors.accent,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        quota.isPro
                            ? 'Pro active: Watermark is removed from all card exports.'
                            : 'Free exports include a subtle watermark. Upgrade to Pro for watermark-free cards.',
                        style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
    );
  }
}
