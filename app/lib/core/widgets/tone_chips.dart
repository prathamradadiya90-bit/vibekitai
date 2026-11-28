import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import 'motion_widgets.dart';

/// Reusable horizontal or wrap selector for vibes and tones.
class ToneChips extends StatelessWidget {
  final List<String> tones;
  final String selectedTone;
  final ValueChanged<String> onSelected;

  const ToneChips({
    super.key,
    required this.tones,
    required this.selectedTone,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unselectedBg = isDark ? AppColors.surfaceCardDark : AppColors.surfaceCardLight;
    final unselectedBorder = isDark ? AppColors.borderDark : AppColors.borderLight;
    final unselectedText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: tones.map((tone) {
          final isSelected = tone == selectedTone;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: TactileScale(
              pressedScale: 0.94,
              child: ChoiceChip(
                label: Text(tone),
                selected: isSelected,
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  onSelected(tone);
                },
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : unselectedText,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 13,
                ),
                selectedColor: AppColors.primary,
                backgroundColor: unselectedBg,
                side: BorderSide(
                  color: isSelected ? AppColors.primary : unselectedBorder,
                  width: 1,
                ),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppSpacing.roundedFull,
                ),
                showCheckmark: false,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
