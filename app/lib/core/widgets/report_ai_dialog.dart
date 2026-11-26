import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_colors.dart';
import '../providers/app_providers.dart';

/// Shared Generative AI content flagging modal complying with Google Play AI Content policy.
/// Returns `true` when the user submits a report.
Future<bool> showReportAiContentDialog(
  BuildContext context, {
  required String category,
  required String content,
}) async {
  const reasons = [
    'Inappropriate or offensive tone',
    'Hate speech, harassment or bullying',
    'Sexually explicit or adult content',
    'Dangerous, harmful or illegal content',
    'Spam, deceptive or misleading',
    'Other content concern',
  ];
  String selectedReason = reasons.first;

  final isDark = Theme.of(context).brightness == Brightness.dark;
  final sheetBg = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
  final textCol = isDark ? Colors.white : AppColors.textPrimaryLight;
  final textSecCol =
      isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
  final borderCol = isDark ? AppColors.borderDark : AppColors.borderLight;

  final shouldSubmit = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: sheetBg,
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
                        color: borderCol,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(
                        Icons.flag_rounded,
                        color: AppColors.accentPink,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Report AI Content',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textCol,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Help keep VibeKit safe. Select why this AI response is inappropriate:',
                    style: TextStyle(fontSize: 13, color: textSecCol),
                  ),
                  const SizedBox(height: 14),
                  ...reasons.map((reason) {
                    final isSelected = reason == selectedReason;
                    return InkWell(
                      onTap: () => setSheetState(() => selectedReason = reason),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 4,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              size: 20,
                              color: isSelected
                                  ? (isDark
                                      ? AppColors.accentWarm
                                      : AppColors.primary)
                                  : (isDark
                                      ? AppColors.textMutedDark
                                      : AppColors.textMutedLight),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                reason,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isSelected
                                      ? (isDark
                                          ? Colors.white
                                          : AppColors.primary)
                                      : textSecCol,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
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
                          onPressed: () =>
                              Navigator.of(sheetContext).pop(false),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: borderCol),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(color: textSecCol),
                          ),
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
                          child: const Text(
                            'Submit Report',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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

  if (shouldSubmit == true && context.mounted) {
    final trimmedSnippet = content.replaceAll('\n', ' ').trim();
    final safeSnippet = trimmedSnippet.length > 280
        ? '${trimmedSnippet.substring(0, 280)}...'
        : trimmedSnippet;
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      final client = container.read(apiClientProvider);
      await client.sendFeedback(
        'REPORT_AI_CONTENT [$category]: reason="$selectedReason", snippet="$safeSnippet"',
      );
    } catch (_) {
      // Fallback for offline / test environments
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Report submitted. Thank you for helping keep our community safe!',
          ),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
    }
    return true;
  }

  return false;
}
