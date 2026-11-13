import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/providers/app_providers.dart';
import '../../../models/streak_model.dart';

class StreakNotifier extends StateNotifier<StreakModel> {
  final ApiClient _client;

  StreakNotifier(this._client) : super(StreakModel.initial()) {
    fetchStreak();
  }

  Future<void> fetchStreak() async {
    try {
      final streak = await _client.getStreak();
      state = streak;
    } catch (_) {
      // Retain optimistic local state on error
    }
  }

  void updateStreakLocally(StreakModel updated) {
    state = updated;
  }

  Future<void> recordAction(String action) async {
    try {
      final res = await _client.checkinStreak(action);
      if (res['success'] == true) {
        state = state.copyWith(
          currentStreak: (res['current_streak'] as num?)?.toInt() ?? state.currentStreak,
          longestStreak: (res['longest_streak'] as num?)?.toInt() ?? state.longestStreak,
          totalXp: state.totalXp + ((res['xp_awarded'] as num?)?.toInt() ?? 10),
          level: (state.totalXp / 100).floor() + 1,
          checkedInToday: true,
        );
      }
    } catch (_) {
      // Non-blocking telemetry
    }
  }

  Future<bool> claimMilestone(int day, WidgetRef ref) async {
    try {
      final res = await _client.claimStreakMilestone(day);
      if (res['success'] == true) {
        final updated = List<int>.from(state.claimedMilestones)..add(day);
        state = state.copyWith(claimedMilestones: updated);
        // Refresh quota if credits were awarded
        ref.read(quotaProvider.notifier).refresh();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> earnFreeze() async {
    try {
      final res = await _client.earnStreakFreeze();
      if (res['success'] == true) {
        state = state.copyWith(
          freezeCount: (res['freeze_count'] as num?)?.toInt() ?? (state.freezeCount + 1),
        );
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}

final streakProvider = StateNotifierProvider<StreakNotifier, StreakModel>((ref) {
  final client = ref.watch(apiClientProvider);
  return StreakNotifier(client);
});
