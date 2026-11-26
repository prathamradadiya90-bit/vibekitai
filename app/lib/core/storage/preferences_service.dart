import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class PreferencesService {
  static const String _keyAppInstanceId = 'app_instance_id';
  static const String _keyOnboardingDone = 'onboarding_done';
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyLanguage = 'selected_language';
  static const String _keyCredits = 'cached_credits';
  static const String _keyIsPro = 'cached_is_pro';
  static const String _keySuccessGenerations = 'successful_generations_count';
  static const String _keyReviewPrompted = 'review_prompted_done';
  static const String _keySessionToken = 'auth_session_token';
  static const String _keyCustomApiUrl = 'custom_api_url';

  final SharedPreferences _prefs;

  PreferencesService(this._prefs);

  static Future<PreferencesService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return PreferencesService(prefs);
  }

  String? getCustomApiUrl() {
    final url = _prefs.getString(_keyCustomApiUrl)?.trim();
    return (url != null && url.isNotEmpty) ? url : null;
  }

  Future<void> setCustomApiUrl(String? url) async {
    if (url == null || url.trim().isEmpty) {
      await _prefs.remove(_keyCustomApiUrl);
    } else {
      await _prefs.setString(_keyCustomApiUrl, url.trim());
    }
  }

  /// Cryptographic pseudonymous installation ID used for daily quota anchoring.
  /// Never ties to personal information.
  String getAppInstanceId() {
    String? id = _prefs.getString(_keyAppInstanceId);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      _prefs.setString(_keyAppInstanceId, id);
    }
    return id;
  }

  bool isOnboardingCompleted() {
    return _prefs.getBool(_keyOnboardingDone) ?? false;
  }

  Future<void> setOnboardingCompleted(bool value) async {
    await _prefs.setBool(_keyOnboardingDone, value);
  }

  String getThemeMode() {
    return _prefs.getString(_keyThemeMode) ?? 'system';
  }

  Future<void> setThemeMode(String mode) async {
    await _prefs.setString(_keyThemeMode, mode);
  }

  String getLanguage() {
    return _prefs.getString(_keyLanguage) ?? 'English';
  }

  Future<void> setLanguage(String lang) async {
    await _prefs.setString(_keyLanguage, lang);
  }

  static const String _keyLastCreditResetDate = 'last_credit_reset_date';
  static const String _keyRewardedAdsWatched = 'rewarded_ads_watched_today';
  static const String _keyRewardedCredits = 'cached_rewarded_credits';

  String getTodayLocalDateStr() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String? getLastCreditResetDate() {
    return _prefs.getString(_keyLastCreditResetDate);
  }

  Future<void> setLastCreditResetDate(String dateStr) async {
    await _prefs.setString(_keyLastCreditResetDate, dateStr);
  }

  int getCachedRewardedCredits() {
    return (_prefs.getInt(_keyRewardedCredits) ?? 0).clamp(0, 9999);
  }

  Future<void> setCachedRewardedCredits(int credits) async {
    await _prefs.setInt(_keyRewardedCredits, credits.clamp(0, 9999));
  }

  /// Automatically verifies if a new calendar day has started.
  /// If today is a new day, resets daily free credits while preserving carried-over rewarded credits.
  bool checkAndPerformDailyLocalReset({int defaultDailyCredits = 3}) {
    final today = getTodayLocalDateStr();
    final lastReset = getLastCreditResetDate();
    if (lastReset == null) {
      _prefs.setString(_keyLastCreditResetDate, today);
      return false;
    }
    if (lastReset != today) {
      final preservedRewarded = getCachedRewardedCredits();
      _prefs.setString(_keyLastCreditResetDate, today);
      _prefs.setInt(_keyCredits, defaultDailyCredits + preservedRewarded);
      _prefs.setInt(_keyRewardedAdsWatched, 0);
      return true;
    }
    return false;
  }

  int getCachedCredits() {
    checkAndPerformDailyLocalReset();
    return _prefs.getInt(_keyCredits) ?? 3;
  }

  Future<void> setCachedCredits(int credits) async {
    await _prefs.setInt(_keyCredits, credits);
  }

  bool getCachedIsPro() {
    return _prefs.getBool(_keyIsPro) ?? false;
  }

  Future<void> setCachedIsPro(bool isPro) async {
    await _prefs.setBool(_keyIsPro, isPro);
  }

  int getSuccessfulGenerationsCount() {
    return _prefs.getInt(_keySuccessGenerations) ?? 0;
  }

  Future<int> incrementSuccessfulGenerations() async {
    final count = getSuccessfulGenerationsCount() + 1;
    await _prefs.setInt(_keySuccessGenerations, count);
    return count;
  }

  bool hasPromptedReview() {
    return _prefs.getBool(_keyReviewPrompted) ?? false;
  }

  Future<void> setPromptedReview(bool value) async {
    await _prefs.setBool(_keyReviewPrompted, value);
  }

  String? getSessionToken() {
    return _prefs.getString(_keySessionToken);
  }

  Future<void> setSessionToken(String? token) async {
    if (token == null) {
      await _prefs.remove(_keySessionToken);
    } else {
      await _prefs.setString(_keySessionToken, token);
    }
  }

  // --- Achievement & Progress Tracking ---
  static const String _keyUnlockedAchievements = 'unlocked_achievements_list';
  static const String _keyTonesUsed = 'tones_used_set';
  static const String _keyLanguagesUsed = 'languages_used_set';
  static const String _keyCardsExported = 'cards_exported_count';
  static const String _keyChallengesSolved = 'challenges_solved_count';

  List<String> getUnlockedAchievements() {
    return _prefs.getStringList(_keyUnlockedAchievements) ?? [];
  }

  Future<void> saveUnlockedAchievement(String id) async {
    final list = getUnlockedAchievements();
    if (!list.contains(id)) {
      list.add(id);
      await _prefs.setStringList(_keyUnlockedAchievements, list);
    }
  }

  List<String> getTonesUsed() {
    return _prefs.getStringList(_keyTonesUsed) ?? [];
  }

  Future<void> recordToneUsed(String tone) async {
    final list = getTonesUsed();
    if (!list.contains(tone)) {
      list.add(tone);
      await _prefs.setStringList(_keyTonesUsed, list);
    }
  }

  List<String> getLanguagesUsed() {
    return _prefs.getStringList(_keyLanguagesUsed) ?? [];
  }

  Future<void> recordLanguageUsed(String lang) async {
    final list = getLanguagesUsed();
    if (!list.contains(lang)) {
      list.add(lang);
      await _prefs.setStringList(_keyLanguagesUsed, list);
    }
  }

  int getCardsExportedCount() {
    return _prefs.getInt(_keyCardsExported) ?? 0;
  }

  Future<int> incrementCardsExported() async {
    final count = getCardsExportedCount() + 1;
    await _prefs.setInt(_keyCardsExported, count);
    return count;
  }

  int getChallengesSolvedCount() {
    return _prefs.getInt(_keyChallengesSolved) ?? 0;
  }

  Future<int> incrementChallengesSolved() async {
    final count = getChallengesSolvedCount() + 1;
    await _prefs.setInt(_keyChallengesSolved, count);
    return count;
  }

  Future<void> clearAll() async {
    await _prefs.clear();
  }
}
