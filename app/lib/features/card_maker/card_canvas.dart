import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'card_templates.dart';

class CardCanvas extends StatelessWidget {
  final GlobalKey repaintKey;
  final String text;
  final String? author;
  final CardTemplate template;
  final double aspectRatio; // 1.0 (Square), 9/16 (Story), 4/5 (Portrait)
  final TextAlign textAlign;
  final double fontSize;
  final bool showWatermark;

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
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: RepaintBoundary(
          key: repaintKey,
          child: Container(
            decoration: BoxDecoration(
              gradient: template.backgroundGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: kIsWeb
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top decorative icon / badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: template.accentColor.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.format_quote_rounded,
                        size: 22,
                        color: template.accentColor,
                      ),
                    ),
                    const SizedBox(), // Spacer
                  ],
                ),

                // Center Main Text (Unicode safe for English, Hindi, Gujarati)
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Text(
                        text.isEmpty
                            ? 'Type your thought, quote or meme text here...'
                            : text,
                        textAlign: textAlign,
                        style: GoogleFonts.outfit(
                          fontSize: fontSize,
                          fontWeight: FontWeight.w600,
                          color: template.textColor,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom Author / Signature & Watermark
                Column(
                  children: [
                    if (author != null && author!.trim().isNotEmpty) ...[
                      Text(
                        '— ${author!.trim()}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: template.textColor.withOpacity(0.75),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (showWatermark)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 11,
                            color: template.textColor.withOpacity(0.45),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Made with VibeKit AI',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.6,
                              color: template.textColor.withOpacity(0.45),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
