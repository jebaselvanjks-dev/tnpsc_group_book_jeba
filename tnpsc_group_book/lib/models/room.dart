import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/app_date.dart';

class Room {
  final String id;
  final String hostId;
  final String subject;
  final int maxPlayers;
  final String status; // 'waiting', 'active', 'finished'
  final String mode; // 'group_test'
  final int expectedPlayerCount;
  final DateTime createdAt;
  final DateTime? startTime;
  final DateTime? endTime;
  final List<dynamic> questions;

  Room({
    required this.id,
    required this.hostId,
    required this.subject,
    required this.maxPlayers,
    required this.status,
    this.mode = 'group_test',
    this.expectedPlayerCount = 0,
    required this.createdAt,
    this.startTime,
    this.endTime,
    required this.questions,
  });

  factory Room.fromMap(Map<String, dynamic> map, String id) {
    return Room(
      id: id,
      hostId: map['hostId'] ?? '',
      subject: map['subject'] ?? '',
      maxPlayers: map['maxPlayers'] ?? 10,
      status: map['status'] ?? 'waiting',
      mode: map['mode'] ?? 'group_test',
      expectedPlayerCount: map['expectedPlayerCount'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? AppDate.getISTNow(),
      startTime: (map['startTime'] as Timestamp?)?.toDate(),
      endTime: (map['endTime'] as Timestamp?)?.toDate(),
      questions: map['questions'] ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hostId': hostId,
      'subject': subject,
      'maxPlayers': maxPlayers,
      'status': status,
      'mode': mode,
      'expectedPlayerCount': expectedPlayerCount,
      'createdAt': FieldValue.serverTimestamp(),
      'startTime': startTime != null ? Timestamp.fromDate(startTime!) : null,
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'questions': questions,
      'rewardDistributed': false,
    };
  }
}

class RoomPlayer {
  final String uid;
  final String name;
  final int score;
  final int timeTaken;
  final bool hasFinished;

  RoomPlayer({
    required this.uid,
    required this.name,
    this.score = 0,
    this.timeTaken = 0,
    this.hasFinished = false,
  });

  factory RoomPlayer.fromMap(Map<String, dynamic> map, String uid) {
    return RoomPlayer(
      uid: uid,
      name: map['name'] ?? 'Player',
      score: map['score'] ?? 0,
      timeTaken: map['timeTaken'] ?? 0,
      hasFinished: map['hasFinished'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'score': score,
      'timeTaken': timeTaken,
      'hasFinished': hasFinished,
      'abandoned': false,
      'status': hasFinished ? 'finished' : 'waiting',
      'rewardClaimed': false,
    };
  }
}
