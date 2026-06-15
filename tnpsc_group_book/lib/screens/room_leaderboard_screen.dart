import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/room_service.dart';
import '../services/reward_service.dart';
import '../services/hive_service.dart';
import '../utils/app_language.dart';
import '../utils/app_theme.dart';
import '../main.dart';

class RoomLeaderboardScreen extends StatefulWidget {
  final String roomCode;
  final String? date;

  const RoomLeaderboardScreen({super.key, required this.roomCode, this.date});

  @override
  State<RoomLeaderboardScreen> createState() => _RoomLeaderboardScreenState();
}

class _RoomLeaderboardScreenState extends State<RoomLeaderboardScreen> {
  final RoomService _roomService = RoomService();
  bool _rewardFlowStarted = false;
  bool _claimingReward = false;

  void _tryGroupRewardFlow(
    Map<String, dynamic> roomData,
    List<QueryDocumentSnapshot> playerDocs,
  ) {
    if (_rewardFlowStarted || _claimingReward) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    QueryDocumentSnapshot? myDoc;
    for (final d in playerDocs) {
      if (d.id == uid) {
        myDoc = d;
        break;
      }
    }
    if (myDoc == null) return;
    final myData = myDoc.data() as Map;
    if (myData['rewardClaimed'] == true) return;
    if (myData['abandoned'] == true || myData['status'] == 'abandoned') return;
    if (myData['hasFinished'] != true) return;

    _rewardFlowStarted = true;
    _claimingReward = true;

    final ta = AppLanguage.languageNotifier.value == 'ta';
    final grant = () async {
      await _roomService.claimGroupReward(widget.roomCode);
      if (!mounted) return;
      setState(() => _claimingReward = false);
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            ta
                ? '+${RoomService.groupTestRewardPoints} புள்ளிகள் கிடைத்தது!'
                : 'You earned +${RoomService.groupTestRewardPoints} points!',
          ),
          backgroundColor: AppTheme.secondaryColor,
        ),
      );
    };

    if (HiveService.isAdFree()) {
      grant();
    } else {
      RewardService.showRewardAdIfAllowed(onRewardEarned: grant);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ta = AppLanguage.languageNotifier.value == 'ta';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          ta ? 'குழு தேர்வு முடிவு' : 'Group Test Results',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.home_rounded),
            onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _roomService.roomStream(widget.roomCode, date: widget.date),
        builder: (context, roomSnap) {
          if (!roomSnap.hasData || !roomSnap.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }

          final roomData = roomSnap.data!.data() as Map<String, dynamic>;
          final status = roomData['status'] as String? ?? 'active';
          final expected = roomData['expectedPlayerCount'] as int? ?? 0;

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: AppTheme.primaryColor.withValues(alpha: 0.12),
                child: Column(
                  children: [
                    Text('Room: ${widget.roomCode}',
                        style: AppTheme.getStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    if (widget.date != null)
                      Text('Date: ${widget.date}',
                          style: AppTheme.getStyle(
                              fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    if (status != 'finished')
                      Text(
                        ta
                            ? 'அனைவரும் முடிக்கும் வரை காத்திருக்கவும்...'
                            : 'Waiting for all players to finish...',
                        style: AppTheme.getStyle(
                            fontSize: 13, color: Colors.orange),
                      )
                    else if (_claimingReward)
                      const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Text(
                        HiveService.isAdFree()
                            ? (ta
                                ? 'விளம்பரம் இல்லை. புள்ளிகள் வழங்கப்பட்டது.'
                                : 'Ad-free experience. Reward applied.')
                            : (ta
                                ? 'அனைவரும் முடித்தனர்!'
                                : 'All finished!'),
                        textAlign: TextAlign.center,
                        style: AppTheme.getStyle(
                            fontSize: 13, color: AppTheme.secondaryColor),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _roomService.playersStream(widget.roomCode, date: widget.date),
                  builder: (context, playersSnap) {
                    if (!playersSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = playersSnap.data!.docs;
                    final players = docs
                        .map((d) => {
                              'id': d.id,
                              ...d.data() as Map<String, dynamic>,
                            })
                        .toList();

                    players.sort((a, b) {
                      final sc = (b['score'] ?? 0).compareTo(a['score'] ?? 0);
                      if (sc != 0) return sc;
                      return (a['timeTaken'] ?? 9999)
                          .compareTo(b['timeTaken'] ?? 9999);
                    });

                    final playerIdsAtStart =
                        List<String>.from(roomData['playerIdsAtStart'] ?? []);
                    int finished = 0;
                    int abandoned = 0;
                    for (final p in players) {
                      if (!playerIdsAtStart.contains(p['id'])) continue;
                      if (p['abandoned'] == true || p['status'] == 'abandoned') {
                        abandoned++;
                      } else if (p['hasFinished'] == true) {
                        finished++;
                      }
                    }
                    final playing = expected > 0
                        ? (expected - finished - abandoned).clamp(0, expected)
                        : 0;

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _tryGroupRewardFlow(roomData, docs);
                    });

                    return Column(
                      children: [
                        if (expected > 0)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: LinearProgressIndicator(
                              value: expected > 0 ? finished / expected : 0,
                              backgroundColor:
                                  AppTheme.primaryColor.withValues(alpha: 0.15),
                              valueColor: const AlwaysStoppedAnimation(
                                  AppTheme.primaryColor),
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        if (expected > 0)
                          Text(
                            ta
                                ? 'முடித்தவர்: $finished / $expected · விளையாடுகிறார்: $playing · தவரவிட்டவர்: $abandoned'
                                : 'Completed: $finished / $expected · Playing: $playing · Left: $abandoned',
                            style: AppTheme.getStyle(
                                fontSize: 13, color: Colors.grey),
                          ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(20),
                            itemCount: players.length,
                            itemBuilder: (context, index) {
                              final player = players[index];
                              final hasFinished =
                                  player['hasFinished'] ?? false;
                              final hasAbandoned = player['abandoned'] == true ||
                                  player['status'] == 'abandoned';
                              final claimed =
                                  player['rewardClaimed'] ?? false;

                              return Card(
                                color: isDark
                                    ? Colors.grey.shade900
                                    : Colors.white,
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15)),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: _getRankColor(index),
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  title: Text(
                                    player['name'] as String? ?? 'Player',
                                    style: AppTheme.getStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16),
                                  ),
                                  subtitle: hasAbandoned
                                      ? Text(
                                          ta
                                              ? 'தவரவிட்டவர் - மதிப்பெண் சேர்க்கப்பட்டது'
                                              : 'Left match - score saved',
                                          style: AppTheme.getStyle(
                                            fontSize: 12,
                                            color: Colors.redAccent,
                                          ).copyWith(fontStyle: FontStyle.italic),
                                        )
                                      : hasFinished
                                      ? Text(
                                          'Time: ${player['timeTaken']}s${claimed ? (ta ? ' · வெற்றியாளர் ✓' : ' · Reward ✓') : ''}',
                                          style: AppTheme.getStyle(
                                              color: Colors.grey, fontSize: 12),
                                        )
                                      : Text(
                                          ta
                                              ? 'இன்னும் விளையாடுகிறார்...'
                                              : 'Still playing...',
                                          style: AppTheme.getStyle(
                                            fontSize: 12,
                                            color: Colors.orange,
                                          ).copyWith(fontStyle: FontStyle.italic),
                                        ),
                                  trailing: Text(
                                    '${player['score']} pts',
                                    style: AppTheme.getStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _getRankColor(int index) {
    if (index == 0) return Colors.amber;
    if (index == 1) return Colors.grey.shade400;
    if (index == 2) return Colors.brown.shade400;
    return AppTheme.primaryColor;
  }
}
