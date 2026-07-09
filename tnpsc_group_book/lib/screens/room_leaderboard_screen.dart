import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import '../services/room_service.dart';
import '../services/reward_service.dart';
import '../services/hive_service.dart';
import '../utils/app_language.dart';
import '../utils/app_theme.dart';
import '../utils/app_icons.dart';
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
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _rewardFlowStarted = false;
  bool _claimingReward = false;

  void _shareResults() async {
    final image = await _screenshotController.capture();
    if (image == null) return;

    final directory = await getTemporaryDirectory();
    final imagePath = File('${directory.path}/result_${widget.roomCode}.png');
    await imagePath.writeAsBytes(image);

    await Share.shareXFiles(
      [XFile(imagePath.path)],
      text: 'I just finished a TNPSC Group Test Battle!\n'
            'Room: ${widget.roomCode}\n\n'
            'Download the app to compete: : https://play.google.com/store/apps/details?id=com.tnpsc.groupbook.tnpsc_group_book',
    );
  }

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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.popUntil(context, (r) => r.isFirst);
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            ta ? 'குழு தேர்வு முடிவு' : 'Group Test Results',
            style: AppTheme.getStyle(
            fontWeight: FontWeight.bold, fontSize: 18
          ),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: AppIcon(AppIcons.back, color: isDark ? Colors.white : AppTheme.textMainColor),
            onPressed: () => Navigator.maybePop(context),
          ),
        actions: [
          IconButton(
            icon: const AppIcon(AppIcons.share),
            onPressed: _shareResults,
          ),
          IconButton(
            icon: const AppIcon(AppIcons.home),
            onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
          ),
        ],
      ),
      body: Screenshot(
        controller: _screenshotController,
        child: StreamBuilder<DocumentSnapshot>(
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
                      if (status != 'finished') ...[
                        Text(
                          ta
                              ? 'அனைவரும் முடிக்கும் வரை காத்திருக்கவும்...'
                              : 'Waiting for all players to finish...',
                          style: AppTheme.getStyle(
                              fontSize: 13, color: Colors.orange),
                        ),
                        if (FirebaseAuth.instance.currentUser?.uid == roomData['hostId'])
                          Padding(
                            padding: const EdgeInsets.only(top: 12.0),
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Text(ta ? "தேர்வை முடிக்கவா?" : "Finish Test?"),
                                    content: Text(ta 
                                      ? "இதை அழுத்தினால் தேர்வு முடிந்து வெற்றியாளர் பட்டியல் காட்டப்படும். புதியவர்கள் யாரும் சேர முடியாது." 
                                      : "This will end the test and show winners. No new users can join."),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ta ? "இல்லை" : "Cancel")),
                                      ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ta ? "ஆம், முடி" : "Yes, Finish")),
                                    ],
                                  )
                                );
                                if (confirm == true) {
                                  await _roomService.finishRoom(widget.roomCode);
                                }
                              },
                              icon: const AppIcon(Icons.check_circle_outline, color: Colors.white, size: 18),
                              label: Text(ta ? "தேர்வை முடி (Complete Test)" : "Complete Test"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                      ] else if (_claimingReward)
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

                      // --- Achievement Badges Logic ---
                      String? fastestPlayerId;
                      List<String> perfectScoreIds = [];
                      String? firstFinisherId;
                      String? comebackKingId;

                      final finishedPlayers = players.where((p) => p['hasFinished'] == true && p['abandoned'] != true).toList();

                      if (finishedPlayers.isNotEmpty) {
                        // Fastest Player: Lowest timeTaken
                        int minTime = 999999;
                        for (var p in finishedPlayers) {
                          int t = p['timeTaken'] ?? 999999;
                          if (t < minTime) {
                            minTime = t;
                            fastestPlayerId = p['id'];
                          }
                        }

                        // Perfect Score: Score == 20
                        for (var p in finishedPlayers) {
                          if ((p['score'] ?? 0) >= RoomService.roomQuestionCount) {
                            perfectScoreIds.add(p['id']);
                          }
                        }

                        // First Finisher: Earliest finishedAt timestamp
                        Timestamp? earliestFinish;
                        for (var p in finishedPlayers) {
                          Timestamp? t = p['finishedAt'] as Timestamp?;
                          if (t != null) {
                            if (earliestFinish == null || t.compareTo(earliestFinish) < 0) {
                              earliestFinish = t;
                              firstFinisherId = p['id'];
                            }
                          }
                        }

                        // Comeback King: Top 3 finisher who started latest (started from behind)
                        final topCount = players.length < 3 ? players.length : 3;
                        final topPlayers = players.take(topCount).toList();
                        Timestamp? latestStart;
                        for (var p in topPlayers) {
                          Timestamp? t = p['startedAt'] as Timestamp?;
                          if (t != null) {
                            if (latestStart == null || t.compareTo(latestStart) > 0) {
                              latestStart = t;
                              comebackKingId = p['id'];
                            }
                          }
                        }
                      }

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
                                        style: AppTheme.getStyle(
                                            fontSize: 14,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    title: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          player['name'] as String? ?? 'Player',
                                          style: AppTheme.getStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16),
                                        ),
                                        if (hasFinished && !hasAbandoned)
                                          Wrap(
                                            children: [
                                              if (player['id'] == fastestPlayerId)
                                                _buildBadge('⚡', ta ? 'அதிவேக வீரர்' : 'Fastest Player', Colors.blue, ta),
                                              if (perfectScoreIds.contains(player['id']))
                                                _buildBadge('🏆', ta ? 'முழு மதிப்பெண்' : 'Perfect Score', Colors.orange, ta),
                                              if (player['id'] == firstFinisherId)
                                                _buildBadge('🚀', ta ? 'முதலில் முடித்தவர்' : 'First Finisher', Colors.purple, ta),
                                              if (player['id'] == comebackKingId)
                                                _buildBadge('🔥', ta ? 'கம்பேக் கிங்' : 'Comeback King', Colors.red, ta),
                                            ],
                                          ),
                                      ],
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
                                        color: AppTheme.secondaryColorLight,
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
      ),
    ));
  }

  Color _getRankColor(int index) {
    if (index == 0) return Colors.amber;
    if (index == 1) return Colors.grey.shade400;
    if (index == 2) return Colors.brown.shade400;
    return AppTheme.primaryColor;
  }

  Widget _buildBadge(String icon, String label, Color color, bool ta) {
    return Container(
      margin: const EdgeInsets.only(right: 6, top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: AppTheme.getStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTheme.getStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
