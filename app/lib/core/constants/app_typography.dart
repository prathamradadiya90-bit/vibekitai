import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Centralized Typography tokens for VibeKit AI design system.
/// Uses Outfit for brand headings and Plus Jakarta Sans for body readability.
class AppTypography {
  AppTypography._();

  static const String headingFontFamily = 'Outfit';
  static const String bodyFontFamily = 'Plus Jakarta Sans';

  // Headings
  static TextStyle h1({Color color = AppColors.textPrimaryDark}) =>
      GoogleFonts.outfit(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: color,
      );

  static TextStyle h2({Color color = AppColors.textPrimaryDark}) =>
      GoogleFonts.outfit(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: color,
      );

  static TextStyle h3({Color color = AppColors.textPrimaryDark}) =>
      GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: color,
      );

  // Body
  static TextStyle bodyLarge({Color color = AppColors.textPrimaryDark}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: color,
      );

  static TextStyle bodyMedium({Color color = AppColors.textPrimaryDark}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: color,
      );

  static TextStyle bodySmall({Color color = AppColors.textSecondaryDark}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: color,
      );

  // Labels & Buttons
  static TextStyle button({Color color = Colors.white}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: color,
      );

  static TextStyle caption({Color color = AppColors.textSecondaryDark}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: color,
      );
}
