import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tnpsc_group_book/screens/room_leaderboard_screen.dart';
import '../services/room_service.dart';
import '../utils/app_language.dart';
import '../utils/app_theme.dart';
import '../models/subject.dart';
import 'waiting_room_screen.dart';
import '../services/hive_service.dart';
import '../services/reward_service.dart';
import 'package:hive/hive.dart';
import '../services/version_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/question.dart';

class RoomSetupScreen extends StatefulWidget {
  const RoomSetupScreen({super.key});

  @override
  State<RoomSetupScreen> createState() => _RoomSetupScreenState();
}

class _RoomSetupScreenState extends State<RoomSetupScreen> {
  final RoomService _roomService = RoomService();
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  bool _showOnlySpinner = false;
  String _selectedSubject = 'general_tamil';
  int _selectedMaxPlayers = RoomService.baseMaxPlayers;
  bool _isFirstAttempt = true;
  String? _existingRoomCode;

  // Teaser for loading screen
  List<Question> _teaserQuestions = [];
  PageController? _teaserController;
  Timer? _teaserTimer;
  int _currentTeaserIndex = 0;

  bool get _isAdmin {
    final user = FirebaseAuth.instance.currentUser;
    return user?.phoneNumber == '+918754236411' || user?.email == 'adminjeba@gmail.com' || user?.email == 'kjebaselvan987@gmail.com';
  }

  @override
  void initState() {
    super.initState();
    _loadTeaserQuestions();
    _existingRoomCode = HiveService.getHostRoomCode();
    _refreshExistingRoom();
  }

  @override
  void dispose() {
    _teaserTimer?.cancel();
    _teaserController?.dispose();
    super.dispose();
  }

  Future<void> _refreshExistingRoom() async {
    String? serverCode = await _roomService.getActiveHostRoom();
    if (mounted) {
      setState(() {
        _existingRoomCode = serverCode;
      });
    }
  }

  // Compute required points based on daily attempts and selected max players
  int _requiredRoomPoints() {
    if (_isAdmin) return 0; // Admins create rooms for free

    String today = DateTime.now().toString().split(' ')[0];
    var box = Hive.box(HiveService.userBoxName);
    int attempts = box.get('room_create_attempts_$today', defaultValue: 0) as int;
    
    // First daily attempt is free (no base cost)
    int baseCost = attempts > 0 ? RoomService.roomCreateCostPoints : 0;
    
    // Extra cost logic:
    // 10-30 players: Flat 100 points
    // 31-100 players: +100 points for every additional 10 players
    int extraCost = 0;
    if (_selectedMaxPlayers > RoomService.baseMaxPlayers) {
      extraCost = 100; // Flat 100 for 11-30 players
      if (_selectedMaxPlayers > 30) {
        int additionalPlayers = _selectedMaxPlayers - 30;
        extraCost += ((additionalPlayers + 9) ~/ 10) * 100;
      }
    }

    return baseCost + extraCost;
  }

  bool _hasEnoughPointsForRoom() =>
    (Hive.box(HiveService.userBoxName).get('totalScore', defaultValue: 0) as int) >= _requiredRoomPoints();

  void _showNeedPointsMessage() {
    _showError(AppLanguage.getString('insufficient_points_create').replaceAll('{points}', '${_requiredRoomPoints()}'));
  }

