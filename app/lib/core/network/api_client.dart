import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../config/app_config.dart';
import '../storage/preferences_service.dart';
import '../../models/generation_models.dart';
import '../../models/quota_model.dart';
import '../../models/streak_model.dart';
import 'api_endpoints.dart';
import 'api_exception.dart';
import 'result.dart';

class ApiClient {
  final http.Client _client;
  final PreferencesService _prefs;
  final String _baseUrl;

  ApiClient({
    http.Client? client,
    required PreferencesService prefs,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _prefs = prefs,
        _baseUrl = baseUrl ?? AppConfig.defaultApiUrl;

  Map<String, String> _buildHeaders({String? idempotencyKey}) {
    final requestId = const Uuid().v4();
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Request-Id': requestId,
      'X-App-Instance-Id': _prefs.getAppInstanceId(),
      'X-App-Version': AppConfig.appVersion,
    };
    final sessionToken = _prefs.getSessionToken();
    if (sessionToken != null && sessionToken.isNotEmpty) {
      headers['X-Session-Token'] = sessionToken;
    }
    if (idempotencyKey != null) {
      headers['X-Idempotency-Key'] = idempotencyKey;
      headers['Idempotency-Key'] = idempotencyKey;
    }
    return headers;
  }

  Future<Map<String, dynamic>> _executeWithRetry({
    required Future<http.Response> Function() action,
    required bool isIdempotent,
    int maxRetries = 2,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    int attempt = 0;
    while (true) {
      try {
        final response = await action().timeout(timeout);
        // Only retry transient 502/503/504 gateway errors for idempotent calls
        if (isIdempotent &&
            attempt < maxRetries &&
            (response.statusCode == 502 ||
                response.statusCode == 503 ||
                response.statusCode == 504)) {
          attempt++;
          await Future.delayed(Duration(milliseconds: 300 * (1 << attempt)));
          continue;
        }
        return _handleResponse(response);
      } on SocketException {
        if (isIdempotent && attempt < maxRetries) {
          attempt++;
          await Future.delayed(Duration(milliseconds: 300 * (1 << attempt)));
          continue;
        }
        throw const ApiException(
          code: 'NETWORK_UNAVAILABLE',
          message:
              'No internet connection. Please check your network and try again.',
          statusCode: 0,
        );
      } on http.ClientException {
        if (isIdempotent && attempt < maxRetries) {
          attempt++;
          await Future.delayed(Duration(milliseconds: 300 * (1 << attempt)));
          continue;
        }
        throw const ApiException(
          code: 'NETWORK_UNAVAILABLE',
          message:
              'Unable to reach server. Please check your connection and try again.',
          statusCode: 0,
        );
      } on TimeoutException {
        if (isIdempotent && attempt < maxRetries) {
          attempt++;
          await Future.delayed(Duration(milliseconds: 300 * (1 << attempt)));
          continue;
        }
        throw const ApiException(
          code: 'REQUEST_TIMEOUT',
          message: 'Request timed out. The server took too long to respond.',
          statusCode: 408,
        );
      } catch (e) {
        if (e is ApiException) rethrow;
        throw ApiException(
          code: 'UNKNOWN_ERROR',
          message: 'An unexpected connection error occurred: ${e.toString()}',
          statusCode: 0,
        );
      }
    }
  }

  Future<Map<String, dynamic>> _post(
    String endpoint,
    Map<String, dynamic> body, {
    String? idempotencyKey,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    final url = Uri.parse('$_baseUrl$endpoint');
    final finalIdempotencyKey = idempotencyKey ?? const Uuid().v4();
    final isIdempotent = idempotencyKey != null ||
        endpoint.contains('/generations/') ||
        endpoint.contains('/auth/');

    return _executeWithRetry(
      action: () => _client.post(
        url,
        headers: _buildHeaders(idempotencyKey: finalIdempotencyKey),
        body: jsonEncode(body),
      ),
      isIdempotent: isIdempotent,
      timeout: timeout,
    );
  }

  Future<Map<String, dynamic>> _get(
    String endpoint, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final url = Uri.parse('$_baseUrl$endpoint');

    return _executeWithRetry(
      action: () => _client.get(
        url,
        headers: _buildHeaders(),
      ),
      isIdempotent: true, // GET is naturally idempotent
      timeout: timeout,
    );
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    Map<String, dynamic> data = {};
    try {
      if (response.body.isNotEmpty) {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {
      // In case body was not valid JSON
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    final errorCode =
        (data['error']?['code'] as String?) ?? 'HTTP_${response.statusCode}';
    final errorMessage = (data['error']?['message'] as String?) ??
        'Request failed with status ${response.statusCode}';

    throw ApiException(
      code: errorCode,
      message: errorMessage,
      statusCode: response.statusCode,
      details: data['error']?['details'],
    );
  }

  // API Methods

  /// Fetches daily usage quota and subscription status
  Future<QuotaModel> getUsage() async {
    try {
      final res = await _get(ApiEndpoints.usage);
      final quota = QuotaModel.fromJson(res);
      await _prefs.setCachedCredits(quota.totalCreditsRemaining);
      await _prefs.setCachedIsPro(quota.isPro);
      return quota;
    } catch (e) {
      debugPrint('ApiClient.getUsage error ($e). Returning cached quota.');
      return QuotaModel(
        freeCreditsRemaining: _prefs.getCachedCredits(),
        rewardedCreditsRemaining: 0,
        totalCreditsRemaining: _prefs.getCachedCredits(),
        isPro: _prefs.getCachedIsPro(),
        proCreditsRemaining: _prefs.getCachedIsPro() ? 200 : 0,
        proCycleResetsAt: null,
        rewardedAdsWatchedToday: 0,
        maxRewardedAdsPerDay: 2,
        resetAtUtc: '',
      );
    }
  }

  /// Generates 3 replies with selected tone and language
  Future<ReplyResponse> generateReply(ReplyRequest request) async {
    final res = await _post(ApiEndpoints.generateReply, request.toJson());
    final reply = ReplyResponse.fromJson(res);
    await _prefs.setCachedCredits(reply.creditsRemaining);
    return reply;
  }

  /// Generates social captions, hooks, CTAs, and hashtags
  Future<CaptionResponse> generateCaption(CaptionRequest request) async {
    final res = await _post(ApiEndpoints.generateCaption, request.toJson());
    final caption = CaptionResponse.fromJson(res);
    await _prefs.setCachedCredits(caption.creditsRemaining);
    return caption;
  }

  /// Generates profile bios and usernames
  Future<BioResponse> generateBio(BioRequest request) async {
    final res = await _post(ApiEndpoints.generateBio, request.toJson());
    final bio = BioResponse.fromJson(res);
    await _prefs.setCachedCredits(bio.creditsRemaining);
    return bio;
  }

  /// Analyzes text vibe, rates score, critiques, and suggests leveled-up rewrites
  Future<VibeCheckResponse> checkVibe(VibeCheckRequest request) async {
    final res = await _post(ApiEndpoints.vibeCheck, request.toJson());
    final vibe = VibeCheckResponse.fromJson(res);
    await _prefs.setCachedCredits(vibe.creditsRemaining);
    return vibe;
  }

  /// Submits Play Store purchase token for server-side verification
  Future<Map<String, dynamic>> verifyPurchase({
    required String productId,
    required String purchaseToken,
    required String orderId,
  }) async {
    final res = await _post(ApiEndpoints.verifyPurchase, {
      'product_id': productId,
      'purchase_token': purchaseToken,
      'order_id': orderId,
    });
    if (res['is_verified'] == true) {
      await _prefs.setCachedIsPro(true);
    }
    return res;
  }

  /// Submits consumable credit pack token for server-side verification and crediting
  Future<Map<String, dynamic>> verifyCreditPack({
    required String productId,
    required String purchaseToken,
    required String orderId,
  }) async {
    final res = await _post(ApiEndpoints.verifyCreditPack, {
      'product_id': productId,
      'purchase_token': purchaseToken,
      'order_id': orderId,
    });
    if (res['credits_granted'] != null && (res['credits_granted'] as num) > 0) {
      final current = _prefs.getCachedCredits();
      await _prefs.setCachedCredits(current + (res['credits_granted'] as num).toInt());
    }
    return res;
  }

  /// Requests a fresh single-use nonce for AdMob SSV custom_data
  Future<String?> requestAdNonce() async {
    try {
      final res = await _post(ApiEndpoints.requestAdNonce, {});
      return res['nonce'] as String?;
    } catch (e) {
      debugPrint('Error requesting ad nonce: $e');
      return null;
    }
  }

  /// Verifies an AdMob rewarded ad completion callback with SSV
  Future<Map<String, dynamic>> verifyRewardedAd({
    String? rewardId,
    String? transactionId,
    String? nonce,
    String? adNetwork,
  }) async {
    final res = await _post(ApiEndpoints.verifyReward, {
      if (rewardId != null) 'reward_id': rewardId,
      if (transactionId != null) 'transaction_id': transactionId,
      if (nonce != null) 'nonce': nonce,
      if (adNetwork != null) 'ad_network': adNetwork,
    });
    if (res['credits_remaining'] != null) {
      await _prefs.setCachedCredits((res['credits_remaining'] as num).toInt());
    }
    return res;
  }

  /// Requests complete deletion of backend installation data
  Future<void> deleteUserData() async {
    await _post(ApiEndpoints.deleteData, {});
  }

  /// Sends user feedback message to backend
  Future<Map<String, dynamic>> sendFeedback(String message) async {
    return await _post(ApiEndpoints.feedback, {'message': message});
  }

  /// Fetches daily streak, XP level, and claimed milestones
  Future<StreakModel> getStreak() async {
    try {
      final res = await _get(ApiEndpoints.streak);
      return StreakModel.fromJson(res);
    } catch (e) {
      debugPrint('ApiClient.getStreak error ($e). Returning initial streak.');
      return StreakModel.initial();
    }
  }

  /// Records daily user activity checkin
  Future<Map<String, dynamic>> checkinStreak(String action) async {
    final offsetMinutes = DateTime.now().timeZoneOffset.inMinutes;
    return await _post(ApiEndpoints.streakCheckin, {
      'utc_offset_minutes': offsetMinutes,
      'action': action,
    });
  }

  /// Claims milestone rewards for 3, 7, 14, or 30 days
  Future<Map<String, dynamic>> claimStreakMilestone(int milestoneDay) async {
    return await _post(ApiEndpoints.streakClaimMilestone, {
      'milestone_day': milestoneDay,
    });
  }

  /// Free users earn a streak freeze by watching a rewarded ad
  Future<Map<String, dynamic>> earnStreakFreeze() async {
    return await _post(ApiEndpoints.streakEarnFreeze, {});
  }

  /// Claims referral bonus (+2 credits)
  Future<Map<String, dynamic>> claimReferral(String referrerCode, {String? integrityToken}) async {
    final res = await _post(ApiEndpoints.claimReferral, {
      'referrer_code': referrerCode,
      if (integrityToken != null) 'integrity_token': integrityToken,
    });
    if (res['credits_awarded'] != null) {
      final current = _prefs.getCachedCredits();
      await _prefs.setCachedCredits(current + (res['credits_awarded'] as num).toInt());
    }
    return res;
  }

  /// Fetches referral code and statistics
  Future<Map<String, dynamic>> getReferralStats() async {
    try {
      return await _get(ApiEndpoints.referralStats);
    } catch (e) {
      return {
        'referral_code': _prefs.getAppInstanceId(),
        'total_referred': 0,
        'max_referrals': 10,
        'credits_earned': 0,
        'can_refer_more': true,
      };
    }
  }

  /// Fetches remote configuration and feature flags
  Future<Map<String, dynamic>> getConfig() async {
    try {
      return await _get(ApiEndpoints.config);
    } catch (e) {
      return {};
    }
  }

  /// Functional Result wrapper for safe execution without throwing unhandled exceptions.
  Future<Result<T>> runCatching<T>(Future<T> Function() call) async {
    try {
      final res = await call();
      return Success(res);
    } on ApiException catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(ApiException(
        code: 'UNKNOWN_ERROR',
        message: e.toString(),
        statusCode: 0,
      ));
    }
  }

  Future<Result<QuotaModel>> getUsageSafe() => runCatching(getUsage);
  Future<Result<ReplyResponse>> generateReplySafe(ReplyRequest req) => runCatching(() => generateReply(req));
  Future<Result<CaptionResponse>> generateCaptionSafe(CaptionRequest req) => runCatching(() => generateCaption(req));
  Future<Result<BioResponse>> generateBioSafe(BioRequest req) => runCatching(() => generateBio(req));
}
