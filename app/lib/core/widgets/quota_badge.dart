import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../providers/app_providers.dart';

/// Reusable badge displaying real-time credits remaining or Pro active status.
class QuotaBadge extends ConsumerWidget {
  const QuotaBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPro = ref.watch(quotaProvider.select((q) => q.isPro));
    final proCredits = ref.watch(quotaProvider.select((q) => q.proCreditsRemaining));
    final totalCredits = ref.watch(quotaProvider.select((q) => q.totalCreditsRemaining));

    if (isPro) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: const BoxDecoration(
          gradient: AppColors.accentGradient,
          borderRadius: AppSpacing.roundedFull,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star, size: 14, color: Colors.white),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'PRO ($proCredits)',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    final hasCredits = totalCredits > 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () => context.push('/paywall'),
      borderRadius: AppSpacing.roundedFull,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: hasCredits
              ? (isDark ? AppColors.surfaceCardDark : AppColors.surfaceCardLight)
              : AppColors.error.withAlpha(30),
          border: Border.all(
            color: hasCredits
                ? (isDark ? AppColors.borderDark : AppColors.borderLight)
                : AppColors.error,
            width: 1,
          ),
          borderRadius: AppSpacing.roundedFull,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasCredits ? Icons.bolt : Icons.warning_amber_rounded,
              size: 14,
              color: hasCredits ? AppColors.accent : AppColors.error,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '$totalCredits Left',
              style: TextStyle(
                color: hasCredits
                    ? (isDark ? Colors.white : AppColors.textPrimaryLight)
                    : AppColors.error,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
