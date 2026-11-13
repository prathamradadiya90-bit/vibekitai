import 'package:flutter/material.dart';

/// Centralized brand palette for VibeKit AI.
/// Artisan Coffee, Toasted Mocha, Warm Caramel & Velvet Latte design system.
class AppColors {
  AppColors._();

  // Dark Theme Foundation (Velvet Roasted Espresso)
  static const Color backgroundDark = Color(0xFF140E0A); // Deep Velvet Espresso Bean
  static const Color surfaceDark = Color(0xFF1E140E); // Warm Roasted Cocoa
  static const Color surfaceCardDark = Color(0xFF2B1D15); // Rich Toasted Mocha Card
  static const Color surfaceElevatedDark = Color(0xFF38271C); // Warm Cinnamon Roast Surface

  // Light Theme Foundation (Warm Milky Cream & Biscuit Oat Foam)
  static const Color backgroundLight = Color(0xFFFAF7F2); // Silky Warm Oat Latte
  static const Color surfaceLight = Color(0xFFFFFFFF); // Fresh Steamed Milk Foam
  static const Color surfaceCardLight = Color(0xFFF3ECE2); // Toasted Biscuit Card
  static const Color surfaceElevatedLight = Color(0xFFEBE2D4); // Warm Caramel Sand Surface

  // Brand Accents (Artisan Roasted Coffee, Toffee & Caramel)
  static const Color primary = Color(0xFF6B4226); // Artisan Roasted Coffee Brown
  static const Color primaryLight = Color(0xFF8B5A36); // Warm Cinnamon Roast
  static const Color primaryDark = Color(0xFF472814); // Deep Roasted Espresso
  static const Color secondary = Color(0xFF52321C); // Dark Toasted Cocoa
  static const Color accent = Color(0xFFC89058); // Warm Golden Caramel Toffee
  static const Color accentWarm = Color(0xFFE0BA94); // Toasted Almond Biscuit
  static const Color accentPink = Color(0xFFBF6449); // Warm Terracotta Cinnamon

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF7D4E2D), Color(0xFF472814)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGlowGradient = LinearGradient(
    colors: [Color(0xFF382315), Color(0xFF1E130B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFFD89B5F), Color(0xFF9E653A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warmCreamGradient = LinearGradient(
    colors: [Color(0xFFFAF7F2), Color(0xFFF0E5D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Status & Utility Colors
  static const Color success = Color(0xFF2E7D32); // Forest Matcha Green
  static const Color warning = Color(0xFFD97706); // Warm Amber Honey
  static const Color error = Color(0xFFC2410C); // Roasted Rust / Clay Red
  static const Color info = Color(0xFF8C6239); // Warm Toffee Muted

  // Text Colors - Dark Mode
  static const Color textPrimaryDark = Color(0xFFFFFBF7); // Warm Steamed Milk Cream
  static const Color textSecondaryDark = Color(0xFFD6C1B1); // Warm Toasted Oat
  static const Color textMutedDark = Color(0xFFA68D7B); // Muted Coffee Froth

  // Text Colors - Light Mode
  static const Color textPrimaryLight = Color(0xFF2E1A11); // Deep Espresso
  static const Color textSecondaryLight = Color(0xFF7A5C47); // Warm Cinnamon Mocha
  static const Color textMutedLight = Color(0xFFA88B77); // Soft Latte Foam

  // Borders & Dividers
  static const Color borderDark = Color(0xFF4A3426); // Subtle Roasted Bean Border
  static const Color borderLight = Color(0xFFE5DACB); // Crisp Warm Biscuit Border
}
