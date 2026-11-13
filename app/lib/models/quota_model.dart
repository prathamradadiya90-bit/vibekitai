/// Authoritative daily usage and quota status returned from the server
/// and cached locally for fast presentation.
class QuotaModel {
  final int freeCreditsRemaining;
  final int rewardedCreditsRemaining;
  final int totalCreditsRemaining;
  final bool isPro;
  final int proCreditsRemaining;
  final String? proCycleResetsAt;
  final int rewardedAdsWatchedToday;
  final int maxRewardedAdsPerDay;
  final String resetAtUtc;

  const QuotaModel({
    required this.freeCreditsRemaining,
    required this.rewardedCreditsRemaining,
    required this.totalCreditsRemaining,
    required this.isPro,
    required this.proCreditsRemaining,
    this.proCycleResetsAt,
    required this.rewardedAdsWatchedToday,
    required this.maxRewardedAdsPerDay,
    required this.resetAtUtc,
  });

  factory QuotaModel.initial() {
    return const QuotaModel(
      freeCreditsRemaining: 3,
      rewardedCreditsRemaining: 0,
      totalCreditsRemaining: 3,
      isPro: false,
      proCreditsRemaining: 0,
      proCycleResetsAt: null,
      rewardedAdsWatchedToday: 0,
      maxRewardedAdsPerDay: 2,
      resetAtUtc: '',
    );
  }

  factory QuotaModel.fromJson(Map<String, dynamic> json) {
    return QuotaModel(
      freeCreditsRemaining:
          (json['free_credits_remaining'] as num?)?.toInt() ?? 0,
      rewardedCreditsRemaining:
          (json['rewarded_credits_remaining'] as num?)?.toInt() ?? 0,
      totalCreditsRemaining:
          (json['total_credits_remaining'] as num?)?.toInt() ?? 0,
      isPro: (json['is_pro'] as bool?) ?? false,
      proCreditsRemaining:
          (json['pro_credits_remaining'] as num?)?.toInt() ?? 0,
      proCycleResetsAt: json['pro_cycle_resets_at'] as String?,
      rewardedAdsWatchedToday:
          (json['rewarded_ads_watched_today'] as num?)?.toInt() ?? 0,
      maxRewardedAdsPerDay:
          (json['max_rewarded_ads_per_day'] as num?)?.toInt() ?? 2,
      resetAtUtc: (json['reset_at_utc'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'free_credits_remaining': freeCreditsRemaining,
        'rewarded_credits_remaining': rewardedCreditsRemaining,
        'total_credits_remaining': totalCreditsRemaining,
        'is_pro': isPro,
        'pro_credits_remaining': proCreditsRemaining,
        'pro_cycle_resets_at': proCycleResetsAt,
        'rewarded_ads_watched_today': rewardedAdsWatchedToday,
        'max_rewarded_ads_per_day': maxRewardedAdsPerDay,
        'reset_at_utc': resetAtUtc,
      };

  bool get canGenerate =>
      totalCreditsRemaining > 0 || (isPro && proCreditsRemaining > 0);
  bool get canWatchRewardedAd => rewardedAdsWatchedToday < maxRewardedAdsPerDay;

  QuotaModel copyWith({
    int? freeCreditsRemaining,
    int? rewardedCreditsRemaining,
    int? totalCreditsRemaining,
    bool? isPro,
    int? proCreditsRemaining,
    String? proCycleResetsAt,
    int? rewardedAdsWatchedToday,
    int? maxRewardedAdsPerDay,
    String? resetAtUtc,
  }) {
    return QuotaModel(
      freeCreditsRemaining: freeCreditsRemaining ?? this.freeCreditsRemaining,
      rewardedCreditsRemaining:
          rewardedCreditsRemaining ?? this.rewardedCreditsRemaining,
      totalCreditsRemaining:
          totalCreditsRemaining ?? this.totalCreditsRemaining,
      isPro: isPro ?? this.isPro,
      proCreditsRemaining: proCreditsRemaining ?? this.proCreditsRemaining,
      proCycleResetsAt: proCycleResetsAt ?? this.proCycleResetsAt,
      rewardedAdsWatchedToday:
          rewardedAdsWatchedToday ?? this.rewardedAdsWatchedToday,
      maxRewardedAdsPerDay: maxRewardedAdsPerDay ?? this.maxRewardedAdsPerDay,
      resetAtUtc: resetAtUtc ?? this.resetAtUtc,
    );
  }
}
