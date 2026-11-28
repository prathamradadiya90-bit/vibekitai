import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibekit_ai/core/constants/app_colors.dart';
import 'package:vibekit_ai/core/constants/app_durations.dart';
import 'package:vibekit_ai/core/providers/app_providers.dart';
import 'package:vibekit_ai/core/storage/local_database.dart';
import 'package:vibekit_ai/core/storage/preferences_service.dart';
import 'package:vibekit_ai/core/theme/app_theme.dart';
import 'package:vibekit_ai/core/widgets/loading_shimmer.dart';
import 'package:vibekit_ai/core/widgets/motion_widgets.dart';
import 'package:vibekit_ai/features/achievements/presentation/achievements_screen.dart';
import 'package:vibekit_ai/features/aura_radar/presentation/aura_radar_screen.dart';
import 'package:vibekit_ai/features/history/history_screen.dart';
import 'package:vibekit_ai/features/streaks/presentation/streak_screen.dart';
import 'package:vibekit_ai/models/history_item.dart';

void main() {
  group('UI Motion Primitives & Brand Harmony Tests', () {
    test('AppDurations & AppCurves expose cohesive motion tokens', () {
      expect(AppDurations.press.inMilliseconds, equals(90));
      expect(AppDurations.normal.inMilliseconds, equals(260));
      expect(AppCurves.tactilePress, isNotNull);
      expect(AppCurves.espressoPour, isNotNull);
      expect(AppCurves.cremaSpring, isNotNull);
      expect(AppCurves.ambientBreath, isNotNull);
    });

    testWidgets('SlidingSegmentedPill glides cleanly between options', (tester) async {
      String selected = 'Replies';
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SlidingSegmentedPill<String>(
                  items: const ['Replies', 'Vibe Check', 'Captions'],
                  selectedItem: selected,
                  labelBuilder: (s) => s,
                  onSelected: (val) => setState(() => selected = val),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Replies'), findsOneWidget);
      expect(find.text('Vibe Check'), findsOneWidget);
      expect(find.text('Captions'), findsOneWidget);

      await tester.tap(find.text('Vibe Check'));
      await tester.pumpAndSettle();
      expect(selected, equals('Vibe Check'));
    });

    testWidgets('TactileScale, StaggeredEntrance & AnimatedProgressBar settle under Reduced Motion', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: Column(
                children: [
                  TactileScale(
                    child: ElevatedButton(
                      onPressed: () => tapped = true,
                      child: const Text('Tap Me'),
                    ),
                  ),
                  const StaggeredEntrance(
                    index: 2,
                    child: Text('Cascaded Card'),
                  ),
                  const AnimatedProgressBar(
                    value: 0.72,
                    color: AppColors.accent,
                    backgroundColor: AppColors.borderLight,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Cascaded Card'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      await tester.tap(find.text('Tap Me'));
      expect(tapped, isTrue);
    });

    testWidgets('ResultCardSkeleton animates shimmer placeholders cleanly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: ResultCardSkeleton(),
          ),
        ),
      );
      expect(find.byType(ResultCardSkeleton), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('AchievementsScreen uses Espresso harmony instead of indigo gradient', (tester) async {
      SharedPreferences.setMockInitialValues({'has_completed_onboarding': true});
      final prefs = await PreferencesService.create();
      final db = LocalDatabase();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preferencesServiceProvider.overrideWithValue(prefs),
            localDatabaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const AchievementsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Achievements & Badges'), findsOneWidget);
      expect(find.textContaining('Badges Unlocked'), findsOneWidget);
    });

    testWidgets('StreakScreen renders 7-day rhythm strip cleanly', (tester) async {
      SharedPreferences.setMockInitialValues({'has_completed_onboarding': true});
      final prefs = await PreferencesService.create();
      final db = LocalDatabase();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preferencesServiceProvider.overrideWithValue(prefs),
            localDatabaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const StreakScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Vibe Streaks & Rewards'), findsOneWidget);
      expect(find.text('M'), findsOneWidget);
      expect(find.text('S'), findsNWidgets(2));
    });

    testWidgets('AuraRadarScreen transitions smoothly from quiz to polygon result', (tester) async {
      SharedPreferences.setMockInitialValues({'has_completed_onboarding': true});
      final prefs = await PreferencesService.create();
      final db = LocalDatabase();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preferencesServiceProvider.overrideWithValue(prefs),
            localDatabaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const AuraRadarScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('QUESTION 1 OF 4'), findsOneWidget);

      // Answer all 4 questions
      await tester.tap(find.textContaining('Match energy'));
      await tester.pumpAndSettle();
      expect(find.text('QUESTION 2 OF 4'), findsOneWidget);

      await tester.tap(find.textContaining('Roast their camera'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('ghosting reality'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Mic-drop comebacks'));
      await tester.pumpAndSettle();

      expect(find.text('Vibe Radar Analysis'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('HistoryScreen renders date group headers cleanly', (tester) async {
      SharedPreferences.setMockInitialValues({'has_completed_onboarding': true});
      final prefs = await PreferencesService.create();
      final db = LocalDatabase();
      await db.insertItem(
        HistoryItem(
          id: 'hist_today_1',
          title: 'Today test',
          content: 'Coffee-fueled comeback',
          type: 'reply',
          category: 'Witty',
          createdAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preferencesServiceProvider.overrideWithValue(prefs),
            localDatabaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const HistoryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Coffee-fueled comeback'), findsOneWidget);
    });
  });
}
