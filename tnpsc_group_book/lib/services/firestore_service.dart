import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import '../models/question.dart';
import '../models/subject.dart';
import '../utils/app_log.dart';
import 'hive_service.dart';
import 'ai_service.dart';
import 'package:tnpsc_group_book/utils/app_language.dart';
import '../utils/app_date.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Helper to retry Firestore operations
  Future<T> _retry<T>(Future<T> Function() operation,
      {int maxAttempts = 3}) async {
    int attempt = 0;
    while (true) {
      attempt++;
      try {
        return await operation();
      } catch (e) {
        if (attempt >= maxAttempts ||
            e.toString().contains('permission-denied')) {
          rethrow;
        }
        AppLog.d(
            "AI_DEBUG: Firestore Operation failed (Attempt $attempt/$maxAttempts). Retrying in ${attempt *
                2}s...");
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
      AppLog.d("AI_DEBUG: User profile name updated in Firestore: $name");

      // Refresh user data immediately after save
      await getUserData(forceRefresh: true);
    } catch (e) {
      AppLog.e("Error updating profile name", e);
    }
  }

  /// Fetches relevant study content and questions to provide context to the AI
  Future<String> getSearchContext(String query) async {
    try {
      String context = "";
      query = query.toLowerCase();

      // 1. Search in subject study materials
      final studyDocs = await _db
          .collection('subject_study_material')
          .limit(10)
          .get();
      for (var doc in studyDocs.docs) {
        String subject = (doc.get('subject') ?? "").toString().toLowerCase();
        if (query.contains(subject) || subject.contains(query)) {
          List material = doc.get('material') ?? [];
          for (var item in material.take(5)) {
            context +=
            "Topic: ${item['english']}\nContent (Tamil): ${item['tamil']}\n\n";
          }
        }
      }

      // 2. Search in subject questions (to understand the style and depth)
      if (context.length < 500) {
        final questionDocs = await _db
            .collection('subject_questions')
            .limit(5)
            .get();
        for (var doc in questionDocs.docs) {
          String subject = (doc.get('subject') ?? "").toString().toLowerCase();
          if (query.contains(subject) || subject.contains(query)) {
            List questions = doc.get('questions') ?? [];
            for (var q in questions.take(3)) {
              context +=
              "Question: ${q['question']}\nExplanation: ${q['explanation']}\n\n";
            }
          }
        }
      }

      return context.isNotEmpty ? context : "No specific local context found.";
    } catch (e) {
      AppLog.e("Error fetching context", e);
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
        await box.put(
            'dailyquiz_last_completed_date', completed.last.toString());
      }
    }

    if (data.containsKey('completedMockQuizzes')) {
      final completed = data['completedMockQuizzes'];
      if (completed is String) {
        await box.put('mockquiz_last_completed_date', completed);
      } else if (completed is List && completed.isNotEmpty) {
        // Migration: Take the last date from the array
        await box.put(
            'mockquiz_last_completed_date', completed.last.toString());
      }
    }
  }

  /// Recursively sanitizes data for Hive (Converts Timestamps to ISO Strings)
  dynamic _sanitizeForHive(dynamic data) {
    if (data is Timestamp) {
      return data.toDate().toIso8601String();
    } else if (data is Map) {
      return Map<String, dynamic>.from(
        data.map((key, value) => MapEntry(key.toString(), _sanitizeForHive(value))),
      );
    } else if (data is List) {
      return data.map((e) => _sanitizeForHive(e)).toList();
    }
    return data;
  }

  // Get user data with Offline Cache support (Cache-first optimization)
  Future<DocumentSnapshot?> getUserData({bool forceRefresh = false}) async {
    String? uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    // 1. Try Cache First for immediate UI response
    if (!forceRefresh) {
      try {
        DocumentSnapshot cachedDoc = await _db.collection('users').doc(uid).get(
            const GetOptions(source: Source.cache));
        if (cachedDoc.exists) {
          AppLog.d("AI_DEBUG: User data fetched from FIRESTORE CACHE (Initial)");
          var data = cachedDoc.data() as Map<String, dynamic>;
          // Sync to Hive in background to not block return
          _syncCompletedQuizzesToHive(data);
          return cachedDoc;
        }
      } catch (_) {
        AppLog.d("AI_DEBUG: No User Data in Firestore Cache");
      }
    }

    try {
      // 2. Try server fetch with retry logic
      AppLog.d("AI_DEBUG: Fetching user data from SERVER (forceRefresh: $forceRefresh)...");
      DocumentSnapshot doc = await _retry(() =>
          _db.collection('users').doc(uid).get(
              const GetOptions(source: Source.serverAndCache)));

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) return doc;

        try {
          // AI_DEBUG: Sanitize data for Hive (Recursive Timestamp conversion)
          Map<String, dynamic> sanitizedData = _sanitizeForHive(data) as Map<String, dynamic>;

          // Cache to Hive for offline
          await HiveService.cacheUserData(sanitizedData);
          await _syncCompletedQuizzesToHive(data);

          // Sync stats to Hive
          final userBox = Hive.box(HiveService.userBoxName);
          if (data.containsKey('totalScore')) await userBox.put('totalScore', data['totalScore'] ?? 0);
          if (data.containsKey('quizzesCompleted')) await userBox.put('quizzesCompleted', data['quizzesCompleted'] ?? 0);
          if (data.containsKey('streak')) await userBox.put('streak', data['streak'] ?? 0);
          if (data.containsKey('lastActiveDate')) await userBox.put('lastActiveDate', data['lastActiveDate'] ?? "");
        } catch (e) {
          AppLog.e("Error processing user data for Hive", e);
        }

        return doc;
      }
      return doc;
    } catch (e) {
      AppLog.d(
          "AI_DEBUG: Server fetch failed after retries, falling back to cache: $e");
      try {
        DocumentSnapshot doc = await _db.collection('users').doc(uid).get(
            const GetOptions(source: Source.cache));
        if (doc.exists) {
          var data = doc.data() as Map<String, dynamic>;
          await _syncCompletedQuizzesToHive(data);
        }
        return doc;
      } catch (ce) {
        AppLog.d(
            "AI_DEBUG: Firestore cache failed, app will use HiveService fallback");
        return null;
      }
    }
  }

  /// Increments user points in Firestore and local Hive cache
  Future<void> incrementUserPoints(int points) async {
    String? uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      // 1. Update local Hive first for immediate UI feedback
      final userBox = Hive.box(HiveService.userBoxName);
      int currentPoints = userBox.get('totalScore', defaultValue: 0) as int;
      await userBox.put('totalScore', currentPoints + points);
      
      // Invalidate global rank cache
      await HiveService.invalidateGlobalRankCache();
      
      // 2. Update Firestore
      await _db.collection('users').doc(uid).set({
        'totalScore': FieldValue.increment(points),
      }, SetOptions(merge: true));
      AppLog.d("AI_DEBUG: User points incremented in Firestore by $points");

      // Refresh user data in background
      getUserData(forceRefresh: true);
    } catch (e) {
      AppLog.e("Error incrementing user points", e);
    }
  }

  // Fetch Daily Quiz Questions with Caching
  Future<List<Question>> getDailyQuiz() async {
    try {
      String today = AppDate.getTodayString();
      String tomorrow = AppDate.format(
          AppDate.getISTNow().add(const Duration(days: 1)));

      // AI_DEBUG: Check Hive first for today's quiz
      List<Question> cachedToday = HiveService.getQuestions("Daily Quiz");
      String? lastActiveDate = Hive.box(HiveService.userBoxName).get(
          'last_active_quiz_date') as String?;
      if (cachedToday.isNotEmpty && lastActiveDate == today) {
        AppLog.d("AI_DEBUG: Today's Daily quiz fetched from HIVE");
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
        AppLog.d("AI_DEBUG: Today's Daily quiz found in Firestore");
      } else {
        // 2. Not found, try generating via AI (with timeout to prevent delay)
        AppLog.d(
            "AI_DEBUG: Today's Daily quiz not found. Generating via AI...");
        try {
          bool generated = await AiService.generateAndSaveDailyQuiz(
              AppDate.getISTNow())
              .timeout(const Duration(seconds: 30));
          if (generated) {
            QuerySnapshot newTodaySnap = await _db
                .collection('quizzes')
                .where('type', isEqualTo: 'daily_quiz')
                .where('date', isEqualTo: today)
                .limit(1)
                .get();
            if (newTodaySnap.docs.isNotEmpty) {
              resolvedDoc = newTodaySnap.docs.first;
              AppLog.d(
                  "AI_DEBUG: AI Generated Daily quiz for today fetched successfully");
            }
          }
        } catch (e) {
          AppLog.d(
              "AI_DEBUG: Daily quiz generation timed out or failed: $e. Falling back...");
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
          AppLog.d(
              "AI_DEBUG: Tomorrow's quiz not found. Generating in background...");
          AiService.generateAndSaveDailyQuiz(
              AppDate.getISTNow().add(const Duration(days: 1)));
        }
      } catch (_) {}

      // 3. Fallback: If AI fails or today's quiz still missing, fetch older quiz
      if (resolvedDoc == null) {
        AppLog.d(
            "AI_DEBUG: Daily quiz generation failed or missing today. Fetching older quiz as fallback...");
        QuerySnapshot fallbackSnap = await _db
            .collection('quizzes')
            .where('type', isEqualTo: 'daily_quiz')
            .where('date', isLessThan: today)
            .orderBy('date', descending: true)
            .limit(20)
            .get();

        if (fallbackSnap.docs.isNotEmpty) {
          final docsList = List<DocumentSnapshot>.from(fallbackSnap.docs);
          docsList.shuffle(); // Pick one at random for variety
          resolvedDoc = docsList.first;
          AppLog.d(
              "AI_DEBUG: Fallback to a random older Daily quiz from date: ${resolvedDoc
                  .get('date')}");
        }
      }

      if (resolvedDoc != null) {
        String activeDate = resolvedDoc.get('date');

        // Save the active quiz date to Hive
        await Hive.box(HiveService.userBoxName).put(
            'last_active_quiz_date', activeDate);

        List<dynamic> questionsData = resolvedDoc.get('questions');
        List<Question> questions = questionsData.map((q) =>
            Question.fromMap(q as Map<String, dynamic>)).toList();

        // Save to Hive for Offline Mode
        await HiveService.saveQuestions("Daily Quiz", questions);
        return questions;
      }
    } catch (e) {
      AppLog.e("Error fetching daily quiz", e);
    }

    // 4. Guaranteed non-empty: Final fallback to Hive
    AppLog.d("AI_DEBUG: Fetching daily quiz from HIVE (Offline Fallback)");
    return HiveService.getQuestions("Daily Quiz");
  }

  // Fetch a deterministic rotating quiz based on the current time slot (Every 6 Hours)
  // Rotation: General Tamil -> General Studies -> Aptitude
  // The question returned is deterministic based on the slot seed to stay consistent for all users
  Future<List<Question>> getDailyRotatingQuiz({bool isAdmin = false}) async {
    try {
      List<String> types = ['general_tamil', 'general_studies', 'aptitude'];
      int slotSeed = AppDate.getSlotSeed();

      // Deterministic rotation based on 6-hour slot
      String targetType = types[slotSeed % types.length];
      AppLog.d("FirestoreService: Slot-based rotating quiz type: $targetType (Seed: $slotSeed)");

      QuerySnapshot snap = await _db
          .collection('quizzes')
          .where('quiz_type', isEqualTo: targetType)
          .limit(20)
          .get();

      if (snap.docs.isNotEmpty) {
        final docsList = List<DocumentSnapshot>.from(snap.docs);
        
        // Sort locally to ensure consistency across users
        docsList.sort((a, b) {
          String dateA = a.get('date') ?? "";
          String dateB = b.get('date') ?? "";
          return dateB.compareTo(dateA); 
        });
        
        int docIndex = slotSeed % docsList.length;
        var doc = docsList[docIndex];
        List<dynamic> questionsData = doc.get('questions');
        
        if (questionsData.isNotEmpty) {
          int qIndex = slotSeed % questionsData.length;
          var selectedQMap = Map<String, dynamic>.from(questionsData[qIndex] as Map);
          selectedQMap['quiz_type'] = targetType;
          selectedQMap['subject'] = targetType; 
          return [Question.fromMap(selectedQMap)];
        }
      }

      // 2. Fallback: If no quiz of that type found, try any recent daily quiz
      AppLog.d("FirestoreService: No quiz found for rotation. Falling back to type=daily_quiz...");
      QuerySnapshot fallbackSnap = await _db
          .collection('quizzes')
          .where('type', isEqualTo: 'daily_quiz')
          .limit(20)
          .get();

      if (fallbackSnap.docs.isNotEmpty) {
        final docsList = List<DocumentSnapshot>.from(fallbackSnap.docs);
        
        // Sort locally
        docsList.sort((a, b) {
          String dateA = a.get('date') ?? "";
          String dateB = b.get('date') ?? "";
          return dateB.compareTo(dateA); // Descending
        });
        int docIndex = slotSeed % docsList.length;
        var doc = docsList[docIndex];
        List<dynamic> questionsData = doc.get('questions');
        
        if (questionsData.isNotEmpty) {
          int qIndex = slotSeed % questionsData.length;
          var selectedQMap = Map<String, dynamic>.from(questionsData[qIndex] as Map);
          
          String qType = targetType;
          try { 
            qType = doc.get('quiz_type') ?? targetType;
          } catch (_) {}

          selectedQMap['quiz_type'] = qType;
          return [Question.fromMap(selectedQMap)];
        }
      }
    } catch (e) {
      AppLog.e("Error fetching daily rotating quiz: $e");
    }

    // 3. Final Fallback to standard daily quiz logic
    try {
      List<Question> dailyQuiz = await getDailyQuiz();
      if (dailyQuiz.isNotEmpty) {
        int slotSeed = AppDate.getSlotSeed();
        int qIndex = slotSeed % dailyQuiz.length;
        Question q = dailyQuiz[qIndex];
        
        return [Question(
          id: q.id,
          question: q.question,
          options: q.options,
          correctOptionIndex: q.correctOptionIndex,
          explanation: q.explanation,
          subject: q.subject,
          quizType: 'general_tamil', 
          questionEn: q.questionEn,
          questionTa: q.questionTa,
          optionsEn: q.optionsEn,
          optionsTa: q.optionsTa,
          explanationEn: q.explanationEn,
          explanationTa: q.explanationTa,
        )];
      }
    } catch (e) {
      AppLog.e("Final fallback error: $e");
    }

    return [];
  }

  // Fetch Mock Quiz Questions with Caching
  Future<List<Question>> getMockQuiz() async {
    try {
      String today = AppDate.getTodayString();
      String tomorrow = AppDate.format(AppDate.getISTNow().add(const Duration(days: 1)));
      
      // AI_DEBUG: Check Hive first for today's mock quiz
      List<Question> cachedToday = HiveService.getQuestions("Mock Quiz");
      String? lastActiveDate = Hive.box(HiveService.userBoxName).get('last_active_mock_quiz_date') as String?;
      if (cachedToday.isNotEmpty && lastActiveDate == today) {
        AppLog.d("AI_DEBUG: Today's Mock quiz fetched from HIVE");
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
        AppLog.d("AI_DEBUG: Today's Mock quiz found in Firestore");
      } else {
        // 2. Not found, try generating via AI (with timeout)
        AppLog.d("AI_DEBUG: Today's Mock quiz not found. Generating via AI...");
        try {
          bool generated = await AiService.generateAndSaveMockQuiz(AppDate.getISTNow())
              .timeout(const Duration(seconds: 45)); // Mock quiz has more questions, give more time
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
              AppLog.d("AI_DEBUG: AI Generated Mock quiz for today fetched successfully");
            }
          }
        } catch (e) {
          AppLog.d("AI_DEBUG: Mock quiz generation timed out or failed: $e. Falling back...");
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
           AppLog.d("AI_DEBUG: Tomorrow's mock quiz not found. Generating in background...");
           AiService.generateAndSaveMockQuiz(AppDate.getISTNow().add(const Duration(days: 1)));
         }
      } catch (_) {}

      // 3. Fallback: If AI fails or today's quiz still missing, fetch older mock quiz
      if (resolvedDoc == null) {
        AppLog.d("AI_DEBUG: Mock quiz generation failed or missing today. Fetching older mock quiz as fallback...");
        QuerySnapshot fallbackSnap = await _db
            .collection('mock_tests')
            .where('type', isEqualTo: 'daily_quiz')
            .where('quizType', isEqualTo: 'daily_50_quiz')
            .where('date', isLessThan: today)
            .orderBy('date', descending: true)
            .limit(20)
            .get();
            
        if (fallbackSnap.docs.isNotEmpty) {
          final docsList = List<DocumentSnapshot>.from(fallbackSnap.docs);
          docsList.shuffle(); // Pick one at random for variety
          resolvedDoc = docsList.first;
          AppLog.d("AI_DEBUG: Fallback to a random older Mock quiz from date: ${resolvedDoc.get('date')}");
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
      AppLog.e("Error fetching mock quiz", e);
    }
    
    // 4. Final fallback to Hive
    AppLog.d("AI_DEBUG: Fetching mock quiz from HIVE (Offline Fallback)");
    return HiveService.getQuestions("Mock Quiz");
  }

  String _getMondayDateString() {
    DateTime now = AppDate.getISTNow();
    // weekday is 1 (Monday) to 7 (Sunday)
    DateTime monday = now.subtract(Duration(days: now.weekday - 1));
    return AppDate.format(monday);
  }

  String _getMockLeaderboardDocId() {
    DateTime now = AppDate.getISTNow();
    int weekday = now.weekday; // 1 (Mon) to 7 (Sun)
    DateTime targetDate;

    // Mapping: Mon(1)->Sun, Wed(3)->Tue, Fri(5)->Thu
    if (weekday == 1 || weekday == 3 || weekday == 5) {
      targetDate = now.subtract(const Duration(days: 1));
    } else {
      targetDate = now;
    }
    
    String datePart = AppDate.format(targetDate);
    String docId = "mock_$datePart";
    AppLog.d("AI_DEBUG: Generated Mock Leaderboard Doc ID: $docId (Now: ${DateFormat('yyyy-MM-dd HH:mm').format(now)} IST)");
    return docId;
  }

  // Get Top Scorers for Leaderboard (Static Fetch - No Stream)
  Future<List<Map<String, dynamic>>> getLeaderboard({bool isDaily = true, bool forceRefresh = false}) async {
    try {
      AppLog.d("AI_DEBUG: getLeaderboard(isDaily: $isDaily, forceRefresh: $forceRefresh) started");
      
      if (!forceRefresh) {
        if (!HiveService.shouldFetchLeaderboard(isDaily)) {
           AppLog.d("AI_DEBUG: Returning Leaderboard from HIVE cache");
           return HiveService.getLeaderboardData(isDaily) ?? [];
        }
      }

      Query query;
      String fullPath;
      if (isDaily) {
        String today = AppDate.getTodayString();
        fullPath = 'leaderboards/daily_$today/scores';
        query = _db.collection('leaderboards').doc('daily_$today').collection('scores');
      } else {
        String docId = _getMockLeaderboardDocId();
        fullPath = 'leaderboards/$docId/scores';
        query = _db.collection('leaderboards').doc(docId).collection('scores');
      }

      AppLog.d("AI_DEBUG: Fetching from Firestore Path: $fullPath");

      // Server fetch
      QuerySnapshot snapshot = await _retry(() => query
          .orderBy('score', descending: true)
          .limit(20)
          .get());
      
      AppLog.d("AI_DEBUG: Fetch successful. Document count: ${snapshot.docs.length}");
      
      if (snapshot.docs.isEmpty) {
        AppLog.d("AI_DEBUG: No documents found at path: $fullPath");
        
        // Fallback: Check if collection exists without ordering (in case index is missing)
        try {
          QuerySnapshot testSnap = await query.limit(1).get();
          if (testSnap.docs.isNotEmpty) {
             AppLog.d("AI_DEBUG: ALERT: Collection HAS data, but orderBy failed. MISSING INDEX?");
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
        AppLog.d("AI_DEBUG: Found User: ${d['userName']} with Score: ${d['score']}");
        return d;
      }).toList();

      // AI_DEBUG: Perform local sorting to handle cases where 'streak' field might be missing in old records
      // This ensures NO ONE is hidden from the leaderboard while still giving preference to streaks.
      data.sort((a, b) {
        int scoreA = a['score'] ?? 0;
        int scoreB = b['score'] ?? 0;
        if (scoreB != scoreA) return scoreB.compareTo(scoreA);
        
        // If scores are equal, sort by streak
        int streakA = a['streak'] ?? 0;
        int streakB = b['streak'] ?? 0;
        return streakB.compareTo(streakA);
      });
      
      // Update Hive cache
      await HiveService.saveLeaderboardData(isDaily, data);
      await HiveService.setLastLeaderboardFetch(isDaily);
      await HiveService.markSessionLeaderboardFetched();

      return data;
    } catch (e, stack) {
      AppLog.e("AI_DEBUG: LEADERBOARD ERROR", e, stack);
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
        String today = AppDate.getTodayString();
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
          .get();
      if (doc.exists) {
        AppLog.d("AI_DEBUG: User ${isDaily ? 'daily' : 'mock'} score fetched from SERVER");
        var userData = doc.data() as Map<String, dynamic>;
        int myScore = userData['score'] ?? 0;

        // READ_OPT: Check Hive first for cached rank to avoid count() costs
        var cachedRank = HiveService.getCachedRank(isDaily, myScore);
        if (cachedRank != null) {
          userData['rank'] = cachedRank['rank'];
          AppLog.d("FIRESTORE_OPT: Using cached rank from HIVE: ${userData['rank']}");
          return userData;
        }
        
        // AI_DEBUG: Calculate current user's rank for today's leaderboard
        try {
          // Count how many users have a higher score
          AggregateQuerySnapshot higherScoresCount = await _db
              .collection('leaderboards')
              .doc(docId)
              .collection('scores')
              .where('score', isGreaterThan: myScore)
              .count()
              .get();
          
          int finalRank = (higherScoresCount.count ?? 0) + 1;
          userData['rank'] = finalRank;

          // Save to Hive
          await HiveService.saveCachedRank(isDaily, myScore, finalRank);
        } catch (e) {
          AppLog.e("Error calculating daily rank", e);
          userData['rank'] = 0;
        }

        return userData;
      }
    } catch (e) {
      AppLog.d("AI_DEBUG: Error fetching user's score: $e");
    }
    return null;
  }

  // Save Quiz Result to Firestore
  Future<void> saveQuizResult({
    required String subject,
    required int score,
    required int totalQuestions,
    required int timeTaken,
    bool isDaily = false,
    bool isMock = false,
  }) async {
    String? uid = _auth.currentUser?.uid;
    if (uid != null) {
      // 1. Update local Hive immediately for real-time UI update (Fast & Free)
      final userBox = Hive.box(HiveService.userBoxName);
      int currentTotalPoints = userBox.get('totalScore', defaultValue: 0) as int;
      int currentQuizzes = userBox.get('quizzesCompleted', defaultValue: 0) as int;
      await userBox.put('totalScore', currentTotalPoints + score);
      await userBox.put('quizzesCompleted', currentQuizzes + 1);

      // AI_OPTIMIZATION: Check if this is the best score for today using Hive
      String today = AppDate.getTodayString();
      String bestScoreKey = isDaily ? 'best_score_daily_$today' : 'best_score_mock_$today';
      String bestStreakKey = isDaily ? 'best_streak_daily_$today' : 'best_streak_mock_$today';
      
      int previousBestScore = userBox.get(bestScoreKey, defaultValue: -1) as int;
      int previousBestStreak = userBox.get(bestStreakKey, defaultValue: -1) as int;
      int currentStreak = userBox.get('streak', defaultValue: 0) as int;

      // WRITE_OPT: Only update leaderboard if score is better OR if score is same but streak improved (badge update)
      bool isNewBest = score > previousBestScore || (score == previousBestScore && currentStreak > previousBestStreak);

      // AI_DYNAMIC: Update local Hive immediately so subsequent calls (like notification rescheduling) use the latest score
      if (isNewBest) {
        await userBox.put(bestScoreKey, score);
        await userBox.put(bestStreakKey, currentStreak);
      }

      WriteBatch batch = _db.batch();

      // 2. Save to results collection (For My History screen)
      // This is 1 Write per quiz.
      batch.set(_db.collection('results').doc(), {
        'userId': uid,
        'subject': subject,
        'score': score,
        'totalQuestions': totalQuestions,
        'timeTaken': timeTaken,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      // 3. Update Leaderboard ONLY if it's a new best score (Saves huge amount of Writes)
      if (score > 0 && (isDaily || isMock) && isNewBest) {
        String userName = AppLanguage.getString('user_fallback');
        var cachedData = HiveService.getCachedUserData();
        if (cachedData != null) {
          userName = cachedData['name'] ?? userName;
        }

        String docId = isDaily ? 'daily_$today' : _getMockLeaderboardDocId();
        
        var scoreData = {
          'userId': uid,
          'userName': userName,
          'score': score, 
          'totalQuestions': totalQuestions,
          'timeTaken': timeTaken,
          'streak': userBox.get('streak', defaultValue: 0) as int,
          'timestamp': FieldValue.serverTimestamp(),
          'expiresAt': AppDate.getISTNow().add(const Duration(days: 7)), 
        };

        batch.set(_db.collection('leaderboards').doc(docId).collection('scores').doc(uid), scoreData, SetOptions(merge: true));
        
        // Update weekly if daily
        if (isDaily) {
          String monday = _getMondayDateString();
          batch.set(_db.collection('leaderboards').doc('weekly_$monday').collection('scores').doc(uid), scoreData, SetOptions(merge: true));
        }

        // READ_OPT: Invalidate rank cache because a new best score means rank needs recalculation
        await HiveService.invalidateRankCache(isDaily || isMock);
        await HiveService.invalidateGlobalRankCache();
        
        AppLog.d("FIRESTORE_OPT: New Best Score/Streak! Syncing to Leaderboard.");
      } else if (isDaily || isMock) {
        AppLog.d("FIRESTORE_OPT: Result not better than $previousBestScore score / $previousBestStreak streak. Leaderboard Write skipped.");
      }

      // 4. Update user overall stats in Firestore
      batch.set(_db.collection('users').doc(uid), {
        'totalScore': FieldValue.increment(score),
        'quizzesCompleted': FieldValue.increment(1),
        if (isDaily) 'completedDailyQuizzes': today,
        if (isMock) 'completedMockQuizzes': today,
      }, SetOptions(merge: true));
      
      await batch.commit();
      AppLog.d("FIRESTORE_OPT: Batch commit completed.");

      // Refresh user data in background with Source.cache first
      getUserData();
    }
  }

  // Update daily streak
  Future<void> updateStreak() async {
    String? uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final userBox = Hive.box(HiveService.userBoxName);
    String today = AppDate.getTodayString();

    // AI_OPTIMIZATION: Exit immediately if already updated today to save Writes
    String localLastActive = userBox.get('lastActiveDate', defaultValue: "") as String;
    if (localLastActive == today) {
      AppLog.d("FIRESTORE_OPT: Streak already synced today. Skipping Write.");
      return;
    }

    try {
      DocumentReference userRef = _db.collection('users').doc(uid);
      
      // Try cache first for streak logic to speed up startup and save Reads
      DocumentSnapshot userDoc;
      try {
        userDoc = await userRef.get(const GetOptions(source: Source.cache));
        if (!userDoc.exists) {
          userDoc = await userRef.get();
        }
      } catch (_) {
        userDoc = await userRef.get();
      }

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

      DateTime istNow = AppDate.getISTNow();
      DateTime lastDate = DateFormat('yyyy-MM-dd', 'en_US').parse(lastActive == "" ? today : lastActive);
      int diff = DateTime(istNow.year, istNow.month, istNow.day).difference(lastDate).inDays;

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
      AppLog.e("Error updating streak", e);
    }
  }

  // Get user's global rank based on totalScore
  Future<int> getUserGlobalRank() async {
    String? uid = _auth.currentUser?.uid;
    if (uid == null) return 0;

    try {
      // READ_OPT: Use Hive totalScore to avoid a document read
      final userBox = Hive.box(HiveService.userBoxName);
      int myScore = userBox.get('totalScore', defaultValue: -1) as int;

      if (myScore == -1) {
        // Fallback: Get current user's score from server if hive is empty
        DocumentSnapshot userDoc = await _db.collection('users').doc(uid).get();
        if (!userDoc.exists) return 0;
        myScore = (userDoc.data() as Map<String, dynamic>)['totalScore'] ?? 0;
        await userBox.put('totalScore', myScore);
      }
      
      // READ_OPT: Check Hive cache for global rank
      var cached = HiveService.getCachedGlobalRank(myScore);
      if (cached != null) {
        AppLog.d("FIRESTORE_OPT: Using cached GLOBAL rank from HIVE: ${cached['rank']}");
        return cached['rank'] ?? 0;
      }

      // FIRESTORE_OPT: Use count() aggregation instead of fetching all docs (CHEAP & FAST)
      AppLog.d("FIRESTORE_OPT: Calculating global rank using count()...");
      AggregateQuerySnapshot snapshot = await _db.collection('users')
          .where('totalScore', isGreaterThan: myScore)
          .count()
          .get();
      
      int rank = (snapshot.count ?? 0) + 1;

      // Cache the result
      await HiveService.saveCachedGlobalRank(myScore, rank);
      
      return rank;
    } catch (e) {
      AppLog.e("Error calculating rank", e);
      return 0;
    }
  }

  // Upload all static questions from models/question.dart to Firestore
  Future<void> uploadAllLocalQuestions() async {
    try {
      AppLog.d("AI_DEBUG: Starting bulk upload...");
      for (var entry in subjectQuestions.entries) {
        String subject = entry.key;
        List<Question> questions = entry.value;

        // Sanitize subject name to be used as document ID (replace / with -)
        String safeId = subject.replaceAll('/', '-');

        AppLog.d("AI_DEBUG: Uploading subject: $subject as $safeId (${questions.length} questions)");

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
      AppLog.d("AI_DEBUG: Bulk upload completed successfully!");
    } catch (e) {
      AppLog.e("AI_DEBUG: BULK UPLOAD ERROR", e);
      rethrow;
    }
  }

  // Fetch Questions for a specific subject with Hive fallback (Cache-first optimization)
  Future<List<Question>> getSubjectQuestions(String subject, {bool forceRefresh = false}) async {
    try {
      if (!forceRefresh) {
        List<Question> cached = HiveService.getQuestions(subject);
        if (cached.isNotEmpty) {
          AppLog.d("AI_DEBUG: Subject questions $subject fetched from HIVE");
          return cached;
        }
      }

      String safeId = subject.replaceAll('/', '-');
      
      DocumentSnapshot doc;
      if (!forceRefresh) {
        try {
          doc = await _db.collection('subject_questions').doc(safeId).get(const GetOptions(source: Source.cache));
          if (doc.exists) {
            AppLog.d("AI_DEBUG: Subject questions $subject fetched from FIRESTORE CACHE");
            List<dynamic> questionsData = doc.get('questions');
            List<Question> questions = questionsData.map((q) => Question.fromMap(Map<String, dynamic>.from(q))).toList();
            
            // Save to Hive
            await HiveService.saveQuestions(subject, questions);
            return questions;
          }
        } catch (_) {}
      }

      // Try server fetch
      doc = await _db.collection('subject_questions').doc(safeId).get();
      if (doc.exists) {
        AppLog.d("AI_DEBUG: Subject questions $subject fetched from SERVER");
        List<dynamic> questionsData = doc.get('questions');
        List<Question> questions = questionsData.map((q) => Question.fromMap(Map<String, dynamic>.from(q))).toList();
        
        // Save to Hive
        await HiveService.saveQuestions(subject, questions);
        return questions;
      }
    } catch (e) {
      AppLog.e("Error fetching subject questions", e);
    }
    
    // Fallback to Hive
    AppLog.d("AI_DEBUG: Fetching $subject from HIVE (Last Fallback)");
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
        return questionsData.map((q) => Question.fromMap(Map<String, dynamic>.from(q))).toList();
      }
    } catch (e) {
      AppLog.e("Error fetching mock test: $e");
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
        AppLog.d("AI_DEBUG: Removed Bookmark: $qId");
      } else {
        await bookmarkRef.doc(qId).set(question.toMap());
        AppLog.d("AI_DEBUG: Added Bookmark: $qId");
      }
    } catch (e) {
      AppLog.e("Error toggling bookmark", e);
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
      AppLog.e("Error checking bookmark status", e);
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
      AppLog.e("Error fetching bookmarks: $e");
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
      AppLog.e("Error sending feedback: $e");
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
      AppLog.e("Error saving mistake", e);
    }
  }

  Future<void> removeMistake(String questionText) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      String qId = questionText.hashCode.toString();
      await _db.collection('users').doc(user.uid).collection('mistakes').doc(qId).delete();
    } catch (e) {
      AppLog.e("Error removing mistake", e);
    }
  }

  Future<List<Question>> getMistakes() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final snapshot = await _db.collection('users').doc(user.uid).collection('mistakes').get();
      return snapshot.docs.map((doc) => Question.fromMap(doc.data())).toList();
    } catch (e) {
      AppLog.e("Error fetching mistakes: $e");
      return [];
    }
  }

  // Fetch Study Material for a specific subject (Cache-first optimization)
  Future<List<Map<String, dynamic>>> getStudyMaterial(String subject, {bool forceRefresh = false}) async {
    try {
      if (!forceRefresh) {
        List<Map<String, dynamic>>? cached = HiveService.getStudyMaterial(subject);
        if (cached != null && cached.isNotEmpty) {
          AppLog.d("AI_DEBUG: Study material $subject fetched from HIVE");
          return cached;
        }
      }

      String safeId = subject.replaceAll('/', '-');
      
      DocumentSnapshot doc;
      if (!forceRefresh) {
        try {
          doc = await _db.collection('subject_study_material').doc(safeId).get(const GetOptions(source: Source.cache));
          if (doc.exists) {
            AppLog.d("AI_DEBUG: Study material $subject fetched from FIRESTORE CACHE");
            List<dynamic> material = doc.get('material');
            var data = material.map((e) => Map<String, dynamic>.from(e)).toList();
            await HiveService.saveStudyMaterial(subject, data);
            return data;
          }
        } catch (_) {}
      }

      doc = await _db.collection('subject_study_material').doc(safeId).get();
      if (doc.exists) {
        AppLog.d("AI_DEBUG: Study material $subject fetched from SERVER");
        List<dynamic> material = doc.get('material');
        var data = material.map((e) => Map<String, dynamic>.from(e)).toList();
        await HiveService.saveStudyMaterial(subject, data);
        return data;
      }
    } catch (e) {
      AppLog.e("Error fetching study material", e);
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
      AppLog.e("Error fetching history", e);
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
            AppLog.d("AI_DEBUG: Mastery data fetched from CACHE");
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
      AppLog.e("Error calculating mastery", e);
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
      AppLog.e("Error calculating subject scores", e);
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

  // Fetch random quizzes by topic/subject for promotion
  // Accepts an optional seed for deterministic synchronized shuffling
  Future<List<Question>> getRandomQuizzesByTopic(String topic, {int limit = 3, int? seed}) async {
    try {
      // 1. Try subject_questions collection first (static/master questions)
      String safeId = topic.replaceAll('/', '-');
      DocumentSnapshot masterDoc = await _db.collection('subject_questions').doc(safeId).get();
      
      List<Question> pool = [];
      if (masterDoc.exists) {
        List<dynamic> questionsData = masterDoc.get('questions');
        pool.addAll(questionsData.map((q) {
          var map = Map<String, dynamic>.from(q as Map);
          map['subject'] = topic;
          return Question.fromMap(map);
        }));
      }

      // 2. Try quizzes collection (AI generated daily ones)
      QuerySnapshot snap = await _db
          .collection('quizzes')
          .where('quiz_type', isEqualTo: topic.toLowerCase().replaceAll(' ', '_'))
          .limit(10)
          .get();
      
      for (var doc in snap.docs) {
        List<dynamic> qData = doc.get('questions');
        pool.addAll(qData.map((q) {
           var map = Map<String, dynamic>.from(q as Map);
           map['subject'] = topic;
           return Question.fromMap(map);
        }));
      }

      if (pool.isNotEmpty) {
        if (seed != null) {
          pool.shuffle(Random(seed));
        } else {
          pool.shuffle();
        }
        return pool.take(limit).toList();
      }
    } catch (e) {
      AppLog.e("Error fetching random quizzes by topic: $e");
    }
    return [];
  }

  // Upload all static subjects from models/subject.dart to Firestore
  Future<void> uploadAllSubjects() async {
    try {
      AppLog.d("AI_DEBUG: Starting bulk upload for subjects...");
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
          'colorValue': subject.color.toARGB32(),
          'topicsTa': subject.topicsTa,
          'topicsEn': subject.topicsEn,
          'subTopicsMapTa': subject.subTopicsMapTa,
          'subTopicsMapEn': subject.subTopicsMapEn,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
        AppLog.d("AI_DEBUG: Uploaded subject: ${subject.titleEn}");
      }
      AppLog.d("AI_DEBUG: Bulk upload for subjects completed successfully!");
    } catch (e) {
      AppLog.e("AI_DEBUG: BULK UPLOAD SUBJECTS ERROR", e);
      rethrow;
    }
  }

  // Fetch a large pool of questions for Share feature (Admin-only refresh)
  Future<List<Question>> fetchLargeShareQuizPool(int limit) async {
    try {
      AppLog.d("AI_DEBUG: Admin Refresh: Fetching large share quiz pool (limit: $limit)...");
      List<Question> pool = [];
      List<String> types = ['general_tamil', 'general_studies', 'aptitude'];
      
      int perType = (limit * 0.7 ~/ types.length); // 70% from specific types

      for (String type in types) {
        QuerySnapshot snap = await _db.collection('quizzes')
            .where('quiz_type', isEqualTo: type)
            .limit(10) // Get 10 documents, each has ~10 questions
            .get();
            
        for (var doc in snap.docs) {
          List<dynamic> qData = doc.get('questions');
          pool.addAll(qData.map((q) {
             var map = Map<String, dynamic>.from(q as Map);
             map['quiz_type'] = type;
             map['subject'] = type;
             return Question.fromMap(map);
          }));
          if (pool.length > limit) break;
        }
      }

      // Fallback/Variety from general daily quizzes
      if (pool.length < limit) {
         QuerySnapshot dailySnap = await _db.collection('quizzes')
            .where('type', isEqualTo: 'daily_quiz')
            .limit(15)
            .get();
            
         for (var doc in dailySnap.docs) {
           List<dynamic> qData = doc.get('questions');
           pool.addAll(qData.map((q) {
             var map = Map<String, dynamic>.from(q as Map);
             map['quiz_type'] = 'general_studies';
             return Question.fromMap(map);
           }));
           if (pool.length > limit) break;
         }
      }

      pool.shuffle();
      return pool.take(limit).toList();
    } catch (e) {
      AppLog.e("Error fetching large share quiz pool: $e");
      return [];
    }
  }
}