  void _startSpinnerTimer() {
    setState(() => _showOnlySpinner = true);
    Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _showOnlySpinner = false);
      }
    });
  }

  Future<void> _createRoom() async {
    // 1. Check App Version
    if (await VersionService.isUpdateRequired()) {
      if (mounted) VersionService.showUpdateDialogIfNeeded(context);
      return;
    }

    // 2. Check Daily Quiz Status
    if (!HiveService.isDailyQuizDone()) {
      _showError(AppLanguage.getString('daily_quiz_first_error'));
      return;
    }

    // 3. Check for Existing Room (Server sync)
    setState(() => _isLoading = true);
    _startSpinnerTimer();
    final activeCode = await _roomService.getActiveHostRoom() ?? HiveService.getHostRoomCode();
    setState(() => _isLoading = false);

    if (activeCode != null) {
      setState(() { _existingRoomCode = activeCode; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLanguage.getString('room_exists_error')), backgroundColor: Colors.orange),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => WaitingRoomScreen(roomCode: activeCode, isHost: true)),
      );
      return;
    }

    // 4. Check Points
    if (!_hasEnoughPointsForRoom()) {
      _showError(AppLanguage.getString('insufficient_points_create').replaceAll('{points}', '${_requiredRoomPoints()}'));
      return;
    }

    // 5. If all checks pass, proceed with Rewarded Ad
    setState(() => _isLoading = true);
    _startSpinnerTimer();
    
    RewardService.showRewardAdIfAllowed(
      useLimit: false,
      onRewardEarned: () async {
        // Ad successful - Unlock the attempt
        await HiveService.incrementRoomAdWatchCount();
        
        // Start creating the room on Firestore
        String? code = await _roomService.createRoom(_selectedSubject, _selectedMaxPlayers);
      
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (code == 'limit_reached') {
        _showRoomLimitDialog(context);
      } else if (code == 'no_questions') {
        _showError("No questions could be loaded or generated. Please try again.");
      } else if (code != null) {
        // Handle point deduction and attempt increment
        var box = Hive.box(HiveService.userBoxName);
        String today = DateTime.now().toString().split(' ')[0];
        int attempts = box.get('room_create_attempts_$today', defaultValue: 0) as int;
        int newScore = (box.get('totalScore', defaultValue: 0) as int);
        
        if (!_isAdmin) {
          if (attempts == 0) {
            if (_selectedMaxPlayers > RoomService.baseMaxPlayers) {
              newScore -= _requiredRoomPoints();
            } else {
              newScore += 10; // Bonus for first free room
            }
          } else {
            newScore -= _requiredRoomPoints();
          }
          box.put('totalScore', newScore);
        }
        box.put('room_create_attempts_$today', attempts + 1);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLanguage.getString('room_created_success').replaceAll('{points}', '${_requiredRoomPoints()}')),
            backgroundColor: Colors.green,
          ),
        );

        setState(() { _isFirstAttempt = false; });
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => WaitingRoomScreen(roomCode: code, isHost: true)),
        );
      } else {
        _showError("Failed to create room.");
      }
    });
  }

  Future<void> _joinRoom() async {
    if (await VersionService.isUpdateRequired()) {
      if (mounted) VersionService.showUpdateDialogIfNeeded(context);
      return;
    }

    String code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      _showError("Invalid room code");
      return;
    }

    setState(() => _isLoading = true);
    _startSpinnerTimer();
    String? result = await _roomService.joinRoom(code);
    setState(() => _isLoading = false);

    if (result == 'success') {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => WaitingRoomScreen(roomCode: code, isHost: false)),
      );
    } else if (result == 'limit_reached') {
      if (mounted) _showRoomLimitDialog(context);
    } else if (result == 'already_started') {
      _showError(AppLanguage.getString('room_already_started'));
    } else if (result == 'room_full') {
      _showError(AppLanguage.getString('room_full'));
    } else {
      _showError(AppLanguage.getString('room_not_found'));
    }
  }

  // Returns the option string localized based on current app language.
  String _localizedOption(String raw) {
    if (!raw.contains('/')) return raw.trim();
    final parts = raw.split('/');
    final en = parts[0].trim();
    final ta = parts.length > 1 ? parts[1].trim() : en;
    final isTamil = AppLanguage.languageNotifier.value == 'ta';
    return isTamil ? ta : en;
  }


  void _loadTeaserQuestions() {
    // Fetch some historical questions to show while loading
    final cached = HiveService.getQuestions("Daily Quiz");
    if (cached.isNotEmpty) {
      setState(() {
        _teaserQuestions = List<Question>.from(cached)..shuffle();
        _teaserQuestions = _teaserQuestions.take(10).toList();
        _teaserController = PageController();
      });
      _startTeaserTimer();
    }
  }

  void _startTeaserTimer() {
    _teaserTimer?.cancel();
    _teaserTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_teaserQuestions.isNotEmpty && _teaserController != null && _teaserController!.hasClients) {
        int next = (_currentTeaserIndex + 1) % _teaserQuestions.length;
        _teaserController!.animateToPage(
          next,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
        setState(() {
          _currentTeaserIndex = next;
        });
      }
    });
  }

  void _showRoomLimitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final int adWatches = HiveService.getRoomAdWatchCount();
            final ta = AppLanguage.languageNotifier.value == 'ta';

            return AlertDialog(
              backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF101F42) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.ondemand_video_rounded, color: Colors.orange, size: 40),
                  ),
                  const SizedBox(height: 16),
                  Text(AppLanguage.getString('room_limit_title'), style: AppTheme.getStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppLanguage.getString('room_limit_desc'),
                    textAlign: TextAlign.center,
                    style: AppTheme.getStyle(fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      AppLanguage.getString('ads_watched').replaceAll('{watched}', '$adWatches'),
                      style: AppTheme.getStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(AppLanguage.getString('close_btn'), style: TextStyle(color: Colors.grey[600])),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    if (!_hasEnoughPointsForRoom()) {
                      _showNeedPointsMessage();
                      return;
                    }
                    RewardService.showRewardAdIfAllowed(
                      useLimit: false,
                      onRewardEarned: () async {
                        final nextWatches =
                            await HiveService.incrementRoomAdWatchCount();
                        if (context.mounted) {
                          if (nextWatches == 0) {
                            // Unlocked!
                            Navigator.pop(context);
                            await _createRoom();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ta
                                      ? 'வாழ்த்துகள்! மற்றொரு குரூப் தேர்வு அன்லாக் செய்யப்பட்டது.'
                                      : 'Congratulations! Another Room Match attempt has been unlocked.',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            // Update dialog UI
                            setStateDialog(() {});
                          }
                        }
                      }
                    );
                  },
                  icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 18),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  label: Text(
                    AppLanguage.getString('watch_ad_btn'),
                    style: AppTheme.getStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showRoomInfoDialog() {
    showModalBottomSheet(constraints: BoxConstraints(minHeight: 300,maxHeight: 500),
      useSafeArea: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: AppTheme.accentColor.withOpacity(0.2)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: Row(
                  children: [
                    // const Icon(Icons.info_outline_rounded, color: AppTheme.primaryColor),
                    // const SizedBox(width: 12),
                    Text(
                      AppLanguage.getString('room_info_title'),
                      style: AppTheme.getStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoSection(context, AppLanguage.getString('room_info_create_title'), AppLanguage.getString('room_info_create_desc')),
                      _buildInfoSection(context, AppLanguage.getString('room_info_join_title'), AppLanguage.getString('room_info_join_desc')),
                      _buildInfoSection(context, AppLanguage.getString('room_info_play_title'), AppLanguage.getString('room_info_play_desc')),
                      _buildInfoSection(context, AppLanguage.getString('room_info_earn_title'), AppLanguage.getString('room_info_earn_desc')),
                      _buildInfoSection(context, AppLanguage.getString('room_info_points_spend_title'), AppLanguage.getString('room_info_points_spend_desc')),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    AppLanguage.getString('ok'),
                    style: AppTheme.getStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context, String title, String desc) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTheme.getStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? AppTheme.secondaryColor : AppTheme.primaryColor)),
          const SizedBox(height: 4),
          Text(desc, style: AppTheme.getStyle(fontSize: 13, height: 1.4, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildRoomHistorySection(BuildContext context, bool isDark) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _roomService.getUserRoomHistory(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final history = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4.0, bottom: 12.0),
              child: Text(
                AppLanguage.getString('room_history'),
                style: AppTheme.getStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ...history.map((room) {
              final code = room['roomCode'] as String;
              final date = room['date'] as String;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade900 : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryColorLight.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.history_rounded, color: AppTheme.secondaryColorLight, size: 20),
                  ),
                  title: Row(
                    children: [
                      Text(
                        AppLanguage.getString('last_room_history') + ": ",
                        style: AppTheme.getStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.secondaryColor).copyWith(letterSpacing: 1.5),
                      ),
                      Text(
                        code,
                        style: AppTheme.getStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.secondaryColor).copyWith(letterSpacing: 1.5),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    date,
                    style: AppTheme.getStyle(fontSize: 12, color: Colors.grey),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RoomLeaderboardScreen(roomCode: code, date: date),
                      ),
                    );
                  },
                ),
              );
            }).toList(),
            const SizedBox(height: 40),
          ],
        );
      },
    );
  }

  void _showError(String message) {
    debugPrint(message);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  Future<bool> _showExitConfirmation() async {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF101F42) : Colors.white70,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          AppLanguage.languageNotifier.value == 'ta' ? 'வெளியேறவா?' : 'Exit Room Setup?',
          style: AppTheme.getStyle(fontSize: 18,fontWeight: FontWeight.bold,color: isDark ? Colors.white70 : AppTheme.textMainColor),
        ),
        content: Text(
          AppLanguage.languageNotifier.value == 'ta' 
            ? 'குரூப் தேர்வு அமைப்பிலிருந்து வெளியேற விரும்புகிறீர்களா?' 
            : 'Are you sure you want to exit the room setup?',
          style: AppTheme.getStyle(
              fontSize: 15,
              color: isDark ? Colors.white : AppTheme.textMainColor
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLanguage.getString('close_btn'), style: TextStyle(fontSize: 14,color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              AppLanguage.languageNotifier.value == 'ta' ? 'வெளியேறு' : 'Exit',
              style: TextStyle(fontSize: 14, color: isDark ? Colors.white : AppTheme.textMainColor),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Widget _buildPointCalculator(bool isDark) {
    int currentPoints = Hive.box(HiveService.userBoxName).get('totalScore', defaultValue: 0) as int;
    int totalCost = _requiredRoomPoints();
    int balance = currentPoints - totalCost;
    bool hasEnough = currentPoints >= totalCost;
    
    String today = DateTime.now().toString().split(' ')[0];
    int attempts = Hive.box(HiveService.userBoxName).get('room_create_attempts_$today', defaultValue: 0) as int;
    
    // Logic matching _requiredRoomPoints()
    int baseCost = (_isAdmin || attempts == 0) ? 0 : RoomService.roomCreateCostPoints;
    int extraCost = totalCost - baseCost;

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(top: 10, bottom: 20),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
        ),
        child: Column(
          children: [
            _buildCalcRow(AppLanguage.getString('current_points_label'), currentPoints.toDouble(), isDark),
            const Divider(height: 20),
            if (baseCost == 0)
              _buildCalcRow(AppLanguage.getString('base_cost_label'), 0, isDark, overrideValue: AppLanguage.getString('free'))
            else
              _buildCalcRow(AppLanguage.getString('base_cost_label'), baseCost.toDouble(), isDark, isDeduction: true, prefix: "-"),
            
            if (extraCost > 0)
              _buildCalcRow(AppLanguage.getString('extra_cost_label'), extraCost.toDouble(), isDark, isDeduction: true, prefix: "-"),
            
            const Divider(height: 20),
            
            if (totalCost == 0)
               _buildCalcRow(AppLanguage.getString('total_deduction_label'), 0, isDark, isBold: true, overrideValue: AppLanguage.getString('free'))
            else
              _buildCalcRow(
                AppLanguage.getString('total_deduction_label'), 
                totalCost.toDouble(), 
                isDark, 
                isBold: true,
                isDeduction: true,
                prefix: "-",
              ),
              
            const SizedBox(height: 8),
            _buildCalcRow(
              AppLanguage.getString('remaining_points_label'), 
              balance.toDouble(), 
              isDark, 
              isBold: true, 
              valueColor: hasEnough ? Colors.green : Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalcRow(String label, double value, bool isDark, {bool isBold = false, bool isDeduction = false, Color? valueColor, String? overrideValue, String prefix = ""}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTheme.getStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.grey.shade700,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        if (overrideValue != null)
           Expanded(
             child: Text(
              overrideValue,
              style: AppTheme.getStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: valueColor ?? (isDark ? Colors.white : Colors.black87),
              ),
                       ),
           )
        else
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: value),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            builder: (context, animValue, child) {
              return Text(
                "$prefix${animValue.toInt()}",
                style: AppTheme.getStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: valueColor ?? (isDeduction ? Colors.redAccent : (isDark ? Colors.white : Colors.black87)),
                ),
              );
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    String lang = AppLanguage.languageNotifier.value;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _showExitConfirmation();
        if (shouldPop && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_rounded, color: isDark ? Colors.white : AppTheme.textMainColor),
            onPressed: () async {
              if (await _showExitConfirmation()) {
                if (mounted) Navigator.pop(context);
              }
            },
          ),
          title: Text(AppLanguage.getString('room_screen_title'), style: AppTheme.getStyle(
              fontSize: 15, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        ),
      body: _isLoading
          ? Expanded(
        child: _showOnlySpinner || _teaserQuestions.isEmpty || _teaserController == null
            ? const Center(child: CircularProgressIndicator())
            : PageView.builder(
          controller: _teaserController,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _teaserQuestions.length,
          itemBuilder: (context, index) {
            final q = _teaserQuestions[index];
            return SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                    height: 150,
                    child: Column(
                      // mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 24),
                        Text(
                          AppLanguage.getString('loading_quiz'),
                          style: AppTheme.getStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.secondaryColor : AppTheme.textSecondaryColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          lang == 'ta' ? 'காத்திருக்கும் நேரத்தில் சில வினாக்கள்...' : 'Learn while we load...',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                  ),
                  const SizedBox(height: 40),
                  Text(
                    q.question.replaceAll('\\n', '\n'),
                    style: AppTheme.getStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ...List.generate(q.options.length, (optIndex) {
                    bool isCorrect = optIndex == q.correctOptionIndex;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isCorrect ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isCorrect ? Colors.green : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isCorrect ? Icons.check_circle : Icons.circle_outlined,
                            color: isCorrect ? Colors.green : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _localizedOption(q.options[optIndex]),
                              style: TextStyle(
                                color: isCorrect ? Colors.green.shade700 : null,
                                fontWeight: isCorrect ? FontWeight.bold : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        ),)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_existingRoomCode != null) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      margin: const EdgeInsets.only(bottom: 25),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.secondaryColor.withOpacity(0.4), width: 1.5),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))
                        ]
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.star_rounded, color: AppTheme.secondaryColor, size: 28),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  AppLanguage.getString('active_room_available'),
                                  style: AppTheme.getStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            AppLanguage.getString('active_room_desc'),
                            style: AppTheme.getStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black54),
                          ),
                          const SizedBox(height: 14),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.black38 : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300, width: 1),
                              ),
                              child: Text(
                                _existingRoomCode!,
                                style: AppTheme.getStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.secondaryColor,
                                ).copyWith(letterSpacing: 3),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            // width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                if (await VersionService.isUpdateRequired()) {
                                  if (mounted) VersionService.showUpdateDialogIfNeeded(context);
                                  return;
                                }
                                if (mounted) {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => WaitingRoomScreen(roomCode: _existingRoomCode!, isHost: true),
                                    ),
                                  );
                                }
                              },
                              // icon: const Icon(Icons.login_rounded, color: Colors.black87),
                              label: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        AppLanguage.getString('enter_waiting_room'),
                                        textAlign: TextAlign.center,
                                        style: AppTheme.getStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.secondaryColor,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Create Room Section – only show if no active host room
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade900 : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppLanguage.getString('create_room_section'), style: AppTheme.getStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Text(AppLanguage.getString('create_room_desc'), style: AppTheme.getStyle(fontSize: 14, color: Colors.grey)),
                          const SizedBox(height: 20),
                          Text(AppLanguage.getString('select_subject'), style: AppTheme.getStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedSubject,
                                isExpanded: true,
                                style: AppTheme.getStyle(color: isDark ? Colors.white : Colors.black, fontSize: 16, fontWeight: FontWeight.w400),
                                items: [
                                  'general_tamil',
                                  'general_studies',
                                  'aptitude'
                                ].map((key) => DropdownMenuItem(
                                  value: key,
                                  child: Text(AppLanguage.getString(key), style: AppTheme.getStyle(color: isDark ? Colors.white : Colors.black, fontSize: 16, fontWeight: FontWeight.w400)),
                                )).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedSubject = val);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(AppLanguage.getString('max_players_label'), style: AppTheme.getStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                              Text(
                                "$_selectedMaxPlayers users",
                                style: AppTheme.getStyle(fontSize: 14, color: AppTheme.secondaryColor, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Slider(
                            min: RoomService.baseMaxPlayers.toDouble(),
                            max: RoomService.maxRoomPlayers.toDouble(),
                            divisions: 9,
                            value: _selectedMaxPlayers.toDouble(),
                            label: "$_selectedMaxPlayers",
                            onChanged: _isFirstAttempt ? (value) {
                              setState(() {
                                _selectedMaxPlayers = value.round();
                              });
                            } : null,
                          ),
                          Text(
                            _selectedMaxPlayers > RoomService.baseMaxPlayers
                                ? AppLanguage.getString('extra_player_cost').replaceAll('{points}', '${RoomService.extraPlayersCostPoints}').replaceAll('{total}', '${_requiredRoomPoints()}')
                                : AppLanguage.getString('base_room_cost').replaceAll('{points}', '${RoomService.roomCreateCostPoints}'),
                            style: AppTheme.getStyle(fontSize: 12, color: Colors.grey),
                          ),
                          _buildPointCalculator(isDark),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _createRoom,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(AppLanguage.getString('create_room_btn'), style: AppTheme.getStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                          )
                        ],
                      ),
                    ),

                  const SizedBox(height: 30),
                  
                  // Join Room Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade900 : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))
                      ]
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppLanguage.getString('join_room_section'), style: AppTheme.getStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Text(AppLanguage.getString('join_room_desc'), style: AppTheme.getStyle(fontSize: 14, color: Colors.grey)),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _codeController,
                          maxLength: 6,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            hintText: AppLanguage.getString('room_code_hint'),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            counterText: "",
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _joinRoom,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(AppLanguage.getString('join_room_btn'), style: AppTheme.getStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        )
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  _buildRoomHistorySection(context, isDark),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showRoomInfoDialog,
        backgroundColor: isDark ? AppTheme.secondaryColor : AppTheme.primaryColor,
        child: const Icon(Icons.help_outline_rounded, color: Colors.white),
      ),
    ));
  }
}
