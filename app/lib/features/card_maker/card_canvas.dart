import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_durations.dart';
import 'card_templates.dart';

class CardCanvas extends StatelessWidget {
  final GlobalKey repaintKey;
  final String text;
  final String? author;
  final CardTemplate template;
  final double aspectRatio; // 1.0 (Square), 9/16 (Story), 4/5 (Portrait), 16/9 (Landscape)
  final TextAlign textAlign;
  final double fontSize;
  final bool showWatermark;
  final CardStyle style;
  final CardFontFamily fontFamily;

  const CardCanvas({
    super.key,
    required this.repaintKey,
    required this.text,
    this.author,
    required this.template,
    required this.aspectRatio,
    required this.textAlign,
    required this.fontSize,
    required this.showWatermark,
    this.style = CardStyle.quote,
    this.fontFamily = CardFontFamily.modernSans,
  });

  TextStyle _getTextStyle({
    required double size,
    required FontWeight weight,
    required Color color,
    double height = 1.35,
    double? letterSpacing,
  }) {
    switch (fontFamily) {
      case CardFontFamily.modernSans:
        return GoogleFonts.outfit(
          fontSize: size,
          fontWeight: weight,
          color: color,
          height: height,
          letterSpacing: letterSpacing,
        );
      case CardFontFamily.editorialSerif:
        return GoogleFonts.playfairDisplay(
          fontSize: size,
          fontWeight: weight,
          color: color,
          height: height,
          letterSpacing: letterSpacing,
        );
      case CardFontFamily.boldImpact:
        return GoogleFonts.anton(
          fontSize: size,
          fontWeight: weight,
          color: color,
          height: height,
          letterSpacing: letterSpacing ?? 0.5,
        );
      case CardFontFamily.techMono:
        return GoogleFonts.spaceMono(
          fontSize: size,
          fontWeight: weight,
          color: color,
          height: height,
          letterSpacing: letterSpacing,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Center(
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: RepaintBoundary(
          key: repaintKey,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cardPadding = (constraints.maxWidth * 0.06).clamp(12.0, 28.0);
              return AnimatedContainer(
                duration: reduceMotion ? Duration.zero : AppDurations.normal,
                curve: AppCurves.espressoPour,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  gradient: template.backgroundGradient,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: template.accentColor.withValues(alpha: 0.25),
                    width: 1.2,
                  ),
                  boxShadow: kIsWeb
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 28,
                            offset: const Offset(0, 10),
                          ),
                        ],
                ),
                padding: EdgeInsets.all(cardPadding),
                child: AnimatedSwitcher(
                  duration: reduceMotion ? Duration.zero : AppDurations.fast,
                  switchInCurve: AppCurves.espressoPour,
                  child: KeyedSubtree(
                    key: ValueKey<CardStyle>(style),
                    child: _buildLayout(constraints),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLayout(BoxConstraints constraints) {
    switch (style) {
      case CardStyle.quote:
        return _buildQuoteLayout(constraints);
      case CardStyle.socialPost:
        return _buildSocialPostLayout(constraints);
      case CardStyle.memeImpact:
        return _buildMemeImpactLayout(constraints);
      case CardStyle.minimalNote:
        return _buildMinimalNoteLayout(constraints);
    }
  }

  // 1. Classic & Aesthetic Quote Card
  Widget _buildQuoteLayout(BoxConstraints constraints) {
    final displayText = text.isEmpty ? 'Type your thought, quote or meme text here...' : text;
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: template.accentColor.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.format_quote_rounded,
                size: 20,
                color: template.accentColor,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.auto_awesome,
              size: 15,
              color: template.accentColor.withValues(alpha: 0.5),
            ),
          ],
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Text(
                displayText,
                textAlign: textAlign,
                style: _getTextStyle(
                  size: fontSize,
                  weight: FontWeight.w600,
                  color: template.textColor,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ),
        Column(
          children: [
            if (author != null && author!.trim().isNotEmpty) ...[
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '— ${author!.trim()}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: template.textColor.withValues(alpha: 0.75),
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],
            if (showWatermark) _buildWatermarkBadge(),
          ],
        ),
      ],
    );
  }

  // 2. Viral Social Media Post / Tweet Card
  Widget _buildSocialPostLayout(BoxConstraints constraints) {
    final displayText = text.isEmpty ? 'Drop your hot take, relatable tweet, or viral moment here...' : text;
    final authorClean = (author != null && author!.trim().isNotEmpty) ? author!.trim() : 'vibekit';
    final initial = authorClean.isNotEmpty ? authorClean[0].toUpperCase() : 'V';
    final handle = authorClean.replaceAll(' ', '').toLowerCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Profile Header
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [template.accentColor, template.accentColor.withValues(alpha: 0.6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        authorClean,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: template.textColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.verified_rounded,
                        size: 14,
                        color: template.accentColor,
                      ),
                    ],
                  ),
                  Text(
                    '@$handle • Just now',
                    style: TextStyle(
                      fontSize: 11,
                      color: template.textColor.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Body Content
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Align(
                alignment: textAlign == TextAlign.center
                    ? Alignment.center
                    : (textAlign == TextAlign.right ? Alignment.centerRight : Alignment.centerLeft),
                child: Text(
                  displayText,
                  textAlign: textAlign,
                  style: _getTextStyle(
                    size: fontSize,
                    weight: FontWeight.w500,
                    color: template.textColor,
                    height: 1.45,
                  ),
                ),
              ),
            ),
          ),
        ),

