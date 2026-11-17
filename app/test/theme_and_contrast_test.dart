import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibekit_ai/core/config/app_config.dart';
import 'package:vibekit_ai/core/providers/app_providers.dart';
import 'package:vibekit_ai/core/storage/preferences_service.dart';
import 'package:vibekit_ai/core/theme/app_theme.dart';
import 'package:vibekit_ai/core/widgets/error_view.dart';
import 'package:vibekit_ai/core/widgets/loading_shimmer.dart';
import 'package:vibekit_ai/core/widgets/quota_badge.dart';
import 'package:vibekit_ai/core/widgets/result_card.dart';
import 'package:vibekit_ai/core/widgets/tone_chips.dart';
import 'package:vibekit_ai/features/onboarding/onboarding_screen.dart';
import 'package:vibekit_ai/features/paywall/paywall_screen.dart';

void main() {
  group('Theme Contrast & Accessibility Verification Tests', () {
    testWidgets('ResultCard renders cleanly in Light and Dark themes', (tester) async {
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: theme,
              home: const Scaffold(
                body: ResultCard(
                  content: 'Test savage comeback content',
                  subtitle: 'Savage Option',
                  category: 'reply',
                ),
              ),
            ),
          ),
        );

        expect(find.text('Test savage comeback content'), findsOneWidget);
        expect(find.text('Savage Option'), findsOneWidget);
        expect(find.byIcon(Icons.copy), findsOneWidget);
        expect(find.byIcon(Icons.share_outlined), findsOneWidget);
        expect(find.text('Make Card'), findsOneWidget);
      }
    });

    testWidgets('ToneChips adapts to selected and unselected states in Light & Dark mode', (tester) async {
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        String selected = 'Savage';
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return ToneChips(
                    tones: const ['Savage', 'Flirty', 'Witty'],
                    selectedTone: selected,
                    onSelected: (tone) => setState(() => selected = tone),
                  );
                },
              ),
            ),
          ),
        );

        expect(find.text('Savage'), findsOneWidget);
        expect(find.text('Flirty'), findsOneWidget);
        expect(find.text('Witty'), findsOneWidget);

        await tester.tap(find.text('Flirty'));
        await tester.pumpAndSettle();
        expect(selected, equals('Flirty'));
      }
    });

    testWidgets('ErrorView renders error message legibly across brightness modes', (tester) async {
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        bool retried = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: ErrorView(
                message: 'Something went wrong',
                onRetry: () => retried = true,
              ),
            ),
          ),
        );

        expect(find.text('Something went wrong'), findsOneWidget);
        expect(find.text('Tap to retry'), findsOneWidget);

        await tester.tap(find.text('Tap to retry'));
        await tester.pump();
        expect(retried, isTrue);
      }
    });

    testWidgets('LoadingShimmer animates without throwing in Light & Dark mode', (tester) async {
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: const Scaffold(
              body: LoadingShimmer(height: 100),
            ),
          ),
        );

        expect(find.byType(LoadingShimmer), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump(const Duration(milliseconds: 500));
      }
    });

    testWidgets('QuotaBadge renders in Light & Dark modes without overflowing', (tester) async {
      SharedPreferences.setMockInitialValues({'cached_credits': 5, 'cached_is_pro': false});
      final prefs = await PreferencesService.create();

      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              preferencesServiceProvider.overrideWithValue(prefs),
            ],
            child: MaterialApp(
              theme: theme,
              home: const Scaffold(
                body: QuotaBadge(),
              ),
            ),
          ),
        );

        expect(find.byType(QuotaBadge), findsOneWidget);
        expect(find.text('5 Left'), findsOneWidget);
      }
    });

    testWidgets('PaywallScreen renders in Light and Dark themes without contrast errors', (tester) async {
      SharedPreferences.setMockInitialValues({'cached_credits': 5, 'cached_is_pro': false});
      final prefs = await PreferencesService.create();

      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              preferencesServiceProvider.overrideWithValue(prefs),
            ],
            child: MaterialApp(
              theme: theme,
              home: const PaywallScreen(),
            ),
          ),
        );

        expect(find.text('VibeKit VIP & Pro'), findsOneWidget);
        expect(find.text('Annual Creator Pass'), findsOneWidget);
        expect(find.text('Tier Comparison Matrix'), findsOneWidget);
        expect(find.text('What Creators Say'), findsOneWidget);
      }
    });

    testWidgets('OnboardingScreen renders slides and adapts to Light and Dark themes', (tester) async {
      SharedPreferences.setMockInitialValues({'vibekit_onboarding_completed': false});
      final prefs = await PreferencesService.create();

      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              preferencesServiceProvider.overrideWithValue(prefs),
            ],
            child: MaterialApp(
              theme: theme,
              home: OnboardingScreen(key: UniqueKey()),
            ),
          ),
        );

        expect(find.text(AppConfig.appName.toUpperCase()), findsOneWidget);
        expect(find.text('Clever Replies in Seconds'), findsOneWidget);
        expect(find.text('Continue'), findsOneWidget);

        // Advance to slide 1
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(find.text('Viral Captions & Reel Hooks'), findsOneWidget);
      }
    });
  });
}
