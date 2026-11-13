class StreakModel {
  final int currentStreak;
  final int longestStreak;
  final String lastCheckinDate;
  final int freezeCount;
  final bool checkedInToday;
  final int totalXp;
  final int level;
  final List<int> claimedMilestones;

  const StreakModel({
    required this.currentStreak,
    required this.longestStreak,
    required this.lastCheckinDate,
    required this.freezeCount,
    required this.checkedInToday,
    required this.totalXp,
    required this.level,
    required this.claimedMilestones,
  });

  factory StreakModel.initial() {
    return const StreakModel(
      currentStreak: 0,
      longestStreak: 0,
      lastCheckinDate: '',
      freezeCount: 0,
      checkedInToday: false,
      totalXp: 0,
      level: 1,
      claimedMilestones: [],
    );
  }

  factory StreakModel.fromJson(Map<String, dynamic> json) {
    final rawMilestones = json['claimed_milestones'];
    final List<int> milestones = [];
    if (rawMilestones is List) {
      for (final m in rawMilestones) {
        if (m is num) milestones.add(m.toInt());
      }
    }

    return StreakModel(
      currentStreak: (json['current_streak'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longest_streak'] as num?)?.toInt() ?? 0,
      lastCheckinDate: (json['last_checkin_date'] as String?) ?? '',
      freezeCount: (json['freeze_count'] as num?)?.toInt() ?? 0,
      checkedInToday: (json['checked_in_today'] as bool?) ?? false,
      totalXp: (json['total_xp'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 1,
      claimedMilestones: milestones,
    );
  }

  Map<String, dynamic> toJson() => {
        'current_streak': currentStreak,
        'longest_streak': longestStreak,
        'last_checkin_date': lastCheckinDate,
        'freeze_count': freezeCount,
        'checked_in_today': checkedInToday,
        'total_xp': totalXp,
        'level': level,
        'claimed_milestones': claimedMilestones,
      };

  bool isMilestoneClaimed(int day) => claimedMilestones.contains(day);

  StreakModel copyWith({
    int? currentStreak,
    int? longestStreak,
    String? lastCheckinDate,
    int? freezeCount,
    bool? checkedInToday,
    int? totalXp,
    int? level,
    List<int>? claimedMilestones,
  }) {
    return StreakModel(
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastCheckinDate: lastCheckinDate ?? this.lastCheckinDate,
      freezeCount: freezeCount ?? this.freezeCount,
      checkedInToday: checkedInToday ?? this.checkedInToday,
      totalXp: totalXp ?? this.totalXp,
      level: level ?? this.level,
      claimedMilestones: claimedMilestones ?? this.claimedMilestones,
    );
  }
}
