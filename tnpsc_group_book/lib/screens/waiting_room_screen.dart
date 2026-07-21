import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../services/room_service.dart';
import '../utils/app_theme.dart';
import '../utils/app_date.dart';
import '../utils/app_icons.dart';
import 'multiplayer_quiz_screen.dart';
import 'room_leaderboard_screen.dart';
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
  bool _isExiting = false;
  TimeOfDay? _customTime;
  DateTime? _roomStartTime;
  DateTime? _roomEndTime;

  void _shareRoomCode() async {
    final isTamil = AppLanguage.languageNotifier.value == 'ta';

    // Show selection dialog
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (modalContext) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isTamil ? "அழைப்பிதழைப் பகிரவும்" : "Share Invitation",
              style: AppTheme.getStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const AppIcon(Icons.text_fields_rounded, color: Colors.blue),
              title: Text(isTamil ? "உரைச் செய்தியாக (Text Message)" : "Share as Text"),
              onTap: () {
                Navigator.pop(modalContext);
                _shareAsText();
              },
            ),
            ListTile(
              leading: const AppIcon(Icons.image_rounded, color: Colors.orange),
              title: Text(isTamil ? "அழைப்பிதழ் அட்டையாக (Image Card)" : "Share as Image Card"),
              onTap: () async {
                Navigator.pop(modalContext);
                
                // Show time picker restricted to room range
                final initialTime = _customTime ?? AppDate.getISTTimeOfDay();
                
                final TimeOfDay? picked = await showTimePicker(
                  context: context,
                  initialTime: initialTime,
                  helpText: isTamil ? "அழைப்பிதழ் நேரத்தைத் தேர்ந்தெடுக்கவும்" : "Select Invitation Time",
                  builder: (context, child) {
                    bool isDark = Theme.of(context).brightness == Brightness.dark;
                    Color accentColor = isDark ? AppTheme.secondaryColor : AppTheme.primaryColor;
                    Color goldColor = AppTheme.secondaryColor;

                    return Theme(
                      data: Theme.of(context).copyWith(
                        timePickerTheme: TimePickerThemeData(
                          backgroundColor: isDark ? const Color(0xFF101F42).withOpacity(0.9) : Colors.white.withOpacity(0.9),
                          hourMinuteTextColor: WidgetStateColor.resolveWith((states) => 
                            states.contains(WidgetState.selected) ? Colors.white : goldColor),
                          hourMinuteColor: WidgetStateColor.resolveWith((states) => 
                            states.contains(WidgetState.selected) ? accentColor : (isDark ? Colors.white10 : Colors.grey.shade200)),
                          dayPeriodTextColor: WidgetStateColor.resolveWith((states) => 
                            states.contains(WidgetState.selected) ? Colors.white : goldColor),
                          dayPeriodColor: WidgetStateColor.resolveWith((states) => 
                            states.contains(WidgetState.selected) ? accentColor : Colors.transparent),
                          dialHandColor: accentColor,
                          dialBackgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
                          dialTextColor: WidgetStateColor.resolveWith((states) => 
                            states.contains(WidgetState.selected) ? Colors.white : goldColor),
                          entryModeIconColor: goldColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                          helpTextStyle: AppTheme.getStyle(fontSize: 14, color: goldColor, fontWeight: FontWeight.bold),
                        ),
                        colorScheme: ColorScheme.fromSeed(
                          seedColor: accentColor,
                          primary: accentColor,
                          onPrimary: Colors.white,
                          surface: isDark ? const Color(0xFF101F42) : Colors.white,
                          onSurface: goldColor,
                          brightness: isDark ? Brightness.dark : Brightness.light,
                        ),
                      ),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: MediaQuery(
                          data: MediaQuery.of(context).copyWith(
                            textScaler: const TextScaler.linear(0.9),
                          ),
                          child: child!,
                        ),
                      ),
                    );
                  },
                );

                if (picked != null) {
                  // Validate against room range if available
                  if (_roomStartTime != null && _roomEndTime != null) {
                    final pickedDateTime = AppDate.getISTTodayWithTime(picked.hour, picked.minute);
                    
                    // Check if it's within range (using a small margin for comparison)
                    bool isValid = pickedDateTime.isAfter(_roomStartTime!.subtract(const Duration(minutes: 1))) && 
                                   pickedDateTime.isBefore(_roomEndTime!.add(const Duration(minutes: 1)));
                    
                    if (!isValid) {
                      if (mounted) {
                        final startStr = DateFormat('hh:mm a').format(_roomStartTime!);
                        final endStr = DateFormat('hh:mm a').format(_roomEndTime!);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isTamil 
                              ? "அழைப்பிதழ் நேரம் $startStr முதல் $endStr வரை மட்டுமே இருக்க வேண்டும்" 
                              : "Invitation time must be between $startStr and $endStr"),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                      return;
                    }
                  }

                  setState(() {
                    _customTime = picked;
                  });
                  final roomSnapshot = await _roomService.roomStream(widget.roomCode).first;
                  if (roomSnapshot.exists) {
                    final roomData = roomSnapshot.data() as Map<String, dynamic>;
                    _shareAsImage(roomData);
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _shareAsText() async {
    final isTamil = AppLanguage.languageNotifier.value == 'ta';
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isTamil ? "அழைப்பிதழ் பகிரப்படுகிறது..." : "Sharing invitation..."),
          duration: const Duration(seconds: 2),
          backgroundColor: AppTheme.primaryColor,
        ),
      );
    }

    final String subjectName = AppLanguage.getString(_subject);
    final String message = 'Join my TNPSC Live Quiz Battle!\n\n'
        'Room Code: ${widget.roomCode}\n'
        'Subject: $subjectName\n\n'
        'Tap to Join: tnpscmaster://join?code=${widget.roomCode}\n\n'
        'Download App: https://play.google.com/store/apps/details?id=com.tnpsc.groupbook.tnpsc_group_book';
    
    await Share.share(message);
  }

  void _shareAsImage(Map<String, dynamic> roomData) async {
    final isTamil = AppLanguage.languageNotifier.value == 'ta';
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isTamil ? "அழைப்பிதழ் அட்டை தயாராகிறது..." : "Preparing invitation card..."),
          duration: const Duration(seconds: 2),
          backgroundColor: AppTheme.primaryColor,
        ),
      );
    }

    // Show a loading indicator while capturing
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final image = await _screenshotController.captureFromWidget(
        Material(
          color: Colors.black,
          child: Directionality(
            textDirection: ui.TextDirection.ltr,
            child: MediaQuery(
              data: const MediaQueryData().copyWith(textScaler: const TextScaler.linear(0.9)),
              child: _buildShareCard(roomData),
            ),
          ),
        ),
        pixelRatio: 4.0,
        delay: const Duration(milliseconds: 500),
        targetSize: const Size(400, 750),
      );
      if (mounted) Navigator.pop(context); // Dismiss loading

      if (image == null) return;

      if (mounted) {
        _showSharePreviewDialog(image, roomData);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to prepare invitation card.')),
        );
      }
    }
  }

  void _showSharePreviewDialog(Uint8List imageBytes, Map<String, dynamic> roomData) {
    final isTamil = AppLanguage.languageNotifier.value == 'ta';
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: isDark ? const Color(0xFF101F42) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      isTamil ? "அழைப்பிதழ் முன்னோட்டம்" : "Invitation Preview",
                      style: AppTheme.getStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(imageBytes, fit: BoxFit.contain),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    _executeShare(imageBytes);
                  },
                  icon: const Icon(Icons.share_rounded, color: Colors.white),
                  label: Text(
                    isTamil ? "இப்போதே பகிர்க" : "Share Now",
                    style: AppTheme.getStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _executeShare(Uint8List image) async {
    try {
      final directory = await getTemporaryDirectory();
      final imagePath = File('${directory.path}/invitation_${widget.roomCode}.png');
      await imagePath.writeAsBytes(image);

      await Share.shareXFiles(
        [XFile(imagePath.path)],
        text: 'Join my TNPSC Live Quiz Battle!\n\n'
              'Room Code: ${widget.roomCode}\n'
              'Subject: ${AppLanguage.getString(_subject)}\n\n'
              'Tap to Join: tnpscmaster://join?code=${widget.roomCode}\n\n'
              'Download App: https://play.google.com/store/apps/details?id=com.tnpsc.groupbook.tnpsc_group_book',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to share invitation card.')),
        );
      }
    }
  }

  Widget _buildShareCard(Map<String, dynamic> roomData) {
    const Color goldColor = Color(0xFFFFD700);
    int dayIndex = AppDate.getISTNow().weekday;
    String backgroundImage = 'asset/images/sharequiz$dayIndex.png';

    final now = AppDate.getISTNow();
    DateTime displayDate = now;
    if (_customTime != null) {
      displayDate = AppDate.getISTTodayWithTime(_customTime!.hour, _customTime!.minute);
    }

    return Container(
      width: 400,
      height: 750,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(color: Colors.black),
      child: Stack(
        children: [
          _buildPosterBackground(backgroundImage),
          _buildPosterHeader(goldColor, roomData),
          _buildPosterRoomCodeSection(goldColor, displayDate, roomData),
          _buildPosterCTA(goldColor),
          _buildPosterDownloadSection(),
          // _buildPosterFeatures(goldColor),
          _buildPosterMockups(),
        ],
      ),
    );
  }

  Widget _buildPosterBackground(String imagePath) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            imagePath,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFF030611)),
          ),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.9),
                  Colors.black.withOpacity(0.5),
                  Colors.black.withOpacity(0.95),
                ],
              ),
            ),
          ),
        ),
        // Glow effect
        Positioned(
          top: -50,
          left: -50,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.secondaryColor.withOpacity(0.15),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPosterHeader(Color goldColor, Map<String, dynamic> roomData) {
    return Positioned(
      top: 30,
      left: 0,
      right: 0,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 85,
                    height: 85,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: goldColor, width: 2),
                      boxShadow: [BoxShadow(color: goldColor.withOpacity(0.3), blurRadius: 20)],
                      gradient: const RadialGradient(colors: [Color(0xFF2A2A2A), Color(0xFF000000)]),
                    ),
                    child: ClipOval(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Image.asset('asset/images/logo.png', fit: BoxFit.contain),
                      ),
                    ),
                  ),
                  const SizedBox(width: 60),
                  Column(
                    children: [
                      Text(
                        "TNPSC",
                        style: AppTheme.getStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, height: 1.0, letterSpacing: 2),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "LIVE BATTLE",
                        style: AppTheme.getStyle(fontSize: 32, fontWeight: FontWeight.w900, color: goldColor, height: 1.0, letterSpacing: 1),
                      ),
                    ],
                  ),
                ],
              ),
              // Simulated dots decoration
              Positioned(
                left: 30,
                child: Opacity(opacity: 0.2, child: _buildDotsPattern()),
              ),
              Positioned(
                right: 30,
                child: Opacity(opacity: 0.2, child: _buildDotsPattern()),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white24, width: 0.5),
                bottom: BorderSide(color: Colors.white24, width: 0.5),
              ),
            ),
            child: Text(
              AppLanguage.getString(roomData['subject'] ?? 'General'),
              style: AppTheme.getStyle(fontSize: 25, fontWeight: FontWeight.bold, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDotsPattern() {
    return Column(
      children: List.generate(6, (i) => Row(
        children: List.generate(4, (j) => Container(
          width: 2,
          height: 2,
          margin: const EdgeInsets.all(3),
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        )),
      )),
    );
  }

  Widget _buildPosterRoomCodeSection(Color goldColor, DateTime date, Map<String, dynamic> roomData) {
    return Positioned(
      top: 180,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF0A1931).withOpacity(0.8),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 30, spreadRadius: 5)],
        ),
        child: Column(
          children: [
            Text(
              "ROOM CODE",
              style: AppTheme.getStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 3),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Text(
                widget.roomCode,
                textAlign: TextAlign.center,
                style: AppTheme.getStyle(fontSize: 30, fontWeight: FontWeight.w900, color: const Color(0xFF030611), letterSpacing: 8),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Expanded(child: _buildInfoItem(Icons.calendar_month_rounded, DateFormat('dd MMM yyyy').format(date), DateFormat('hh:mm a').format(date))),
                  Container(width: 1, height: 35, color: Colors.white10),
                  Expanded(child: _buildInfoItem(Icons.groups_rounded, "அதிகபட்ச வீரர்கள்", "${roomData['maxPlayers'] ?? 100}")),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String top, String bottom) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFFE5BA73), size: 18),
            const SizedBox(width: 8),
            Text(top, style: AppTheme.getStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70)),
          ],
        ),
        const SizedBox(height: 4),
        Text(bottom, style: AppTheme.getStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
      ],
    );
  }

  Widget _buildPosterCTA(Color goldColor) {
    return Positioned(
      top: 400,
      left: 40,
      right: 40,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: goldColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: goldColor.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: goldColor.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: goldColor.withOpacity(0.2),
              ),
              child: Icon(Icons.emoji_events_rounded, color: goldColor, size: 24),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Join Battle",
                    style: AppTheme.getStyle(fontSize: 10, color: Colors.white70),
                  ),
                  Text(
                    "குழு வினாடி வினா",
                    style: AppTheme.getStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPosterDownloadSection() {
    return Positioned(
      top: 460,
      left: 40,
      right: 40,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.network(
            'https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png',
            height: 50,
          ),
        ],
      ),
    );
  }

  Widget _buildPosterMockups() {
    return Positioned(
      bottom: -15,
      left: 0,
      right: 0,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildPhoneMockup('asset/images/homeScreenLayout.jpg', rotation: -0.15),
              const SizedBox(width: 40),
              _buildPhoneMockup('asset/images/groupScreenLayout.jpg', rotation: 0.15),
            ],
          ),
          // Decorative Wreath Text
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star_rounded, color: Color(0xFFE5BA73), size: 16),
              const SizedBox(height: 4),
              Text("PREPARE", style: AppTheme.getStyle(fontSize: 7, fontWeight: FontWeight.w900, color: const Color(0xFFE5BA73), letterSpacing: 1)),
              Text("PRACTICE", style: AppTheme.getStyle(fontSize: 7, fontWeight: FontWeight.w900, color: const Color(0xFFE5BA73), letterSpacing: 1)),
              Text("SUCCEED", style: AppTheme.getStyle(fontSize: 7, fontWeight: FontWeight.w900, color: const Color(0xFFE5BA73), letterSpacing: 1)),
              const SizedBox(height: 4),
              const Icon(Icons.star_rounded, color: Color(0xFFE5BA73), size: 16),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneMockup(String imagePath, {required double rotation}) {
    return Transform.rotate(
      angle: rotation,
      child: Container(
        width: 140,
        height: 250,
        decoration: BoxDecoration(
          color: const Color(0xFF030611),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24, width: 3),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: Image.asset(imagePath, fit: BoxFit.fill),
        ),
      ),
    );
  }

  Future<bool> _showStartConfirmation(int playerCount) async {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    bool isTamil = AppLanguage.languageNotifier.value == 'ta';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF101F42) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isTamil ? 'தேர்வைத் தொடங்கவா?' : 'Start Group Test?',
          style: AppTheme.getStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: Text(
          isTamil 
            ? 'மொத்தம் $playerCount வீரர்கள் இணைந்துள்ளனர். தேர்வை இப்போதே தொடங்க விரும்புகிறீர்களா?' 
            : 'Total $playerCount players joined. Are you sure you want to start the test now?',
          style: AppTheme.getStyle(
              fontSize: 15,
              color: isDark ? Colors.white70 : AppTheme.textSecondaryColor
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLanguage.getString('no'), style: AppTheme.getStyle(fontSize: 14, color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              isTamil ? 'தொடங்கு' : 'Start',
              style: AppTheme.getStyle(fontSize: 14, color: Colors.white),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
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

  void _editRoomTime() async {
    final isTamil = AppLanguage.languageNotifier.value == 'ta';
    TimeOfDay start = _roomStartTime != null ? AppDate.getISTTimeOfDay(_roomStartTime!) : AppDate.getISTTimeOfDay();
    TimeOfDay end = _roomEndTime != null ? AppDate.getISTTimeOfDay(_roomEndTime!) : TimeOfDay(hour: (start.hour + 1) % 24, minute: start.minute);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isTamil ? "தேர்வு நேரத்தை மாற்றவும்" : "Edit Room Time Range",
                style: AppTheme.getStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: start,
                          builder: (context, child) {
                            bool isDark = Theme.of(context).brightness == Brightness.dark;
                            Color accentColor = isDark ? AppTheme.secondaryColor : AppTheme.primaryColor;
                            Color goldColor = AppTheme.secondaryColor;

                            return Theme(
                              data: Theme.of(context).copyWith(
                                timePickerTheme: TimePickerThemeData(
                                  backgroundColor: isDark ? const Color(0xFF101F42).withOpacity(0.9) : Colors.white.withOpacity(0.9),
                                  hourMinuteTextColor: WidgetStateColor.resolveWith((states) => 
                                    states.contains(WidgetState.selected) ? Colors.white : goldColor),
                                  hourMinuteColor: WidgetStateColor.resolveWith((states) => 
                                    states.contains(WidgetState.selected) ? accentColor : (isDark ? Colors.white10 : Colors.grey.shade200)),
                                  dayPeriodTextColor: WidgetStateColor.resolveWith((states) => 
                                    states.contains(WidgetState.selected) ? Colors.white : goldColor),
                                  dayPeriodColor: WidgetStateColor.resolveWith((states) => 
                                    states.contains(WidgetState.selected) ? accentColor : Colors.transparent),
                                  dialHandColor: accentColor,
                                  dialBackgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
                                  dialTextColor: WidgetStateColor.resolveWith((states) => 
                                    states.contains(WidgetState.selected) ? Colors.white : goldColor),
                                  entryModeIconColor: goldColor,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                                  helpTextStyle: AppTheme.getStyle(fontSize: 14, color: goldColor, fontWeight: FontWeight.bold),
                                ),
                                colorScheme: ColorScheme.fromSeed(
                                  seedColor: accentColor,
                                  primary: accentColor,
                                  onPrimary: Colors.white,
                                  surface: isDark ? const Color(0xFF101F42) : Colors.white,
                                  onSurface: goldColor,
                                  brightness: isDark ? Brightness.dark : Brightness.light,
                                ),
                              ),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: MediaQuery(
                                  data: MediaQuery.of(context).copyWith(
                                    textScaler: const TextScaler.linear(0.9),
                                  ),
                                  child: child!,
                                ),
                              ),
                            );
                          },
                        );
                        if (picked != null) {
                          final now = AppDate.getISTNow();
                          final pickedDT = AppDate.getISTTodayWithTime(picked.hour, picked.minute);
                          
                          if (pickedDT.isBefore(now.subtract(const Duration(minutes: 1)))) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(isTamil 
                                  ? "கடந்த கால நேரத்தைத் தேர்ந்தெடுக்க முடியாது" 
                                  : "Cannot select past time")),
                              );
                            }
                            return;
                          }

                          setModalState(() {
                            start = picked;
                            // Auto increment end time by 1 hour when start is changed
                            end = TimeOfDay(
                              hour: (picked.hour + 1) % 24,
                              minute: picked.minute,
                            );
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(isTamil ? "தொடக்க நேரம்" : "Start Time", style: AppTheme.getStyle(fontSize: 12, color: Colors.grey)),
                            Text(start.format(context), style: AppTheme.getStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: end,
                          builder: (context, child) {
                            bool isDark = Theme.of(context).brightness == Brightness.dark;
                            Color accentColor = isDark ? AppTheme.secondaryColor : AppTheme.primaryColor;
                            Color goldColor = AppTheme.secondaryColor;

                            return Theme(
                              data: Theme.of(context).copyWith(
                                timePickerTheme: TimePickerThemeData(
                                  backgroundColor: isDark ? const Color(0xFF101F42).withOpacity(0.9) : Colors.white.withOpacity(0.9),
                                  hourMinuteTextColor: WidgetStateColor.resolveWith((states) => 
                                    states.contains(WidgetState.selected) ? Colors.white : goldColor),
                                  hourMinuteColor: WidgetStateColor.resolveWith((states) => 
                                    states.contains(WidgetState.selected) ? accentColor : (isDark ? Colors.white10 : Colors.grey.shade200)),
                                  dayPeriodTextColor: WidgetStateColor.resolveWith((states) => 
                                    states.contains(WidgetState.selected) ? Colors.white : goldColor),
                                  dayPeriodColor: WidgetStateColor.resolveWith((states) => 
                                    states.contains(WidgetState.selected) ? accentColor : Colors.transparent),
                                  dialHandColor: accentColor,
                                  dialBackgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
                                  dialTextColor: WidgetStateColor.resolveWith((states) => 
                                    states.contains(WidgetState.selected) ? Colors.white : goldColor),
                                  entryModeIconColor: goldColor,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                                  helpTextStyle: AppTheme.getStyle(fontSize: 14, color: goldColor, fontWeight: FontWeight.bold),
                                ),
                                colorScheme: ColorScheme.fromSeed(
                                  seedColor: accentColor,
                                  primary: accentColor,
                                  onPrimary: Colors.white,
                                  surface: isDark ? const Color(0xFF101F42) : Colors.white,
                                  onSurface: goldColor,
                                  brightness: isDark ? Brightness.dark : Brightness.light,
                                ),
                              ),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: MediaQuery(
                                  data: MediaQuery.of(context).copyWith(
                                    textScaler: const TextScaler.linear(0.9),
                                  ),
                                  child: child!,
                                ),
                              ),
                            );
                          },
                        );
                        if (picked != null) {
                          final baseDate = _roomStartTime ?? AppDate.getISTNow();
                          final startDT = AppDate.getISTDateTime(baseDate.year, baseDate.month, baseDate.day, start.hour, start.minute);
                          final pickedDT = AppDate.getISTDateTime(baseDate.year, baseDate.month, baseDate.day, picked.hour, picked.minute);

                          if (pickedDT.isBefore(startDT)) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(isTamil 
                                  ? "முடிவு நேரம் தொடக்க நேரத்திற்குப் பிறகு இருக்க வேண்டும்" 
                                  : "End time must be after start time")),
                              );
                            }
                            return;
                          }

                          if (pickedDT.difference(startDT).inMinutes < 60) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(isTamil 
                                  ? "முடிவு நேரம் தொடக்க நேரத்திலிருந்து குறைந்தது 1 மணிநேரம் தள்ளி இருக்க வேண்டும்" 
                                  : "End time must be at least 1 hour after start time")),
                              );
                            }
                            return;
                          }

                          setModalState(() => end = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(isTamil ? "முடிவு நேரம்" : "End Time", style: AppTheme.getStyle(fontSize: 12, color: Colors.grey)),
                            Text(end.format(context), style: AppTheme.getStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final baseDate = _roomStartTime ?? AppDate.getISTNow();
                    final startDT = AppDate.getISTDateTime(baseDate.year, baseDate.month, baseDate.day, start.hour, start.minute);
                    final endDT = AppDate.getISTDateTime(baseDate.year, baseDate.month, baseDate.day, end.hour, end.minute);

                    // Validation: Start time must be in future (at least 2 mins from now)
                    final nowAtEdit = AppDate.getISTNow();
                    if (startDT.isBefore(nowAtEdit.add(const Duration(minutes: 2)))) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(isTamil 
                          ? "தொடக்க நேரம் குறைந்தது 2 நிமிடங்கள் எதிர்காலத்தில் இருக்க வேண்டும்" 
                          : "Start time must be at least 2 minutes in the future")),
                      );
                      return;
                    }

                    if (endDT.isBefore(startDT)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(isTamil 
                          ? "முடிவு நேரம் தொடக்க நேரத்திற்குப் பிறகு இருக்க வேண்டும்" 
                          : "End time must be after start time")),
                      );
                      return;
                    }

                    final diffInMinutes = endDT.difference(startDT).inMinutes;

                    if (diffInMinutes < 60) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(isTamil ? "குறைந்தது 1 மணிநேர இடைவெளி தேவை" : "Minimum 1 hour duration required")),
                      );
                      return;
                    }

                    if (diffInMinutes > 1440) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(isTamil ? "அதிகபட்சம் 24 மணிநேரம் மட்டுமே" : "Maximum duration is 24 hours")),
                      );
                      return;
                    }

                    await _roomService.updateRoomTimeRange(widget.roomCode, startDT, endDT);
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(isTamil ? "நேரம் மாற்றப்பட்டது" : "Time range updated successfully"), backgroundColor: Colors.green),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(isTamil ? "சேமி" : "Save Changes", style: AppTheme.getStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
              const AppIcon(AppIcons.idea, color: AppTheme.secondaryColor, size: 18),
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

  Future<bool> _showExitConfirmation() async {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF101F42) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          AppLanguage.languageNotifier.value == 'ta' ? 'வெளியேறவா?' : 'Exit Waiting Room?',
          style: AppTheme.getStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.textMainColor),
        ),
        content: Text(
          AppLanguage.languageNotifier.value == 'ta' 
            ? 'இந்த ரூமில் இருந்து வெளியேற விரும்புகிறீர்களா?' 
            : 'Are you sure you want to leave the waiting room?',
          style: AppTheme.getStyle(
              fontSize: 15,
              color: isDark ? Colors.white70 : AppTheme.textSecondaryColor
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLanguage.getString('no'), style: AppTheme.getStyle(fontSize: 14, color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              AppLanguage.languageNotifier.value == 'ta' ? 'வெளியேறு' : 'Exit',
              style: AppTheme.getStyle(fontSize: 14, color: Colors.white),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _handleBack() async {
    if (_isExiting) return;
    final confirmed = await _showExitConfirmation();
    if (confirmed && mounted) {
      setState(() {
        _isExiting = true;
      });
      Navigator.of(context).pop();
    }
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
          _roomStartTime = (roomData['startTime'] as Timestamp?)?.toDate();
          _roomEndTime = (roomData['endTime'] as Timestamp?)?.toDate();
          
          if (roomData['status'] == 'active' || roomData['status'] == 'finished') {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid == null) return;

              // Check if user has already finished
              final playerSnap = await FirebaseFirestore.instance
                  .collection('rooms')
                  .doc('daily_${AppDate.getTodayString()}')
                  .collection('matches')
                  .doc(widget.roomCode)
                  .collection('players')
                  .doc(uid)
                  .get();
              
              if (!mounted) return;

              if (playerSnap.exists && (playerSnap.data()?['hasFinished'] == true)) {
                // Already finished, go to leaderboard
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RoomLeaderboardScreen(roomCode: widget.roomCode),
                  ),
                );
              } else if (roomData!['status'] == 'active') {
                // Not finished and room is active, go to quiz
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MultiplayerQuizScreen(roomCode: widget.roomCode, roomData: roomData!),
                  ),
                );
              } else if (roomData!['status'] == 'finished') {
                // Room finished and user hasn't played, go to leaderboard
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RoomLeaderboardScreen(roomCode: widget.roomCode),
                  ),
                );
              }
            });
          }
        }

        bool isCurrentUserHost = widget.isHost || (roomData?['hostId'] == FirebaseAuth.instance.currentUser?.uid);

        return PopScope(
          canPop: _isExiting,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            _handleBack();
          },
          child: Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
              leading: IconButton(
                icon: AppIcon(AppIcons.back, color: isDark ? Colors.white : AppTheme.textMainColor),
                onPressed: _handleBack,
              ),
              title: Text(AppLanguage.getString('group_test_lobby'), style: AppTheme.getStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(
                color: isDark ? Colors.white : Colors.black,
                size: AppTheme.getScaledIconSize(24),
              ),
              actions: [
                if (roomExists)
                  IconButton(
                    icon: const AppIcon(AppIcons.share),
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
                Center(
                  child: Column(
                    children: [
                      const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppTheme.secondaryColor)),
                      const SizedBox(height: 20),
                      Text(
                        widget.isHost 
                          ? (AppLanguage.languageNotifier.value == 'ta' ? "குழு உருவாக்கப்படுகிறது..." : "Creating your room...")
                          : AppLanguage.getString('joining_room_msg'), 
                        style: AppTheme.getStyle(fontSize: 14, color: Colors.grey)
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Screenshot(
                  controller: _screenshotController,
                  child: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          child: Text(
                            AppLanguage.getString('welcome_group_quiz'),
                            style: AppTheme.getStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                              Flexible(
                                child: Text(
                                  AppLanguage.getString(_subject),
                                  style: AppTheme.getStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white60 : Colors.black87,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Text(
                                AppLanguage.getString('lobby_max_players').replaceAll('{max}', '${roomData!['maxPlayers']}'),
                                style: AppTheme.getStyle(fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white60 : Colors.black87),
                              ),
                            ],
                          ),
                        ),
                        if (_roomStartTime != null && _roomEndTime != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AppIcon(Icons.access_time_rounded, size: 14, color: isDark ? Colors.white60 : Colors.black45),
                                const SizedBox(width: 4),
                                Text(
                                  "${DateFormat('hh:mm a').format(_roomStartTime!)} - ${DateFormat('hh:mm a').format(_roomEndTime!)}",
                                  style: AppTheme.getStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black45),
                                ),
                                if (isCurrentUserHost)
                                  IconButton(
                                    icon: const AppIcon(AppIcons.edit, size: 14),
                                    onPressed: _editRoomTime,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                          decoration: BoxDecoration(
                              color: isDark ? Colors.grey.shade900 : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
                          ),
                          child: Text(
                            widget.roomCode,
                            style: AppTheme.getStyle(fontSize: 30, fontWeight: FontWeight.bold, color: AppTheme.secondaryColor).copyWith(letterSpacing: 8),
                          ),
                        ),

                      ],
                    ),
                  ),
                ),
                // const LinearProgressIndicator(minHeight: 2, backgroundColor: Colors.transparent, valueColor: AlwaysStoppedAnimation(AppTheme.secondaryColor)),
                // const SizedBox(height: 10),
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
                        // const SizedBox(height: 16),
                        // Center(
                        //   child: ElevatedButton.icon(
                        //     onPressed: _shareRoomCode,
                        //     icon: const Icon(Icons.share_rounded, size: 18),
                        //     label: Text(
                        //       AppLanguage.languageNotifier.value == 'ta' ? "நண்பர்களை அழைக்கவும்" : "Invite Friends",
                        //       style: AppTheme.getStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        //     ),
                        //     style: ElevatedButton.styleFrom(
                        //       backgroundColor: Colors.blue.shade700,
                        //       foregroundColor: Colors.white,
                        //       padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        //     ),
                        //   ),
                        // ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                              stream: _roomService.playersStream(widget.roomCode),
                              builder: (context, playersSnapshot) {
                                var players = playersSnapshot.data?.docs ?? [];
                                if (players.isEmpty) {
                                  return Center(child: Text(AppLanguage.getString('no_history_title'), style: AppTheme.getStyle(fontSize: 14, color: Colors.grey)));
                                }
                                return ListView.separated(
                                  padding: const EdgeInsets.only(top: 6, bottom: 6),
                                  itemCount: players.length,
                                  separatorBuilder: (context, index) => Divider(height: 1, color: Colors.transparent),
                                  itemBuilder: (context, index) {
                                    var pData = players[index].data() as Map<String, dynamic>;
                                    bool isRoomHost = players[index].id == roomData?['hostId'];
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8.0),
                                      child: Container(
                                          decoration: BoxDecoration(
                                            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                                          ),
                                          child: ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        leading: CircleAvatar(
                                          radius: 18,
                                          backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                                          child: const AppIcon(AppIcons.person, color: Colors.white70, size: 20),
                                        ),
                                        title: Text(
                                          pData['name'] ?? 'Player',
                                          style: AppTheme.getStyle(fontSize: 15, fontWeight: FontWeight.bold)
                                        ),
                                        trailing: isRoomHost
                                            ? Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.amber.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const AppIcon(AppIcons.star, color: Colors.amber, size: 14),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      AppLanguage.languageNotifier.value == 'ta' ? "நிர்வாகி" : "Host",
                                                      style: AppTheme.getStyle(fontSize: 11, color: Colors.amber.shade800, fontWeight: FontWeight.bold),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            : null,
                                      )),
                                    );
                                  },
                                );
                              },
                            ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          bottomNavigationBar: roomExists 
            ? Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade900 : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: SafeArea(
                  child: isCurrentUserHost
                      ? StreamBuilder<QuerySnapshot>(
                          stream: _roomService.playersStream(widget.roomCode),
                          builder: (context, ps) {
                            final count = ps.data?.docs.length ?? 0;
                            final canStart = count >= 2;
                            return Column(
                              mainAxisSize: MainAxisSize.min,
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
                                    onPressed: canStart ? () async {
                                      final confirmed = await _showStartConfirmation(count);
                                      if (confirmed) {
                                        _startExam();
                                      }
                                    } : null,
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
                      : Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            AppLanguage.getString('waiting_for_host'),
                            textAlign: TextAlign.center,
                            style: AppTheme.getStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ).copyWith(fontStyle: FontStyle.italic),
                          ),
                        ),
                ),
              )
            : null,
        )
        );
      },
    );
  }
}
