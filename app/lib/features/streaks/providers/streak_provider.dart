import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers/app_providers.dart';
import '../../../models/streak_model.dart';

class StreakNotifier extends StateNotifier<StreakModel> {
  final ApiClient _client;
  final Ref? _ref;
  String? _lastError;

  String? get lastError => _lastError;

  StreakNotifier(this._client, [this._ref]) : super(StreakModel.initial()) {
    fetchStreak();
  }

  int _readBonusXp() {
    try {
      return _ref?.read(preferencesServiceProvider).getAchievementBonusXp() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> fetchStreak() async {
    try {
      final streak = await _client.getStreak();
      if (!mounted) return;
      final totalXp = streak.totalXp + _readBonusXp();
      state = streak.copyWith(
        totalXp: totalXp,
        level: (totalXp / 100).floor() + 1,
      );
    } catch (_) {
      // Retain optimistic local state on error
    }
  }

  void updateStreakLocally(StreakModel updated) {
    if (!mounted) return;
    state = updated;
  }

  void reset() {
    if (!mounted) return;
    state = StreakModel.initial();
  }

  Future<int> recordAction(String action) async {
    try {
      final res = await _client.checkinStreak(action);
      if (!mounted) return -1;
      if (res['success'] == true) {
        final xpAwarded = (res['xp_awarded'] as num?)?.toInt() ?? 0;
        final newXp = state.totalXp + xpAwarded;
        state = state.copyWith(
          currentStreak: (res['current_streak'] as num?)?.toInt() ?? state.currentStreak,
          longestStreak: (res['longest_streak'] as num?)?.toInt() ?? state.longestStreak,
          totalXp: newXp,
          level: (newXp / 100).floor() + 1,
          checkedInToday: true,
        );
        return xpAwarded;
      }
      return -1;
    } catch (_) {
      return -1;
    }
  }

  Future<bool> claimMilestone(int day, [WidgetRef? fallbackRef]) async {
    try {
      final res = await _client.claimStreakMilestone(day);
      if (!mounted) return false;
      if (res['success'] == true) {
        final updated = List<int>.from(state.claimedMilestones);
        if (!updated.contains(day)) updated.add(day);
        state = state.copyWith(claimedMilestones: updated);
        if (_ref != null) {
          _ref.read(quotaProvider.notifier).refresh();
        } else if (fallbackRef != null) {
          fallbackRef.read(quotaProvider.notifier).refresh();
        }
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> earnFreeze({bool retryForSsv = false}) async {
    _lastError = null;
    final maxAttempts = retryForSsv ? 4 : 1;
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      if (attempt > 0) {
        await Future.delayed(Duration(milliseconds: 1000 * attempt));
      }
      if (!mounted) return false;
      try {
        final res = await _client.earnStreakFreeze();
        if (!mounted) return false;
        if (res['success'] == true) {
          state = state.copyWith(
            freezeCount: (res['freeze_count'] as num?)?.toInt() ?? (state.freezeCount + 1),
          );
          _ref?.read(quotaProvider.notifier).refresh();
          return true;
        }
        _lastError = 'Could not unlock a streak freeze right now.';
        return false;
      } on ApiException catch (e) {
        if (retryForSsv && e.code == 'AD_REQUIRED' && attempt < maxAttempts - 1) {
          continue;
        }
        _lastError = e.message;
        return false;
      } catch (_) {
        _lastError = 'Network error. Please check your connection and try again.';
        return false;
      }
    }
    return false;
  }
}

final streakProvider = StateNotifierProvider<StreakNotifier, StreakModel>((ref) {
  final client = ref.watch(apiClientProvider);
  return StreakNotifier(client, ref);
});
