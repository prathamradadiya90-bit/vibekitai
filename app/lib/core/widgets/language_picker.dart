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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceCardDark,
        borderRadius: AppSpacing.roundedMd,
        border: Border.all(color: AppColors.borderDark),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedLanguage,
          isExpanded: true,
          dropdownColor: AppColors.surfaceElevatedDark,
          icon: const Icon(Icons.arrow_drop_down, color: AppColors.textSecondaryDark),
          items: languages.map((lang) {
            return DropdownMenuItem<String>(
              value: lang,
              child: Text(
                lang,
                style: const TextStyle(
                  color: Colors.white,
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
