import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/question.dart';
import 'dart:convert';
import 'package:package_info_plus/package_info_plus.dart';

class HiveService {
  static const String questionsBoxName = 'offline_questions';
  static const String userBoxName = 'user_data';
  static const String studyMaterialBoxName = 'study_material';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(userBoxName);
    await Hive.openBox(questionsBoxName);
    await Hive.openBox(studyMaterialBoxName);
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

  // Save questions for a topic
  static Future<void> saveQuestions(String topic, List<Question> questions) async {
    var box = Hive.box(questionsBoxName);
    List<Map<String, dynamic>> questionsJson = questions.map((q) => {
      'question': q.question,
      'options': q.options,
      'correctOptionIndex': q.correctOptionIndex,
      'explanation': q.explanation,
    }).toList();
    
    await box.put(topic, jsonEncode(questionsJson));
  }

  // Get questions for a topic
  static List<Question> getQuestions(String topic) {
    var box = Hive.box(questionsBoxName);
    String? data = box.get(topic);
    
    if (data != null) {
      List<dynamic> decoded = jsonDecode(data);
      return decoded.map((q) => Question(
        question: q['question'],
        options: List<String>.from(q['options']),
        correctOptionIndex: q['correctOptionIndex'],
        explanation: q['explanation'],
      )).toList();
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
    String today = DateTime.now().toString().split(' ')[0];
    int usage = box.get('ai_usage_$today', defaultValue: 0);
    print("AI_DEBUG: Daily usage for $today is $usage / 50");
    return usage < 50; // Increased limit to 50 messages per day
  }

  static Future<void> incrementAiUsage() async {
    var box = Hive.box(userBoxName);
    String today = DateTime.now().toString().split(' ')[0];
    int usage = box.get('ai_usage_$today', defaultValue: 0);
    await box.put('ai_usage_$today', usage + 1);
  }

  // Daily Quiz Limit
  static bool isDailyQuizDone() {
    final box = Hive.box(userBoxName);
    final today = DateTime.now().toString().split(' ')[0];
    String? lastDone = box.get('dailyquiz_last_completed_date') as String?;
    return lastDone == today;
  }

  static Future<void> setDailyQuizDone() async {
    final box = Hive.box(userBoxName);
    final today = DateTime.now().toString().split(' ')[0];
    await box.put('dailyquiz_last_completed_date', today);
  }

  // Mock Quiz Limit
  static bool isMockQuizDone() {
    final box = Hive.box(userBoxName);
    final today = DateTime.now().toString().split(' ')[0];
    String? lastDone = box.get('mockquiz_last_completed_date') as String?;
    return lastDone == today;
  }

  static Future<void> setMockQuizDone() async {
    var box = Hive.box(userBoxName);
    final today = DateTime.now().toString().split(' ')[0];
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
    return DateTime.now().toString().split(' ')[0];
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
    
    debugPrint('AI_DEBUG: Points added: +$pts. New Total: ${curTotal + pts}');
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
    String today = DateTime.now().toString().split(' ')[0];
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
    return Hive.box(userBoxName).get('font_size_factor', defaultValue: 1.0) as double;
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
    await box.put(key, DateTime.now().toString().split(' ')[0]);
  }

  static bool shouldFetchLeaderboard(bool isDaily) {
    final box = Hive.box(userBoxName);
    final key = isDaily ? 'last_leaderboard_fetch_daily' : 'last_leaderboard_fetch_mock';
    final dataKey = isDaily ? 'leaderboard_data_daily' : 'leaderboard_data_mock';
    
    String? lastFetch = box.get(key) as String?;
    String? cachedData = box.get(dataKey) as String?;

    // Fetch if never fetched today OR if cache was explicitly cleared (after a quiz)
    return lastFetch != DateTime.now().toString().split(' ')[0] || cachedData == null || cachedData == "[]";
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
    await Hive.box(userBoxName).put('last_name_update_date', DateTime.now().toIso8601String());
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
    return DateTime.now().difference(lastUpdate).inDays >= 30;
  }
  static int getRewardAdWatchCountToday() {
    var box = Hive.box(userBoxName);
    String today = DateTime.now().toString().split(' ')[0];
    return box.get('reward_ad_watches_$today', defaultValue: 0) as int;
  }

  static Future<void> incrementRewardAdWatchCountToday() async {
    var box = Hive.box(userBoxName);
    String today = DateTime.now().toString().split(' ')[0];
    int current = box.get('reward_ad_watches_$today', defaultValue: 0) as int;
    await box.put('reward_ad_watches_$today', current + 1);
  }

  static int getQuizAdWatchCountToday() {
    var box = Hive.box(userBoxName);
    String today = DateTime.now().toString().split(' ')[0];
    return box.get('quiz_ad_watches_$today', defaultValue: 0) as int;
  }

  static Future<void> incrementQuizAdWatchCountToday() async {
    var box = Hive.box(userBoxName);
    String today = DateTime.now().toString().split(' ')[0];
    int current = box.get('quiz_ad_watches_$today', defaultValue: 0) as int;
    await box.put('quiz_ad_watches_$today', current + 1);
  }

  static bool canWatchRewardAdToday() {
    return getRewardAdWatchCountToday() < 3;
  }
}
