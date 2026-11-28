import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';
import '../constants/app_durations.dart';
import '../constants/app_spacing.dart';
import '../services/share_service.dart';
import '../services/review_prompt_service.dart';
import 'motion_widgets.dart';
import 'report_ai_dialog.dart';

/// Reusable card displaying an AI generated reply, caption, or bio snippet
/// with one-tap Copy, Share, Favorite, Flag/Report, and "Send to Card Maker" actions.
class ResultCard extends StatefulWidget {
  final String content;
  final String? subtitle;
  final String category;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;

  const ResultCard({
    super.key,
    required this.content,
    this.subtitle,
    required this.category,
    this.isFavorite = false,
    this.onFavoriteToggle,
  });

  @override
  State<ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<ResultCard> {
  bool _copied = false;
  bool _isReported = false;

  Future<void> _handleCopy() async {
    await Clipboard.setData(ClipboardData(text: widget.content));
    if (!mounted) return;
    setState(() => _copied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard!'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
    await ReviewPromptService.instance.onGenerationCompleted(context);
  }

  void _handleShare() {
    ShareService.shareText(widget.content);
    ReviewPromptService.instance.onGenerationCompleted(context);
  }

  void _sendToCardMaker() {
    context.push('/card-maker', extra: {'text': widget.content});
  }

  Future<void> _showReportDialog() async {
    final reported = await showReportAiContentDialog(
      context,
      category: widget.category,
      content: widget.content,
    );
    if (reported && mounted) {
      setState(() => _isReported = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.surfaceCardDark : AppColors.surfaceCardLight;
    final borderCol = isDark ? AppColors.borderDark : AppColors.borderLight;
    final textCol = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subtitleCol = isDark ? AppColors.accent : AppColors.primary;
    final dividerCol = isDark ? AppColors.borderDark : AppColors.borderLight;
    final iconCol = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return AnimatedContainer(
      duration: AppDurations.fast,
      curve: AppCurves.espressoPour,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: _copied
            ? AppColors.success.withValues(alpha: isDark ? 0.10 : 0.05)
            : cardBg,
        borderRadius: AppSpacing.roundedMd,
        border: Border.all(
          color: _copied ? AppColors.success : borderCol,
          width: _copied ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
            Text(
              widget.subtitle!,
              style: TextStyle(
                color: subtitleCol,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          SelectableText(
            widget.content,
            style: TextStyle(
              color: textCol,
              fontSize: 15,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Divider(color: dividerCol, height: 16),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  children: [
                    // Copy Button with animated morph
                    Semantics(
                      label: 'Copy generated text to clipboard',
                      button: true,
                      child: TactileScale(
                        child: IconButton(
                          icon: AnimatedSwitcher(
                            duration: AppDurations.fast,
                            switchInCurve: AppCurves.cremaSpring,
                            transitionBuilder: (child, animation) =>
                                ScaleTransition(scale: animation, child: child),
                            child: Icon(
                              _copied ? Icons.check : Icons.copy,
                              key: ValueKey<bool>(_copied),
                              size: 18,
                              color: _copied ? AppColors.success : iconCol,
                            ),
                          ),
                          tooltip: 'Copy',
                          onPressed: _handleCopy,
                          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        ),
                      ),
                    ),
                    // Share Button
                    Semantics(
                      label: 'Share generated text',
                      button: true,
                      child: TactileScale(
                        child: IconButton(
                          icon: Icon(
                            Icons.share_outlined,
                            size: 18,
                            color: iconCol,
                          ),
                          tooltip: 'Share',
                          onPressed: _handleShare,
                          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        ),
                      ),
                    ),
                    // Favorite Button with heart spring pop
                    if (widget.onFavoriteToggle != null)
                      Semantics(
                        label: widget.isFavorite ? 'Remove from favorites' : 'Save to favorites',
                        button: true,
                        child: TactileScale(
                          child: IconButton(
                            icon: AnimatedSwitcher(
                              duration: AppDurations.normal,
                              switchInCurve: AppCurves.cremaSpring,
                              transitionBuilder: (child, animation) =>
                                  ScaleTransition(scale: animation, child: child),
                              child: Icon(
                                widget.isFavorite ? Icons.favorite : Icons.favorite_border,
                                key: ValueKey<bool>(widget.isFavorite),
                                size: 18,
                                color: widget.isFavorite ? AppColors.accentPink : iconCol,
                              ),
                            ),
                            tooltip: 'Favorite',
                            onPressed: widget.onFavoriteToggle,
                            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                          ),
                        ),
                      ),
                    // Flag / Report Inappropriate Content (Google Play Generative AI Policy)
                    Semantics(
                      label: 'Report offensive or inappropriate AI content',
                      button: true,
                      child: TactileScale(
                        child: IconButton(
                          icon: Icon(
                            _isReported ? Icons.flag_rounded : Icons.flag_outlined,
                            size: 18,
                            color: _isReported ? AppColors.accentPink : iconCol,
                          ),
                          tooltip: _isReported ? 'Reported' : 'Report content',
                          onPressed: _isReported ? null : _showReportDialog,
                          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // Send to Card Maker Action (Caramel Tinted Pill CTA)
              Semantics(
                label: 'Open text in visual card maker',
                button: true,
                child: TactileScale(
                  child: TextButton.icon(
                    onPressed: _sendToCardMaker,
                    icon: Icon(
                      Icons.palette_outlined,
                      size: 16,
                      color: isDark ? AppColors.accentWarm : AppColors.primary,
                    ),
                    label: Text(
                      'Make Card',
                      style: TextStyle(
                        color: isDark ? AppColors.accentWarm : AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: (isDark ? AppColors.accent : AppColors.primary)
                          .withValues(alpha: 0.12),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppSpacing.roundedFull,
                      ),
                      minimumSize: const Size(48, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
