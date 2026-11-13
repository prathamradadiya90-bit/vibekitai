import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_exception.dart';
import '../providers/app_providers.dart';
import '../services/analytics_service.dart';
import '../../models/history_item.dart';

/// Standard state representing an asynchronous AI generation cycle.
class GenerationState<TResult> {
  final bool isGenerating;
  final String? errorMessage;
  final bool isQuotaExceeded;
  final TResult? result;

  const GenerationState({
    this.isGenerating = false,
    this.errorMessage,
    this.isQuotaExceeded = false,
    this.result,
  });

  GenerationState<TResult> copyWith({
    bool? isGenerating,
    String? errorMessage,
    bool? isQuotaExceeded,
    TResult? result,
  }) {
    return GenerationState<TResult>(
      isGenerating: isGenerating ?? this.isGenerating,
      errorMessage: errorMessage,
      isQuotaExceeded: isQuotaExceeded ?? this.isQuotaExceeded,
      result: result ?? this.result,
    );
  }
}

/// Generic generation notifier that handles loading states, error mapping,
/// quota enforcement, credit synchronization, history storage, and analytics.
class GenerationNotifier<TRequest, TResult>
    extends StateNotifier<GenerationState<TResult>> {
  final Ref ref;

  GenerationNotifier(this.ref) : super(GenerationState<TResult>());

  Future<bool> execute({
    required TRequest request,
    required Future<TResult> Function() caller,
    required int Function(TResult result) getCreditsRemaining,
    required List<HistoryItem> Function(TResult result) buildHistoryItems,
    String actionType = 'general',
  }) async {
    // 1. Quota Check
    final quota = ref.read(quotaProvider);
    if (!quota.canGenerate) {
      state = state.copyWith(
        isGenerating: false,
        isQuotaExceeded: true,
        errorMessage: 'Daily credits exhausted. Upgrade to Pro or watch an ad.',
      );
      AnalyticsService.instance.logQuotaExceeded();
      return false;
    }

    state = state.copyWith(
      isGenerating: true,
      errorMessage: null,
      isQuotaExceeded: false,
    );

    try {
      // 2. Perform Network Call
      final result = await caller();

      // 3. Sync Credits from Authoritative Server Result
      final remaining = getCreditsRemaining(result);
      ref.read(quotaProvider.notifier).syncCredits(remaining);

      // 4. Record to Local History Database
      final db = ref.read(localDatabaseProvider);
      final historyItems = buildHistoryItems(result);
      for (final item in historyItems) {
        await db.insertItem(item);
      }

      // 5. Track Funnel Analytics
      AnalyticsService.instance.logGenerateSuccess(actionType);

      state = state.copyWith(
        isGenerating: false,
        result: result,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(
        isGenerating: false,
        errorMessage: e.message,
        isQuotaExceeded: e.isQuotaExceeded,
      );
      if (e.isQuotaExceeded) {
        AnalyticsService.instance.logQuotaExceeded();
      }
      return false;
    } catch (e) {
      state = state.copyWith(
        isGenerating: false,
        errorMessage: 'An error occurred: $e',
      );
      return false;
    }
  }

  void reset() {
    state = GenerationState<TResult>();
  }
}
