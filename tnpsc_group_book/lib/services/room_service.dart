import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tnpsc_group_book/utils/app_date.dart';
import '../models/room.dart';
import '../models/question.dart';
import '../utils/app_log.dart';
import 'firestore_service.dart';
import 'ai_service.dart';
import 'hive_service.dart';
import 'package:hive/hive.dart';

class RoomService {
  static const int roomQuestionCount = 20;
  static const int baseMaxPlayers = 10;
  static const int maxRoomPlayers = 100;
  static const int roomCreateCostPoints = 200;
  static const int roomJoinCostPoints = 100;
  static const int extraPlayersCostPoints = 100;

  /// Centralized logic to calculate room creation cost.
  /// Admin always pays 0. First attempt of the day is free (base cost).
  static int calculateRoomCost({
    required int maxPlayers,
    required int dailyAttempts,
    required bool isAdmin,
  }) {
    if (isAdmin) return 0;

    // First daily attempt is free (no base cost)
    int baseCost = dailyAttempts > 0 ? roomCreateCostPoints : 0;

    // Extra cost logic:
    // 10-30 players: Flat 100 points
    // 31-100 players: +100 points for every additional 10 players
    int extraCost = 0;
    if (maxPlayers > baseMaxPlayers) {
      extraCost = 100; // Flat 100 for 11-30 players
      if (maxPlayers > 30) {
        int additionalPlayers = maxPlayers - 30;
        extraCost += ((additionalPlayers + 9) ~/ 10) * 100;
      }
    }

    return baseCost + extraCost;
  }

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

  static String? currentRoomDate;

  DocumentReference _getRoomRef(String roomCode, {String? date}) {
    String d = date ?? (currentRoomDate ?? AppDate.getTodayString());
    return _db.collection('rooms').doc('daily_$d').collection('matches').doc(roomCode);
  }

