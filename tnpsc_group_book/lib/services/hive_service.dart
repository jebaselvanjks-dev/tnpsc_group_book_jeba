import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/question.dart';
import 'dart:convert';
import 'package:package_info_plus/package_info_plus.dart';
import '../utils/app_log.dart';
import '../utils/app_date.dart';

class HiveService {
  static const String questionsBoxName = 'offline_questions';
  static const String userBoxName = 'user_data';
  static const String studyMaterialBoxName = 'study_material';

  static bool isInitialized = false;

  static Future<void> init() async {
    if (isInitialized) return;
    
    await Hive.initFlutter();
    
    // Parallelize opening boxes for faster startup
    await Future.wait([
      Hive.openBox(userBoxName),
      Hive.openBox(questionsBoxName),
      Hive.openBox(studyMaterialBoxName),
    ]);
    
    isInitialized = true;
    
    // AI_DEBUG: Run daily cleanup in the background to not block startup
    Future.microtask(() => _cleanupOldDailyData());
  }

  // AI_DEBUG: Deletes old daily stat keys to prevent local storage growth
  static Future<void> _cleanupOldDailyData() async {
    var box = Hive.box(userBoxName);
    String today = _todayDate();
    String? lastCleanupDate = box.get('last_daily_cleanup_date') as String?;
    
    if (lastCleanupDate != today) {
      List<dynamic> keys = box.keys.toList();
      List<String> keysToDelete = [];
      
      for (var key in keys) {
        if (key is String && (
            key.startsWith('reward_points_') ||
            key.startsWith('ai_usage_') ||
            key.startsWith('extra_room_attempts_') ||
            key.startsWith('room_ad_watches_') ||
            key.startsWith('reward_ad_watches_') ||
            key.startsWith('quiz_ad_watches_') ||
            key.startsWith('share_reward_earned_') ||
            key.startsWith('room_create_attempts_') ||
            key.startsWith('sticky_ai_config_')
        )) {
          // If the key belongs to a different date, add to delete list
          if (!key.endsWith(today)) {
             keysToDelete.add(key);
          }
        }
      }

      if (keysToDelete.isNotEmpty) {
        await box.deleteAll(keysToDelete);
        AppLog.d("AI_DEBUG: Mobile Memory Cleanup: Removed ${keysToDelete.length} old daily stat keys from Hive.");
      }
      
      await box.put('last_daily_cleanup_date', today);
    }
  }

  static Future<void> saveThemeMode(ThemeMode mode) async {
    await Hive.box(userBoxName).put('theme_mode', mode.name);
  }

