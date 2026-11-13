import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';

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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: tones.map((tone) {
          final isSelected = tone == selectedTone;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: ChoiceChip(
              label: Text(tone),
              selected: isSelected,
              onSelected: (_) => onSelected(tone),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondaryDark,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.surfaceCardDark,
              side: BorderSide(
                color: isSelected ? AppColors.primary : AppColors.borderDark,
                width: 1,
              ),
              shape: const RoundedRectangleBorder(
                borderRadius: AppSpacing.roundedFull,
              ),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }
}
