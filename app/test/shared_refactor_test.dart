import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibekit_ai/core/network/api_client.dart';
import 'package:vibekit_ai/core/providers/app_providers.dart';
import 'package:vibekit_ai/core/storage/local_database.dart';
import 'package:vibekit_ai/core/storage/preferences_service.dart';
import 'package:vibekit_ai/core/widgets/error_view.dart';
import 'package:vibekit_ai/core/widgets/primary_button.dart';
import 'package:vibekit_ai/core/widgets/result_card.dart';
import 'package:vibekit_ai/core/widgets/tone_chips.dart';
import 'package:vibekit_ai/models/generation_models.dart';
import 'package:vibekit_ai/models/history_item.dart';

void main() {
  group('Phase 7 - Shared Refactor Unit & Widget Tests', () {
    test('GenerationNotifier manages lifecycle, history, and credit sync', () async {
      SharedPreferences.setMockInitialValues({'cached_credits': 3, 'cached_is_pro': false});
      final prefs = await PreferencesService.create();
      final db = LocalDatabase();
      final client = ApiClient(prefs: prefs);

      final container = ProviderContainer(
        overrides: [
          preferencesServiceProvider.overrideWithValue(prefs),
          localDatabaseProvider.overrideWithValue(db),
          apiClientProvider.overrideWithValue(client),
        ],
      );

      final notifier = container.read(replyGenerationProvider.notifier);
      expect(notifier.state.isGenerating, isFalse);
      expect(notifier.state.result, isNull);

      const request = ReplyRequest(
        message: 'Hello there',
        tone: 'Friendly',
        language: 'English',
        length: 'short',
        count: 2,
      );

      final success = await notifier.execute(
        request: request,
        caller: () async => const ReplyResponse(
          suggestions: ['Hi!', 'Hello!'],
          tone: 'Friendly',
          language: 'English',
          creditsRemaining: 2,
        ),
        getCreditsRemaining: (res) => res.creditsRemaining,
        buildHistoryItems: (res) => [
          HistoryItem(
            id: 'test_hist_1',
            title: 'Hello',
            content: res.suggestions.first,
            type: 'reply',
            category: 'Friendly',
            createdAt: DateTime.now(),
          ),
        ],
        actionType: 'reply',
      );

      expect(success, isTrue);
      expect(notifier.state.isGenerating, isFalse);
      expect(notifier.state.result?.suggestions.length, equals(2));
      expect(container.read(quotaProvider).totalCreditsRemaining, equals(2));

      // Verify item saved to DB
      final saved = await db.getItems();
      expect(saved.length, equals(1));
      expect(saved.first.content, equals('Hi!'));

      container.dispose();
    });

    testWidgets('ResultCard renders content, subtitle, and action buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResultCard(
              content: 'Test content for result card',
              subtitle: 'SUBTITLE',
              category: 'Reply',
              onFavoriteToggle: () {},
            ),
          ),
        ),
      );

      expect(find.text('Test content for result card'), findsOneWidget);
      expect(find.text('SUBTITLE'), findsOneWidget);
      expect(find.text('Make Card'), findsOneWidget);
      expect(find.byIcon(Icons.copy), findsOneWidget);
      expect(find.byIcon(Icons.share_outlined), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
    });

    testWidgets('ToneChips renders chips and fires onSelected callback', (tester) async {
      String selected = 'Funny';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ToneChips(
              tones: const ['Funny', 'Witty', 'Flirty'],
              selectedTone: selected,
              onSelected: (tone) => selected = tone,
            ),
          ),
        ),
      );

      expect(find.text('Funny'), findsOneWidget);
      expect(find.text('Witty'), findsOneWidget);

      await tester.tap(find.text('Witty'));
      expect(selected, equals('Witty'));
    });

    testWidgets('PrimaryButton renders label, handles loading spinner and taps', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrimaryButton(
              label: 'Generate',
              isLoading: false,
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Generate'), findsOneWidget);
      await tester.tap(find.text('Generate'));
      expect(tapped, isTrue);

      // Loading state
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrimaryButton(
              label: 'Generate',
              isLoading: true,
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('ErrorView renders error message and triggers retry', (tester) async {
      bool retried = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorView(
              message: 'Custom test error',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.text('Custom test error'), findsOneWidget);
      expect(find.text('Tap to retry'), findsOneWidget);

      await tester.tap(find.text('Tap to retry'));
      expect(retried, isTrue);
    });
  });
}