  static ThemeMode? getThemeMode() {
    final name = Hive.box(userBoxName).get('theme_mode') as String?;
    switch (name) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      default:
        return null;
    }
  }

  static Future<void> saveLanguage(String code) async {
    await Hive.box(userBoxName).put('app_language', code);
  }

  static String getLanguage() {
    return Hive.box(userBoxName).get('app_language', defaultValue: 'ta') as String;
  }

  // Save questions for a topic with memory optimization (Keep last 10 subjects only)
  static Future<void> saveQuestions(String topic, List<Question> questions) async {
    var box = Hive.box(questionsBoxName);
    var userBox = Hive.box(userBoxName);
    
    List<Map<String, dynamic>> questionsJson = questions.map((q) => {
      'question': q.question,
      'options': q.options,
      'correctOptionIndex': q.correctOptionIndex,
      'explanation': q.explanation,
      'question_en': q.questionEn,
      'question_ta': q.questionTa,
      'options_en': q.optionsEn,
      'options_ta': q.optionsTa,
      'explanation_en': q.explanationEn,
      'explanation_ta': q.explanationTa,
    }).toList();
    
    // Save the questions
    await box.put(topic, jsonEncode(questionsJson));

    // AI_DEBUG: Check if full sync is done. If so, we keep everything.
    bool syncDone = userBox.get('is_initial_sync_done', defaultValue: false) as bool;
    if (syncDone) return;

    // Cleanup logic: Keep track of cached topics order (Only before full sync)
    List<String> cachedTopics = List<String>.from(userBox.get('cached_topics_list', defaultValue: []) as List);
    
    // Remove if already exists to move it to the end (MRU)
    cachedTopics.remove(topic);
    cachedTopics.add(topic);

    // If more than 10 topics, remove the oldest one
    if (cachedTopics.length > 10) {
      String oldest = cachedTopics.removeAt(0);
      await box.delete(oldest);
      AppLog.d("AI_DEBUG: Memory Cleanup: Removed old subject cache for $oldest");
    }

    await userBox.put('cached_topics_list', cachedTopics);
  }

  // Get questions for a topic
  static List<Question> getQuestions(String topic) {
    var box = Hive.box(questionsBoxName);
    String? data = box.get(topic);
    
    if (data != null) {
      List<dynamic> decoded = jsonDecode(data);
      return decoded.map((q) => Question.fromMap(Map<String, dynamic>.from(q))).toList();
    }
    return [];
  }

  // Cache user data
  static Future<void> cacheUserData(Map<String, dynamic> data) async {
    var box = Hive.box(userBoxName);
    await box.put('current_user', jsonEncode(data));
  }

  static Map<String, dynamic>? getCachedUserData() {
    var box = Hive.box(userBoxName);
    String? data = box.get('current_user');
    if (data != null) {
      return jsonDecode(data) as Map<String, dynamic>;
    }
    return null;
  }

  // Track Daily AI Usage
  static bool canUseAi() {
    var box = Hive.box(userBoxName);
    String today = _todayDate();
    int usage = box.get('ai_usage_$today', defaultValue: 0);
    AppLog.d("AI_DEBUG: Daily usage for $today is $usage / 50");
    return usage < 50; // Increased limit to 50 messages per day
  }

  static Future<void> incrementAiUsage() async {
    var box = Hive.box(userBoxName);
    String today = _todayDate();
    int usage = box.get('ai_usage_$today', defaultValue: 0);
    await box.put('ai_usage_$today', usage + 1);
  }

  // Daily Quiz Limit
  static bool isDailyQuizDone() {
    final box = Hive.box(userBoxName);
    final today = _todayDate();
    String? lastDone = box.get('dailyquiz_last_completed_date') as String?;
    return lastDone == today;
  }

  static Future<void> setDailyQuizDone() async {
    final box = Hive.box(userBoxName);
    final today = _todayDate();
    await box.put('dailyquiz_last_completed_date', today);
  }

  // Mock Quiz Limit
  static bool isMockQuizDone() {
    final box = Hive.box(userBoxName);
    final today = _todayDate();
    String? lastDone = box.get('mockquiz_last_completed_date') as String?;
    return lastDone == today;
  }

  static Future<void> setMockQuizDone() async {
    var box = Hive.box(userBoxName);
    final today = _todayDate();
    await box.put('mockquiz_last_completed_date', today);
  }


   // Clear all offline questions to save space
  static Future<void> clearCache() async {
    var box = Hive.box(questionsBoxName);
    await box.clear();
  }

  // Premium Checks
  static bool isPremium() {
    return true; // Unlocked for all users
  }

  static String getPremiumPlan() {
    return 'Elite'; // Set high level plan for ad-free and mock tests
  }

  /// Starter, Pro, Elite — 10 room matches per day while subscription is active.
  static bool hasRoomMatchBoost() => true;

  static String _todayDate() {
    return AppDate.getTodayString();
  }

  // ------------------- Reward Points Management -------------------
  static int getUserPoints() {
    var box = Hive.box(userBoxName);
    return box.get('reward_points_${_todayDate()}', defaultValue: 0) as int;
  }

  static Future<void> addPoints(int pts) async {
    var box = Hive.box(userBoxName);
    String today = _todayDate();
    
    // 1. Update daily points
    int curDaily = box.get('reward_points_$today', defaultValue: 0) as int;
    await box.put('reward_points_$today', curDaily + pts);
    
    // 2. Update global totalScore
    int curTotal = box.get('totalScore', defaultValue: 0) as int;
    await box.put('totalScore', curTotal + pts);
    
    AppLog.d('AI_DEBUG: Points added: +$pts. New Total: ${curTotal + pts}');
  }

  static Future<void> deductPoints(int pts) async {
    var box = Hive.box(userBoxName);
    String today = _todayDate();
    int cur = box.get('reward_points_$today', defaultValue: 0) as int;
    int newVal = cur - pts;
    if (newVal < 0) newVal = 0;
    await box.put('reward_points_$today', newVal);
  }

  static int dailyRoomMatchLimit() {
    var box = Hive.box(userBoxName);
    int extra = box.get('extra_room_attempts_${_todayDate()}', defaultValue: 0);
    return 1 + extra; // 1 Free attempt + extra attempts unlocked via ads
  }

  static int getRoomAdWatchCount() {
    var box = Hive.box(userBoxName);
    return box.get('room_ad_watches_${_todayDate()}', defaultValue: 0) as int;
  }

  // Increment ad watch count for room matches. Every 1 ad unlocks one extra attempt.
  static Future<int> incrementRoomAdWatchCount() async {
    var box = Hive.box(userBoxName);
    String today = _todayDate();
    int current = box.get('room_ad_watches_$today', defaultValue: 0) as int;
    int next = current + 1;
    if (next >= 1) {
      int extra = box.get('extra_room_attempts_$today', defaultValue: 0) as int;
      await box.put('extra_room_attempts_$today', extra + 1);
      await box.put('room_ad_watches_$today', 0);
      return 0;
    }
    await box.put('room_ad_watches_$today', next);
    return next;
  }


  /// Unlocked for all users after removing payment system.
  static bool isAdFree() {
    return true;
  }

  /// Pro (₹99) & Elite (₹259).
  static bool isMockTestsUnlocked() {
    return true; // Mock tests unlocked for everyone
  }

  // Background Audio Settings
  static Future<void> setBackgroundAudioEnabled(bool enabled) async {
    await Hive.box(userBoxName).put('background_audio_enabled', enabled);
  }

  static bool? getBackgroundAudioEnabled() {
    return Hive.box(userBoxName).get('background_audio_enabled') as bool?;
  }

  // Host Room Code Cache (Valid for 1 day)
  static Future<void> saveHostRoom(String roomCode, String date) async {
    var box = Hive.box(userBoxName);
    await box.put('host_room_code', roomCode);
    await box.put('host_room_date', date);
  }

  static String? getHostRoomCode() {
    var box = Hive.box(userBoxName);
    String? date = box.get('host_room_date') as String?;
    String today = _todayDate();
    if (date == today) {
      return box.get('host_room_code') as String?;
    }
    return null;
  }

  static Future<void> clearHostRoom() async {
    var box = Hive.box(userBoxName);
    await box.delete('host_room_code');
    await box.delete('host_room_date');
  }

  // TTS Speed Setting (default: 0.5 speech rate, stored as a double)
  static Future<void> setTtsSpeed(double speed) async {
    await Hive.box(userBoxName).put('tts_speed', speed);
  }

  static double getTtsSpeed() {
    return Hive.box(userBoxName).get('tts_speed', defaultValue: 0.5) as double;
  }

  // TTS Repeat Setting (default: 1, stored as an int)
  static Future<void> setTtsRepeat(int repeat) async {
    await Hive.box(userBoxName).put('tts_repeat', repeat);
  }

  static int getTtsRepeat() {
    return Hive.box(userBoxName).get('tts_repeat', defaultValue: 1) as int;
  }

  // Font Size Factor Setting (default: 1.0, stored as a double)
  static Future<void> setFontSizeFactor(double factor) async {
    await Hive.box(userBoxName).put('font_size_factor', factor);
  }

  static double getFontSizeFactor() {
    return Hive.box(userBoxName).get('font_size_factor', defaultValue: 0.9) as double;
  }

  // Vibration Setting
  static Future<void> setVibrationEnabled(bool enabled) async {
    await Hive.box(userBoxName).put('vibration_enabled', enabled);
  }

  static bool isVibrationEnabled() {
    return Hive.box(userBoxName).get('vibration_enabled', defaultValue: true) as bool;
  }

  // ------------------- Study Material -------------------
  static Future<void> saveStudyMaterial(String subject, List<Map<String, dynamic>> material) async {
    var box = Hive.box(studyMaterialBoxName);
    await box.put(subject, jsonEncode(material));
  }

  static List<Map<String, dynamic>>? getStudyMaterial(String subject) {
    var box = Hive.box(studyMaterialBoxName);
    String? data = box.get(subject);
    if (data != null) {
      List<dynamic> decoded = jsonDecode(data);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return null;
  }

  // ------------------- Last Fetch Tracking -------------------
  static Future<void> setLastLeaderboardFetch(bool isDaily) async {
    final box = Hive.box(userBoxName);
    final key = isDaily ? 'last_leaderboard_fetch_daily' : 'last_leaderboard_fetch_mock';
    await box.put(key, _todayDate());
  }

  static bool shouldFetchLeaderboard(bool isDaily) {
    final box = Hive.box(userBoxName);
    final key = isDaily ? 'last_leaderboard_fetch_daily' : 'last_leaderboard_fetch_mock';
    final dataKey = isDaily ? 'leaderboard_data_daily' : 'leaderboard_data_mock';
    
    String? lastFetch = box.get(key) as String?;
    String? cachedData = box.get(dataKey) as String?;

    // AI_DEBUG: Check if this is the first time fetching in the current session
    bool sessionFetched = box.get('session_leaderboard_fetched', defaultValue: false) as bool;

    // Fetch if never fetched today OR if cache was explicitly cleared (after a quiz)
    bool shouldFetch = lastFetch != _todayDate() || cachedData == null || cachedData == "[]";
    
    // If it's a "login/app start" fresh fetch, we allow it once per session regardless of date
    if (!shouldFetch && !sessionFetched) {
       AppLog.d("AI_DEBUG: Forcing leaderboard fetch for new session");
       return true;
    }

    return shouldFetch;
  }

  static Future<void> markSessionLeaderboardFetched() async {
    final box = Hive.box(userBoxName);
    await box.put('session_leaderboard_fetched', true);
  }

  static Future<void> resetSessionLeaderboardFetched() async {
    final box = Hive.box(userBoxName);
    await box.put('session_leaderboard_fetched', false);
  }

  static Future<void> saveLeaderboardData(bool isDaily, List<Map<String, dynamic>> data) async {
    final box = Hive.box(userBoxName);
    final key = isDaily ? 'leaderboard_data_daily' : 'leaderboard_data_mock';
    await box.put(key, jsonEncode(data));
  }

  static List<Map<String, dynamic>>? getLeaderboardData(bool isDaily) {
    final box = Hive.box(userBoxName);
    final key = isDaily ? 'leaderboard_data_daily' : 'leaderboard_data_mock';
    String? data = box.get(key);
    if (data != null) {
      List<dynamic> decoded = jsonDecode(data);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return null;
  }

  // ------------------- Performance Statistics -------------------
  static Future<void> updateCategoryPerformance(
      String categoryKey,
      int correct,
      int total,
      ) async {
    var box = Hive.box(userBoxName);

    // OVERWRITE instead of increment to show only the latest quiz results
    int wrong = total - correct;

    await box.put(
      'perf_correct_$categoryKey',
      correct,
    );

    await box.put(
      'perf_total_$categoryKey',
      total,
    );

    await box.put(
      'perf_wrong_$categoryKey',
      wrong,
    );
  }
  static Map<String, dynamic> getCategoryPerformance(String categoryKey) {
    var box = Hive.box(userBoxName);

    int correct =
    box.get('perf_correct_$categoryKey', defaultValue: 0) as int;

    int total =
    box.get('perf_total_$categoryKey', defaultValue: 0) as int;

    int wrong = total - correct;

    double correctPercent =
    total > 0 ? (correct / total) * 100 : 0;

    double wrongPercent =
    total > 0 ? (wrong / total) * 100 : 0;

    return {
      'correct': correct,
      'total': total,
      'wrong': wrong,
      'correctPercent': correctPercent,
      'wrongPercent': wrongPercent,
    };
  }

  // ------------------- User Profile -------------------
  static Future<void> updateUserName(String name) async {
    await Hive.box(userBoxName).put('user_display_name', name);
    await Hive.box(userBoxName).put('last_name_update_date', AppDate.getISTNow().toIso8601String());
  }

  static String? getUserName() {
    return Hive.box(userBoxName).get('user_display_name') as String?;
  }

  static DateTime? getLastNameUpdateDate() {
    String? dateStr = Hive.box(userBoxName).get('last_name_update_date') as String?;
    if (dateStr != null) {
      return DateTime.parse(dateStr);
    }
    return null;
  }

  static bool canUpdateName() {
    DateTime? lastUpdate = getLastNameUpdateDate();
    if (lastUpdate == null) return true;
    
    // Check if at least 30 days have passed
    return AppDate.getISTNow().difference(lastUpdate).inDays >= 30;
  }

  // ------------------- Sticky AI Config -------------------
  static Future<void> saveStickyAiConfig(String key, String model, String version) async {
    var box = Hive.box(userBoxName);
    String today = _todayDate();
    await box.put('sticky_ai_config_$today', {
      'key': key,
      'model': model,
      'version': version,
    });
  }

  static Map<String, String>? getStickyAiConfig() {
    var box = Hive.box(userBoxName);
    String today = _todayDate();
    var data = box.get('sticky_ai_config_$today');
    if (data != null && data is Map) {
      return Map<String, String>.from(data);
    }
    return null;
  }

  static Future<void> clearStickyAiConfig() async {
    var box = Hive.box(userBoxName);
    String today = _todayDate();
    await box.delete('sticky_ai_config_$today');
  }

  static int getRewardAdWatchCountToday() {
    var box = Hive.box(userBoxName);
    String today = _todayDate();
    return box.get('reward_ad_watches_$today', defaultValue: 0) as int;
  }

  static Future<void> incrementRewardAdWatchCountToday() async {
    var box = Hive.box(userBoxName);
    String today = _todayDate();
    int current = box.get('reward_ad_watches_$today', defaultValue: 0) as int;
    await box.put('reward_ad_watches_$today', current + 1);
  }

  static int getQuizAdWatchCountToday() {
    var box = Hive.box(userBoxName);
    String today = _todayDate();
    return box.get('quiz_ad_watches_$today', defaultValue: 0) as int;
  }

  static Future<void> incrementQuizAdWatchCountToday() async {
    var box = Hive.box(userBoxName);
    String today = _todayDate();
    int current = box.get('quiz_ad_watches_$today', defaultValue: 0) as int;
    await box.put('quiz_ad_watches_$today', current + 1);
  }

  static bool canWatchRewardAdToday() {
    return getRewardAdWatchCountToday() < 3;
  }

  // ------------------- Share Rewards -------------------
  static bool canEarnShareRewardToday() {
    var box = Hive.box(userBoxName);
    String today = _todayDate();
    return !(box.get('share_reward_earned_$today', defaultValue: false) as bool);
  }

  static Future<void> markShareRewardEarnedToday() async {
    var box = Hive.box(userBoxName);
    String today = _todayDate();
    await box.put('share_reward_earned_$today', true);
  }

  // ------------------- Share Quiz Pool & History (Optimization) -------------------
  static const String _shareQuizPoolKey = 'share_quiz_pool';
  static const String _sharedQuizIdsKey = 'shared_quiz_ids';
  static const String _lastShareHistoryResetKey = 'last_share_history_reset_date';
  static const String _lastSharePoolRefreshKey = 'last_share_pool_refresh_date';

  static Future<void> saveShareQuizPool(List<Question> pool) async {
    var box = Hive.box(questionsBoxName);
    List<Map<String, dynamic>> poolJson = pool.map((q) => q.toMap()).toList();
    await box.put(_shareQuizPoolKey, jsonEncode(poolJson));
    
    // Mark the refresh date
    await Hive.box(userBoxName).put(_lastSharePoolRefreshKey, _todayDate());
    AppLog.d("AI_DEBUG: Saved ${pool.length} quizzes to Share Pool cache.");
  }

  static bool shouldRefreshSharePool() {
    var box = Hive.box(userBoxName);
    String? lastRefresh = box.get(_lastSharePoolRefreshKey) as String?;
    if (lastRefresh == null) return true;

    DateTime now = AppDate.getISTNow();
    DateTime last = AppDate.parse(lastRefresh);
    return now.difference(last).inDays >= 7;
  }

  static List<Question> getShareQuizPool() {
    var box = Hive.box(questionsBoxName);
    String? data = box.get(_shareQuizPoolKey);
    if (data != null) {
      List<dynamic> decoded = jsonDecode(data);
      return decoded.map((q) => Question.fromMap(Map<String, dynamic>.from(q))).toList();
    }
    return [];
  }

  static List<String> getSharedQuizIds() {
    var box = Hive.box(userBoxName);
    return List<String>.from(box.get(_sharedQuizIdsKey, defaultValue: []) as List);
  }

  static Future<void> markQuizAsShared(String id) async {
    var box = Hive.box(userBoxName);
    List<String> sharedIds = getSharedQuizIds();
    if (!sharedIds.contains(id)) {
      sharedIds.add(id);
      // Cap at 300 to prevent local storage growth while covering at least 1 week
      if (sharedIds.length > 300) {
        sharedIds.removeAt(0);
      }
      await box.put(_sharedQuizIdsKey, sharedIds);
    }
  }

  static Future<void> resetSharedQuizHistoryIfNeeded() async {
    var box = Hive.box(userBoxName);
    String today = _todayDate();
    String? lastReset = box.get(_lastShareHistoryResetKey) as String?;

    if (lastReset == null) {
      await box.put(_lastShareHistoryResetKey, today);
      return;
    }

    DateTime now = AppDate.getISTNow();
    DateTime last = AppDate.parse(lastReset);
    
    // Reset every 7 days
    if (now.difference(last).inDays >= 7) {
      await box.put(_sharedQuizIdsKey, <String>[]);
      await box.put(_lastShareHistoryResetKey, today);
      AppLog.d("AI_DEBUG: Weekly Share History Reset completed.");
    }
  }

  // ------------------- Rank Caching (Read Optimization) -------------------
  static Future<void> saveCachedRank(bool isDaily, int score, int rank) async {
    final box = Hive.box(userBoxName);
    final today = _todayDate();
    final key = isDaily ? 'cached_rank_daily_$today' : 'cached_rank_mock_$today';
    await box.put(key, {'score': score, 'rank': rank});
  }

  static Map<String, int>? getCachedRank(bool isDaily, int currentScore) {
    final box = Hive.box(userBoxName);
    final today = _todayDate();
    final key = isDaily ? 'cached_rank_daily_$today' : 'cached_rank_mock_$today';
    final data = box.get(key);
    
    if (data != null && data is Map) {
      int cachedScore = data['score'] ?? -1;
      if (cachedScore == currentScore) {
        return {'score': cachedScore, 'rank': data['rank'] ?? 0};
      }
    }
    return null;
  }

  static Future<void> saveCachedGlobalRank(int score, int rank) async {
    final box = Hive.box(userBoxName);
    await box.put('cached_global_rank', {'score': score, 'rank': rank});
  }

  static Map<String, int>? getCachedGlobalRank(int currentScore) {
    final box = Hive.box(userBoxName);
    final data = box.get('cached_global_rank');
    if (data != null && data is Map) {
      int cachedScore = data['score'] ?? -1;
      if (cachedScore == currentScore) {
        return {'score': cachedScore, 'rank': data['rank'] ?? 0};
      }
    }
    return null;
  }

  static Future<void> invalidateRankCache(bool isDaily) async {
    final box = Hive.box(userBoxName);
    final today = _todayDate();
    final key = isDaily ? 'cached_rank_daily_$today' : 'cached_rank_mock_$today';
    await box.delete(key);
  }

  static Future<void> invalidateGlobalRankCache() async {
    final box = Hive.box(userBoxName);
    await box.delete('cached_global_rank');
  }

  // ------------------- Room Preferences -------------------
  static Future<void> saveRoomTimePreference(int hour, int minute) async {
    await Hive.box(userBoxName).put('pref_room_end_time', '$hour:$minute');
  }

  static TimeOfDay? getRoomTimePreference() {
    String? val = Hive.box(userBoxName).get('pref_room_end_time') as String?;
    if (val != null && val.contains(':')) {
      final parts = val.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }
    return null;
  }
}
