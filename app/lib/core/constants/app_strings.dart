/// Centralized string constants for VibeKit AI client.
/// Eliminates hardcoded magic strings across screens, dialogs, and errors.
class AppStrings {
  AppStrings._();

  // App Identity
  static const String appName = 'VibeKit AI';
  static const String appTagline = 'Smart Replies, Viral Captions & Bio Studio';

  // Navigation & Feature Titles
  static const String replyStudioTitle = 'Reply Studio';
  static const String captionLabTitle = 'Caption Lab';
  static const String bioLabTitle = 'Bio Studio';
  static const String cardMakerTitle = 'Card Studio';
  static const String historyTitle = 'Saved Cards & History';
  static const String settingsTitle = 'Settings';
  static const String paywallTitle = 'VibeKit Pro';

  // Quota & Billing
  static const String outOfCreditsTitle = 'Daily Credits Exhausted';
  static const String outOfCreditsMessage =
      'You have used all daily free credits. Watch a short video to earn +3 credits or upgrade to Pro for unlimited generation.';
  static const String watchAdButton = 'Watch Video (+3 Credits)';
  static const String upgradeProButton = 'Unlock VibeKit Pro';
  static const String freeCreditsBadge = 'Free Credits';
  static const String proCreditsBadge = 'PRO Active';

  // Generation Actions
  static const String generateButton = 'Generate';
  static const String generatingLabel = 'Cooking up vibes...';
  static const String copySuccess = 'Copied to clipboard!';
  static const String shareSuccess = 'Shared successfully!';
  static const String saveSuccess = 'Saved to favorites!';

  // Errors
  static const String networkError =
      'No internet connection. Please check your network and try again.';
  static const String timeoutError =
      'Request timed out. The server took too long to respond.';
  static const String genericError =
      'Something went wrong. Please try again in a moment.';
  static const String quotaExceededError =
      'Daily limit reached. Please watch an ad or upgrade to Pro.';
}
