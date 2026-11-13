class AchievementModel {
  final String id;
  final String title;
  final String description;
  final String icon;
  final int xpReward;
  final int bonusCredits;
  final String category;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final double progress;
  final String progressText;

  const AchievementModel({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.xpReward,
    this.bonusCredits = 0,
    required this.category,
    this.isUnlocked = false,
    this.unlockedAt,
    this.progress = 0.0,
    this.progressText = '',
  });

  AchievementModel copyWith({
    String? id,
    String? title,
    String? description,
    String? icon,
    int? xpReward,
    int? bonusCredits,
    String? category,
    bool? isUnlocked,
    DateTime? unlockedAt,
    double? progress,
    String? progressText,
  }) {
    return AchievementModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      xpReward: xpReward ?? this.xpReward,
      bonusCredits: bonusCredits ?? this.bonusCredits,
      category: category ?? this.category,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      progress: progress ?? this.progress,
      progressText: progressText ?? this.progressText,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'icon': icon,
        'xp_reward': xpReward,
        'bonus_credits': bonusCredits,
        'category': category,
        'is_unlocked': isUnlocked ? 1 : 0,
        'unlocked_at': unlockedAt?.toIso8601String(),
        'progress': progress,
        'progress_text': progressText,
      };

  factory AchievementModel.fromMap(Map<String, dynamic> map) =>
      AchievementModel(
        id: map['id'] as String,
        title: map['title'] as String,
        description: map['description'] as String,
        icon: map['icon'] as String,
        xpReward: (map['xp_reward'] as num?)?.toInt() ?? 0,
        bonusCredits: (map['bonus_credits'] as num?)?.toInt() ?? 0,
        category: (map['category'] as String?) ?? 'General',
        isUnlocked: (map['is_unlocked'] as num?) == 1,
        unlockedAt: map['unlocked_at'] != null
            ? DateTime.tryParse(map['unlocked_at'] as String)
            : null,
        progress: (map['progress'] as num?)?.toDouble() ?? 0.0,
        progressText: (map['progress_text'] as String?) ?? '',
      );
}

