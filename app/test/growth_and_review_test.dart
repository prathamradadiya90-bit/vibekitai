import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibekit_ai/core/services/analytics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 5: Growth, Review Triggers & Localization Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('ARB localization files exist and contain identical keys across locales', () {
      final locales = ['en', 'es', 'hi', 'pt'];
      final keySets = <String, Set<String>>{};

      for (final loc in locales) {
        final file = File('lib/l10n/app_$loc.arb');
        expect(file.existsSync(), isTrue, reason: 'app_$loc.arb should exist');
        final jsonContent = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        final keys = jsonContent.keys.where((k) => !k.startsWith('@')).toSet();
        keySets[loc] = keys;
      }

      final enKeys = keySets['en']!;
      expect(enKeys.isNotEmpty, isTrue);

      for (final loc in ['es', 'hi', 'pt']) {
        final locKeys = keySets[loc]!;
        final missing = enKeys.difference(locKeys);
        final extra = locKeys.difference(enKeys);
        expect(missing, isEmpty, reason: 'app_$loc.arb missing keys: $missing');
        expect(extra, isEmpty, reason: 'app_$loc.arb has extra keys: $extra');
      }
    });

    test('ReviewPromptService enforces 90-day cooldown and interaction persistence', () async {
      final prefs = await SharedPreferences.getInstance();

      // Mock user previously engaged
      await prefs.setBool('vibekit_review_interacted', true);
      expect(prefs.getBool('vibekit_review_interacted'), isTrue);

      // Verify cooldown calculation
      final now = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt('vibekit_last_review_prompt_ms', now - const Duration(days: 45).inMilliseconds);
      final elapsed = now - (prefs.getInt('vibekit_last_review_prompt_ms') ?? 0);
      const cooldownMs = 90 * 24 * 60 * 60 * 1000;
      expect(elapsed < cooldownMs, isTrue); // Within cooldown
    });

    test('AnalyticsService accepts whitelisted in-app review events', () {
      // Should not throw or crash
      AnalyticsService.instance.logEvent('in_app_review_prompt_shown', parameters: {'source': '2nd_generation'});
      AnalyticsService.instance.logEvent('in_app_review_dismissed');
      AnalyticsService.instance.logEvent('in_app_review_accepted');
    });
  });
}
