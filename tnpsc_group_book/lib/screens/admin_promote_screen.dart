import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import '../models/question.dart';
import '../models/subject.dart';
import '../services/firestore_service.dart';
import '../utils/app_date.dart';
import '../utils/app_log.dart';
import '../utils/app_theme.dart';
import '../utils/app_language.dart';
import '../widgets/share_poster.dart';

class AdminPromoteScreen extends StatefulWidget {
  const AdminPromoteScreen({super.key});

  @override
  State<AdminPromoteScreen> createState() => _AdminPromoteScreenState();
}

class _AdminPromoteScreenState extends State<AdminPromoteScreen> with TickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  final ScreenshotController _screenshotController = ScreenshotController();
  
  List<Question> _quizzes = [];
  bool _isLoading = true;
  int _currentIndex = 0;
  int _timerSeconds = 5;
  bool _showAnswer = false;
  Timer? _timer;
  Subject? _currentTopicSubject;
  
  late AnimationController _fadeController;
  late AnimationController _revealController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _revealController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _loadQuizzes();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fadeController.dispose();
    _revealController.dispose();
    super.dispose();
  }

  Future<void> _loadQuizzes() async {
    try {
      DateTime now = AppDate.getISTNow();
      int daysSinceEpoch = now.difference(DateTime(1970, 1, 1)).inDays;
      
      // 1. Select Topic based on rotation
      final subjects = tnpscSubjects;
      _currentTopicSubject = subjects[daysSinceEpoch % subjects.length];
      String topicName = _currentTopicSubject!.titleEn;

      // 2. Fetch 3 quizzes for this topic
      List<Question> pool = await _firestoreService.getRandomQuizzesByTopic(topicName, limit: 3);
      
      // Fallback if topic query fails
      if (pool.isEmpty) {
        final daily = await _firestoreService.getDailyRotatingQuiz(isAdmin: true);
        pool.addAll(daily);
      }
      
      if (pool.length < 3) {
        pool.addAll(defaultRoomQuestions);
      }

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
    _fadeController.forward(from: 0);
    _revealController.reset();
    
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
    _revealController.forward();

    // Wait 3 seconds for reveal then move to next
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        if (_currentIndex < _quizzes.length - 1) {
          _fadeController.reverse().then((_) {
            if (mounted) {
              setState(() {
                _currentIndex++;
                _startSequence();
              });
            }
          });
        } else {
          // Finished all 3
        }
      }
    });
  }

  Future<void> _shareCurrentQuiz() async {
    final question = _quizzes[_currentIndex];
    final subject = _getSubjectForQuestion(question);
    final now = AppDate.getISTNow();

    try {
      final Uint8List? imageBytes = await _screenshotController.captureFromWidget(
        Material(
          color: Colors.black,
          child: Directionality(
            textDirection: ui.TextDirection.ltr,
            child: MediaQuery(
              data: const MediaQueryData().copyWith(textScaler: const TextScaler.linear(0.9)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: SharePoster(
                  question: question, 
                  subject: subject, 
                  dayIndex: now.weekday,
                  showCorrectAnswer: _showAnswer,
                ),
              ),
            ),
          ),
        ),
        pixelRatio: 4.0,
        delay: const Duration(milliseconds: 200),
      );

      if (imageBytes != null && mounted) {
        final directory = await getTemporaryDirectory();
        final imagePath = await File('${directory.path}/promo_quiz.png').create();
        await imagePath.writeAsBytes(imageBytes);
        
        String shareText = "Daily TNPSC Challenge! Can you solve this? 📚\n\nDownload: https://play.google.com/store/apps/details?id=com.tnpsc.groupbook.tnpsc_group_book";
        
        await Share.shareXFiles([XFile(imagePath.path)], text: shareText);
      }
    } catch (e) {
      AppLog.e("Error sharing from promo: $e");
    }
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
      return _currentTopicSubject ?? tnpscSubjects[0];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
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
          // Main Poster Content
          Center(
            child: FadeTransition(
              opacity: _fadeController,
              child: FittedBox(
                child: SharePoster(
                  question: question,
                  subject: subject,
                  dayIndex: now.weekday,
                  showCorrectAnswer: _showAnswer,
                ),
              ),
            ),
          ),

          // Timer / Answer Reveal Center
          if (!_showAnswer)
            Positioned(
              bottom: MediaQuery.of(context).size.height * 0.08,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.7),
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "$_timerSeconds",
                    style: const TextStyle(color: Colors.white, fontSize: 35, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),

          // Footer Call to Action
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 20,
            left: 20,
            right: 20,
            child: Column(
              children: [
                const Text(
                  "DOWNLOAD TNPSC MASTER APP",
                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 2),
                ),
                const SizedBox(height: 5),
                Text(
                  "LINK IN BIO",
                  style: AppTheme.getStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ],
            ),
          ),

          // Close button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 10,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white60, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // End controls
          if (_currentIndex == _quizzes.length - 1 && _showAnswer)
            Positioned.fill(
              child: Container(
                color: Colors.black87,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.celebration_rounded, color: Colors.amber, size: 80),
                      const SizedBox(height: 20),
                      Text(
                        "Sequence Complete!",
                        style: AppTheme.getStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Record your screen and share\nthis on YouTube / Instagram!",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _currentIndex = 0;
                            _startSequence();
                          });
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text("Restart From Beginning"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextButton(
                         onPressed: () => Navigator.pop(context),
                         child: const Text("Exit to Dashboard", style: TextStyle(color: Colors.white54)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSideIcon(IconData icon, String label, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.4),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
