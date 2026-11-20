import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibekit_ai/features/card_maker/card_canvas.dart';
import 'package:vibekit_ai/features/card_maker/card_maker_screen.dart';
import 'package:vibekit_ai/features/card_maker/card_templates.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      'app_instance_id': 'test-card-maker-instance',
    });
    prefsService = await PreferencesService.create();
    db = LocalDatabase();
  });

  group('Modern Meme & Card Maker Tests', () {
    test('CardTemplates contains signature brand palettes and backward-compatible templates', () {
      final templates = CardTemplates.all;
      expect(templates.length, greaterThanOrEqualTo(11));

      final names = templates.map((t) => t.name).toList();
      expect(names, contains('Deep Indigo'));
      expect(names, contains('Neon Sunset'));
      expect(names, contains('Emerald Zen'));
      expect(names, contains('Obsidian Dark'));
      expect(names, contains('Cream Paper'));
      expect(names, contains('Velvet Espresso'));
      expect(names, contains('Pastel Latte'));
      expect(names, contains('Titanium Slate'));
    });

    test('CardStyle enum defines 4 distinct viral formats', () {
      expect(CardStyle.values.length, 4);
      expect(CardStyle.quote.label, 'Quote');
      expect(CardStyle.socialPost.label, 'Post');
      expect(CardStyle.memeImpact.label, 'Meme');
      expect(CardStyle.minimalNote.label, 'Note');
    });

    test('CardFontFamily enum defines 4 versatile typography presets', () {
      expect(CardFontFamily.values.length, 4);
      expect(CardFontFamily.modernSans.label, 'Modern Sans');
      expect(CardFontFamily.editorialSerif.label, 'Editorial Serif');
      expect(CardFontFamily.boldImpact.label, 'Bold Impact');
      expect(CardFontFamily.techMono.label, 'Cyber Mono');
    });

    testWidgets('CardCanvas renders quote layout cleanly', (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CardCanvas(
              repaintKey: key,
              text: 'Late night coffee & big dreams.',
              author: 'vibekit',
              template: CardTemplates.all.first,
              aspectRatio: 1.0,
              textAlign: TextAlign.center,
              fontSize: 20.0,
              showWatermark: true,
              style: CardStyle.quote,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Late night coffee & big dreams.'), findsOneWidget);
      expect(find.text('— vibekit'), findsOneWidget);
      expect(find.text('Made with VibeKit AI'), findsOneWidget);
      expect(find.byIcon(Icons.format_quote_rounded), findsOneWidget);
    });

    testWidgets('CardCanvas renders social post (tweet) layout cleanly', (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CardCanvas(
              repaintKey: key,
              text: 'Texted first, put phone in fridge.',
              author: 'alex_vibe',
              template: CardTemplates.all.first,
              aspectRatio: 4 / 5,
              textAlign: TextAlign.left,
              fontSize: 18.0,
              showWatermark: false,
              style: CardStyle.socialPost,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Texted first, put phone in fridge.'), findsOneWidget);
      expect(find.text('alex_vibe'), findsOneWidget);
      expect(find.text('@alex_vibe • Just now'), findsOneWidget);
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
      expect(find.text('Made with VibeKit AI'), findsNothing); // Watermark suppressed
    });

    testWidgets('CardCanvas renders meme impact layout cleanly', (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CardCanvas(
              repaintKey: key,
              text: 'HOLDING IT TOGETHER WITH ICED COFFEE',
              author: 'POV: MONDAY MORNING',
              template: CardTemplates.all.first,
              aspectRatio: 1.0,
              textAlign: TextAlign.center,
              fontSize: 22.0,
              showWatermark: true,
              style: CardStyle.memeImpact,
              fontFamily: CardFontFamily.boldImpact,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('HOLDING IT TOGETHER WITH ICED COFFEE'), findsOneWidget);
      expect(find.text('POV: MONDAY MORNING'), findsOneWidget);
      expect(find.text('Made with VibeKit AI'), findsOneWidget);
    });

    testWidgets('CardCanvas renders minimal note layout cleanly', (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CardCanvas(
              repaintKey: key,
              text: 'In a world of fast trends, remain timeless.',
              author: 'Daily Epiphany',
              template: CardTemplates.all.first,
              aspectRatio: 9 / 16,
              textAlign: TextAlign.left,
              fontSize: 16.0,
              showWatermark: true,
              style: CardStyle.minimalNote,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('In a world of fast trends, remain timeless.'), findsOneWidget);
      expect(find.text('Daily Epiphany'), findsOneWidget);
      expect(find.byIcon(Icons.push_pin_rounded), findsOneWidget);
      expect(find.text('Made with VibeKit AI'), findsOneWidget);
    });

    testWidgets('CardMakerScreen mounts and switches editor tabs without error', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preferencesServiceProvider.overrideWithValue(prefsService),
            localDatabaseProvider.overrideWithValue(db),
            adMobServiceProvider.overrideWithValue(AdMobService()),
          ],
          child: const MaterialApp(
            home: CardMakerScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Screen Title and Canvas
      expect(find.text('Meme & Card Studio'), findsOneWidget);
      expect(find.text('Export & Share Card'), findsOneWidget);

      // Verify Editor Tabs
      expect(find.text('Content'), findsOneWidget);
      expect(find.text('Style'), findsOneWidget);
      expect(find.text('Layout'), findsOneWidget);

      // Tap Style Tab
      await tester.tap(find.text('Style'));
      await tester.pumpAndSettle();
      expect(find.text('Format Preset'), findsOneWidget);
      expect(find.text('Aesthetic Palettes'), findsOneWidget);

      // Tap Layout Tab
      await tester.tap(find.text('Layout'));
      await tester.pumpAndSettle();
      expect(find.text('Font Family'), findsOneWidget);
      expect(find.text('Format & Aspect Ratio'), findsOneWidget);
    });
  });
}