        // Engagement Metrics Row & Watermark
        Column(
          children: [
            Container(
              padding: const EdgeInsets.only(top: 6, bottom: 4),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: template.textColor.withValues(alpha: 0.12),
                  ),
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMetric(Icons.favorite_rounded, '3.4k', Colors.redAccent.withValues(alpha: 0.8)),
                    const SizedBox(width: 14),
                    _buildMetric(Icons.chat_bubble_outline_rounded, '184', template.textColor.withValues(alpha: 0.6)),
                    const SizedBox(width: 14),
                    _buildMetric(Icons.repeat_rounded, '492', template.textColor.withValues(alpha: 0.6)),
                    const SizedBox(width: 14),
                    _buildMetric(Icons.bookmark_border_rounded, '82', template.textColor.withValues(alpha: 0.6)),
                  ],
                ),
              ),
            ),
            if (showWatermark) ...[
              const SizedBox(height: 4),
              _buildWatermarkBadge(),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildMetric(IconData icon, String count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          count,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: template.textColor.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  // 3. Modern High-Impact Meme Format
  Widget _buildMemeImpactLayout(BoxConstraints constraints) {
    final displayText = text.isEmpty ? 'PUNCHLINE OR RELATABLE MEME TEXT' : text.toUpperCase();
    final setup = author?.isNotEmpty == true ? author!.trim().toUpperCase() : 'POV: YOU JUST OPENED THIS APP';

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Top Setup Header
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: template.accentColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: template.accentColor.withValues(alpha: 0.35)),
            ),
            child: Text(
              setup,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: template.textColor,
              ),
            ),
          ),
        ),

        // Bold Punchline
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Text(
                displayText,
                textAlign: textAlign,
                style: _getTextStyle(
                  size: (fontSize + 2).clamp(16.0, 36.0),
                  weight: FontWeight.w900,
                  color: template.textColor,
                  letterSpacing: 1.1,
                  height: 1.25,
                ),
              ),
            ),
          ),
        ),

        if (showWatermark) _buildWatermarkBadge(),
      ],
    );
  }

  // 4. Minimalist Aesthetic Note Card
  Widget _buildMinimalNoteLayout(BoxConstraints constraints) {
    final displayText = text.isEmpty ? 'Write your stream of consciousness or midnight epiphany...' : text;
    final authorClean = (author != null && author!.trim().isNotEmpty) ? author!.trim() : 'Daily Memo';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.push_pin_rounded, size: 15, color: template.accentColor),
                const SizedBox(width: 5),
                Text(
                  'Memo',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: template.textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                authorClean,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: template.textColor.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Divider(color: template.textColor.withValues(alpha: 0.15), height: 1),
        const SizedBox(height: 10),

        // Body
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Text(
              displayText,
              textAlign: textAlign,
              style: _getTextStyle(
                size: fontSize,
                weight: FontWeight.w500,
                color: template.textColor,
                height: 1.5,
              ),
            ),
          ),
        ),

        if (showWatermark) ...[
          const SizedBox(height: 6),
          Center(child: _buildWatermarkBadge()),
        ],
      ],
    );
  }

  Widget _buildWatermarkBadge() {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: 11,
            color: template.textColor.withValues(alpha: 0.45),
          ),
          const SizedBox(width: 4),
          Text(
            'Made with VibeKit AI',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: template.textColor.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }
}
