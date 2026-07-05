import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/question.dart';
import '../services/hive_service.dart';
import '../services/room_service.dart';
import '../utils/app_theme.dart';
import '../utils/app_language.dart';
import '../services/reward_service.dart';
import '../services/tts_service.dart';
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
  bool _isExiting = false;
  
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  int _remainingSeconds = 600; // 10 mins total for 20 questions

  // Helper to format bilingual text (English / Tamil)
  String _formatBilingual(String raw) {
    if (raw.isEmpty) return "";

    // Normalize escaped newlines
    raw = raw.replaceAll('\\n', '\n');
    
    // 1. Check for explicit separators first
    if (raw.contains('\n') || raw.contains(' / ') || raw.contains(' | ')) {
      List<String> parts;
      if (raw.contains('\n')) {
        parts = raw.split('\n');
      } else if (raw.contains(' / ')) {
        parts = raw.split(' / ');
      } else {
        parts = raw.split(' | ');
      }

      final en = parts[0].trim();
      final ta = parts.length > 1 ? parts[1].trim() : en;

      if (en == ta) return en;
      return "$en\n$ta";
    }

    // 2. Smart detection: Split at the first Tamil character if no separator is found
    int tamilIndex = -1;
    for (int i = 0; i < raw.length; i++) {
      int code = raw.codeUnitAt(i);
      if (code >= 0x0B80 && code <= 0x0BFF) {
        tamilIndex = i;
        break;
      }
    }

    if (tamilIndex > 0) {
      String en = raw.substring(0, tamilIndex).trim();
      String ta = raw.substring(tamilIndex).trim();
      if (en.isNotEmpty && ta.isNotEmpty) {
        return "$en\n$ta";
      }
    }

    return raw.trim();
  }

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

    final isCorrect = index == _questions[_currentQuestionIndex].correctOptionIndex;
    if (HiveService.isVibrationEnabled()) {
      if (isCorrect) {
        HapticFeedback.lightImpact();
      } else {
        HapticFeedback.heavyImpact();
      }
    }

    // Stop speaking if option is tapped
    if (TtsService.isSpeaking(_getQuestionTtsText(_questions[_currentQuestionIndex]))) {
      TtsService.stop();
    }
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() => _currentQuestionIndex++);
    } else {
      _submitQuiz();
    }
  }

  String _getQuestionTtsText(Question q) {
    String text = _formatBilingual(q.question);
    for (var i = 0; i < q.options.length; i++) {
      text += ". Option ${i + 1}: " + _formatBilingual(q.options[i]);
    }
    return text;
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

  Future<bool> _showExitConfirmation() async {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF101F42) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          AppLanguage.languageNotifier.value == 'ta' ? 'வெளியேறவா?' : 'Exit Battle?',
          style: AppTheme.getStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.textMainColor),
        ),
        content: Text(
          AppLanguage.languageNotifier.value == 'ta' 
            ? 'இந்தத் தேர்விலிருந்து வெளியேற விரும்புகிறீர்களா? நீங்கள் தோல்வியுற்றதாகக் கருதப்படுவீர்கள்.' 
            : 'Are you sure you want to exit the battle? You will be marked as abandoned.',
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
      await _abandonQuiz();
      if (mounted) Navigator.of(context).pop();
    }
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
      canPop: _isExiting,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: isDark ? Colors.white : AppTheme.textMainColor),
          onPressed: _handleBack,
        ),
        title: Text(AppLanguage.getString('battle_title') + ': ${widget.roomCode}', style: AppTheme.getStyle(fontSize: 16)),
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
                    style: AppTheme.getStyle(
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
                  Row(
                    children: [
                      Text("${AppLanguage.getString('question')} ${_currentQuestionIndex + 1}", style: AppTheme.getStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.secondaryColor)),
                      const SizedBox(width: 8),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          TtsService.isSpeaking(_getQuestionTtsText(_questions[_currentQuestionIndex])) ? Icons.volume_up_rounded : Icons.volume_up_outlined,
                          color: _selectedAnswers[_currentQuestionIndex] != null ? AppTheme.secondaryColor : Colors.grey.withOpacity(0.5),
                          size: 20,
                        ),
                        onPressed: _selectedAnswers[_currentQuestionIndex] != null ? () {
                          final textToSpeak = _getQuestionTtsText(_questions[_currentQuestionIndex]);
                          if (TtsService.isSpeaking(textToSpeak)) {
                            TtsService.stop();
                          } else {
                            TtsService.speak(textToSpeak);
                          }
                          setState(() {});
                        } : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(AppLanguage.languageNotifier.value == 'ta' 
                                ? "பதிலளித்த பிறகுதான் ஆடியோ கேட்க முடியும்" 
                                : "Answer the question first to enable audio"),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
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
                      _formatBilingual(question.question),
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
                                Expanded(child: Text(_formatBilingual(question.options[index]), style: AppTheme.getStyle(fontSize: 15, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal))),
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
                    style: AppTheme.getStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
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
