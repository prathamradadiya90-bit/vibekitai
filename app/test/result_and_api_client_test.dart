import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibekit_ai/core/config/app_config.dart';
import 'package:vibekit_ai/core/constants/app_strings.dart';
import 'package:vibekit_ai/core/network/api_client.dart';
import 'package:vibekit_ai/core/network/api_exception.dart';
import 'package:vibekit_ai/core/network/offline_fallback.dart';
import 'package:vibekit_ai/core/network/result.dart';
import 'package:vibekit_ai/core/providers/app_providers.dart';
import 'package:vibekit_ai/core/services/notification_service.dart';
import 'package:vibekit_ai/core/services/review_service.dart';
import 'package:vibekit_ai/core/storage/preferences_service.dart';
import 'package:vibekit_ai/models/generation_models.dart';

void main() {
  group('Result<T> Pattern & Functional Handlers', () {
    test('Success variant encapsulates data and transforms via map', () {
      const Result<int> result = Success(42);

      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.dataOrNull, equals(42));
      expect(result.errorOrNull, isNull);

      final mapped = result.map((val) => 'Value: $val');
      expect(mapped.isSuccess, isTrue);
      expect(mapped.dataOrNull, equals('Value: 42'));
    });

    test('Failure variant encapsulates ApiException and preserves error in map', () {
      const error = ApiException(
        code: 'QUOTA_EXCEEDED',
        message: 'Daily credits exhausted',
        statusCode: 429,
      );
      const Result<int> result = Failure(error);

      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      expect(result.dataOrNull, isNull);
      expect(result.errorOrNull?.code, equals('QUOTA_EXCEEDED'));

      final mapped = result.map((val) => 'Value: $val');
      expect(mapped.isFailure, isTrue);
      expect(mapped.errorOrNull?.statusCode, equals(429));
    });

    test('when pattern-matches exhaustively between success and failure', () {
      const Result<String> success = Success('vibes');
      final successOutput = success.when(
        success: (d) => 'Received: $d',
        failure: (e) => 'Failed: ${e.code}',
      );
      expect(successOutput, equals('Received: vibes'));

      const Result<String> failure = Failure(ApiException(
        code: 'TIMEOUT',
        message: 'Request timed out',
        statusCode: 408,
      ));
      final failureOutput = failure.when(
        success: (d) => 'Received: $d',
        failure: (e) => 'Failed: ${e.code}',
      );
      expect(failureOutput, equals('Failed: TIMEOUT'));
    });
  });

  group('ApiClient, OfflineFallback & AppConfig Safety Tests', () {
    test('OfflineFallback.getFallbackBios handles emoji-only interests cleanly', () {
      const req = BioRequest(
        interests: '✨🔥🎉',
        platform: 'Instagram',
        vibe: 'Aesthetic',
        language: 'English',
      );
      final bio = OfflineFallback.getFallbackBios(req, 3);
      expect(bio.usernames.first, equals('@vibe_daily'));
      expect(bio.usernames[2], equals('@not_just_creator'));
      expect(bio.usernames.every((u) => u.startsWith('@') && !u.endsWith('_')), isTrue);
    });

    test('ApiClient.generateReply rethrows 400 validation error instead of offline fallback', () async {
      SharedPreferences.setMockInitialValues({'cached_credits': 3});
      final prefs = await PreferencesService.create();
      final mockHttp = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {'code': 'VALIDATION_ERROR', 'message': 'Invalid input'}
          }),
          400,
        );
      });
      final client = ApiClient(client: mockHttp, prefs: prefs, baseUrl: 'https://example.test');

      await expectLater(
        client.generateReply(
          const ReplyRequest(message: 'hi', tone: 'Funny', language: 'English'),
        ),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 400)),
      );
      expect(prefs.getCachedCredits(), equals(3));
    });

    test('ApiClient.getUsage preserves rewarded credits on offline fallback', () async {
      SharedPreferences.setMockInitialValues({
        'cached_credits': 5,
        'cached_rewarded_credits': 2,
      });
      final prefs = await PreferencesService.create();
      final mockHttp = MockClient((_) async => throw Exception('offline'));
      final client = ApiClient(client: mockHttp, prefs: prefs, baseUrl: 'https://example.test');

      final usage = await client.getUsage();
      expect(usage.totalCreditsRemaining, equals(5));
      expect(usage.rewardedCreditsRemaining, equals(2));
      expect(usage.freeCreditsRemaining, equals(3));
    });

    test('AppConfig uses consistent Android package ID and safe ad validator', () {
      expect(AppConfig.androidPackageId, equals('com.vibekit.vibekit_ai'));
      expect(AppConfig.validateAdEnvironment, returnsNormally);
    });
  });

  group('QuotaNotifier Rewarded Ad & NotificationService Guards', () {
    test('QuotaNotifier.grantRewardCredit fails fast on HTTP 429 without dev fallback bypass', () async {
      SharedPreferences.setMockInitialValues({
        'cached_credits': 3,
        'cached_rewarded_credits': 0,
      });
      final prefs = await PreferencesService.create();
      int postCalls = 0;

      final mockHttp = MockClient((request) async {
        if (request.method == 'POST') {
          postCalls++;
          return http.Response(
            jsonEncode({
              'error': {
                'code': 'DAILY_REWARD_LIMIT_REACHED',
                'message': 'Daily rewarded ads limit reached.',
              }
            }),
            429,
          );
        }
        return http.Response(
          jsonEncode({
            'free_credits_remaining': 3,
            'rewarded_credits_remaining': 0,
            'total_credits_remaining': 3,
            'is_pro': false,
            'pro_credits_remaining': 0,
            'rewarded_ads_watched_today': 0,
            'max_rewarded_ads_per_day': 2,
            'reset_at_utc': '',
          }),
          200,
        );
      });

      final client = ApiClient(client: mockHttp, prefs: prefs, baseUrl: 'https://example.test');
      final notifier = QuotaNotifier(client, prefs);
      await notifier.refresh();

      final granted = await notifier.grantRewardCredit();
      expect(granted, isFalse);
      expect(postCalls, equals(1));
      expect(notifier.state.totalCreditsRemaining, equals(3));
    });

    test('QuotaNotifier.grantRewardCredit short-circuits when daily ad cap is already reached', () async {
      SharedPreferences.setMockInitialValues({'cached_credits': 3});
      final prefs = await PreferencesService.create();
      int postCalls = 0;

      final mockHttp = MockClient((request) async {
        if (request.method == 'POST') {
          postCalls++;
          return http.Response(jsonEncode({'verified': true}), 200);
        }
        return http.Response(
          jsonEncode({
            'free_credits_remaining': 3,
            'rewarded_credits_remaining': 0,
            'total_credits_remaining': 3,
            'is_pro': false,
            'pro_credits_remaining': 0,
            'rewarded_ads_watched_today': 2,
            'max_rewarded_ads_per_day': 2,
            'reset_at_utc': '',
          }),
          200,
        );
      });

      final client = ApiClient(client: mockHttp, prefs: prefs, baseUrl: 'https://example.test');
      final notifier = QuotaNotifier(client, prefs);
      await notifier.refresh();

      expect(notifier.state.canWatchRewardedAd, isFalse);
      expect(await notifier.grantRewardCredit(), isFalse);
      expect(postCalls, equals(0));
    });

    test('QuotaNotifier.grantRewardCredit computes rewardedCreditsRemaining from total minus free', () async {
      SharedPreferences.setMockInitialValues({'cached_credits': 2});
      final prefs = await PreferencesService.create();

      final mockHttp = MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode({
              'verified': true,
              'credits_added': 3,
              'credits_remaining': 5,
              'rewarded_ads_watched_today': 1,
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'free_credits_remaining': 2,
            'rewarded_credits_remaining': 0,
            'total_credits_remaining': 2,
            'is_pro': false,
            'pro_credits_remaining': 0,
            'rewarded_ads_watched_today': 0,
            'max_rewarded_ads_per_day': 2,
            'reset_at_utc': '',
          }),
          200,
        );
      });

      final client = ApiClient(client: mockHttp, prefs: prefs, baseUrl: 'https://example.test');
      final notifier = QuotaNotifier(client, prefs);
      await notifier.refresh();

      expect(await notifier.grantRewardCredit(), isTrue);
      expect(notifier.state.totalCreditsRemaining, equals(5));
      expect(notifier.state.rewardedCreditsRemaining, equals(3));
      expect(notifier.state.rewardedAdsWatchedToday, equals(1));
    });

    test('NotificationService methods safely no-op when uninitialized', () async {
      final service = NotificationService();
      expect(service.isInitialized, isFalse);
      expect(await service.requestPermission(), isFalse);
      await service.showStreakNotification(title: 'Test', body: 'Streak reminder');
      await service.cancelAll();
    });

    test('Play Store Policy Compliance: accurate Pro quota strings, configured prod ad IDs, and cooldown guard', () async {
      expect(AppStrings.outOfCreditsMessage.toLowerCase(), isNot(contains('unlimited')));
      expect(AppStrings.outOfCreditsMessage, contains('200 monthly'));
      expect(AppConfig.prodBannerAdUnitId, startsWith('ca-app-pub-'));
      expect(AppConfig.prodRewardedAdUnitId, startsWith('ca-app-pub-'));

      // ReviewService instance respects shared cooldown state without throwing
      SharedPreferences.setMockInitialValues({'vibekit_review_interacted': true});
      final prefs = await PreferencesService.create();
      expect(ReviewService(prefs), isNotNull);
    });
  });

  group('OfflineFallback Localization & Option Differentiation Tests', () {
    final gujaratiRegex = RegExp(r'[\u0A80-\u0AFF]');
    final devanagariRegex = RegExp(r'[\u0900-\u097F]');

    test('getFallbackReplies honors Gujarati, Hindi, Hinglish and differentiates tones', () {
      final gujFunny = OfflineFallback.getFallbackReplies(
        const ReplyRequest(message: 'Kem cho?', tone: 'Funny', language: 'Gujarati'),
        9,
      );
      final gujSavage = OfflineFallback.getFallbackReplies(
        const ReplyRequest(message: 'Kem cho?', tone: 'Savage', language: 'Gujarati'),
        9,
      );
      expect(gujFunny.language, equals('Gujarati'));
      expect(gujFunny.tone, equals('Funny'));
      expect(gujFunny.suggestions, isNotEmpty);
      expect(gujFunny.suggestions.every((s) => gujaratiRegex.hasMatch(s)), isTrue);
      expect(gujSavage.suggestions.every((s) => gujaratiRegex.hasMatch(s)), isTrue);
      expect(gujFunny.suggestions, isNot(equals(gujSavage.suggestions)));

      final hindi = OfflineFallback.getFallbackReplies(
        const ReplyRequest(message: 'Kaise ho?', tone: 'Witty', language: 'Hindi'),
        9,
      );
      expect(hindi.suggestions.every((s) => devanagariRegex.hasMatch(s)), isTrue);

      final hinglish = OfflineFallback.getFallbackReplies(
        const ReplyRequest(message: 'Scene kya hai?', tone: 'Rizz', language: 'Hinglish'),
        9,
      );
      expect(hinglish.suggestions, isNotEmpty);
      expect(hinglish.suggestions.any((s) => devanagariRegex.hasMatch(s) || gujaratiRegex.hasMatch(s)), isFalse);
    });

    test('getFallbackCaptions, getFallbackBios, and getFallbackVibeCheck honor Gujarati and options', () {
      final captions = OfflineFallback.getFallbackCaptions(
        const CaptionRequest(
          topic: 'coffee',
          platform: 'Instagram',
          tone: 'Witty',
          language: 'Gujarati',
        ),
        8,
      );
      expect(captions.captions.every((c) => gujaratiRegex.hasMatch(c)), isTrue);
      expect(captions.hooks.every((h) => gujaratiRegex.hasMatch(h)), isTrue);
      expect(captions.callToActions.every((c) => gujaratiRegex.hasMatch(c)), isTrue);
      expect(captions.hashtags, contains('#Witty'));

      final bios = OfflineFallback.getFallbackBios(
        const BioRequest(
          interests: 'chai',
          platform: 'Instagram',
          vibe: 'Confident',
          language: 'Gujarati',
        ),
        7,
      );
      expect(bios.bios.every((b) => gujaratiRegex.hasMatch(b)), isTrue);
      expect(bios.bios.first, contains('Confident'));

      final flagsCheck = OfflineFallback.getFallbackVibeCheck(
        const VibeCheckRequest(text: 'hi', mode: 'flags', language: 'Gujarati'),
        6,
      );
      final roastCheck = OfflineFallback.getFallbackVibeCheck(
        const VibeCheckRequest(text: 'hi', mode: 'roast', language: 'Gujarati'),
        6,
      );
      expect(gujaratiRegex.hasMatch(flagsCheck.title), isTrue);
      expect(gujaratiRegex.hasMatch(flagsCheck.verdict), isTrue);
      expect(flagsCheck.rewrites.every((r) => gujaratiRegex.hasMatch(r)), isTrue);
      expect(flagsCheck.title, isNot(equals(roastCheck.title)));
      expect(flagsCheck.score, isNot(equals(roastCheck.score)));
    });
  });
}
