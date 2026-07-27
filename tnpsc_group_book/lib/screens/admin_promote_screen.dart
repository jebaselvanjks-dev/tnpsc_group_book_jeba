import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_widget_recorder/flutter_widget_recorder.dart';
import 'package:gal/gal.dart';
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

class _AdminPromoteScreenState extends State<AdminPromoteScreen> with TickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  final ScreenshotController _screenshotController = ScreenshotController();
  final WidgetRecorderController _recorderController = WidgetRecorderController(targetFps: 60);
  
  List<Question> _quizzes = [];
  bool _isLoading = true;
  bool _isRecording = false;
  bool _isSaving = false;
  int _currentIndex = 0;
  int _timerSeconds = 10;
  final int _maxTimerSeconds = 10;
  bool _showAnswer = false;
  Timer? _timer;
  Subject? _currentTopicSubject;
  
  late AnimationController _fadeController;
  late AnimationController _revealController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _revealController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _loadQuizzes();
    _preCacheImages();
  }

  void _preCacheImages() {
    for (int i = 1; i <= 7; i++) {
      precacheImage(AssetImage('asset/images/sharequiz$i.png'), context);
    }
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
      int slotSeed = AppDate.getSlotSeed();
      
      // 1. Select Topic based on synchronized 6-hour rotation
      final subjects = tnpscSubjects;
      _currentTopicSubject = subjects[slotSeed % subjects.length];
      String topicName = _currentTopicSubject!.titleEn;

      // 2. Fetch 3 quizzes for this topic with a SEED for synchronized shuffle
      List<Question> pool = await _firestoreService.getRandomQuizzesByTopic(
        topicName, 
        limit: 3, 
        seed: slotSeed
      );
      
      // Fallback logic remains seeded for consistency
      if (pool.isEmpty) {
        final daily = await _firestoreService.getDailyRotatingQuiz(isAdmin: true);
        pool.addAll(daily);
      }
      
      if (pool.length < 3) {
        // Deterministic pick from defaults
        var tempDefaults = List<Question>.from(defaultRoomQuestions);
        tempDefaults.shuffle(Random(slotSeed));
        pool.addAll(tempDefaults);
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
    _timerSeconds = _maxTimerSeconds;
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

    // Wait 4 seconds for reveal then move to next (slightly longer for drama)
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        if (_currentIndex < _quizzes.length - 1) {
          setState(() {
            _currentIndex++;
            _startSequence();
          });
        } else {
          // Finished all 3
          if (_isRecording) {
            // Add a 2-second outro pause for professional finish
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) _stopRecordingAndSave();
            });
          }
        }
      }
    });
  }

  Future<void> _startRecording() async {
    AppLog.d("VideoRec: Checking permissions...");
    final hasAccess = await Gal.hasAccess();
    if (!hasAccess) {
      final granted = await Gal.requestAccess();
      if (!granted) {
        AppLog.d("VideoRec: Gallery access denied");
        return;
      }
    }

    AppLog.d("VideoRec: Starting recording process...");
    setState(() {
      _isRecording = true;
      _currentIndex = 0;
      _showAnswer = false; // Reset state
      _timerSeconds = _maxTimerSeconds;
    });

    try {
      await _recorderController.startRecording(
        'tnpsc_promo_${DateTime.now().millisecondsSinceEpoch}',
        pixelRatio: 2.5, // Increased for professional crisp quality
      );
      AppLog.d("VideoRec: Recording started successfully");
      
      // Professional 1-second "Intro" pause before sequence begins
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted && _isRecording) _startSequence();
      });
    } catch (e) {
      AppLog.e("VideoRec: Error starting recording: $e");
      setState(() => _isRecording = false);
    }
  }

  Future<void> _stopRecordingAndSave() async {
    AppLog.d("VideoRec: Stopping recording...");
    setState(() {
      _isRecording = false;
      _isSaving = true;
    });

    try {
      await _recorderController.stopRecording();
      final path = _recorderController.path;
      AppLog.d("VideoRec: Recording stopped. Path: $path");
      
      if (path != null) {
        AppLog.d("VideoRec: Saving to gallery...");
        await Gal.putVideo(path);
        AppLog.d("VideoRec: Saved to gallery successfully");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Video saved to gallery! ✅"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        AppLog.d("VideoRec: No video path found after stopping");
      }
    } catch (e) {
      AppLog.e("VideoRec: Error saving recording: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save video: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _shareCurrentQuiz() async {
    final question = _quizzes[_currentIndex];
    final subject = _getSubjectForQuestion(question);
    int slotSeed = AppDate.getSlotSeed();

    try {
      final Uint8List? imageBytes = await _screenshotController.captureFromWidget(
        Material(
          color: Colors.black,
          child: Directionality(
            textDirection: ui.TextDirection.ltr,
            child: MediaQuery(
              data: const MediaQueryData().copyWith(textScaler: const TextScaler.linear(0.9)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 475),
                child: SharePoster(
                  question: question, 
                  subject: subject, 
                  dayIndex: (slotSeed % 7) + 1,
                  showCorrectAnswer: _showAnswer,
                  timerSeconds: _timerSeconds,
                  maxTimerSeconds: _maxTimerSeconds,
                  showFooter: true,
                ),
              ),
            ),
          ),
        ),
        pixelRatio: 5.0,
        delay: const Duration(milliseconds: 500),
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

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ─── Recordable Content Wrapper ───
          WidgetRecorderWrapper(
            controller: _recorderController,
            child: Container(
              color: Colors.black, // Background for video
              child: Stack(
                children: [
                  // Smooth Quiz Transitions
                  Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 1000),
                      switchInCurve: Curves.easeInOutQuart,
                      switchOutCurve: Curves.easeInOutQuart,
                      transitionBuilder: (Widget child, Animation<double> animation) {
                        final offsetAnimation = Tween<Offset>(
                          begin: const Offset(1.0, 0.0),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOutQuart));

                        final scaleAnimation = Tween<double>(
                          begin: 0.9,
                          end: 1.0,
                        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack));

                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: offsetAnimation,
                            child: ScaleTransition(
                              scale: scaleAnimation,
                              child: child,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        key: ValueKey<int>(_currentIndex),
                        child: FittedBox(
                          child: SharePoster(
                            question: question,
                            subject: subject,
                            dayIndex: (AppDate.getSlotSeed() % 7) + 1,
                            showCorrectAnswer: _showAnswer,
                            timerSeconds: _timerSeconds,
                            maxTimerSeconds: _maxTimerSeconds,
                            showFooter: true,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Professional Animated Timer (Modern Linear Style)
                  // Moved inside SharePoster
                ],
              ),
            ),
          ),

          // ─── Non-Recordable Controls Overlay ───
          
          // Saving Overlay
          if (_isSaving)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.8),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Colors.amber),
                      const SizedBox(height: 25),
                      Text(
                        "Saving Video...",
                        style: AppTheme.getStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Optimizing MP4 for your gallery.\nPlease wait a moment.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Recording Indicator
          if (_isRecording)
            Positioned(
              top: MediaQuery.of(context).padding.top + 35,
              left: 25,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 10)
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BlinkingDot(),
                    SizedBox(width: 8),
                    Text(
                      "LIVE RECORDING",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),

          // Side Icons (Non-recordable)
          Positioned(
            right: 15,
            bottom: MediaQuery.of(context).size.height * 0.25,
            child: Column(
              children: [
                _buildSideIcon(
                  Icons.videocam_rounded, 
                  _isRecording ? "Stop" : "Record", 
                  _isRecording ? Colors.red : Colors.white,
                  onTap: _isRecording ? _stopRecordingAndSave : _startRecording,
                ),
                const SizedBox(height: 25),
                _buildSideIcon(
                  Icons.share_rounded, 
                  "Share", 
                  Colors.white,
                  onTap: _shareCurrentQuiz,
                ),
                const SizedBox(height: 25),
                _buildSideIcon(
                  Icons.refresh_rounded, 
                  "Restart", 
                  Colors.white,
                  onTap: () {
                    setState(() {
                      _currentIndex = 0;
                      _startSequence();
                    });
                  },
                ),
              ],
            ),
          ),

          // Close button (Non-recordable)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 10,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white60, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // End controls (Non-recordable)
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
                        "Production Ready!",
                        style: AppTheme.getStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Your professional video has been\nsaved to your device gallery!",
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
                        label: const Text("Restart Sequence"),
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
              border: icon == Icons.videocam_rounded && label == "Stop" 
                ? Border.all(color: Colors.red, width: 2) 
                : null,
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

class BlinkingDot extends StatefulWidget {
  const BlinkingDot({super.key});

  @override
  State<BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<BlinkingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      ),
    );
  }
}
