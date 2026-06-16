import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import '../services/room_service.dart';
import '../utils/app_theme.dart';
import 'multiplayer_quiz_screen.dart';
import '../utils/app_language.dart';

class WaitingRoomScreen extends StatefulWidget {
  final String roomCode;
  final bool isHost;

  const WaitingRoomScreen({super.key, required this.roomCode, required this.isHost});

  @override
  State<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends State<WaitingRoomScreen> {
  final RoomService _roomService = RoomService();
  final ScreenshotController _screenshotController = ScreenshotController();
  String _subject = 'General';

  void _shareRoomCode() async {
    // Show a loading indicator while capturing
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final image = await _screenshotController.capture();
      if (mounted) Navigator.pop(context); // Dismiss loading

      if (image == null) return;

      final directory = await getTemporaryDirectory();
      final imagePath = File('${directory.path}/invitation_${widget.roomCode}.png');
      await imagePath.writeAsBytes(image);

      await Share.shareXFiles(
        [XFile(imagePath.path)],
        text: 'Join my TNPSC Live Quiz Battle!\n\n'
              'Room Code: ${widget.roomCode}\n'
              'Subject: ${AppLanguage.getString(_subject)}\n\n'
              // 'Download App: https://play.google.com/store/apps/details?id=com.tnpsc.master',
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to share invitation card.')),
        );
      }
    }
  }

  void _startExam() async {
    final result = await _roomService.startRoom(widget.roomCode);
    if (!mounted) return;
    if (result == 'need_more_players') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLanguage.getString('group_test_needs_players'),
          ),
        ),
      );
    } else if (result != 'success') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLanguage.getString('could_not_start_group_test'))),
      );
    }
  }

  final List<String> _loadingTipsEn = [
    "Madras Service Commission was established in 1929.",
    "TNPSC is the first Provincial Public Service Commission in India.",
    "Unit 8 & 9 are key areas in the new TNPSC syllabus.",
    "The official language of Tamil Nadu is Tamil.",
    "Tamil Nadu has 38 districts as of 2024.",
  ];

  final List<String> _loadingTipsTa = [
    "மெட்ராஸ் சேவை ஆணையம் 1929 இல் நிறுவப்பட்டது.",
    "இந்தியாவில் முதல் மாகாண பொதுப்பணி ஆணையம் TNPSC ஆகும்.",
    "புதிய TNPSC பாடத்திட்டத்தில் யூனிட் 8 மற்றும் 9 முக்கியப் பகுதிகள்.",
    "தமிழ்நாட்டின் அதிகாரப்பூர்வ மொழி தமிழ்.",
    "2024 நிலவரப்படி தமிழ்நாட்டில் 38 மாவட்டங்கள் உள்ளன.",
  ];

  Widget _buildEducationalTips(bool isDark) {
    bool isTamil = AppLanguage.languageNotifier.value == 'ta';
    List<String> tips = isTamil ? _loadingTipsTa : _loadingTipsEn;
    
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(isDark ? 0.1 : 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lightbulb_outline_rounded, color: AppTheme.secondaryColor, size: 18),
              const SizedBox(width: 8),
              Text(
                isTamil ? "உங்களுக்குத் தெரியுமா?" : "Did you know?",
                style: AppTheme.getStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.secondaryColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: DefaultTextStyle(
              style: AppTheme.getStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              textAlign: TextAlign.center,
              child: AnimatedTextKit(
                repeatForever: true,
                animatedTexts: tips.map((tip) => FadeAnimatedText(tip, duration: const Duration(seconds: 3))).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<DocumentSnapshot>(
      stream: _roomService.roomStream(widget.roomCode),
      builder: (context, roomSnapshot) {
        bool roomExists = roomSnapshot.hasData && roomSnapshot.data!.exists;
        Map<String, dynamic>? roomData;
        
        if (roomExists) {
          roomData = roomSnapshot.data!.data() as Map<String, dynamic>;
          _subject = roomData['subject'] ?? 'General';
          
          if (roomData['status'] == 'active') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => MultiplayerQuizScreen(roomCode: widget.roomCode, roomData: roomData!),
                ),
              );
            });
          }
        }

        bool isCurrentUserHost = widget.isHost || (roomData?['hostId'] == FirebaseAuth.instance.currentUser?.uid);

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_rounded, color: isDark ? Colors.white : AppTheme.textMainColor),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(AppLanguage.getString('group_test_lobby'), style: AppTheme.getStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
            actions: [
              if (roomExists)
                IconButton(
                  icon: const Icon(Icons.share_rounded),
                  onPressed: _shareRoomCode,
                )
            ],
          ),
          body: Column(
            children: [
              if (!roomExists) ...[
                const SizedBox(height: 50),
                _buildEducationalTips(isDark),
                const SizedBox(height: 40),
                const Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppTheme.secondaryColor)),
                      SizedBox(height: 20),
                      Text("Creating your room...", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ] else ...[
                Screenshot(
                  controller: _screenshotController,
                  child: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                          child: Text(
                            AppLanguage.getString('welcome_group_quiz'),
                            style: AppTheme.getStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: Text(
                            AppLanguage.getString('room_setup_note'),
                            style: AppTheme.getStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: isDark ? Colors.white60 : Colors.black45,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                AppLanguage.getString(_subject),
                                style: AppTheme.getStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white60 : Colors.black87,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                AppLanguage.getString('lobby_max_players').replaceAll('{max}', '${roomData!['maxPlayers']}'),
                                style: AppTheme.getStyle(fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white60 : Colors.black87),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                          decoration: BoxDecoration(
                              color: isDark ? Colors.grey.shade900 : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
                          ),
                          child: Text(
                            widget.roomCode,
                            style: AppTheme.getStyle(fontSize: 40, fontWeight: FontWeight.bold, color: AppTheme.secondaryColor).copyWith(letterSpacing: 8),
                          ),
                        ),

                      ],
                    ),
                  ),
                ),
                const LinearProgressIndicator(minHeight: 2, backgroundColor: Colors.transparent, valueColor: AlwaysStoppedAnimation(AppTheme.secondaryColor)),
                const SizedBox(height: 10),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black12 : Colors.grey.shade50,
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(child: Text(AppLanguage.getString('players_joined'), style: AppTheme.getStyle(fontSize: 15, fontWeight: FontWeight.bold))),
                            // Moved to screenshot area
                          ],
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: _roomService.playersStream(widget.roomCode),
                            builder: (context, playersSnapshot) {
                              var players = playersSnapshot.data?.docs ?? [];
                              if (players.isEmpty) {
                                return Center(child: Text(AppLanguage.getString('no_history_title'), style: const TextStyle(color: Colors.grey)));
                              }
                              return ListView.builder(
                                itemCount: players.length,
                                itemBuilder: (context, index) {
                                  var pData = players[index].data() as Map<String, dynamic>;
                                  bool isRoomHost = players[index].id == roomData?['hostId'];
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                                      child: const Icon(Icons.person, color: Colors.white70),
                                    ),
                                    title: Text(pData['name'] ?? 'Player', style: AppTheme.getStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                    trailing: isRoomHost ? const Icon(Icons.star, color: Colors.amber) : null,
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (isCurrentUserHost)
                          StreamBuilder<QuerySnapshot>(
                            stream: _roomService.playersStream(widget.roomCode),
                            builder: (context, ps) {
                              final count = ps.data?.docs.length ?? 0;
                              final canStart = count >= 2;
                              return Column(
                                children: [
                                  Text(
                                    canStart
                                        ? 'All $count players will attempt the same quiz.'
                                        : 'Need at least 2 players to start ($count joined)',
                                    textAlign: TextAlign.center,
                                    style: AppTheme.getStyle(
                                      fontSize: 13,
                                      color: canStart ? AppTheme.secondaryColor : Colors.orange,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: canStart ? _startExam : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.secondaryColor,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: Text(
                                        AppLanguage.getString('start_group_test'),
                                        style: AppTheme.getStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          )
                        else
                          Center(
                            child: Text(AppLanguage.getString('waiting_for_host'), style: AppTheme.getStyle(fontSize: 14, color: Colors.grey).copyWith(fontStyle: FontStyle.italic)),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              // பட்டனுக்குக் கீழே இதனைச் சேர்க்கவும்
              const SizedBox(height: 60),
            ],
          ),
        );
      },
    );
  }
}
