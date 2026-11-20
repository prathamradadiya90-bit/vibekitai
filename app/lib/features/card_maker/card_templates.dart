import 'package:flutter/material.dart';

enum CardStyle {
  quote(label: 'Quote', icon: Icons.format_quote_rounded, description: 'Classic aesthetic quote card'),
  socialPost(label: 'Post', icon: Icons.alternate_email_rounded, description: 'Viral social media post style'),
  memeImpact(label: 'Meme', icon: Icons.flash_on_rounded, description: 'High-impact bold meme layout'),
  minimalNote(label: 'Note', icon: Icons.sticky_note_2_rounded, description: 'Minimalist aesthetic thought card');

  final String label;
  final IconData icon;
  final String description;

  const CardStyle({
    required this.label,
    required this.icon,
    required this.description,
  });
}

enum CardFontFamily {
  modernSans(label: 'Modern Sans'),
  editorialSerif(label: 'Editorial Serif'),
  boldImpact(label: 'Bold Impact'),
  techMono(label: 'Cyber Mono');

  final String label;

  const CardFontFamily({required this.label});
}

class CardTemplate {
  final String id;
  final String name;
  final Gradient backgroundGradient;
  final Color textColor;
  final Color accentColor;
  final bool isDark;
  final bool isProOnly;

  const CardTemplate({
    required this.id,
    required this.name,
    required this.backgroundGradient,
    required this.textColor,
    required this.accentColor,
    this.isDark = true,
    this.isProOnly = false,
  });
}

class CardTemplates {
  CardTemplates._();

  static const List<CardTemplate> all = [
    // 1. Signature Brand Espresso
    CardTemplate(
      id: 'velvet_mocha',
      name: 'Velvet Espresso',
      backgroundGradient: LinearGradient(
        colors: [Color(0xFF2B1D15), Color(0xFF140E0A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      textColor: Color(0xFFFFFBF7),
      accentColor: Color(0xFFC89058),
      isDark: true,
    ),
    // 2. Deep Indigo (Required by existing test)
    CardTemplate(
      id: 'deep_indigo',
      name: 'Deep Indigo',
      backgroundGradient: LinearGradient(
        colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      textColor: Color(0xFFF8FAFC),
      accentColor: Color(0xFF818CF8),
      isDark: true,
    ),
    // 3. Neon Sunset (Required by existing test)
    CardTemplate(
      id: 'neon_sunset',
      name: 'Neon Sunset',
      backgroundGradient: LinearGradient(
        colors: [Color(0xFF831843), Color(0xFF4C0519), Color(0xFF1E1B4B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      textColor: Color(0xFFFFF1F2),
      accentColor: Color(0xFFF43F5E),
      isDark: true,
    ),
    // 4. Emerald Zen (Required by existing test)
    CardTemplate(
      id: 'emerald_zen',
      name: 'Emerald Zen',
      backgroundGradient: LinearGradient(
        colors: [Color(0xFF064E3B), Color(0xFF022C22)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      textColor: Color(0xFFECFDF5),
      accentColor: Color(0xFF34D399),
      isDark: true,
    ),
    // 5. Obsidian Dark (Required by existing test)
    CardTemplate(
      id: 'minimal_obsidian',
      name: 'Obsidian Dark',
      backgroundGradient: LinearGradient(
        colors: [Color(0xFF111827), Color(0xFF030712)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      textColor: Color(0xFFF9FAFB),
      accentColor: Color(0xFF9CA3AF),
      isDark: true,
    ),
    // 6. Warm Terracotta
    CardTemplate(
      id: 'warm_terracotta',
      name: 'Warm Clay',
      backgroundGradient: LinearGradient(
        colors: [Color(0xFF7C2D12), Color(0xFF451A03)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      textColor: Color(0xFFFFFBEB),
      accentColor: Color(0xFFF59E0B),
      isDark: true,
    ),
    // 7. Cream Paper (Required by existing test)
    CardTemplate(
      id: 'paper_retro',
      name: 'Cream Paper',
      backgroundGradient: LinearGradient(
        colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      textColor: Color(0xFF292524),
      accentColor: Color(0xFFD97706),
      isDark: false,
    ),
    // 8. Sapphire Pro
    CardTemplate(
      id: 'royal_sapphire',
      name: 'Sapphire Pro',
      backgroundGradient: LinearGradient(
        colors: [Color(0xFF1E3A8A), Color(0xFF0369A1)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      textColor: Color(0xFFF0F9FF),
      accentColor: Color(0xFF38BDF8),
      isProOnly: true,
      isDark: true,
    ),
    // 9. Nebula Pro
    CardTemplate(
      id: 'midnight_nebula',
      name: 'Nebula Pro',
      backgroundGradient: LinearGradient(
        colors: [Color(0xFF581C87), Color(0xFF3B0764), Color(0xFF0F172A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      textColor: Color(0xFFFAF5FF),
      accentColor: Color(0xFFA855F7),
      isProOnly: true,
      isDark: true,
    ),
    // 10. Cyberpunk Pro
    CardTemplate(
      id: 'cyberpunk_neon',
      name: 'Cyberpunk Pro',
      backgroundGradient: LinearGradient(
        colors: [Color(0xFF090D16), Color(0xFF0F172A), Color(0xFF1E1B4B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      textColor: Color(0xFF00F0FF),
      accentColor: Color(0xFFFF007F),
      isProOnly: true,
      isDark: true,
    ),
    // 11. Aura Glow Pro
    CardTemplate(
      id: 'aura_glow',
      name: 'Aura Glow Pro',
      backgroundGradient: LinearGradient(
        colors: [Color(0xFF4C1D95), Color(0xFF831843), Color(0xFF701A75)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      textColor: Color(0xFFFDF4FF),
      accentColor: Color(0xFFF472B6),
      isProOnly: true,
      isDark: true,
    ),
    // 12. Golden Hour
    CardTemplate(
      id: 'golden_hour',
      name: 'Golden Hour',
      backgroundGradient: LinearGradient(
        colors: [Color(0xFF451A03), Color(0xFF78350F), Color(0xFFB45309)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      textColor: Color(0xFFFEF3C7),
      accentColor: Color(0xFFFBBF24),
      isDark: true,
    ),
    // 13. Titanium Slate (Modern Minimalist)
    CardTemplate(
      id: 'titanium_slate',
      name: 'Titanium Slate',
      backgroundGradient: LinearGradient(
        colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      textColor: Color(0xFFF1F5F9),
      accentColor: Color(0xFF38BDF8),
      isDark: true,
    ),
    // 14. Pastel Latte (Soft Aesthetic Light)
    CardTemplate(
      id: 'pastel_latte',
      name: 'Pastel Latte',
      backgroundGradient: LinearGradient(
        colors: [Color(0xFFFAF7F2), Color(0xFFEFE6D8)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      textColor: Color(0xFF2E1A11),
      accentColor: Color(0xFF8B5A36),
      isDark: false,
    ),
  ];
}
