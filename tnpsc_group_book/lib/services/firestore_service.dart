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

  // Get user data with Offline Cache support (Cache-first optimization)
  Future<DocumentSnapshot?> getUserData({bool forceRefresh = false}) async {
    String? uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    try {
      if (!forceRefresh) {
        try {
          // Try to get from Firestore cache first (free!)
          DocumentSnapshot cachedDoc = await _db.collection('users').doc(uid).get(const GetOptions(source: Source.cache));
          if (cachedDoc.exists) {
            debugPrint("AI_DEBUG: User data fetched from CACHE");
            var data = cachedDoc.data() as Map<String, dynamic>;
            await _syncCompletedQuizzesToHive(data);
            return cachedDoc;
          }
        } catch (_) {}
      }

      // Try server fetch
      DocumentSnapshot doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        var data = doc.data() as Map<String, dynamic>;
        // Cache to Hive for offline
        await HiveService.cacheUserData(data);
        await _syncCompletedQuizzesToHive(data);
        
        // Sync totalScore, quizzesCompleted and streak to Hive
        if (data.containsKey('totalScore')) {
          await Hive.box(HiveService.userBoxName).put('totalScore', data['totalScore']);
        }
        if (data.containsKey('quizzesCompleted')) {
          await Hive.box(HiveService.userBoxName).put('quizzesCompleted', data['quizzesCompleted']);
        }
        if (data.containsKey('streak')) {
          await Hive.box(HiveService.userBoxName).put('streak', data['streak']);
        }
        if (data.containsKey('lastActiveDate')) {
          await Hive.box(HiveService.userBoxName).put('lastActiveDate', data['lastActiveDate']);
        }
        return doc;
      }
      return doc;
    } catch (e) {
      debugPrint("AI_DEBUG: Server fetch failed, check Firestore cache fallback");
      try {
        DocumentSnapshot doc = await _db.collection('users').doc(uid).get(const GetOptions(source: Source.cache));
        if (doc.exists) {
          var data = doc.data() as Map<String, dynamic>;
          await _syncCompletedQuizzesToHive(data);
          
          if (data.containsKey('totalScore')) {
            await Hive.box(HiveService.userBoxName).put('totalScore', data['totalScore']);
          }
          if (data.containsKey('quizzesCompleted')) {
            await Hive.box(HiveService.userBoxName).put('quizzesCompleted', data['quizzesCompleted']);
          }
          if (data.containsKey('streak')) {
            await Hive.box(HiveService.userBoxName).put('streak', data['streak']);
          }
          if (data.containsKey('lastActiveDate')) {
            await Hive.box(HiveService.userBoxName).put('lastActiveDate', data['lastActiveDate']);
          }
        }
        return doc;
      } catch (ce) {
        debugPrint("AI_DEBUG: Firestore cache failed, using Hive");
        return null; // UI will use HiveService.getCachedUserData()
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
    } catch (e) {
      debugPrint("Error incrementing user points: $e");
    }
  }

  // Fetch Daily Quiz Questions with Caching
  Future<List<Question>> getDailyQuiz() async {
    try {
      String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
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
      String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
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
    String dayName;

    // Logic:
    // Sunday (7) & Monday (1) -> Sunday
    // Tuesday (2) & Wednesday (3) -> Tuesday
    // Thursday (4) & Friday (5) -> Thursday
    // Saturday (6) -> Saturday
    if (weekday == 7 || weekday == 1) {
      dayName = "Sunday";
      targetDate = now.subtract(Duration(days: weekday == 7 ? 0 : 1));
    } else if (weekday == 2 || weekday == 3) {
      dayName = "Tuesday";
      targetDate = now.subtract(Duration(days: weekday == 2 ? 0 : 1));
    } else if (weekday == 4 || weekday == 5) {
      dayName = "Thursday";
      targetDate = now.subtract(Duration(days: weekday == 4 ? 0 : 1));
    } else {
      dayName = "Saturday";
      targetDate = now;
    }
    
    return "${dayName}_${DateFormat('yyyy-MM-dd').format(targetDate)}";
  }

  // Get Top Scorers for Leaderboard (Static Fetch - No Stream)
  Future<List<Map<String, dynamic>>> getLeaderboard({bool isDaily = true, bool forceRefresh = false}) async {
    try {
      Query query;

      if (isDaily) {
        String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        query = _db.collection('leaderboards').doc('daily_$today').collection('scores');
      } else {
        String docId = _getMockLeaderboardDocId();
        query = _db.collection('leaderboards').doc(docId).collection('scores');
      }

      // If forceRefresh, skip cache
      if (forceRefresh) {
        QuerySnapshot snapshot = await query
            .where('score', isGreaterThan: 0)
            .orderBy('score', descending: true)
            .limit(10)
            .get();
        debugPrint("AI_DEBUG: Leaderboard fetched from SERVER (forceRefresh). Count: ${snapshot.docs.length}");
        return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
      }

      // Try cache first
      QuerySnapshot snapshot;
      try {
        snapshot = await query
            .where('score', isGreaterThan: 0)
            .orderBy('score', descending: true)
            .limit(10)
            .get(const GetOptions(source: Source.cache));
        if (snapshot.docs.isNotEmpty) {
          debugPrint("AI_DEBUG: Leaderboard fetched from CACHE. Count: ${snapshot.docs.length}");
          return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
        }
        // Fallback to server if cache empty
        throw Exception("Cache empty");
      } catch (_) {
        // Server fetch
        snapshot = await query
            .where('score', isGreaterThan: 0)
            .orderBy('score', descending: true)
            .limit(10)
            .get();
        debugPrint("AI_DEBUG: Leaderboard fetched from SERVER. Count: ${snapshot.docs.length}");
        return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
      }
    } catch (e) {
      debugPrint("AI_DEBUG: LEADERBOARD ERROR: $e");
      return [];
    }
  }

  // Get current user's accumulated score for today (Daily or Mock)
  Future<Map<String, dynamic>?> getUserBestResultToday({bool isDaily = true}) async {
    String? uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    try {
      String docId;
      if (isDaily) {
        String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
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

      // REMOVED: Saving to 'results' collection as per user request
      // We only keep leaderboard updates and completion flags
      
       // Update Daily and Weekly Leaderboards if score > 0 AND it's a Daily Quiz (Mock Quiz scores should NOT affect leaderboard)
       if (score > 0 && subject == "Daily Quiz") {
         String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
         String monday = _getMondayDateString();

         var scoreData = {
           'userId': uid,
           'userName': userName,
           'score': score, // OVERWRITE: User's latest attempt for the day
           'totalQuestions': totalQuestions,
           'timeTaken': timeTaken,
           'timestamp': FieldValue.serverTimestamp(),
           'expiresAt': DateTime.now().add(const Duration(days: 7)), // For TTL Auto Delete
         };

         // Update Daily (Subcollection format for TTL)
         await _db.collection('leaderboards').doc('daily_$today').collection('scores').doc(uid).set(scoreData, SetOptions(merge: true));
         // Update Weekly (Subcollection format for TTL)
         await _db.collection('leaderboards').doc('weekly_$monday').collection('scores').doc(uid).set(scoreData, SetOptions(merge: true));
         debugPrint("AI_DEBUG: Daily and Weekly leaderboards updated (Mock Quiz excluded)");
       }

       // --- NEW: Save Mock Quiz Result to Scheduled Leaderboard ---
       if (score > 0 && subject == "Mock Quiz") {
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

         await _db.collection('leaderboards').doc(docId).collection('scores').doc(uid).set(scoreData, SetOptions(merge: true));
         debugPrint("AI_DEBUG: Mock leaderboard updated for $docId");
       }

      if (subject == "Daily Quiz") {
        String? activeDate = Hive.box(HiveService.userBoxName).get('last_active_quiz_date') as String?;
        activeDate ??= DateFormat('yyyy-MM-dd').format(DateTime.now());

        await _db.collection('users').doc(uid).set({
          'completedDailyQuizzes': activeDate,
          'dailyquiz_complete': true,
        }, SetOptions(merge: true));
        debugPrint("AI_DEBUG: Completed quiz date $activeDate synchronized to Firestore");
      } else if (subject == "Mock Quiz") {
        String? activeDate = Hive.box(HiveService.userBoxName).get('last_active_mock_quiz_date') as String?;
        activeDate ??= DateFormat('yyyy-MM-dd').format(DateTime.now());
        
        await _db.collection('users').doc(uid).set({
          'completedMockQuizzes': activeDate,
        }, SetOptions(merge: true));
        debugPrint("AI_DEBUG: Completed mock quiz date $activeDate synchronized to Firestore");
      }

      // Update local Hive stats immediately for real-time UI update
      final userBox = Hive.box(HiveService.userBoxName);
      int currentPoints = userBox.get('totalScore', defaultValue: 0) as int;
      int currentQuizzes = userBox.get('quizzesCompleted', defaultValue: 0) as int;
      await userBox.put('totalScore', currentPoints + score);
      await userBox.put('quizzesCompleted', currentQuizzes + 1);

      // Update user overall stats in Firestore
      await _db.collection('users').doc(uid).set({
        'totalScore': FieldValue.increment(score),
        'quizzesCompleted': FieldValue.increment(1),
      }, SetOptions(merge: true));
      debugPrint("AI_DEBUG: User stats updated in Firestore and local Hive");
    }
  }

  // Update daily streak
  Future<void> updateStreak() async {
    String? uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final userBox = Hive.box(HiveService.userBoxName);
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
      String safeId = subject.replaceAll('/', '-');
      
      DocumentSnapshot doc;
      if (!forceRefresh) {
        try {
          doc = await _db.collection('subject_questions').doc(safeId).get(const GetOptions(source: Source.cache));
          if (doc.exists) {
            debugPrint("AI_DEBUG: Subject questions $subject fetched from CACHE");
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
    debugPrint("AI_DEBUG: Fetching $subject from HIVE (Offline)");
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
      String safeId = subject.replaceAll('/', '-');
      
      DocumentSnapshot doc;
      if (!forceRefresh) {
        try {
          doc = await _db.collection('subject_study_material').doc(safeId).get(const GetOptions(source: Source.cache));
          if (doc.exists) {
            debugPrint("AI_DEBUG: Study material $subject fetched from CACHE");
            List<dynamic> material = doc.get('material');
            return material.map((e) => Map<String, dynamic>.from(e)).toList();
          }
        } catch (_) {}
      }

      doc = await _db.collection('subject_study_material').doc(safeId).get();
      if (doc.exists) {
        List<dynamic> material = doc.get('material');
        // Backwards compatibility for UI or internal use
        return material.map((e) => Map<String, dynamic>.from(e)).toList();
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
