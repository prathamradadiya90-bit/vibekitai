import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../providers/app_providers.dart';
import '../services/share_service.dart';
import '../services/review_prompt_service.dart';

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
    final reasons = [
      'Inappropriate or offensive tone',
      'Hate speech, harassment or bullying',
      'Sexually explicit or adult content',
      'Dangerous, harmful or illegal content',
      'Spam, deceptive or misleading',
      'Other content concern',
    ];
    String selectedReason = reasons.first;

    final shouldSubmit = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.borderDark,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Icon(Icons.flag_rounded, color: AppColors.accentPink, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Report AI Content',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Help keep VibeKit safe. Select why this AI response is inappropriate:',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondaryDark),
                    ),
                    const SizedBox(height: 14),
                    ...reasons.map((reason) {
                      final isSelected = reason == selectedReason;
                      return InkWell(
                        onTap: () => setSheetState(() => selectedReason = reason),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          child: Row(
                            children: [
                              Icon(
                                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                size: 20,
                                color: isSelected ? AppColors.primaryLight : AppColors.textMutedDark,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  reason,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isSelected ? Colors.white : AppColors.textSecondaryDark,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(sheetContext).pop(false),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.borderDark),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(sheetContext).pop(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Submit Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (shouldSubmit == true && mounted) {
      setState(() => _isReported = true);
      try {
        final container = ProviderScope.containerOf(context, listen: false);
        final client = container.read(apiClientProvider);
        await client.sendFeedback(
          'REPORT_AI_CONTENT [${widget.category}]: reason="$selectedReason", snippet="${widget.content.replaceAll('\n', ' ')}"',
        );
      } catch (_) {
        // Fallback for tests or offline state
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report submitted. Thank you for helping keep our community safe!'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: AppColors.surfaceCardDark,
        borderRadius: AppSpacing.roundedMd,
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
            Text(
              widget.subtitle!,
              style: const TextStyle(
                color: AppColors.primaryLight,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          SelectableText(
            widget.content,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(color: AppColors.borderDark, height: 16),
          Row(
            children: [
              // Copy Button
              Semantics(
                label: 'Copy generated text to clipboard',
                button: true,
                child: IconButton(
                  icon: Icon(
                    _copied ? Icons.check : Icons.copy,
                    size: 18,
                    color: _copied ? AppColors.success : AppColors.textSecondaryDark,
                  ),
                  tooltip: 'Copy',
                  onPressed: _handleCopy,
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                ),
              ),
              // Share Button
              Semantics(
                label: 'Share generated text',
                button: true,
                child: IconButton(
                  icon: const Icon(
                    Icons.share_outlined,
                    size: 18,
                    color: AppColors.textSecondaryDark,
                  ),
                  tooltip: 'Share',
                  onPressed: _handleShare,
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                ),
              ),
              // Favorite Button
              if (widget.onFavoriteToggle != null)
                Semantics(
                  label: widget.isFavorite ? 'Remove from favorites' : 'Save to favorites',
                  button: true,
                  child: IconButton(
                    icon: Icon(
                      widget.isFavorite ? Icons.favorite : Icons.favorite_border,
                      size: 18,
                      color: widget.isFavorite ? AppColors.accentPink : AppColors.textSecondaryDark,
                    ),
                    tooltip: 'Favorite',
                    onPressed: widget.onFavoriteToggle,
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  ),
                ),
              // Flag / Report Inappropriate Content (Google Play Generative AI Policy)
              Semantics(
                label: 'Report offensive or inappropriate AI content',
                button: true,
                child: IconButton(
                  icon: Icon(
                    _isReported ? Icons.flag_rounded : Icons.flag_outlined,
                    size: 18,
                    color: _isReported ? AppColors.accentPink : AppColors.textSecondaryDark,
                  ),
                  tooltip: _isReported ? 'Reported' : 'Report content',
                  onPressed: _isReported ? null : _showReportDialog,
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                ),
              ),
              const Spacer(),
              // Send to Card Maker Action
              Semantics(
                label: 'Open text in visual card maker',
                button: true,
                child: TextButton.icon(
                  onPressed: _sendToCardMaker,
                  icon: const Icon(Icons.palette_outlined, size: 16, color: AppColors.accent),
                  label: const Text(
                    'Make Card',
                    style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
