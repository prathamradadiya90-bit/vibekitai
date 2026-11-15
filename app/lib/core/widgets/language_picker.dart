import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';

/// Reusable dropdown / selector for languages.
class LanguagePicker extends StatelessWidget {
  final List<String> languages;
  final String selectedLanguage;
  final ValueChanged<String> onChanged;

  const LanguagePicker({
    super.key,
    required this.languages,
    required this.selectedLanguage,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.surfaceCardDark : AppColors.surfaceCardLight;
    final borderCol = isDark ? AppColors.borderDark : AppColors.borderLight;
    final textCol = isDark ? Colors.white : AppColors.textPrimaryLight;
    final iconCol = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final dropdownBg = isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceCardLight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppSpacing.roundedMd,
        border: Border.all(color: borderCol),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedLanguage,
          isExpanded: true,
          dropdownColor: dropdownBg,
          icon: Icon(Icons.arrow_drop_down, color: iconCol),
          items: languages.map((lang) {
            return DropdownMenuItem<String>(
              value: lang,
              child: Text(
                lang,
                style: TextStyle(
                  color: textCol,
                  fontSize: 14,
                ),
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
        ),
      ),
    );
  }
}
