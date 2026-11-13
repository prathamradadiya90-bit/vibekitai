import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Wraps the application in a responsive mobile container when running on wide
/// viewports on the Web.
///
/// On mobile viewports or native mobile devices, it renders full-screen edge-to-edge.
/// On desktop web viewports (width > 520px), it centers the app inside an
/// ultra-sleek, premium smartphone frame with warm coffee ambiance, rounded
/// corners, caramel glassmorphism border, and device chrome.
class ResponsiveAppShell extends StatelessWidget {
  final Widget child;

  const ResponsiveAppShell({super.key, required this.child});

  static const double maxMobileWidth = 440.0;
  static const double mobileBreakPoint = 520.0;

  @override
  Widget build(BuildContext context) {
    // On native mobile builds or non-web test runners, pass through directly
    if (!kIsWeb) {
      return child;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Full screen on mobile devices or narrow browser windows
        if (constraints.maxWidth <= mobileBreakPoint) {
          return child;
        }

        // On wide screens (Desktop Web), present a high-end mobile frame
        const frameWidth = maxMobileWidth;
        final maxHeight = constraints.maxHeight;
        final verticalMargin = maxHeight > 860 ? 24.0 : 8.0;
        final frameHeight = (maxHeight - (verticalMargin * 2)).clamp(600.0, 940.0);

        return Scaffold(
          backgroundColor: const Color(0xFF0F0B07), // Deep Roasted Coffee Obsidian
          body: Stack(
            children: [
              // 1. Ambient Background Warm Glows
              Positioned(
                top: -150,
                left: (constraints.maxWidth / 2) - 300,
                child: Container(
                  width: 600,
                  height: 600,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.22),
                        AppColors.accent.withOpacity(0.10),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -200,
                right: (constraints.maxWidth / 2) - 300,
                child: Container(
                  width: 600,
                  height: 600,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.accentWarm.withOpacity(0.14),
                        AppColors.accentPink.withOpacity(0.06),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // 2. Centered Mobile Device Mockup
              Center(
                child: Container(
                  width: frameWidth,
                  height: frameHeight,
                  margin: EdgeInsets.symmetric(vertical: verticalMargin),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundDark,
                    borderRadius: BorderRadius.circular(42),
                    border: Border.all(
                      color: AppColors.accent.withOpacity(0.35),
                      width: 1.8,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(40),
                    child: Stack(
                      children: [
                        // Inner App Content with adjusted MediaQuery
                        Positioned.fill(
                          child: MediaQuery(
                            data: MediaQuery.of(context).copyWith(
                              size: Size(frameWidth, frameHeight),
                              padding: const EdgeInsets.only(top: 48, bottom: 24),
                              viewPadding: const EdgeInsets.only(top: 48, bottom: 24),
                            ),
                            child: child,
                          ),
                        ),

                        // Dynamic Island / Device Notch Pill
                        Positioned(
                          top: 10,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              width: 110,
                              height: 22,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.accent.withOpacity(0.2),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF1B1612),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryLight.withOpacity(0.6),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Container(
                                        width: 4,
                                        height: 4,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Sleek Bottom Home Indicator Bar
                        Positioned(
                          bottom: 6,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              width: 120,
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppColors.accentWarm.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Desktop Floating Header Hint (Top Left)
              Positioned(
                top: 16,
                left: 24,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                      ),
                      child: const Icon(Icons.coffee_rounded, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'VibeKit Studio Web',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'Warm Coffee & Latte Theme Preview',
                          style: TextStyle(
                            color: AppColors.accentWarm.withOpacity(0.7),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
