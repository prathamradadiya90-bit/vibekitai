import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibekit_ai/features/settings/settings_screen.dart';
import 'package:vibekit_ai/core/providers/app_providers.dart';
import 'package:vibekit_ai/core/storage/preferences_service.dart';
import 'package:vibekit_ai/core/storage/local_database.dart';
import 'package:vibekit_ai/core/services/admob_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PreferencesService prefsService;
  late LocalDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'has_completed_onboarding': true,
      'cached_credits': 3,
      'app_instance_id': 'test-settings-instance',
      'theme_mode': 'dark',
      'language': 'English',
    });
    prefsService = await PreferencesService.create();
    db = LocalDatabase();
  });

  Widget buildTestSettingsApp() {
    return ProviderScope(
      overrides: [
        preferencesServiceProvider.overrideWithValue(prefsService),
        localDatabaseProvider.overrideWithValue(db),
        adMobServiceProvider.overrideWithValue(AdMobService()),
      ],
      child: const MaterialApp(
        home: SettingsScreen(),
      ),
    );
  }

  group('Modern User-Friendly Settings Screen Tests', () {
    testWidgets('SettingsScreen mounts cleanly and renders user-friendly sections', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestSettingsApp());
      await tester.pumpAndSettle();

      // Header Title
      expect(find.text('Account & Settings'), findsOneWidget);

      // Membership / Account Card
      expect(find.text('Free Member'), findsOneWidget);
      expect(find.text('Upgrade'), findsOneWidget);
      expect(find.text('Badges & XP'), findsOneWidget);

      // Preferences Section
      expect(find.text('App Theme'), findsOneWidget);
      expect(find.text('Primary Language'), findsOneWidget);
      expect(find.text('Restore Purchases'), findsOneWidget);

      // Support & Community Section
      expect(find.text('Share with Friends'), findsOneWidget);
      expect(find.text('Help & FAQ Center'), findsOneWidget);
      expect(find.text('Send Feedback'), findsOneWidget);

      // Privacy & Legal Section
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Terms of Service'), findsOneWidget);
      expect(find.text('Delete My Data'), findsOneWidget);

      // Unnecessary / Developer jargon is HIDDEN by default
      expect(find.text('Backend Server Endpoint'), findsNothing);
      expect(find.text('Engineered with Flutter & Cloudflare Workers'), findsNothing);
    });

    testWidgets('Tapping version footer 7 times unlocks Developer Mode', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestSettingsApp());
      await tester.pumpAndSettle();

      final footerFinder = find.byKey(const Key('version_footer_gesture'));
      expect(footerFinder, findsOneWidget);
      await tester.ensureVisible(footerFinder);
      await tester.pumpAndSettle();

      // Tap 7 times
      for (int i = 0; i < 7; i++) {
        await tester.tap(footerFinder);
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();

      // Now developer mode is unlocked and visible
      expect(find.text('DEVELOPER OPTIONS (DEBUG)'), findsOneWidget);
      expect(find.text('API Server Endpoint'), findsOneWidget);
    });

    testWidgets('Theme tile opens modern bottom sheet picker', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestSettingsApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('App Theme'));
      await tester.pumpAndSettle();

      expect(find.text('Choose App Theme'), findsOneWidget);
      expect(find.text('Dark Theme'), findsWidgets);
      expect(find.text('Light Theme'), findsOneWidget);
      expect(find.text('System Default'), findsOneWidget);
    });

    testWidgets('Send Feedback tile opens clean modal dialog', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestSettingsApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Send Feedback'));
      await tester.pumpAndSettle();

      expect(find.text('Send Feedback'), findsWidgets);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Submit'), findsOneWidget);
    });
  });
}
