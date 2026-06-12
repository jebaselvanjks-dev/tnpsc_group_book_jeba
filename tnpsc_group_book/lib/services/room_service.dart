import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/room.dart';
import '../models/question.dart';
import 'firestore_service.dart';
import 'ai_service.dart';
import 'premium_service.dart';
import 'hive_service.dart';
import 'package:flutter/foundation.dart';

class RoomService {
  static const int roomQuestionCount = 20;
  static const int baseMaxPlayers = 10;
  static const int maxRoomPlayers = 100;
  static const int roomCreateCostPoints = 200;
  static const int extraPlayersCostPoints = 100;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

  static String? currentRoomDate;

  DocumentReference _getRoomRef(String roomCode) {
    String date = currentRoomDate ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
    return _db.collection('rooms').doc('daily_$date').collection('matches').doc(roomCode);
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
  // Ensure premium status is up‑to‑date (clears expired premium)
  await PremiumService.syncCurrentUserPremium();

  String? uid = _auth.currentUser?.uid;
  if (uid == null) return false;

  String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
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
    debugPrint("Error checking room limit: $e");
    return false; // Fail safe
  }
}

  // Log an attempt to prevent playing again today
  Future<void> logAttempt() async {
    String? uid = _auth.currentUser?.uid;
    if (uid == null) return;

    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
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
  Future<String?> createRoom(String subject, int maxPlayers) async {
    String? uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    try {
      if (maxPlayers < 2 || maxPlayers > maxRoomPlayers) {
        return 'invalid_player_limit';
      }

      bool canPlay = await canPlayToday();
      if (!canPlay) return 'limit_reached';

      String roomCode = _generateRoomCode();
      
      String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      currentRoomDate = today;

      // Ensure unique room code
      DocumentSnapshot existing = await _getRoomRef(roomCode).get();
      while (existing.exists) {
        roomCode = _generateRoomCode();
        existing = await _getRoomRef(roomCode).get();
      }

      // 1. Force AI Generation first for Room Matches
      List<Question> allQuestions = [];
      debugPrint("RoomService: Forcing AI generation for subject: $subject...");
      try {
        bool generated = await AiService.generateSubjectQuestions(subject);
        if (generated) {
          allQuestions = await _firestoreService.getSubjectQuestions(subject);
        }
      } catch (e) {
        debugPrint("RoomService: AI generation failed: $e");
      }

      // 3. Fallback: Retrieve questions from historical quizzes in the 'quizzes' collection
      if (allQuestions.isEmpty) {
        debugPrint("RoomService: Subject questions empty. Trying fallback: fetching old quizzes...");
        try {
          String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
          QuerySnapshot quizSnap = await _db.collection('quizzes')
              .where('date', isNotEqualTo: today)
              .limit(5)
              .get();
          
          for (var doc in quizSnap.docs) {
            var data = doc.data() as Map<String, dynamic>;
            List? qs = data['questions'];
            if (qs != null) {
              for (var q in qs) {
                allQuestions.add(Question(
                  question: q['question'] ?? '',
                  options: List<String>.from(q['options'] ?? []),
                  correctOptionIndex: q['correctOptionIndex'] ?? 0,
                  explanation: q['explanation'] ?? '',
                  subject: subject,
                ));
              }
            }
          }
        } catch (e) {
          debugPrint("RoomService: Error fetching fallback old quizzes: $e");
        }
      }

      // 4. Fallback: Retrieve questions from 'mock_tests' collection
      if (allQuestions.isEmpty) {
        debugPrint("RoomService: Still empty. Trying fallback: fetching mock tests...");
        try {
          QuerySnapshot mockSnap = await _db.collection('mock_tests').limit(3).get();
          for (var doc in mockSnap.docs) {
            var data = doc.data() as Map<String, dynamic>;
            List? qs = data['questions'];
            if (qs != null) {
              for (var q in qs) {
                allQuestions.add(Question(
                  question: q['question'] ?? '',
                  options: List<String>.from(q['options'] ?? []),
                  correctOptionIndex: q['correctOptionIndex'] ?? 0,
                  explanation: q['explanation'] ?? '',
                  subject: subject,
                ));
              }
            }
          }
        } catch (e) {
          debugPrint("RoomService: Error fetching fallback mock tests: $e");
        }
      }

      // 5. Fallback: Retrieve questions from other subjects in 'subject_questions'
      if (allQuestions.isEmpty) {
        debugPrint("RoomService: Still empty. Trying fallback: fetching other subject questions...");
        try {
          QuerySnapshot subSnap = await _db.collection('subject_questions').limit(5).get();
          for (var doc in subSnap.docs) {
            var data = doc.data() as Map<String, dynamic>;
            List? qs = data['questions'];
            if (qs != null) {
              for (var q in qs) {
                allQuestions.add(Question(
                  question: q['question'] ?? '',
                  options: List<String>.from(q['options'] ?? []),
                  correctOptionIndex: q['correctOptionIndex'] ?? 0,
                  explanation: q['explanation'] ?? '',
                  subject: subject,
                ));
              }
            }
          }
        } catch (e) {
          debugPrint("RoomService: Error fetching fallback other subject questions: $e");
        }
      }

      // 6. Fallback: Load static default bilingual questions so room creation NEVER fails
      if (allQuestions.isEmpty) {
        debugPrint("RoomService: All online fallbacks empty. Using high-quality hardcoded default questions.");
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
        createdAt: DateTime.now(),
        questions: questionsMap,
      );

      await _getRoomRef(roomCode).set(newRoom.toMap());
      
      // Add creator as player
      DocumentSnapshot userDoc = await _firestoreService.getUserData() ?? await _db.collection('users').doc(uid).get();
      String name = 'Player';
      if (userDoc.exists) {
        name = (userDoc.data() as Map<String, dynamic>?)?['name'] ?? 'Player';
      }
      RoomPlayer hostPlayer = RoomPlayer(uid: uid, name: name);
      await _getRoomRef(roomCode).collection('players').doc(uid).set(hostPlayer.toMap());

      await HiveService.saveHostRoom(roomCode, today);
      
      return roomCode;
    } catch (e) {
      debugPrint("Error creating room: $e");
      return null;
    }
  }

  // Get active room hosted by current user today
  Future<String?> getActiveHostRoom() async {
    String? uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    try {
      String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
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
        return roomCode;
      } else {
        await HiveService.clearHostRoom();
        return null;
      }
    } catch (e) {
      debugPrint("Error in getActiveHostRoom: $e");
      // Fallback to local cache if Firestore check fails
      return HiveService.getHostRoomCode();
    }
  }

  // Join a room
  Future<String?> joinRoom(String roomCode) async {
    String? uid = _auth.currentUser?.uid;
    if (uid == null) return 'auth_error';

    try {
      bool canPlay = await canPlayToday();
      if (!canPlay) return 'limit_reached';

      String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      currentRoomDate = today;
      DocumentReference roomRef = _getRoomRef(roomCode);
      DocumentSnapshot roomDoc = await roomRef.get();

      if (!roomDoc.exists) {
        return 'not_found';
      }
      
      Room room = Room.fromMap(roomDoc.data() as Map<String, dynamic>, roomCode);
      
      if (room.status != 'waiting') return 'already_started';
      
      // Check players count
      QuerySnapshot players = await roomRef.collection('players').get();
      if (players.docs.length >= room.maxPlayers && !players.docs.any((d) => d.id == uid)) {
        return 'room_full';
      }

      // Get user name
      DocumentSnapshot userDoc = await _firestoreService.getUserData() ?? await _db.collection('users').doc(uid).get();
      String name = 'Player';
      if (userDoc.exists) {
        name = (userDoc.data() as Map<String, dynamic>?)?['name'] ?? 'Player';
      }

      RoomPlayer player = RoomPlayer(uid: uid, name: name);
      await roomRef.collection('players').doc(uid).set(player.toMap());
      
      return 'success';
    } catch (e) {
      debugPrint("Error joining room: $e");
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
        'playingCount': playersSnap.docs.length,
        'finishedCount': 0,
        'abandonedCount': 0,
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
      debugPrint("Error starting room: $e");
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
      final playerRef =
          _getRoomRef(roomCode).collection('players').doc(uid);
      await playerRef.update({
        'score': score,
        'timeTaken': timeTaken,
        'hasFinished': true,
        'abandoned': abandoned,
        'status': abandoned ? 'abandoned' : 'finished',
        (abandoned ? 'abandonedAt' : 'finishedAt'): FieldValue.serverTimestamp(),
      });

      return await _checkAndMarkRoomFinished(roomCode);
    } catch (e) {
      debugPrint("Error submitting score: $e");
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

    await roomRef.set(
      {
        'playingCount': playing,
        'finishedCount': finished,
        'abandonedCount': abandoned,
        'lastProgressAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

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

    await playerRef.update({'rewardClaimed': true});

    final userRef = _db.collection('users').doc(uid);
    await _db.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      final current = (userSnap.data()?['points'] as num?)?.toInt() ?? 0;
      tx.set(
        userRef,
        {
          'points': current + groupTestRewardPoints,
          'lastGroupRewardAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });

    final cached = HiveService.getCachedUserData() ?? {};
    cached['points'] =
        ((cached['points'] as num?)?.toInt() ?? 0) + groupTestRewardPoints;
    await HiveService.cacheUserData(cached);
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
  Stream<DocumentSnapshot> roomStream(String roomCode) {
    return _getRoomRef(roomCode).snapshots();
  }

  Stream<QuerySnapshot> playersStream(String roomCode) {
    return _getRoomRef(roomCode).collection('players').snapshots();
  }
}