  // Generate 6 character code
  String _generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random rnd = Random();
    return String.fromCharCodes(Iterable.generate(
      6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  // Check if user has already played a multiplayer room today
  Future<bool> canPlayToday() async {
  String? uid = _auth.currentUser?.uid;
  if (uid == null) return false;

  String today = AppDate.getTodayString();
  int allowedLimit = HiveService.dailyRoomMatchLimit();

  try {
    DocumentSnapshot doc = await _db
        .collection('daily_room_attempts')
        .doc('daily_$today')
        .collection('attempts')
        .doc(uid)
        .get();
    
    if (!doc.exists) return true;

    var data = doc.data() as Map<String, dynamic>;
    int attemptsCount = data['attemptsCount'] ?? 0;

    return attemptsCount < allowedLimit;
  } catch (e) {
    AppLog.e("Error checking room limit", e);
    return false; // Fail safe
  }
}

  // Log an attempt to prevent playing again today
  Future<void> logAttempt() async {
    String? uid = _auth.currentUser?.uid;
    if (uid == null) return;

    String today = AppDate.getTodayString();
    
    int currentCount = 0;
    try {
      DocumentSnapshot doc = await _db
          .collection('daily_room_attempts')
          .doc('daily_$today')
          .collection('attempts')
          .doc(uid)
          .get();
          
      if (doc.exists) {
        var data = doc.data() as Map<String, dynamic>;
        currentCount = data['attemptsCount'] ?? 0;
      }
    } catch (_) {}

    await _db
        .collection('daily_room_attempts')
        .doc('daily_$today')
        .collection('attempts')
        .doc(uid)
        .set({
      'attemptsCount': currentCount + 1,
      'lastAttempt': today,
      'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Create a new room
  Future<String?> createRoom(String subject, int maxPlayers, {DateTime? startTime, DateTime? endTime}) async {
    String? uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    // Admin check logic matching RoomSetupScreen
    bool isAdmin = _auth.currentUser?.phoneNumber == '+918754236411' || 
                   _auth.currentUser?.email == 'adminjeba@gmail.com' || 
                   _auth.currentUser?.email == 'kjebaselvan987@gmail.com';

    try {
      if (maxPlayers < 2 || maxPlayers > maxRoomPlayers) {
        return 'invalid_player_limit';
      }

      // Check for hosting room only - allow joining others
      final existingHost = await getActiveHostRoom();
      if (existingHost != null) return 'room_exists_error';
      
      // Strict validation: Prevent creating rooms with past start time
      DateTime now = AppDate.getISTNow();
      if (startTime != null && startTime.isBefore(now.subtract(const Duration(minutes: 1)))) {
        return 'past_time_error';
      }

      // Ensure creation is for TODAY IST
      String today = AppDate.getTodayString();
      if (startTime != null && AppDate.format(startTime) != today) {
        return 'invalid_date_error';
      }

      bool canPlay = await canPlayToday();
      if (!canPlay) return 'limit_reached';

      String roomCode = _generateRoomCode();
      currentRoomDate = today;

      // Ensure unique room code
      DocumentSnapshot existing = await _getRoomRef(roomCode).get();
      while (existing.exists) {
        roomCode = _generateRoomCode();
        existing = await _getRoomRef(roomCode).get();
      }

      // 1. Priority: Fetch and shuffle from the pre-generated room quiz pool
      List<Question> allQuestions = [];
      try {
        AppLog.d("RoomService: Checking for pre-generated room quiz pool for $subject...");
        
        final roomQuizDoc = await _db
            .collection('room_predefined_quizzes')
            .doc(subject)
            .get();

        if (roomQuizDoc.exists) {
          final data = roomQuizDoc.data() as Map<String, dynamic>;
          List? qs = data['questions'];
          if (qs != null && qs.isNotEmpty) {
            // Shuffle the entire pool and take roomQuestionCount
            List pool = List.from(qs);
            pool.shuffle();
            
            for (var q in pool.take(roomQuestionCount)) {
              allQuestions.add(Question.fromMap(Map<String, dynamic>.from(q)));
            }
            AppLog.d("RoomService: Shuffled pool and selected ${allQuestions.length} unique questions.");
          }
        }
      } catch (e) {
        AppLog.e("RoomService: Error fetching pre-generated room quiz pool", e);
      }

      // 2. Force AI Generation if pre-generated is not found or empty
      if (allQuestions.isEmpty) {
        AppLog.d("RoomService: No pre-generated quiz found. Trying AI generation for subject: $subject...");
        try {
          // AI_DEBUG: Use the room-specific generation method for consistency
          bool generated = await AiService.generateAndSaveRoomPredefinedQuiz(subject);
          if (generated) {
             final freshDoc = await _db.collection('room_predefined_quizzes').doc(subject).get();
             if (freshDoc.exists) {
                final freshData = freshDoc.data() as Map<String, dynamic>;
                List? freshQs = freshData['questions'];
                if (freshQs != null && freshQs.isNotEmpty) {
                  for (var q in freshQs.take(roomQuestionCount)) {
                    allQuestions.add(Question.fromMap(Map<String, dynamic>.from(q)));
                  }
                }
             }
          } else {
            // Fallback to general subject questions if specific room generation fails
            bool subGenerated = await AiService.generateSubjectQuestions(subject);
            if (subGenerated) {
              allQuestions = await _firestoreService.getSubjectQuestions(subject);
            }
          }
        } catch (e) {
          AppLog.e("RoomService: AI generation failed", e);
        }
      }

      // 3. Fallback: Retrieve questions from other subjects in 'subject_questions'
      if (allQuestions.length < roomQuestionCount) {
        AppLog.d("RoomService: Still not enough. Trying fallback: fetching subject_questions for $subject...");
        try {
          // Try specific subject document first
          String safeId = subject.replaceAll('/', '-');
          DocumentSnapshot specificSubDoc = await _db.collection('subject_questions').doc(safeId).get();
          
          if (specificSubDoc.exists) {
            var data = specificSubDoc.data() as Map<String, dynamic>;
            List? qs = data['questions'];
            if (qs != null) {
              for (var q in qs) {
                allQuestions.add(Question.fromMap(Map<String, dynamic>.from(q)));
              }
            }
          }

          // If still low, try other documents but filter by subject field
          if (allQuestions.length < roomQuestionCount) {
            QuerySnapshot subSnap = await _db.collection('subject_questions').limit(5).get();
            for (var doc in subSnap.docs) {
              if (doc.id == safeId) continue; // Already checked
              
              var data = doc.data() as Map<String, dynamic>;
              if (data['subject'] == subject) {
                List? qs = data['questions'];
                if (qs != null) {
                  for (var q in qs) {
                    allQuestions.add(Question.fromMap(Map<String, dynamic>.from(q)));
                  }
                }
              }
            }
          }
          AppLog.d("RoomService: After fallback 3 (Subject Questions), pool size: ${allQuestions.length}");
        } catch (e) {
          AppLog.e("RoomService: Error fetching fallback subject questions", e);
        }
      }

      // 4. Fallback: Load static default bilingual questions so room creation NEVER fails
      if (allQuestions.isEmpty) {
        AppLog.d("RoomService: All online fallbacks empty. Using high-quality hardcoded default questions.");
        allQuestions.addAll(defaultRoomQuestions);
      }

      allQuestions.shuffle();
      List<Question> selected = allQuestions.take(roomQuestionCount).toList();
      
      List<Map<String, dynamic>> questionsMap = selected.map((q) => q.toMap()).toList();

      Room newRoom = Room(
        id: roomCode,
        hostId: uid,
        subject: subject,
        maxPlayers: maxPlayers,
        status: 'waiting',
        mode: 'group_test',
        createdAt: AppDate.getISTNow(),
        startTime: startTime,
        endTime: endTime,
        questions: questionsMap,
      );

      // 1. Point Deduction & Attempt Logic via Transaction
      int cost = 0;
      
      final userRef = _db.collection('users').doc(uid);
      final attemptRef = _db.collection('daily_room_attempts')
          .doc('daily_$today')
          .collection('attempts')
          .doc(uid);

      final transactionResult = await _db.runTransaction((transaction) async {
        final userSnap = await transaction.get(userRef);
        final attemptSnap = await transaction.get(attemptRef);

        int currentAttempts = 0;
        if (attemptSnap.exists) {
          currentAttempts = (attemptSnap.data() as Map<String, dynamic>)['attemptsCount'] ?? 0;
        }

        cost = calculateRoomCost(
          maxPlayers: maxPlayers,
          dailyAttempts: currentAttempts,
          isAdmin: isAdmin,
        );

        int currentPoints = 0;
        int currentPointsAlt = 0;
        
        if (userSnap.exists) {
          currentPoints = (userSnap.data()?['totalScore'] as num?)?.toInt() ?? 0;
          currentPointsAlt = (userSnap.data()?['points'] as num?)?.toInt() ?? 0;
        }

        if (currentPoints < cost) {
          return 'insufficient_points';
        }

        // 1. Deduct points & Update room history & Set last played
        transaction.set(userRef, {
          'totalScore': currentPoints - cost,
          'points': currentPointsAlt - cost,
          'room_history': "$roomCode|$today",
          'last_room_played': roomCode,
          'last_room_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // 2. Increment attempts
        transaction.set(attemptRef, {
          'attemptsCount': currentAttempts + 1,
          'lastAttempt': today,
          'timestamp': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // 3. Create the room document
        transaction.set(_getRoomRef(roomCode), newRoom.toMap());

        // 4. Add creator as player
        String name = 'Player';
        if (userSnap.exists) {
          name = (userSnap.data()?['name']) ?? 'Player';
        }
        RoomPlayer hostPlayer = RoomPlayer(uid: uid, name: name);
        transaction.set(_getRoomRef(roomCode).collection('players').doc(uid), hostPlayer.toMap());

        return 'success';
      });

      if (transactionResult == 'insufficient_points') return 'insufficient_points';
      if (transactionResult == 'user_not_found') return null;

      await HiveService.saveActiveRoom(roomCode, true);
      await HiveService.saveHostRoom(roomCode, today);

      
      // Update Hive local state for points and attempts
      final userBox = Hive.box(HiveService.userBoxName);
      
      // Get latest data from the successful transaction
      int newScore = (userBox.get('totalScore', defaultValue: 0) as int) - cost;
      await userBox.put('totalScore', newScore);
      
      int currentAttempts = userBox.get('room_create_attempts_$today', defaultValue: 0) as int;
      await userBox.put('room_create_attempts_$today', currentAttempts + 1);

      // AI_DEBUG: Update the cached user data map as well for Profile screen
      Map<String, dynamic> cachedData = HiveService.getCachedUserData() ?? {};
      cachedData['totalScore'] = newScore;
      cachedData['points'] = (cachedData['points'] ?? 0) - cost;
      await HiveService.cacheUserData(cachedData);

      // Force refresh user data from Firestore to ensure UI is in sync
      await _firestoreService.getUserData(forceRefresh: true);

      return roomCode;
    } catch (e) {
      AppLog.e("Error creating room", e);
      return null;
    }
  }

  // Get active room hosted by current user today
  Future<Map<String, dynamic>?> getActiveHostRoom() async {
    String? uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    try {
      String today = AppDate.getTodayString();
      QuerySnapshot snap = await _db
          .collection('rooms')
          .doc('daily_$today')
          .collection('matches')
          .where('hostId', isEqualTo: uid)
          .where('status', whereIn: ['waiting', 'active'])
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        String roomCode = snap.docs.first.id;
        await HiveService.saveHostRoom(roomCode, today);
        final data = snap.docs.first.data() as Map<String, dynamic>;
        return {
          'roomCode': roomCode,
          'subject': data['subject'],
          'maxPlayers': data['maxPlayers'],
          'status': data['status'],
          'startTime': data['startTime'],
          'endTime': data['endTime'],
        };
      } else {
        await HiveService.clearHostRoom();
        return null;
      }
    } catch (e) {
      AppLog.e("Error in getActiveHostRoom", e);
      String? cachedCode = HiveService.getHostRoomCode();
      if (cachedCode != null) {
        return {'roomCode': cachedCode};
      }
      return null;
    }
  }

  /// Force finish a room (Admin action)
  Future<void> finishRoom(String roomCode) async {
    try {
      await _getRoomRef(roomCode).update({
        'status': 'finished',
        'manualFinishedAt': FieldValue.serverTimestamp(),
      });
      AppLog.d("AI_DEBUG: Room $roomCode manually finished by host");
    } catch (e) {
      AppLog.e("Error finishing room", e);
    }
  }

  // Join a room
  Future<String?> joinRoom(String roomCode) async {
    String? uid = _auth.currentUser?.uid;
    if (uid == null) return 'auth_error';

    // Admin check logic matching RoomSetupScreen
    bool isAdmin = _auth.currentUser?.phoneNumber == '+918754236411' || 
                   _auth.currentUser?.email == 'adminjeba@gmail.com' || 
                   _auth.currentUser?.email == 'kjebaselvan987@gmail.com';

    try {
      // Allow joining multiple rooms, just need to manage history
      String today = AppDate.getTodayString();
      currentRoomDate = today;
      DocumentReference roomRef = _getRoomRef(roomCode);
      
      final userRef = _db.collection('users').doc(uid);
      
      int cost = 0;

      final transactionResult = await _db.runTransaction((transaction) async {
        final roomSnap = await transaction.get(roomRef);
        if (!roomSnap.exists) return 'not_found';
        
        Room room = Room.fromMap(roomSnap.data() as Map<String, dynamic>, roomCode);
        if (room.status == 'finished') return 'finished';
        if (room.status == 'active') return 'already_started';

        // Check if user is already a member
        final playerRef = roomRef.collection('players').doc(uid);
        final playerSnap = await transaction.get(playerRef);
        bool isAlreadyMember = playerSnap.exists;

        if (!isAlreadyMember) {
           // Check players count
           QuerySnapshot players = await roomRef.collection('players').get();
           if (players.docs.length >= room.maxPlayers) {
             return 'room_full';
           }
           
           // Only charge if not admin
           if (!isAdmin) {
             cost = roomJoinCostPoints;
           }
        }

        final userSnap = await transaction.get(userRef);
        int currentPoints = 0;
        int currentPointsAlt = 0;
        if (userSnap.exists) {
          currentPoints = (userSnap.data()?['totalScore'] as num?)?.toInt() ?? 0;
          currentPointsAlt = (userSnap.data()?['points'] as num?)?.toInt() ?? 0;
        }

        if (currentPoints < cost) {
          return 'insufficient_points';
        }

        // 1. Get user name
        String name = 'Player';
        if (userSnap.exists) {
          name = (userSnap.data()?['name']) ?? 'Player';
        }

        // 2. Deduct points & Update room history
        transaction.set(userRef, {
          'totalScore': currentPoints - cost,
          'points': currentPointsAlt - cost,
          'room_history': "$roomCode|$today",
          'last_room_played': roomCode,
          'last_joined_room': roomCode,
          'last_room_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // 3. Add player to room
        RoomPlayer player = RoomPlayer(uid: uid, name: name);
        transaction.set(playerRef, player.toMap());

        return 'success';
      });

      if (transactionResult == 'success') {
         await HiveService.saveActiveRoom(roomCode, false);
         // Update Hive local state for points
         if (cost > 0) {
            final userBox = Hive.box(HiveService.userBoxName);
            int newScore = (userBox.get('totalScore', defaultValue: 0) as int) - cost;
            await userBox.put('totalScore', newScore);

            Map<String, dynamic> cachedData = HiveService.getCachedUserData() ?? {};
            cachedData['totalScore'] = newScore;
            cachedData['points'] = (cachedData['points'] ?? 0) - cost;
            await HiveService.cacheUserData(cachedData);
         }
         
         // Force refresh user data from Firestore
         await _firestoreService.getUserData(forceRefresh: true);
         AppLog.d("AI_DEBUG: Joined room and deducted $cost points");
      }

      return transactionResult as String;
    } catch (e) {
      AppLog.e("Error joining room", e);
      return 'error';
    }
  }

  /// Host starts group test — all joined players must attempt before group reward.
  /// Returns: 'success' | 'need_more_players' | 'error'
  Future<String> startRoom(String roomCode) async {
    try {
      final roomRef = _getRoomRef(roomCode);
      final playersSnap = await roomRef.collection('players').get();
      if (playersSnap.docs.length < 2) {
        return 'need_more_players';
      }

      final playerIds = playersSnap.docs.map((d) => d.id).toList();
      await roomRef.update({
        'status': 'active',
        'mode': 'group_test',
        'expectedPlayerCount': playersSnap.docs.length,
        'playerIdsAtStart': playerIds,
        'rewardDistributed': false,
        'startedAt': FieldValue.serverTimestamp(),
      });

      final batch = _db.batch();
      for (final doc in playersSnap.docs) {
        batch.set(
          doc.reference,
          {
            'status': 'playing',
            'hasStarted': true,
            'startedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
      await batch.commit();
      return 'success';
    } catch (e) {
      AppLog.e("Error starting room", e);
      return 'error';
    }
  }

  // Submit Score
  Future<bool> submitScore(
    String roomCode,
    int score,
    int timeTaken, {
    bool abandoned = false,
  }) async {
    String? uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    try {
      WriteBatch batch = _db.batch();
      final playerRef = _getRoomRef(roomCode).collection('players').doc(uid);
      
      batch.update(playerRef, {
        'score': score,
        'timeTaken': timeTaken,
        'hasFinished': true,
        'abandoned': abandoned,
        'status': abandoned ? 'abandoned' : 'finished',
        (abandoned ? 'abandonedAt' : 'finishedAt'): FieldValue.serverTimestamp(),
      });

      // AI_DEBUG: Add roomCode to user's room_history in the 'users' collection
      String today = AppDate.getTodayString();
      batch.set(_db.collection('users').doc(uid), {
        'room_history': "$roomCode|$today",
        'last_room_played': roomCode,
        'last_room_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();
      AppLog.d("AI_DEBUG: Score submitted and history updated in one batch");
      
      // Refresh user data immediately after save to sync history
      await _firestoreService.getUserData(forceRefresh: true);

      return await _checkAndMarkRoomFinished(roomCode);
    } catch (e) {
      AppLog.e("Error submitting score", e);
      return false;
    }
  }

  Future<void> abandonRoom(String roomCode, int score, int timeTaken) async {
    await submitScore(roomCode, score, timeTaken, abandoned: true);
  }

  Future<Map<String, int>> _syncRoomProgress(String roomCode) async {
    final roomRef = _getRoomRef(roomCode);
    final roomSnap = await roomRef.get();
    if (!roomSnap.exists) {
      return {'playing': 0, 'finished': 0, 'abandoned': 0};
    }

    final room = roomSnap.data() as Map<String, dynamic>;
    final playerIdsAtStart = List<String>.from(room['playerIdsAtStart'] ?? []);
    final playersSnap = await roomRef.collection('players').get();

    int playing = 0;
    int finished = 0;
    int abandoned = 0;

    for (final doc in playersSnap.docs) {
      if (!playerIdsAtStart.contains(doc.id)) continue;
      final data = doc.data();
      if (data['abandoned'] == true || data['status'] == 'abandoned') {
        abandoned++;
      } else if (data['hasFinished'] == true || data['status'] == 'finished') {
        finished++;
      } else {
        playing++;
      }
    }

    return {'playing': playing, 'finished': finished, 'abandoned': abandoned};
  }

  /// True when every player who was in the room at start has finished.
  Future<bool> _checkAndMarkRoomFinished(String roomCode) async {
    final roomRef = _getRoomRef(roomCode);
    final roomSnap = await roomRef.get();
    if (!roomSnap.exists) return false;

    final room = roomSnap.data() as Map<String, dynamic>;
    if (room['status'] == 'finished') return true;

    final expected = room['expectedPlayerCount'] as int? ?? 0;
    if (expected < 1) return false;

    final progress = await _syncRoomProgress(roomCode);
    final finished = progress['finished'] ?? 0;
    final abandoned = progress['abandoned'] ?? 0;
    final playing = progress['playing'] ?? 0;

    if (finished + abandoned >= expected || playing == 0) {
      await roomRef.update({
        'status': 'finished',
        'allFinishedAt': FieldValue.serverTimestamp(),
      });
      return true;
    }
    return false;
  }

  Future<int> countFinishedPlayers(String roomCode) async {
    final roomSnap = await _getRoomRef(roomCode).get();
    if (!roomSnap.exists) return 0;
    final room = roomSnap.data() as Map<String, dynamic>;
    final playerIdsAtStart = List<String>.from(room['playerIdsAtStart'] ?? []);
    final playersSnap =
        await _getRoomRef(roomCode).collection('players').get();
    int finished = 0;
    for (final doc in playersSnap.docs) {
      if (!playerIdsAtStart.contains(doc.id)) continue;
      if (doc.data()['hasFinished'] == true) finished++;
    }
    return finished;
  }

  static const int groupTestRewardPoints = 25;

  /// Grant bonus points after group completes (and ad watched if required).
  Future<void> claimGroupReward(String roomCode) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final playerRef =
        _getRoomRef(roomCode).collection('players').doc(uid);
    final playerSnap = await playerRef.get();
    if (!playerSnap.exists) return;
    if (playerSnap.data()?['rewardClaimed'] == true) return;
    if (playerSnap.data()?['abandoned'] == true) return;
    if (playerSnap.data()?['hasFinished'] != true) return;

    final userRef = _db.collection('users').doc(uid);
    await _db.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      final pSnap = await tx.get(playerRef);

      if (pSnap.exists && pSnap.data()?['rewardClaimed'] == true) {
        return; // Already claimed
      }

      int currentScore = 0;
      int currentPoints = 0;
      if (userSnap.exists) {
        currentScore = (userSnap.data()?['totalScore'] as num?)?.toInt() ?? 0;
        currentPoints = (userSnap.data()?['points'] as num?)?.toInt() ?? 0;
      }
      
      // Update player
      tx.update(playerRef, {'rewardClaimed': true});

      // Update user points
      tx.set(
        userRef,
        {
          'totalScore': currentScore + groupTestRewardPoints,
          'points': currentPoints + groupTestRewardPoints,
          'lastGroupRewardAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });

    final cached = HiveService.getCachedUserData() ?? {};
    cached['totalScore'] = ((cached['totalScore'] as num?)?.toInt() ?? 0) + groupTestRewardPoints;
    cached['points'] = ((cached['points'] as num?)?.toInt() ?? 0) + groupTestRewardPoints;
    await HiveService.cacheUserData(cached);
    
    // Also update Hive individual values
    final box = Hive.box(HiveService.userBoxName);
    int hiveScore = box.get('totalScore', defaultValue: 0) as int;
    await box.put('totalScore', hiveScore + groupTestRewardPoints);
  }

  Future<bool> hasClaimedGroupReward(String roomCode) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    final snap = await _getRoomRef(roomCode)
        .collection('players')
        .doc(uid)
        .get();
    return snap.data()?['rewardClaimed'] == true;
  }

  // Streams for real-time updates
  Stream<DocumentSnapshot> roomStream(String roomCode, {String? date}) {
    return _getRoomRef(roomCode, date: date).snapshots();
  }

  Stream<QuerySnapshot> playersStream(String roomCode, {String? date}) {
    return _getRoomRef(roomCode, date: date).collection('players').snapshots();
  }

  Future<List<Map<String, dynamic>>> getUserRoomHistory() async {
    String? uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    try {
      // 1. Try fetching from user document field first
      final userDoc = await _db.collection('users').doc(uid).get();
      final userData = userDoc.data();
      
      dynamic rawHistory = userData?['room_history'];
      List<dynamic> historyStrings = [];

      if (rawHistory is String) {
        historyStrings = [rawHistory];
      } else if (rawHistory is List) {
        historyStrings = rawHistory;
      }

      // 2. Migration: If field is empty, check old subcollection
      if (historyStrings.isEmpty) {
        AppLog.d("AI_DEBUG: Field room_history is empty, checking subcollection for migration...");
        QuerySnapshot oldSnap = await _db
            .collection('users')
            .doc(uid)
            .collection('room_history')
            .orderBy('timestamp', descending: true)
            .limit(20)
            .get();

        if (oldSnap.docs.isNotEmpty) {
          List<String> migratedStrings = [];
          for (var doc in oldSnap.docs) {
            var data = doc.data() as Map<String, dynamic>;
            String code = data['roomCode'] ?? "";
            String date = data['date'] ?? AppDate.getTodayString();
            if (code.isNotEmpty) {
              migratedStrings.add("$code|$date");
            }
          }
          
          if (migratedStrings.isNotEmpty) {
            // Update the user document with migrated data - Save only the LATEST as a string
            String latestRoom = migratedStrings.first;
            await _db.collection('users').doc(uid).set({
              'room_history': latestRoom,
            }, SetOptions(merge: true));
            AppLog.d("AI_DEBUG: Migrated latest item to room_history field: $latestRoom");
            historyStrings = [latestRoom];
          }
        }
      }

      // 3. Convert "ROOMCODE|DATE" strings back to maps for the UI
      return historyStrings.reversed.map((entry) {
        final parts = entry.toString().split('|');
        return {
          'roomCode': parts[0],
          'date': parts.length > 1 ? parts[1] : AppDate.getTodayString(),
        };
      }).toList();

    } catch (e) {
      AppLog.e("Error fetching room history", e);
      return [];
    }
  }

  Future<void> updateRoomTimeRange(String roomCode, DateTime start, DateTime end) async {
    try {
      await _getRoomRef(roomCode).update({
        'startTime': Timestamp.fromDate(start),
        'endTime': Timestamp.fromDate(end),
      });
    } catch (e) {
      AppLog.e("Error updating room time range", e);
    }
  }

  /// Checks if the user is currently a player in any active or waiting room today.
  Future<Map<String, dynamic>?> getActiveJoinedRoom() async {
    String? uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    try {
      String today = AppDate.getTodayString();
      final userDoc = await _db.collection('users').doc(uid).get();
      final lastJoinedRoom = userDoc.data()?['last_joined_room'] as String?;
      
      if (lastJoinedRoom != null) {
        final roomDoc = await _getRoomRef(lastJoinedRoom).get();
        if (roomDoc.exists) {
          final roomData = roomDoc.data() as Map<String, dynamic>;
          final status = roomData['status'];
          
          // Verify it's not the same room as the one hosted (though last_joined_room should handle this)
          if (roomData['hostId'] == uid) return null;

          if (status == 'waiting' || status == 'active') {
             // Verify user is actually a player
             final playerDoc = await roomDoc.reference.collection('players').doc(uid).get();
             if (playerDoc.exists) {
                final playerData = playerDoc.data() as Map<String, dynamic>;
                if (playerData['hasFinished'] != true) {
                   return {
                     'roomCode': lastJoinedRoom,
                     'status': status,
                     'subject': roomData['subject'],
                     'isHost': false,
                   };
                }
             }
          }
        }
      }
      return null;
    } catch (e) {
      AppLog.e("Error in getActiveJoinedRoom", e);
      return null;
    }
  }
}
