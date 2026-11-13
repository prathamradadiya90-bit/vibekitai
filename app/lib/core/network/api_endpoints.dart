class ApiEndpoints {
  ApiEndpoints._();

  static const String health = '/v1/health';
  static const String config = '/v1/config';
  static const String usage = '/v1/usage';
  static const String generateReply = '/v1/generations/reply';
  static const String generateCaption = '/v1/generations/caption';
  static const String feedback = '/v1/feedback';
  static const String deleteData = '/v1/privacy/delete-data';
  static const String verifyPurchase = '/v1/purchases/verify';
  static const String verifyCreditPack = '/v1/purchases/credit-pack';
  static const String subscriptionStatus = '/v1/subscription/status';
  static const String verifyReward = '/v1/ads/verify-reward';
  static const String requestAdNonce = '/v1/ads/request-nonce';
  static const String streak = '/v1/streak';
  static const String streakCheckin = '/v1/streak/checkin';
  static const String streakClaimMilestone = '/v1/streak/claim-milestone';
  static const String streakEarnFreeze = '/v1/streak/earn-freeze';
  static const String generateBio = '/v1/generations/bio';
  static const String vibeCheck = '/v1/generations/vibe-check';
  static const String claimReferral = '/v1/referrals/claim';
  static const String referralStats = '/v1/referrals/stats';
}
