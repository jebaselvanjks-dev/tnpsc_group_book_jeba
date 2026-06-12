import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/question.dart';
import '../services/hive_service.dart';
import '../services/room_service.dart';
import '../utils/app_theme.dart';
import '../utils/app_language.dart';
import '../services/reward_service.dart';
import 'room_leaderboard_screen.dart';
class MultiplayerQuizScreen extends StatefulWidget {
  final String roomCode;
  final Map<String, dynamic> roomData;

  const MultiplayerQuizScreen({super.key, required this.roomCode, required this.roomData});

  @override
  State<MultiplayerQuizScreen> createState() => _MultiplayerQuizScreenState();
}

class _MultiplayerQuizScreenState extends State<MultiplayerQuizScreen> {
  final RoomService _roomService = RoomService();
  int _currentQuestionIndex = 0;
  List<int?> _selectedAnswers = [];
  List<Question> _questions = [];
  bool _submitted = false;
  
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  int _remainingSeconds = 600; // 10 mins total for 20 questions

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  void _loadQuestions() {
    // Log the play attempt immediately at the start of the match
    _roomService.logAttempt();
    // Clear host room cache since it's now played
    HiveService.clearHostRoom();

    var rawQuestions = widget.roomData['questions'] as List<dynamic>;
    _questions = rawQuestions.map((q) => Question(
      question: q['question'],
      options: List<String>.from(q['options']),
      correctOptionIndex: q['correctOptionIndex'],
      explanation: q['explanation'],
    )).toList();
    
    _selectedAnswers = List.filled(_questions.length, null);
    _stopwatch.start();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _timer?.cancel();
        _submitQuiz();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _handleOptionTap(int index) {
    setState(() {
      _selectedAnswers[_currentQuestionIndex] = index;
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() => _currentQuestionIndex++);
    } else {
      _submitQuiz();
    }
  }

  int _calculateScore() {
    int score = 0;
    for (int i = 0; i < _questions.length; i++) {
      if (_selectedAnswers[i] == _questions[i].correctOptionIndex) {
        score++;
      }
    }
    return score;
  }

  Future<void> _abandonQuiz() async {
    if (_submitted || _questions.isEmpty) return;
    _submitted = true;
    _timer?.cancel();
    _stopwatch.stop();
    await _roomService.abandonRoom(
      widget.roomCode,
      _calculateScore(),
      _stopwatch.elapsed.inSeconds,
    );
  }

  Future<void> _submitQuiz() async {
    if (_submitted) return;
    _submitted = true;
    _timer?.cancel();
    _stopwatch.stop();

    int score = _calculateScore();

    int timeTakenSeconds = _stopwatch.elapsed.inSeconds;
    
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator())
    );

    await _roomService.submitScore(widget.roomCode, score, timeTakenSeconds);

    if (!mounted) return;
    Navigator.pop(context); // pop loading

    // Show reward ad after completion (0 points as requested)
    RewardService.showRewardAdIfAllowed(
      fixedRewardAmount: 0,
      useLimit: false,
      onRewardEarned: () {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => RoomLeaderboardScreen(roomCode: widget.roomCode)),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    final question = _questions[_currentQuestionIndex];
    double progress = (_currentQuestionIndex + 1) / _questions.length;

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _abandonQuiz();
        }
      },
      child: Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: isDark ? Colors.white : AppTheme.textMainColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(AppLanguage.getString('battle_title') + ': ${widget.roomCode}', style: const TextStyle(fontSize: 16)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Builder(
                builder: (context) {
                  int mins = _remainingSeconds ~/ 60;
                  int secs = _remainingSeconds % 60;
                  return Text(
                    "${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}",
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _remainingSeconds < 60 ? Colors.red : AppTheme.secondaryColor,
                    ),
                  );
                }
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("${AppLanguage.getString('question')} ${_currentQuestionIndex + 1}", style: AppTheme.getStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.secondaryColor)),
                  Text("${_currentQuestionIndex + 1}/${_questions.length}", style: AppTheme.getStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppTheme.secondaryColor.withOpacity(0.1),
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.secondaryColor),
                borderRadius: BorderRadius.circular(10),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question.question.replaceAll('?', '?\n'),
                      style: AppTheme.getStyle(fontSize: 18, fontWeight: FontWeight.bold, height: 1.5),
                    ),
                    const SizedBox(height: 20),
                    ...List.generate(question.options.length, (index) {
                      bool isSelected = index == _selectedAnswers[_currentQuestionIndex];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: InkWell(
                          onTap: () => _handleOptionTap(index),
                          borderRadius: BorderRadius.circular(16),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.secondaryColor.withOpacity(0.1) : (isDark ? Colors.grey.shade900 : Colors.white),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isSelected ? AppTheme.secondaryColor : Colors.grey.withOpacity(0.2), width: 2),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 18, height: 18,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: isSelected ? AppTheme.secondaryColor : Colors.grey, width: 2),
                                    color: isSelected ? AppTheme.secondaryColor : Colors.transparent,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(child: Text(question.options[index], style: AppTheme.getStyle(fontSize: 15, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal))),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), offset: const Offset(0, -4), blurRadius: 10)],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _selectedAnswers[_currentQuestionIndex] != null ? _nextQuestion : null,
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                  child: Text(
                    _currentQuestionIndex < _questions.length - 1 ? "Next" : "Submit",
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
