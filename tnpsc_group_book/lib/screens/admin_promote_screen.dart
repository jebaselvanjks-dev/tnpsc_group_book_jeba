import 'dart:async';
import 'package:flutter/material.dart';
import '../models/question.dart';
import '../models/subject.dart';
import '../services/firestore_service.dart';
import '../utils/app_date.dart';
import '../utils/app_log.dart';
import '../utils/app_theme.dart';
import '../widgets/share_poster.dart';

class AdminPromoteScreen extends StatefulWidget {
  const AdminPromoteScreen({super.key});

  @override
  State<AdminPromoteScreen> createState() => _AdminPromoteScreenState();
}

class _AdminPromoteScreenState extends State<AdminPromoteScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  List<Question> _quizzes = [];
  bool _isLoading = true;
  int _currentIndex = 0;
  int _timerSeconds = 5;
  bool _showAnswer = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadQuizzes();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadQuizzes() async {
    try {
      // Fetch some daily quizzes or fallback to default
      List<Question> pool = await _firestoreService.getDailyRotatingQuiz(isAdmin: true);
      if (pool.length < 3) {
        final daily = await _firestoreService.getDailyQuiz();
        pool.addAll(daily);
      }
      
      if (pool.length < 3) {
        pool.addAll(defaultRoomQuestions);
      }

      // Shuffle and take 3
      pool.shuffle();
      setState(() {
        _quizzes = pool.take(3).toList();
        _isLoading = false;
      });

      if (_quizzes.isNotEmpty) {
        _startSequence();
      }
    } catch (e) {
      AppLog.e("Error loading promote quizzes: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _startSequence() {
    _timerSeconds = 5;
    _showAnswer = false;
    _timer?.cancel();
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds > 0) {
        setState(() => _timerSeconds--);
      } else {
        _revealAnswer();
      }
    });
  }

  void _revealAnswer() {
    _timer?.cancel();
    setState(() => _showAnswer = true);

    // Wait 2 seconds then move to next or stay at end
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        if (_currentIndex < _quizzes.length - 1) {
          setState(() {
            _currentIndex++;
            _startSequence();
          });
        } else {
          // Finished all 3
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Promotion Sequence Finished!"))
          );
        }
      }
    });
  }

  Subject _getSubjectForQuestion(Question q) {
    String qSub = (q.subject ?? q.quizType ?? "").toLowerCase();
    try {
      return tnpscSubjects.firstWhere(
        (s) => s.titleEn.toLowerCase().contains(qSub) ||
               s.titleTa.toLowerCase().contains(qSub) ||
               qSub.contains(s.titleEn.toLowerCase())
      );
    } catch (_) {
      return tnpscSubjects[0];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_quizzes.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("App Promotion")),
        body: const Center(child: Text("No quizzes found.")),
      );
    }

    final question = _quizzes[_currentIndex];
    final subject = _getSubjectForQuestion(question);
    final now = AppDate.getISTNow();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: FittedBox(
              child: SharePoster(
                question: question,
                subject: subject,
                dayIndex: now.weekday,
                showCorrectAnswer: _showAnswer,
              ),
            ),
          ),
          // Progress and Timer Overlay
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Row(
                  children: List.generate(3, (index) {
                    return Expanded(
                      child: Container(
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: index <= _currentIndex 
                              ? Colors.white 
                              : Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),
                if (!_showAnswer)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white30),
                    ),
                    child: Text(
                      "Next in $_timerSeconds s",
                      style: AppTheme.getStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                if (_showAnswer)
                   Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      "Correct Answer!",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Close button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 10,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          // Re-start button at end
          if (_currentIndex == _quizzes.length - 1 && _showAnswer)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _currentIndex = 0;
                      _startSequence();
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text("Restart Promotion"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
