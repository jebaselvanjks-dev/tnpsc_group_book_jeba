import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import '../models/question.dart';
import '../models/subject.dart';
import 'hive_service.dart';
import 'ai_service.dart';
import 'package:tnpsc_group_book/utils/app_language.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Helper to retry Firestore operations
  Future<T> _retry<T>(Future<T> Function() operation, {int maxAttempts = 3}) async {
    int attempt = 0;
    while (true) {
      attempt++;
      try {
        return await operation();
      } catch (e) {
        if (attempt >= maxAttempts || e.toString().contains('permission-denied')) {
          rethrow;
        }
        debugPrint("AI_DEBUG: Firestore Operation failed (Attempt $attempt/$maxAttempts). Retrying in ${attempt * 2}s...");
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }
  }

  /// Updates user profile name in Firestore
  Future<void> updateProfileName(String name) async {
    String? uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _db.collection('users').doc(uid).set({
        'name': name,
        'lastNameUpdateDate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint("AI_DEBUG: User profile name updated in Firestore: $name");
      
      // Refresh user data immediately after save
      await getUserData(forceRefresh: true);
    } catch (e) {
      debugPrint("Error updating profile name: $e");
    }
  }

  /// Fetches relevant study content and questions to provide context to the AI
  Future<String> getSearchContext(String query) async {
    try {
      String context = "";
      query = query.toLowerCase();

      // 1. Search in subject study materials
      final studyDocs = await _db.collection('subject_study_material').limit(10).get();
      for (var doc in studyDocs.docs) {
        String subject = (doc.get('subject') ?? "").toString().toLowerCase();
        if (query.contains(subject) || subject.contains(query)) {
          List material = doc.get('material') ?? [];
          for (var item in material.take(5)) {
            context += "Topic: ${item['english']}\nContent (Tamil): ${item['tamil']}\n\n";
          }
        }
      }

      // 2. Search in subject questions (to understand the style and depth)
      if (context.length < 500) {
        final questionDocs = await _db.collection('subject_questions').limit(5).get();
        for (var doc in questionDocs.docs) {
          String subject = (doc.get('subject') ?? "").toString().toLowerCase();
          if (query.contains(subject) || subject.contains(query)) {
            List questions = doc.get('questions') ?? [];
            for (var q in questions.take(3)) {
              context += "Question: ${q['question']}\nExplanation: ${q['explanation']}\n\n";
            }
          }
        }
      }

      return context.isNotEmpty ? context : "No specific local context found.";
    } catch (e) {
      debugPrint("Error fetching context: $e");
      return "Error retrieving context.";
    }
  }

  // Get user data with Offline Cache support (Cache-first optimization)
  Future<void> _syncCompletedQuizzesToHive(Map<String, dynamic>? data) async {
    if (data == null) return;
    final box = Hive.box(HiveService.userBoxName);

    if (data.containsKey('completedDailyQuizzes')) {
      final completed = data['completedDailyQuizzes'];
      if (completed is String) {
        await box.put('dailyquiz_last_completed_date', completed);
      } else if (completed is List && completed.isNotEmpty) {
        // Migration: Take the last date from the array
        await box.put('dailyquiz_last_completed_date', completed.last.toString());
      }
    }

    if (data.containsKey('completedMockQuizzes')) {
      final completed = data['completedMockQuizzes'];
      if (completed is String) {
        await box.put('mockquiz_last_completed_date', completed);
      } else if (completed is List && completed.isNotEmpty) {
        // Migration: Take the last date from the array
        await box.put('mockquiz_last_completed_date', completed.last.toString());
      }
    }
  }

  /// Recursively sanitizes data for Hive (Converts Timestamps to ISO Strings)
  dynamic _sanitizeForHive(dynamic data) {
    if (data is Timestamp) {
      return data.toDate().toIso8601String();
    } else if (data is Map) {
      return data.map((key, value) => MapEntry(key, _sanitizeForHive(value)));
    } else if (data is List) {
      return data.map((e) => _sanitizeForHive(e)).toList();
    }
    return data;
  }

  // Get user data with Offline Cache support (Cache-first optimization)
  Future<DocumentSnapshot?> getUserData({bool forceRefresh = true}) async {
    String? uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    // 1. First, always try to get from Cache for immediate UI response if not forcing refresh
    if (!forceRefresh) {
      try {
        DocumentSnapshot cachedDoc = await _db.collection('users').doc(uid).get(const GetOptions(source: Source.cache));
        if (cachedDoc.exists) {
          debugPrint("AI_DEBUG: User data fetched from FIRESTORE CACHE (Initial)");
          var data = cachedDoc.data() as Map<String, dynamic>;
          await _syncCompletedQuizzesToHive(data);
          return cachedDoc;
        }
      } catch (_) {}
    }

    try {
      // 2. Try server fetch with retry logic
      debugPrint("AI_DEBUG: Fetching user data from SERVER...");
      DocumentSnapshot doc = await _retry(() => _db.collection('users').doc(uid).get(const GetOptions(source: Source.serverAndCache)));
      
      if (doc.exists) {
        var data = doc.data() as Map<String, dynamic>;
        
        // AI_DEBUG: Sanitize data for Hive (Recursive Timestamp conversion)
        Map<String, dynamic> sanitizedData = _sanitizeForHive(data) as Map<String, dynamic>;
        
        // Cache to Hive for offline
        await HiveService.cacheUserData(sanitizedData);
        await _syncCompletedQuizzesToHive(data);
        
        // Sync stats to Hive
        final userBox = Hive.box(HiveService.userBoxName);
        if (data.containsKey('totalScore')) await userBox.put('totalScore', data['totalScore']);
        if (data.containsKey('quizzesCompleted')) await userBox.put('quizzesCompleted', data['quizzesCompleted']);
        if (data.containsKey('streak')) await userBox.put('streak', data['streak']);
        if (data.containsKey('lastActiveDate')) await userBox.put('lastActiveDate', data['lastActiveDate']);
        
        return doc;
      }
      return doc;
    } catch (e) {
      debugPrint("AI_DEBUG: Server fetch failed after retries, falling back to cache: $e");
      try {
        DocumentSnapshot doc = await _db.collection('users').doc(uid).get(const GetOptions(source: Source.cache));
        if (doc.exists) {
          var data = doc.data() as Map<String, dynamic>;
          await _syncCompletedQuizzesToHive(data);
        }
        return doc;
      } catch (ce) {
        debugPrint("AI_DEBUG: Firestore cache failed, app will use HiveService fallback");
        return null;
      }
    }
  }

  /// Increments user points in Firestore
  Future<void> incrementUserPoints(int points) async {
    String? uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _db.collection('users').doc(uid).set({
        'totalScore': FieldValue.increment(points),
      }, SetOptions(merge: true));
      debugPrint("AI_DEBUG: User points incremented in Firestore by $points");
      
      // Refresh user data immediately after save
      await getUserData(forceRefresh: true);
    } catch (e) {
      debugPrint("Error incrementing user points: $e");
    }
  }

  // Fetch Daily Quiz Questions with Caching
  Future<List<Question>> getDailyQuiz() async {
    try {
      String today = DateFormat('yyyy-MM-dd', 'en_US').format(DateTime.now());
      String tomorrow = DateFormat('yyyy-MM-dd', 'en_US').format(DateTime.now().add(const Duration(days: 1)));
      
      // AI_DEBUG: Check Hive first for today's quiz
      List<Question> cachedToday = HiveService.getQuestions("Daily Quiz");
      String? lastActiveDate = Hive.box(HiveService.userBoxName).get('last_active_quiz_date') as String?;
      if (cachedToday.isNotEmpty && lastActiveDate == today) {
        debugPrint("AI_DEBUG: Today's Daily quiz fetched from HIVE");
        return cachedToday;
      }

      // 1. Check if today's quiz exists (Immediate check)
      QuerySnapshot todaySnap = await _db
          .collection('quizzes')
          .where('type', isEqualTo: 'daily_quiz')
          .where('date', isEqualTo: today)
          .limit(1)
          .get();

      DocumentSnapshot? resolvedDoc;
      if (todaySnap.docs.isNotEmpty) {
        resolvedDoc = todaySnap.docs.first;
        debugPrint("AI_DEBUG: Today's Daily quiz found in Firestore");
      } else {
        // 2. Not found, try generating via AI
        debugPrint("AI_DEBUG: Today's Daily quiz not found. Generating via AI...");
        bool generated = await AiService.generateAndSaveDailyQuiz(DateTime.now());
        if (generated) {
          QuerySnapshot newTodaySnap = await _db
              .collection('quizzes')
              .where('type', isEqualTo: 'daily_quiz')
              .where('date', isEqualTo: today)
              .limit(1)
              .get();
          if (newTodaySnap.docs.isNotEmpty) {
            resolvedDoc = newTodaySnap.docs.first;
            debugPrint("AI_DEBUG: AI Generated Daily quiz for today fetched successfully");
          }
        }
      }

      // --- OPTIMIZATION: Prefetch tomorrow's quiz if not present ---
      try {
         QuerySnapshot tomorrowSnap = await _db
            .collection('quizzes')
            .where('type', isEqualTo: 'daily_quiz')
            .where('date', isEqualTo: tomorrow)
            .limit(1)
            .get();
         if (tomorrowSnap.docs.isEmpty) {
           debugPrint("AI_DEBUG: Tomorrow's quiz not found. Generating in background...");
           AiService.generateAndSaveDailyQuiz(DateTime.now().add(const Duration(days: 1)));
         }
      } catch (_) {}

      // 3. Fallback: If AI fails or today's quiz still missing, fetch older quiz
      if (resolvedDoc == null) {
        debugPrint("AI_DEBUG: Daily quiz generation failed or missing today. Fetching older quiz as fallback...");
        QuerySnapshot fallbackSnap = await _db
            .collection('quizzes')
            .where('type', isEqualTo: 'daily_quiz')
            .where('date', isLessThan: today)
            .orderBy('date', descending: true)
            .limit(10)
            .get();
            
        if (fallbackSnap.docs.isNotEmpty) {
          final docsList = List<DocumentSnapshot>.from(fallbackSnap.docs);
          docsList.shuffle(); // Pick one at random to ensure variety
          resolvedDoc = docsList.first;
          debugPrint("AI_DEBUG: Fallback to older Daily quiz from date: ${resolvedDoc.get('date')}");
        }
      }

      if (resolvedDoc != null) {
        String activeDate = resolvedDoc.get('date');
        
        // Save the active quiz date to Hive
        await Hive.box(HiveService.userBoxName).put('last_active_quiz_date', activeDate);

        List<dynamic> questionsData = resolvedDoc.get('questions');
        List<Question> questions = questionsData.map((q) => Question.fromMap(q as Map<String, dynamic>)).toList();
        
        // Save to Hive for Offline Mode
        await HiveService.saveQuestions("Daily Quiz", questions);
        return questions;
      }
    } catch (e) {
      debugPrint("Error fetching daily quiz: $e");
    }
    
    // 4. Guaranteed non-empty: Final fallback to Hive
    debugPrint("AI_DEBUG: Fetching daily quiz from HIVE (Offline Fallback)");
    return HiveService.getQuestions("Daily Quiz");
  }

  // Fetch Mock Quiz Questions with Caching
  Future<List<Question>> getMockQuiz() async {
    try {
      String today = DateFormat('yyyy-MM-dd', 'en_US').format(DateTime.now());
      String tomorrow = DateFormat('yyyy-MM-dd', 'en_US').format(DateTime.now().add(const Duration(days: 1)));
      
      // AI_DEBUG: Check Hive first for today's mock quiz
      List<Question> cachedToday = HiveService.getQuestions("Mock Quiz");
      String? lastActiveDate = Hive.box(HiveService.userBoxName).get('last_active_mock_quiz_date') as String?;
      if (cachedToday.isNotEmpty && lastActiveDate == today) {
        debugPrint("AI_DEBUG: Today's Mock quiz fetched from HIVE");
        return cachedToday;
      }

      // 1. Check if today's mock quiz exists
      QuerySnapshot todaySnap = await _db
          .collection('mock_tests')
          .where('type', isEqualTo: 'daily_quiz')
          .where('quizType', isEqualTo: 'daily_50_quiz')
          .where('date', isEqualTo: today)
          .limit(1)
          .get();

      DocumentSnapshot? resolvedDoc;
      if (todaySnap.docs.isNotEmpty) {
        resolvedDoc = todaySnap.docs.first;
        debugPrint("AI_DEBUG: Today's Mock quiz found in Firestore");
      } else {
        // 2. Not found, try generating via AI
        debugPrint("AI_DEBUG: Today's Mock quiz not found. Generating via AI...");
        bool generated = await AiService.generateAndSaveMockQuiz(DateTime.now());
        if (generated) {
          QuerySnapshot newTodaySnap = await _db
              .collection('mock_tests')
              .where('type', isEqualTo: 'daily_quiz')
              .where('quizType', isEqualTo: 'daily_50_quiz')
              .where('date', isEqualTo: today)
              .limit(1)
              .get();
          if (newTodaySnap.docs.isNotEmpty) {
            resolvedDoc = newTodaySnap.docs.first;
            debugPrint("AI_DEBUG: AI Generated Mock quiz for today fetched successfully");
          }
        }
      }

      // --- OPTIMIZATION: Prefetch tomorrow's mock quiz if not present ---
      try {
         QuerySnapshot tomorrowSnap = await _db
            .collection('mock_tests')
            .where('type', isEqualTo: 'daily_quiz')
            .where('quizType', isEqualTo: 'daily_50_quiz')
            .where('date', isEqualTo: tomorrow)
            .limit(1)
            .get();
         if (tomorrowSnap.docs.isEmpty) {
           debugPrint("AI_DEBUG: Tomorrow's mock quiz not found. Generating in background...");
           AiService.generateAndSaveMockQuiz(DateTime.now().add(const Duration(days: 1)));
         }
      } catch (_) {}

      // 3. Fallback: If AI fails or today's quiz still missing, fetch older mock quiz
      if (resolvedDoc == null) {
        debugPrint("AI_DEBUG: Mock quiz generation failed or missing today. Fetching older mock quiz as fallback...");
        QuerySnapshot fallbackSnap = await _db
            .collection('mock_tests')
            .where('type', isEqualTo: 'daily_quiz')
            .where('quizType', isEqualTo: 'daily_50_quiz')
            .where('date', isLessThan: today)
            .orderBy('date', descending: true)
            .limit(10)
            .get();
            
        if (fallbackSnap.docs.isNotEmpty) {
          final docsList = List<DocumentSnapshot>.from(fallbackSnap.docs);
          docsList.shuffle();
          resolvedDoc = docsList.first;
          debugPrint("AI_DEBUG: Fallback to older Mock quiz from date: ${resolvedDoc.get('date')}");
        }
      }

      if (resolvedDoc != null) {
        String activeDate = resolvedDoc.get('date');
        
        // Save the active quiz date to Hive
        await Hive.box(HiveService.userBoxName).put('last_active_mock_quiz_date', activeDate);

        List<dynamic> questionsData = resolvedDoc.get('questions');
        List<Question> questions = questionsData.map((q) => Question.fromMap(q as Map<String, dynamic>)).toList();
        
        // Save to Hive for Offline Mode
        await HiveService.saveQuestions("Mock Quiz", questions);
        return questions;
      }
    } catch (e) {
      debugPrint("Error fetching mock quiz: $e");
    }
    
    // 4. Final fallback to Hive
    debugPrint("AI_DEBUG: Fetching mock quiz from HIVE (Offline Fallback)");
    return HiveService.getQuestions("Mock Quiz");
  }

  String _getMondayDateString() {
    DateTime now = DateTime.now();
    // weekday is 1 (Monday) to 7 (Sunday)
    DateTime monday = now.subtract(Duration(days: now.weekday - 1));
    return DateFormat('yyyy-MM-dd').format(monday);
  }

  String _getMockLeaderboardDocId() {
    DateTime now = DateTime.now();
    int weekday = now.weekday; // 1 (Mon) to 7 (Sun)
    DateTime targetDate;

    // Logic:
    // We group 2 days into one leaderboard for variety
    // Mon (1) & Tue (2) -> Mon
    // Wed (3) & Thu (4) -> Wed
    // Fri (5) & Sat (6) -> Fri
    // Sun (7) -> Sun
    if (weekday == 7) {
      targetDate = now;
    } else if (weekday % 2 == 0) {
      targetDate = now.subtract(const Duration(days: 1));
    } else {
      targetDate = now;
    }
    
    // AI_DEBUG: Use 'en_US' to ensure consistent document IDs regardless of device language
    String dayName = DateFormat('EEEE', 'en_US').format(targetDate);
    String docId = "mock_${dayName}_${DateFormat('yyyy-MM-dd').format(targetDate)}";
    debugPrint("AI_DEBUG: Generated Mock Leaderboard Doc ID: $docId");
    return docId;
  }

  // Get Top Scorers for Leaderboard (Static Fetch - No Stream)
  Future<List<Map<String, dynamic>>> getLeaderboard({bool isDaily = true, bool forceRefresh = false}) async {
    try {
      debugPrint("AI_DEBUG: getLeaderboard(isDaily: $isDaily, forceRefresh: $forceRefresh) started");
      
      if (!forceRefresh) {
        if (!HiveService.shouldFetchLeaderboard(isDaily)) {
           debugPrint("AI_DEBUG: Returning Leaderboard from HIVE cache");
           return HiveService.getLeaderboardData(isDaily) ?? [];
        }
      }

      Query query;
      String fullPath;
      if (isDaily) {
        String today = DateFormat('yyyy-MM-dd', 'en_US').format(DateTime.now());
        fullPath = 'leaderboards/daily_$today/scores';
        query = _db.collection('leaderboards').doc('daily_$today').collection('scores');
      } else {
        String docId = _getMockLeaderboardDocId();
        fullPath = 'leaderboards/$docId/scores';
        query = _db.collection('leaderboards').doc(docId).collection('scores');
      }

      debugPrint("AI_DEBUG: Fetching from Firestore Path: $fullPath");

      // Server fetch
      QuerySnapshot snapshot = await _retry(() => query
          .orderBy('score', descending: true)
          .limit(20)
          .get());
      
      debugPrint("AI_DEBUG: Fetch successful. Document count: ${snapshot.docs.length}");
      
      if (snapshot.docs.isEmpty) {
        debugPrint("AI_DEBUG: No documents found at path: $fullPath");
        
        // Fallback: Check if collection exists without ordering (in case index is missing)
        try {
          QuerySnapshot testSnap = await query.limit(1).get();
          if (testSnap.docs.isNotEmpty) {
             debugPrint("AI_DEBUG: ALERT: Collection HAS data, but orderBy failed. MISSING INDEX?");
          }
        } catch (_) {}
      }

      var data = snapshot.docs.map((doc) {
        var d = doc.data() as Map<String, dynamic>;
        // AI_DEBUG: Sanitize Firestore Timestamp objects for JSON encoding/Hive storage
        d.forEach((key, value) {
          if (value is Timestamp) {
            d[key] = value.toDate().toIso8601String();
          }
        });
        debugPrint("AI_DEBUG: Found User: ${d['userName']} with Score: ${d['score']}");
        return d;
      }).toList();
      
      // Update Hive cache
      await HiveService.saveLeaderboardData(isDaily, data);
      await HiveService.setLastLeaderboardFetch(isDaily);
      await HiveService.markSessionLeaderboardFetched();

      return data;
    } catch (e, stack) {
      debugPrint("AI_DEBUG: LEADERBOARD ERROR: $e");
      debugPrint("AI_DEBUG: STACKTRACE: $stack");
      // Fallback to Hive if server fails
      return HiveService.getLeaderboardData(isDaily) ?? [];
    }
  }

  // Get current user's accumulated score for today (Daily or Mock)
  Future<Map<String, dynamic>?> getUserBestResultToday({bool isDaily = true}) async {
    String? uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    try {
      String docId;
      if (isDaily) {
        String today = DateFormat('yyyy-MM-dd', 'en_US').format(DateTime.now());
        docId = 'daily_$today';
      } else {
        docId = _getMockLeaderboardDocId();
      }

      // Try cache first
      DocumentSnapshot doc = await _db
          .collection('leaderboards')
          .doc(docId)
          .collection('scores')
          .doc(uid)
          .get(const GetOptions(source: Source.cache));
      if (doc.exists) {
        debugPrint("AI_DEBUG: User ${isDaily ? 'daily' : 'mock'} score fetched from CACHE");
        return doc.data() as Map<String, dynamic>;
      }
      // Fallback to server if not in cache
      doc = await _db
          .collection('leaderboards')
          .doc(docId)
          .collection('scores')
          .doc(uid)
          .get();
      if (doc.exists) {
        debugPrint("AI_DEBUG: User ${isDaily ? 'daily' : 'mock'} score fetched from SERVER");
        return doc.data() as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint("AI_DEBUG: Error fetching user's score: $e");
    }
    return null;
  }

  // Save Quiz Result to Firestore
  Future<void> saveQuizResult({
    required String subject,
    required int score,
    required int totalQuestions,
    required int timeTaken,
  }) async {
    String? uid = _auth.currentUser?.uid;
    if (uid != null) {
      // Fetch user name for leaderboard
      DocumentSnapshot? userDoc = await getUserData();
      String userName = AppLanguage.getString('user_fallback');
      if (userDoc != null && userDoc.exists) {
        userName = (userDoc.data() as Map<String, dynamic>)['name'] ?? AppLanguage.getString('user_fallback');
      }

      WriteBatch batch = _db.batch();
      
      // AI_DEBUG: Only update leaderboard if score is better than previous best today
      Map<String, dynamic>? bestResult = await getUserBestResultToday(isDaily: subject == "Daily Quiz");
      int existingBest = (bestResult?['score'] as num?)?.toInt() ?? -1;

       // Update Daily and Weekly Leaderboards if score > existingBest AND it's a Daily Quiz
       if (score > 0 && subject == "Daily Quiz" && score > existingBest) {
         String today = DateFormat('yyyy-MM-dd', 'en_US').format(DateTime.now());
         String monday = _getMondayDateString();

         var scoreData = {
           'userId': uid,
           'userName': userName,
           'score': score, // OVERWRITE: User's latest BEST attempt for the day
           'totalQuestions': totalQuestions,
           'timeTaken': timeTaken,
           'timestamp': FieldValue.serverTimestamp(),
           'expiresAt': DateTime.now().add(const Duration(days: 7)), // For TTL Auto Delete
         };

         // Update Daily (Subcollection format for TTL)
         batch.set(_db.collection('leaderboards').doc('daily_$today').collection('scores').doc(uid), scoreData, SetOptions(merge: true));
         debugPrint("AI_DEBUG: BATCH: Daily Score updated (New Best: $score > $existingBest)");

         // Update Weekly (Subcollection format for TTL)
         batch.set(_db.collection('leaderboards').doc('weekly_$monday').collection('scores').doc(uid), scoreData, SetOptions(merge: true));
         
         // AI_DEBUG: Reset daily leaderboard fetch tracking to force refresh on next visit
         await HiveService.saveLeaderboardData(true, []); // Clear local cache
       } else if (subject == "Daily Quiz") {
         debugPrint("AI_DEBUG: Daily Leaderboard write SKIPPED (Score $score <= Best $existingBest)");
       }

       // --- NEW: Save Mock Quiz Result to Scheduled Leaderboard ---
       if (score > 0 && subject == "Mock Quiz" && score > existingBest) {
         String docId = _getMockLeaderboardDocId();
         var scoreData = {
           'userId': uid,
           'userName': userName,
           'score': score, // OVERWRITE
           'totalQuestions': totalQuestions,
           'timeTaken': timeTaken,
           'timestamp': FieldValue.serverTimestamp(),
           'expiresAt': DateTime.now().add(const Duration(days: 7)), 
         };

         batch.set(_db.collection('leaderboards').doc(docId).collection('scores').doc(uid), scoreData, SetOptions(merge: true));
         debugPrint("AI_DEBUG: BATCH: Mock Score updated (New Best: $score > $existingBest)");

         // AI_DEBUG: Reset mock leaderboard fetch tracking
         await HiveService.saveLeaderboardData(false, []);
       } else if (subject == "Mock Quiz") {
         debugPrint("AI_DEBUG: Mock Leaderboard write SKIPPED (Score $score <= Best $existingBest)");
       }

      if (subject == "Daily Quiz") {
        String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

        batch.set(_db.collection('users').doc(uid), {
          'completedDailyQuizzes': today,
          'dailyquiz_complete': true,
        }, SetOptions(merge: true));
        debugPrint("AI_DEBUG: BATCH: Completed quiz date $today");
      } else if (subject == "Mock Quiz") {
        String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        
        batch.set(_db.collection('users').doc(uid), {
          'completedMockQuizzes': today,
        }, SetOptions(merge: true));
        debugPrint("AI_DEBUG: BATCH: Completed mock quiz date $today");
      }

      // Update local Hive stats immediately for real-time UI update
      final userBox = Hive.box(HiveService.userBoxName);
      int currentPoints = userBox.get('totalScore', defaultValue: 0) as int;
      int currentQuizzes = userBox.get('quizzesCompleted', defaultValue: 0) as int;
      await userBox.put('totalScore', currentPoints + score);
      await userBox.put('quizzesCompleted', currentQuizzes + 1);

      // Update user overall stats in Firestore
      batch.set(_db.collection('users').doc(uid), {
        'totalScore': FieldValue.increment(score),
        'quizzesCompleted': FieldValue.increment(1),
      }, SetOptions(merge: true));
      
      // Commit the batch
      await batch.commit();
      debugPrint("AI_DEBUG: Quiz result saved via WriteBatch");

      // Refresh user data immediately after save to sync all stats
      await getUserData(forceRefresh: true);
    }
  }

  // Update daily streak
  Future<void> updateStreak() async {
    String? uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final userBox = Hive.box(HiveService.userBoxName);
    String today = DateFormat('yyyy-MM-dd', 'en_US').format(DateTime.now());

    // 1. Local check to prevent double execution in same session/device
    String localLastActive = userBox.get('lastActiveDate', defaultValue: "") as String;
    if (localLastActive == today) {
      debugPrint("AI_DEBUG: Streak already updated today (Local Hive Check)");
      return;
    }

    try {
      DocumentReference userRef = _db.collection('users').doc(uid);
      DocumentSnapshot userDoc = await userRef.get();

      String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      if (!userDoc.exists) {
        await userRef.set({
          'streak': 1,
          'lastActiveDate': today,
        }, SetOptions(merge: true));
        await userBox.put('streak', 1);
        await userBox.put('lastActiveDate', today);
        return;
      }

      var data = userDoc.data() as Map<String, dynamic>;
      String lastActive = data['lastActiveDate'] ?? "";

      if (lastActive == today) {
        // Already updated today, just ensure Hive is synced
        await userBox.put('streak', data['streak'] ?? 0);
        await userBox.put('lastActiveDate', today);
        return;
      }

      DateTime now = DateTime.now();
      DateTime lastDate = DateFormat('yyyy-MM-dd').parse(lastActive == "" ? today : lastActive);
      int diff = DateTime(now.year, now.month, now.day).difference(lastDate).inDays;

      int newStreak = data['streak'] ?? 0;

      if (diff == 1) {
        newStreak += 1;
        await userRef.update({
          'streak': FieldValue.increment(1),
          'lastActiveDate': today,
        });
      } else if (diff > 1) {
        newStreak = 1;
        await userRef.update({
          'streak': 1,
          'lastActiveDate': today,
        });
      } else {
        await userRef.update({
          'lastActiveDate': today,
        });
      }

      // Sync to Hive
      await userBox.put('streak', newStreak);
      await userBox.put('lastActiveDate', today);

      // Refresh user data immediately after save
      await getUserData(forceRefresh: true);

    } catch (e) {
      debugPrint("Error updating streak: $e");
    }
  }

  // Get user's global rank based on totalScore
  Future<int> getUserGlobalRank() async {
    String? uid = _auth.currentUser?.uid;
    if (uid == null) return 0;

    try {
      // Get current user's score
      DocumentSnapshot userDoc = await _db.collection('users').doc(uid).get();
      if (!userDoc.exists) return 0;
      
      int myScore = (userDoc.data() as Map<String, dynamic>)['totalScore'] ?? 0;

      // Count how many users have a higher score
      QuerySnapshot higherScorers = await _db.collection('users')
          .where('totalScore', isGreaterThan: myScore)
          .get();
      
      return higherScorers.docs.length + 1;
    } catch (e) {
      debugPrint("Error calculating rank: $e");
      return 0;
    }
  }

  // Upload all static questions from models/question.dart to Firestore
  Future<void> uploadAllLocalQuestions() async {
    try {
      print("AI_DEBUG: Starting bulk upload...");
      for (var entry in subjectQuestions.entries) {
        String subject = entry.key;
        List<Question> questions = entry.value;

        // Sanitize subject name to be used as document ID (replace / with -)
        String safeId = subject.replaceAll('/', '-');

        print("AI_DEBUG: Uploading subject: $subject as $safeId (${questions.length} questions)");

        List<Map<String, dynamic>> questionsData = questions.map((q) => {
          'question': q.question,
          'options': q.options,
          'correctOptionIndex': q.correctOptionIndex,
          'explanation': q.explanation,
        }).toList();

        await _db.collection('subject_questions').doc(safeId).set({
          'subject': subject,
          'questions': questionsData,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
      print("AI_DEBUG: Bulk upload completed successfully!");
    } catch (e) {
      print("AI_DEBUG: BULK UPLOAD ERROR: $e");
      rethrow;
    }
  }

  // Fetch Questions for a specific subject with Hive fallback (Cache-first optimization)
  Future<List<Question>> getSubjectQuestions(String subject, {bool forceRefresh = false}) async {
    try {
      if (!forceRefresh) {
        List<Question> cached = HiveService.getQuestions(subject);
        if (cached.isNotEmpty) {
          debugPrint("AI_DEBUG: Subject questions $subject fetched from HIVE");
          return cached;
        }
      }

      String safeId = subject.replaceAll('/', '-');
      
      DocumentSnapshot doc;
      if (!forceRefresh) {
        try {
          doc = await _db.collection('subject_questions').doc(safeId).get(const GetOptions(source: Source.cache));
          if (doc.exists) {
            debugPrint("AI_DEBUG: Subject questions $subject fetched from FIRESTORE CACHE");
            List<dynamic> questionsData = doc.get('questions');
            List<Question> questions = questionsData.map((q) => Question(
              question: q['question'],
              options: List<String>.from(q['options']),
              correctOptionIndex: q['correctOptionIndex'],
              explanation: q['explanation'],
            )).toList();
            
            // Save to Hive
            await HiveService.saveQuestions(subject, questions);
            return questions;
          }
        } catch (_) {}
      }

      // Try server fetch
      doc = await _db.collection('subject_questions').doc(safeId).get();
      if (doc.exists) {
        debugPrint("AI_DEBUG: Subject questions $subject fetched from SERVER");
        List<dynamic> questionsData = doc.get('questions');
        List<Question> questions = questionsData.map((q) => Question(
          question: q['question'],
          options: List<String>.from(q['options']),
          correctOptionIndex: q['correctOptionIndex'],
          explanation: q['explanation'],
        )).toList();
        
        // Save to Hive
        await HiveService.saveQuestions(subject, questions);
        return questions;
      }
    } catch (e) {
      print("Error fetching subject questions: $e");
    }
    
    // Fallback to Hive
    debugPrint("AI_DEBUG: Fetching $subject from HIVE (Last Fallback)");
    return HiveService.getQuestions(subject);
  }

  // Fetch a specific Mock Test from Firestore
  Future<List<Question>> getMockTestQuestions(String title) async {
    try {
      QuerySnapshot snapshot = await _db.collection('mock_tests')
          .where('title', isEqualTo: title)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        List<dynamic> questionsData = snapshot.docs.first.get('questions');
        return questionsData.map((q) => Question(
          question: q['question'],
          options: List<String>.from(q['options']),
          correctOptionIndex: q['correctOptionIndex'],
          explanation: q['explanation'],
        )).toList();
      }
    } catch (e) {
      print("Error fetching mock test: $e");
    }
    return [];
  }

  // --- BOOKMARK FEATURES ---

  Future<void> toggleBookmark(Question question) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final bookmarkRef = _db.collection('users').doc(user.uid).collection('bookmarks');
      
      // Use a unique ID based on the question text to prevent duplicates
      String qId = question.question.hashCode.toString();
      
      final doc = await bookmarkRef.doc(qId).get();
      if (doc.exists) {
        await bookmarkRef.doc(qId).delete();
        debugPrint("AI_DEBUG: Removed Bookmark: $qId");
      } else {
        await bookmarkRef.doc(qId).set(question.toMap());
        debugPrint("AI_DEBUG: Added Bookmark: $qId");
      }
    } catch (e) {
      debugPrint("Error toggling bookmark: $e");
    }
  }

  Future<bool> isBookmarked(String questionText) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      String qId = questionText.hashCode.toString();
      final doc = await _db.collection('users').doc(user.uid).collection('bookmarks').doc(qId).get();
      return doc.exists;
    } catch (e) {
      debugPrint("Error checking bookmark status: $e");
      return false;
    }
  }

  Future<List<Question>> getBookmarks() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final snapshot = await _db.collection('users').doc(user.uid).collection('bookmarks').get();
      return snapshot.docs.map((doc) => Question.fromMap(doc.data())).toList();
    } catch (e) {
      print("Error fetching bookmarks: $e");
      return [];
    }
  }

  // --- FEEDBACK SYSTEM ---

  Future<bool> sendFeedback({
    required String name,
    required String email,
    required String message,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      await _db.collection('feedbacks').add({
        'userId': user.uid,
        'userName': name,
        'userEmail': email,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending', // To track in admin panel
      });
      return true;
    } catch (e) {
      print("Error sending feedback: $e");
      return false;
    }
  }

  // --- MISTAKE BANK FEATURES ---

  Future<void> saveMistake(Question question) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final mistakeRef = _db.collection('users').doc(user.uid).collection('mistakes');
      String qId = question.question.hashCode.toString();
      
      // Save the question user got wrong
      await mistakeRef.doc(qId).set({
        ...question.toMap(),
        'mistakeCount': FieldValue.increment(1),
        'lastMistakeAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error saving mistake: $e");
    }
  }

  Future<void> removeMistake(String questionText) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      String qId = questionText.hashCode.toString();
      await _db.collection('users').doc(user.uid).collection('mistakes').doc(qId).delete();
    } catch (e) {
      debugPrint("Error removing mistake: $e");
    }
  }

  Future<List<Question>> getMistakes() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final snapshot = await _db.collection('users').doc(user.uid).collection('mistakes').get();
      return snapshot.docs.map((doc) => Question.fromMap(doc.data())).toList();
    } catch (e) {
      print("Error fetching mistakes: $e");
      return [];
    }
  }

  // Fetch Study Material for a specific subject (Cache-first optimization)
  Future<List<Map<String, dynamic>>> getStudyMaterial(String subject, {bool forceRefresh = false}) async {
    try {
      if (!forceRefresh) {
        List<Map<String, dynamic>>? cached = HiveService.getStudyMaterial(subject);
        if (cached != null && cached.isNotEmpty) {
          debugPrint("AI_DEBUG: Study material $subject fetched from HIVE");
          return cached;
        }
      }

      String safeId = subject.replaceAll('/', '-');
      
      DocumentSnapshot doc;
      if (!forceRefresh) {
        try {
          doc = await _db.collection('subject_study_material').doc(safeId).get(const GetOptions(source: Source.cache));
          if (doc.exists) {
            debugPrint("AI_DEBUG: Study material $subject fetched from FIRESTORE CACHE");
            List<dynamic> material = doc.get('material');
            var data = material.map((e) => Map<String, dynamic>.from(e)).toList();
            await HiveService.saveStudyMaterial(subject, data);
            return data;
          }
        } catch (_) {}
      }

      doc = await _db.collection('subject_study_material').doc(safeId).get();
      if (doc.exists) {
        debugPrint("AI_DEBUG: Study material $subject fetched from SERVER");
        List<dynamic> material = doc.get('material');
        var data = material.map((e) => Map<String, dynamic>.from(e)).toList();
        await HiveService.saveStudyMaterial(subject, data);
        return data;
      }
    } catch (e) {
      debugPrint("Error fetching study material: $e");
    }
    return [];
  }

  // Get User History
  Future<List<Map<String, dynamic>>> getUserHistory() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return [];

      final snapshot = await _db
          .collection('results')
          .where('userId', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        var data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint("Error fetching history: $e");
      return [];
    }
  }
  // Get Mastery Data (Grouped by subject) - Cache-first optimization
  Future<Map<String, double>> getMasteryData({bool forceRefresh = false}) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return {};

      QuerySnapshot snapshot;
      if (!forceRefresh) {
        try {
          snapshot = await _db
              .collection('results')
              .where('userId', isEqualTo: uid)
              .get(const GetOptions(source: Source.cache));
          if (snapshot.docs.isNotEmpty) {
            debugPrint("AI_DEBUG: Mastery data fetched from CACHE");
            return _calculateMastery(snapshot);
          }
        } catch (_) {}
      }

      snapshot = await _db
          .collection('results')
          .where('userId', isEqualTo: uid)
          .get();

      return _calculateMastery(snapshot);
    } catch (e) {
      debugPrint("Error calculating mastery: $e");
      return {};
    }
  }

  Map<String, double> _calculateMastery(QuerySnapshot snapshot) {
    Map<String, List<int>> subjectScores = {}; // subject: [totalCorrect, totalQuestions]

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      String subjectStr = data['subject'] ?? 'General';
      final score = (data['score'] as num?)?.toInt() ?? 0;
      final total = (data['totalQuestions'] as num?)?.toInt() ?? 0;

      // Aggregate sub-topics into main subjects for progress bar
      String mainSubject = subjectStr;
      for (var s in tnpscSubjects) {
        if (s.titleEn == subjectStr || s.titleTa == subjectStr || s.id == subjectStr || s.topicsEn.contains(subjectStr) || s.topicsTa.contains(subjectStr)) {
          mainSubject = s.titleEn; // Group everything under the English title for consistency
          break;
        }
      }

      if (!subjectScores.containsKey(mainSubject)) {
        subjectScores[mainSubject] = [0, 0];
      }
      subjectScores[mainSubject]![0] += score;
      subjectScores[mainSubject]![1] += total;
    }

    Map<String, double> mastery = {};
    subjectScores.forEach((key, value) {
      if (value[1] > 0) {
        mastery[key] = value[0] / value[1];
      } else {
        mastery[key] = 0.0;
      }
    });

    return mastery;
  }

  // Get raw subject scores data (correct/total) for overall Weak Area calculations
  Future<Map<String, List<int>>> getSubjectScoresData({bool forceRefresh = false}) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return {};

      QuerySnapshot snapshot;
      if (!forceRefresh) {
        try {
          snapshot = await _db
              .collection('results')
              .where('userId', isEqualTo: uid)
              .get(const GetOptions(source: Source.cache));
          if (snapshot.docs.isNotEmpty) {
            return _calculateSubjectScores(snapshot);
          }
        } catch (_) {}
      }

      snapshot = await _db
          .collection('results')
          .where('userId', isEqualTo: uid)
          .get();

      return _calculateSubjectScores(snapshot);
    } catch (e) {
      debugPrint("Error calculating subject scores: $e");
      return {};
    }
  }

  Map<String, List<int>> _calculateSubjectScores(QuerySnapshot snapshot) {
    Map<String, List<int>> subjectScores = {}; // subject: [totalCorrect, totalQuestions]

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      String subjectStr = data['subject'] ?? 'General';
      final score = (data['score'] as num?)?.toInt() ?? 0;
      final total = (data['totalQuestions'] as num?)?.toInt() ?? 0;

      // Group under main subject name
      String mainSubject = subjectStr;
      for (var s in tnpscSubjects) {
        if (s.titleEn == subjectStr || s.titleTa == subjectStr || s.id == subjectStr || s.topicsEn.contains(subjectStr) || s.topicsTa.contains(subjectStr)) {
          mainSubject = s.titleEn;
          break;
        }
      }

      if (!subjectScores.containsKey(mainSubject)) {
        subjectScores[mainSubject] = [0, 0];
      }
      subjectScores[mainSubject]![0] += score;
      subjectScores[mainSubject]![1] += total;
    }
    return subjectScores;
  }

  // Upload all static subjects from models/subject.dart to Firestore
  Future<void> uploadAllSubjects() async {
    try {
      print("AI_DEBUG: Starting bulk upload for subjects...");
      for (var subject in tnpscSubjects) {
        String safeId = subject.id;
        
        await _db.collection('subjects').doc(safeId).set({
          'id': subject.id,
          'titleTa': subject.titleTa,
          'titleEn': subject.titleEn,
          'subtitleTa': subject.subtitleTa,
          'subtitleEn': subject.subtitleEn,
          'iconCodePoint': subject.icon.codePoint,
          'iconFontFamily': subject.icon.fontFamily,
          'colorValue': subject.color.value,
          'topicsTa': subject.topicsTa,
          'topicsEn': subject.topicsEn,
          'subTopicsMapTa': subject.subTopicsMapTa,
          'subTopicsMapEn': subject.subTopicsMapEn,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
        print("AI_DEBUG: Uploaded subject: ${subject.titleEn}");
      }
      print("AI_DEBUG: Bulk upload for subjects completed successfully!");
    } catch (e) {
      print("AI_DEBUG: BULK UPLOAD SUBJECTS ERROR: $e");
      rethrow;
    }
  }
}
