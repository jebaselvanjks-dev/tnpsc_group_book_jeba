import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:tnpsc_group_book/utils/app_log.dart';
import 'package:tnpsc_group_book/widgets/bilingual_text.dart';
import '../models/question.dart';
import '../utils/app_theme.dart';
import '../utils/app_icons.dart';
import '../utils/app_date.dart';
import '../utils/app_language.dart';
import '../services/firestore_service.dart';
import 'result_screen.dart';
import '../services/hive_service.dart';
import '../services/analytics_service.dart';
import '../services/ai_service.dart';
import '../services/tts_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/reward_service.dart';
import '../widgets/error_state_widget.dart';

class QuizScreen extends StatefulWidget {
  final String subjectTitle;
  final String? topicKey;
  final String? category; // Added category to link sub-topics to main subjects
  final String? categoryKey;
  final bool isMockTest;
  final List<String>? allTopics;
  final int? currentIndex;
  final List<Question>? customQuestions;
  final bool hideAppBar;
  
  const QuizScreen({
    super.key, 
    required this.subjectTitle, 
    this.topicKey,
    this.category,
    this.categoryKey,
    this.isMockTest = false,
    this.allTopics,
    this.currentIndex,
    this.customQuestions,
    this.hideAppBar = false,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _currentQuestionIndex = 0;
  List<int?> _selectedAnswers = [];
  List<bool> _unlockedHints = [];
  bool _isLoading = true;
  List<Question> _loadedQuestions = [];
  List<Question> _visibleQuestions = [];
  bool _isBookmarked = false;
  bool _isGenerating = false;
  final FirestoreService _firestoreService = FirestoreService();
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  int _remainingSeconds = 600; // Default 10 mins
  bool _isTimeUp = false;
  bool _isAutoTriggering = false;
  bool _showOnlySpinner = true;
  bool _isExiting = false;

  // Teaser for loading screen
  List<Question> _teaserQuestions = [];
  PageController? _teaserController;
  Timer? _teaserTimer;
  int _currentTeaserIndex = 0;

  bool get isAdmin {
    final user = FirebaseAuth.instance.currentUser;
    return user?.phoneNumber == '+918754236411' || 
           user?.email == 'adminjeba@gmail.com' ||
           user?.email == 'kjebaselvan987@gmail.com';
  }

  @override
  void initState() {
    super.initState();
    _loadTeaserQuestions();
    RewardService.loadRewardedAd();
    _loadQuestions();
    AnalyticsService.logQuizStarted(widget.subjectTitle);

    Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showOnlySpinner = false;
        });
      }
    });
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

  Future<void> _loadQuestions() async {
    // Safety check for Daily and Mock quizzes
    if (widget.subjectTitle == "Daily Quiz" || 
        widget.subjectTitle == AppLanguage.getString('daily_quiz')) {
      if (HiveService.isDailyQuizDone()) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLanguage.getString('completed'))),
          );
        }
        return;
      }
    } else if (widget.subjectTitle == "Mock Quiz" ||
               widget.subjectTitle == AppLanguage.getString('mock_quiz')) {
      if (HiveService.isMockQuizDone()) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLanguage.getString('completed'))),
          );
        }
        return;
      }
    }

    List<Question> questions = [];
    
    if (widget.customQuestions != null && widget.customQuestions!.isNotEmpty) {
      questions = widget.customQuestions!;
    } else if (widget.isMockTest) {
      questions = await _firestoreService.getMockTestQuestions(widget.subjectTitle);
    } else if (widget.subjectTitle == "Daily Quiz" || 
               widget.subjectTitle == AppLanguage.getString('daily_quiz')) {
      questions = await _firestoreService.getDailyQuiz();
    } else if (widget.subjectTitle == "Mock Quiz" ||
               widget.subjectTitle == AppLanguage.getString('mock_quiz')) {
      questions = await _firestoreService.getMockQuiz();
    } else if (widget.subjectTitle == AppLanguage.getString('mistake_bank')) {
      questions = await _firestoreService.getMistakes();
    } else if (widget.subjectTitle == AppLanguage.getString('bookmarks')) {
      questions = await _firestoreService.getBookmarks();
    } else {
      questions = await _firestoreService.getSubjectQuestions(widget.topicKey ?? widget.subjectTitle);
    }

    if (questions.isNotEmpty) {
      final shuffledQuestions = List<Question>.from(questions)..shuffle();
      setState(() {
        _loadedQuestions = shuffledQuestions;
        int limitCount = (widget.subjectTitle == "Daily Quiz" || 
                          widget.subjectTitle == AppLanguage.getString('daily_quiz')) ? 20
                       : (widget.subjectTitle == "Mock Quiz" || 
                          widget.subjectTitle == AppLanguage.getString('mock_quiz') || 
                          widget.isMockTest) ? 50 : 20;
        int initialCount = _loadedQuestions.length > limitCount ? limitCount : _loadedQuestions.length;
        _visibleQuestions = _loadedQuestions.sublist(0, initialCount);
        _selectedAnswers = List.filled(_loadedQuestions.length, null);
        _unlockedHints = List.filled(_loadedQuestions.length, false);
        _isLoading = false;
        _stopwatch.start();
        _startTimer();
      });
      _checkBookmarkStatus();
      return;
    }
    
    // Auto-trigger AI generation for Daily/Mock Quiz if empty
    bool isDaily = widget.subjectTitle == "Daily Quiz" || widget.subjectTitle == AppLanguage.getString('daily_quiz');
    bool isMock = widget.subjectTitle == "Mock Quiz" || widget.subjectTitle == AppLanguage.getString('mock_quiz') || widget.isMockTest;
    
    if (!_isAutoTriggering && (isDaily || isMock)) {
      _isAutoTriggering = true;
      await _generateMoreQuestions();
      return;
    }
    
    // Fallback to local questions
    final localQuestions = List<Question>.from(subjectQuestions[widget.subjectTitle] ?? historyQuestions)..shuffle();
    setState(() {
      _loadedQuestions = localQuestions;
      int limitCount = (widget.subjectTitle == "Daily Quiz" || 
                        widget.subjectTitle == AppLanguage.getString('daily_quiz')) ? 20
                     : (widget.subjectTitle == "Mock Quiz" || 
                        widget.subjectTitle == AppLanguage.getString('mock_quiz') || 
                        widget.isMockTest) ? 50 : 20;
      int initialCount = _loadedQuestions.length > limitCount ? limitCount : _loadedQuestions.length;
      _visibleQuestions = _loadedQuestions.sublist(0, initialCount);
      _selectedAnswers = List.filled(_loadedQuestions.length, null);
      _unlockedHints = List.filled(_loadedQuestions.length, false);
      _isLoading = false;
      _stopwatch.start();
      _startTimer();
    });
  }

  void _startTimer() {
    // Set time based on number of questions: 30 seconds per question
    if (widget.isMockTest) {
      _remainingSeconds = 1800; // 30 mins for Mock
    } else {
      _remainingSeconds = _loadedQuestions.length * 30; 
    }

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _timer?.cancel();
        if (!_isTimeUp) {
          _isTimeUp = true;
          _showTimeUpDialog();
        }
      }
    });
  }

  void _showTimeUpDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(AppLanguage.getString('time_up')),
        content: Text(AppLanguage.getString('time_up_desc')),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _submitQuiz();
            },
            child: Text(AppLanguage.getString('view_result')),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _teaserTimer?.cancel();
    _teaserController?.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // Map to store shuffled option order per question
  final Map<int, List<int>> _shuffledOptionIndices = {};

  Future<void> _handleOptionTap(int index) async {
    setState(() {
      _selectedAnswers[_currentQuestionIndex] = index;
    });

    // Show feedback whether the selected answer is correct
    final correctIndex = _visibleQuestions[_currentQuestionIndex].correctOptionIndex;
    final isCorrect = index == correctIndex;

    // Trigger haptic feedback and sound
    if (HiveService.isVibrationEnabled()) {
      if (isCorrect) {
        HapticFeedback.lightImpact();
      } else {
        HapticFeedback.heavyImpact();
      }
    }

    // AI_DEBUG: Points are no longer added immediately for Daily/Mock quizzes
    // They are calculated and claimed on the result screen instead.
    bool isDailyOrMock = widget.subjectTitle == AppLanguage.getString('daily_quiz') ||
        widget.subjectTitle == "Daily Quiz" ||
        widget.subjectTitle == AppLanguage.getString('mock_quiz') ||
        widget.subjectTitle == AppLanguage.getString('mock_quiz_title') ||
        widget.subjectTitle == "Mock Quiz" ||
        widget.isMockTest;

    if (!isDailyOrMock && isCorrect) {
      await RewardService.addPoints(2);
    }

    // Stop speaking if option is tapped
    if (TtsService.isSpeaking(_getQuestionTtsText(_visibleQuestions[_currentQuestionIndex]))) {
      TtsService.stop();
    }
  }

  Future<void> _checkBookmarkStatus() async {
    if (_visibleQuestions.isEmpty) return;
    bool status = await _firestoreService.isBookmarked(_visibleQuestions[_currentQuestionIndex].question);
    setState(() {
      _isBookmarked = status;
    });
  }

  Future<void> _toggleBookmark() async {
    if (_visibleQuestions.isEmpty) return;
    await _firestoreService.toggleBookmark(_visibleQuestions[_currentQuestionIndex]);
    _checkBookmarkStatus();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isBookmarked 
              ? AppLanguage.getString('removed_from_bookmarks') 
              : AppLanguage.getString('added_to_bookmarks')),
          duration: const Duration(seconds: 1),
        ),
      );
        }
    

  }

  // Helper to format bilingual text (English / Tamil)
  String _formatBilingual(String raw) {
    return AppLanguage.formatBilingual(raw);
  }

  // Returns the option string localized based on current app language.
  String _localizedOption(String raw) {
    return _formatBilingual(raw);
  }

  // Returns shuffled option indices for a given question index.
  List<int> _shuffledIndicesFor(int questionIndex) {
    if (!_shuffledOptionIndices.containsKey(questionIndex)) {
      final optionCount = _visibleQuestions[questionIndex].options.length;
      final indices = List<int>.generate(optionCount, (i) => i);
      indices.shuffle(Random());
      _shuffledOptionIndices[questionIndex] = indices;
    }
    return _shuffledOptionIndices[questionIndex]!;
  }

  String _getQuestionTtsText(Question q) {
    return q.ttsText;
  }

  Future<void> _unlockHint(int index) async {
    final int cost = 40;
    final int currentPoints = Hive.box(HiveService.userBoxName).get('totalScore', defaultValue: 0) as int;

    if (currentPoints < cost) {
      // Show dialog to watch ad if points are insufficient
      final bool? watchAd = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            AppLanguage.languageNotifier.value == 'ta' ? 'புள்ளிகள் போதவில்லை' : 'Insufficient Points',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            AppLanguage.languageNotifier.value == 'ta' 
              ? 'விளக்கத்தைக் காண ஒரு விளம்பரத்தைப் பார்க்க விரும்புகிறீர்களா?' 
              : 'Would you like to watch an ad to unlock the explanation for free?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppLanguage.getString('cancel'), style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.play_circle_fill, color: Colors.white),
              label: Text(
                AppLanguage.languageNotifier.value == 'ta' ? 'விளம்பரம் பார்' : 'Watch Ad',
                style: const TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      );

      if (watchAd == true) {
        RewardService.showRewardAd(
          onRewardEarned: () {
            setState(() {
              _unlockedHints[index] = true;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLanguage.languageNotifier.value == 'ta' ? "விளக்கம் திறக்கப்பட்டது!" : "Explanation Unlocked!"),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          },
          onFailure: () {
            // Unlock anyway if ad fails to load, to be user friendly
            setState(() {
              _unlockedHints[index] = true;
            });
          }
        );
      }
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(AppLanguage.getString('show_hint'), style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          AppLanguage.languageNotifier.value == 'ta'
            ? 'விளக்கத்தைக் காண 40 புள்ளிகள் கழிக்கப்படும்.'
            : '40 points will be deducted to view the explanation.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLanguage.getString('cancel'), style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(AppLanguage.getString('unlock_now'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await RewardService.deductPoints(cost);
      setState(() {
        _unlockedHints[index] = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLanguage.languageNotifier.value == 'ta' ? "விளக்கம் திறக்கப்பட்டது!" : "Explanation Unlocked!"),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _visibleQuestions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
      _checkBookmarkStatus();
    } else if (_visibleQuestions.length < _loadedQuestions.length) {
      // Load next batch of 20
      setState(() {
        int currentLen = _visibleQuestions.length;
        int nextBatchSize = (_loadedQuestions.length - currentLen) > 20 ? 20 : (_loadedQuestions.length - currentLen);
        _visibleQuestions.addAll(_loadedQuestions.sublist(currentLen, currentLen + nextBatchSize));
        _currentQuestionIndex++;
      });
      _checkBookmarkStatus();
    }
  }

  Future<void> _generateMoreQuestions() async {
    if (!mounted) return;
    setState(() => _isGenerating = true);
    
    if (widget.isMockTest) {
      await AiService.generateAndSaveMockQuiz(AppDate.getISTNow());
    } else if (widget.subjectTitle == "Daily Quiz" || widget.subjectTitle == AppLanguage.getString('daily_quiz')) {
      await AiService.generateAndSaveDailyQuiz(AppDate.getISTNow());
    } else if (widget.subjectTitle == "Mock Quiz" || widget.subjectTitle == AppLanguage.getString('mock_quiz')) {
      await AiService.generateAndSaveMockQuiz(AppDate.getISTNow());
    } else {
      await AiService.generateSubjectQuestions(
        widget.topicKey ?? widget.subjectTitle,
        category: widget.categoryKey ?? widget.category,
      );
    }

    // Always call _loadQuestions() after generation attempt.
    // If success is false, _loadQuestions will still be called and 
    // it will try to fetch old quizzes or use local fallback.
    await _loadQuestions();

    if (mounted) {
      setState(() => _isGenerating = false);
    }
  }

  void _submitQuiz() {
    int score = 0;
    for (int i = 0; i < _visibleQuestions.length; i++) {
      if (_selectedAnswers[i] == _visibleQuestions[i].correctOptionIndex) {
        score++;
        // If they got it right, remove from mistakes if it was there
        _firestoreService.removeMistake(_visibleQuestions[i].question);
      } else if (_selectedAnswers[i] != null) {
        // If they answered incorrectly, save to Mistake Bank
        _firestoreService.saveMistake(_visibleQuestions[i]);
      }
    }
    
    _stopwatch.stop();
    int timeTakenSeconds = _stopwatch.elapsed.inSeconds;

    // Save result to Firestore for all subject quizzes and mock tests
    if (widget.subjectTitle != AppLanguage.getString('mistake_bank') && 
        widget.subjectTitle != AppLanguage.getString('bookmarks')) {
      
      String saveTitle = widget.categoryKey ?? widget.category ?? widget.topicKey ?? widget.subjectTitle;
      
      // Robust identification for Daily and Mock quizzes
      bool isDaily = widget.subjectTitle == AppLanguage.getString('daily_quiz') || 
                     widget.subjectTitle == "Daily Quiz";
      bool isMock = widget.subjectTitle == AppLanguage.getString('mock_quiz') || 
                    widget.subjectTitle == AppLanguage.getString('mock_quiz_title') ||
                    widget.subjectTitle == "Mock Quiz" || 
                    widget.isMockTest;

      if (isDaily) {
        saveTitle = "Daily Quiz";
      } else if (isMock) {
        saveTitle = "Mock Quiz";
      }

      _firestoreService.saveQuizResult(
        subject: saveTitle,
        score: score,
        totalQuestions: _visibleQuestions.length,
        timeTaken: timeTakenSeconds,
        isDaily: isDaily,
        isMock: isMock,
      );

      if (isDaily) {
        HiveService.setDailyQuizDone();
      } else if (isMock) {
        HiveService.setMockQuizDone();
      }
    }

    AnalyticsService.logQuizCompleted(
      widget.subjectTitle, 
      score, 
      _visibleQuestions.length
    );

    bool isDailyOrMock = widget.subjectTitle == AppLanguage.getString('daily_quiz') ||
        widget.subjectTitle == "Daily Quiz" ||
        widget.subjectTitle == AppLanguage.getString('mock_quiz') ||
        widget.subjectTitle == AppLanguage.getString('mock_quiz_title') ||
        widget.subjectTitle == "Mock Quiz" ||
        widget.isMockTest;

    if (isDailyOrMock) {
      RewardService.showRewardAdIfAllowed(
          useLimit: false,
          onRewardEarned: () {
            if (!mounted) return;
            // Navigate to result screen without adding extra points (points are added per question)
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => ResultScreen(
                  score: score,
                  totalQuestions: _visibleQuestions.length,
                  timeTakenSeconds: timeTakenSeconds,
                  questions: _visibleQuestions,
                  selectedAnswers: _selectedAnswers,
                  allTopics: widget.allTopics,
                  currentIndex: widget.currentIndex,
                  subjectTitle: widget.subjectTitle,
                ),
              ),
            );
          }
      );
    }else{
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ResultScreen(
            score: score,
            totalQuestions: _visibleQuestions.length,
            timeTakenSeconds: timeTakenSeconds,
            questions: _visibleQuestions,
            selectedAnswers: _selectedAnswers,
            allTopics: widget.allTopics,
            currentIndex: widget.currentIndex,
            subjectTitle: widget.subjectTitle,
          ),
        ),
      );
    }
  }

  Future<bool> _showExitConfirmation() async {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF101F42) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          AppLanguage.languageNotifier.value == 'ta' ? 'வெளியேறவா?' : 'Exit Quiz?',
          style: AppTheme.getStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.textMainColor),
        ),
        content: Text(
          AppLanguage.languageNotifier.value == 'ta' 
            ? 'இந்தத் தேர்விலிருந்து வெளியேற விரும்புகிறீர்களா? உங்கள் முன்னேற்றம் சேமிக்கப்படாது.' 
            : 'Are you sure you want to exit the quiz? Your progress will not be saved.',
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
    AppLog.d("AI_DEBUG: [QuizScreen] _handleBack called. isExiting: $_isExiting");
    if (_isExiting) return;
    final confirmed = await _showExitConfirmation();
    AppLog.d("AI_DEBUG: [QuizScreen] Exit confirmed: $confirmed");
    if (confirmed && mounted) {
      setState(() {
        _isExiting = true;
      });
      AppLog.d("AI_DEBUG: [QuizScreen] Popping screen now.");
      // Small delay to ensure build completes with canPop: true
      Future.delayed(Duration.zero, () {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLanguage.languageNotifier,
      builder: (context, lang, child) {
        bool isDark = Theme.of(context).brightness == Brightness.dark;

        Widget scaffoldBody;

        if (_isLoading) {
          scaffoldBody = Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: Column(
              children: [
                Expanded(
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
                                        textAlign: TextAlign.center,
                                        style: AppTheme.getStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? AppTheme.secondaryColor : AppTheme.textSecondaryColor,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        lang == 'ta' ? 'காத்திருக்கும் நேரத்தில் சில வினாக்கள்...' : 'Learn while we load...',
                                        textAlign: TextAlign.center,
                                        style: AppTheme.getStyle(fontSize: 14, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                )
                            ),
                            const SizedBox(height: 40),
                            Text(
                              _formatBilingual(q.question),
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
                                  color: isCorrect ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.05),
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
                                        style: AppTheme.getStyle(
                                          fontSize: 15,
                                          color: isCorrect ? Colors.green.shade700 : (isDark ? Colors.white : AppTheme.textMainColor),
                                          fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
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
                  ),
                ),
              ],
            ),
          );
        } else if (_visibleQuestions.isEmpty) {
          String displayTitle = widget.subjectTitle;
          if (displayTitle == "Daily Quiz" || displayTitle == "daily_quiz") {
            displayTitle = AppLanguage.getString('daily_quiz');
          } else if (displayTitle == "Mock Quiz" || displayTitle == "mock_quiz") {
            displayTitle = AppLanguage.getString('mock_quiz_title');
          } else {
            displayTitle = AppLanguage.getString(displayTitle);
          }
          
          scaffoldBody = Scaffold(
            appBar: widget.hideAppBar ? null : AppBar(
              leading: IconButton(
                icon: AppIcon(AppIcons.back, color: isDark ? Colors.white : AppTheme.textMainColor),
                onPressed: _handleBack,
              ),
              title: Text(displayTitle),
            ),
            body: AppErrorWidget(
              message: AppLanguage.getString('no_questions'),
              onRetry: isAdmin ? _generateMoreQuestions : null,
            ),
          );
        } else {
          final question = _visibleQuestions[_currentQuestionIndex];
          double progress = (_currentQuestionIndex + 1) / _loadedQuestions.length;

          String displayTitle = widget.subjectTitle;
          if (displayTitle == "Daily Quiz" || displayTitle == "daily_quiz") {
            displayTitle = AppLanguage.getString('daily_quiz');
          } else if (displayTitle == "Mock Quiz" || displayTitle == "mock_quiz") {
            displayTitle = AppLanguage.getString('mock_quiz_title');
          } else {
            displayTitle = AppLanguage.getString(displayTitle);
          }

          scaffoldBody = Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: widget.hideAppBar ? null : AppBar(
              leading: IconButton(
                icon: AppIcon(AppIcons.back, color: isDark ? Colors.white : AppTheme.textMainColor),
                onPressed: _handleBack,
              ),
              title: Text(displayTitle, style: AppTheme.getStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 15.0),
                  child: Builder(
                      builder: (context) {
                        int mins = _remainingSeconds ~/ 60;
                        int secs = _remainingSeconds % 60;
                        String timeStr = "${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}";
                        return Text(
                          timeStr,
                          style: AppTheme.getStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _remainingSeconds < 60 ? Colors.red : AppTheme.secondaryColorLight,
                          ),
                        );
                      }
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
                        Text(
                          "${AppLanguage.getString('question')} ${_currentQuestionIndex + 1}",
                          style: AppTheme.getStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : AppTheme.textSecondaryColor,
                          ),
                        ),
                        Row(
                          children: [
                            if (isAdmin)
                              _isGenerating
                                  ? const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    )
                                  : IconButton(
                                      padding: const EdgeInsets.only(right: 8, bottom: 0, top: 0),
                                      constraints: const BoxConstraints(),
                                      icon: const AppIcon(AppIcons.ai, color: Colors.amber, size: 24),
                                      onPressed: _generateMoreQuestions,
                                    ),
                            if (widget.subjectTitle != "Daily Quiz" && 
                                widget.subjectTitle != AppLanguage.getString('daily_quiz'))
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: TextButton(
                                onPressed: _submitQuiz,
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  textStyle: AppTheme.getStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                child: Text(AppLanguage.getString('end')),
                              ),
                            ),
                            Text(
                              "${_currentQuestionIndex + 1}/${_loadedQuestions.length}",
                              style: AppTheme.getStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : AppTheme.textSecondaryColor,
                              ),
                            ),
                            IconButton(
                              padding: const EdgeInsets.only(left: 8, bottom: 0, top: 0),
                              constraints: const BoxConstraints(),
                              icon: Icon(
                                _isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                                color: _isBookmarked ? Colors.amber : Colors.grey,
                                size: 25,
                              ),
                              onPressed: _toggleBookmark,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: AppTheme.secondaryColor.withValues(alpha: 0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.secondaryColor),
                      borderRadius: BorderRadius.circular(10),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (Widget child, Animation<double> animation) {
                              return SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(1.0, 0.0),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                              );
                            },
                            child: SingleChildScrollView(
                              key: ValueKey<int>(_currentQuestionIndex),
                              padding: const EdgeInsets.symmetric(horizontal: 24.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: BilingualText(
                                          en: question.questionEn,
                                          ta: question.questionTa,
                                          legacy: question.question,
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  if (_selectedAnswers[_currentQuestionIndex] != null)
                                    _unlockedHints[_currentQuestionIndex]
                                        ? Container(
                                            padding: const EdgeInsets.all(16),
                                            margin: const EdgeInsets.only(bottom: 24),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    const Icon(Icons.info_outline_rounded, color: Colors.blue, size: 20),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      AppLanguage.getString('explanation'),
                                                      style: AppTheme.getStyle(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.blue,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                BilingualText(
                                                  en: question.explanationEn,
                                                  ta: question.explanationTa,
                                                  legacy: question.explanation,
                                                  fontSize: 14,
                                                  color: isDark ? Colors.white70 : AppTheme.textSecondaryColor,
                                                ),
                                              ],
                                            ),
                                          )
                                        : Padding(
                                            padding: const EdgeInsets.only(bottom: 20.0),
                                            child: Center(
                                              child: ElevatedButton.icon(
                                                onPressed: () => _unlockHint(_currentQuestionIndex),
                                                icon: const Icon(Icons.lightbulb_outline_rounded, size: 20),
                                                label: Text(
                                                  "${AppLanguage.getString('show_hint')} (40 pts)",
                                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.blue.withValues(alpha: 0.1),
                                                  foregroundColor: Colors.blue,
                                                  elevation: 0,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(12),
                                                    side: const BorderSide(color: Colors.blue, width: 1),
                                                  ),
                                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                                ),
                                              ),
                                            ),
                                          ),
                                  ...List.generate(_shuffledIndicesFor(_currentQuestionIndex).length, (i) {
                                    final index = _shuffledIndicesFor(_currentQuestionIndex)[i];
                                    final selected = _selectedAnswers[_currentQuestionIndex];
                                    final correctIndex = _visibleQuestions[_currentQuestionIndex].correctOptionIndex;
                                    bool isSelected = index == selected;
                                    bool isCorrect = selected != null && index == correctIndex;
                                    
                                    String? optEn;
                                    String? optTa;
                                    if (question.optionsEn != null && index < question.optionsEn!.length) {
                                      optEn = question.optionsEn![index];
                                      optTa = question.optionsTa![index];
                                    }

                                    Color cardColor;
                                    Color borderColor;
                                    if (selected == null) {
                                      cardColor = isDark ? Theme.of(context).cardColor : Colors.white;
                                      borderColor = isDark ? Colors.grey.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.2);
                                    } else if (isSelected) {
                                      cardColor = isCorrect ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1);
                                      borderColor = isCorrect ? Colors.green : Colors.red;
                                    } else if (index == correctIndex) {
                                      cardColor = Colors.green.withValues(alpha: 0.1);
                                      borderColor = Colors.green;
                                    } else {
                                      cardColor = isDark ? Theme.of(context).cardColor : Colors.white;
                                      borderColor = isDark ? Colors.grey.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.2);
                                    }

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 16.0),
                                      child: InkWell(
                                        onTap: selected == null ? () => _handleOptionTap(index) : null,
                                        borderRadius: BorderRadius.circular(16),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 300),
                                          padding: const EdgeInsets.all(15),
                                          decoration: BoxDecoration(
                                            color: cardColor,
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: borderColor, width: 2),
                                            boxShadow: isSelected ? [
                                              BoxShadow(
                                                color: borderColor.withValues(alpha: 0.2),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              )
                                            ] : [],
                                          ),
                                          child: Row(
                                            children: [
                                              AnimatedContainer(
                                                duration: const Duration(milliseconds: 300),
                                                width: 18,
                                                height: 18,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: isSelected ? borderColor : Colors.grey,
                                                    width: 2,
                                                  ),
                                                  color: isSelected ? borderColor : Colors.transparent,
                                                ),
                                                child: isSelected
                                                    ? const AppIcon(Icons.circle, size: 12, color: Colors.white)
                                                    : null,
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: BilingualText(
                                                  en: optEn,
                                                  ta: optTa,
                                                  legacy: question.options[index],
                                                  fontSize: 15,
                                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                                  color: isDark ? Colors.white : AppTheme.textMainColor,
                                                ),
                                              ),
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
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          offset: const Offset(0, -4),
                          blurRadius: 10,
                        )
                      ],
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _selectedAnswers[_currentQuestionIndex] != null
                            ? (_currentQuestionIndex < _loadedQuestions.length - 1 ? _nextQuestion : _submitQuiz)
                            : null,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                        ),
                        child: Text(
                          _currentQuestionIndex < _loadedQuestions.length - 1 ? AppLanguage.getString('next') : AppLanguage.getString('submit'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return PopScope(
          canPop: _isExiting,
          onPopInvokedWithResult: (didPop, result) {
            AppLog.d("AI_DEBUG: [QuizScreen] PopScope onPopInvokedWithResult. didPop: $didPop, isExiting: $_isExiting");
            if (didPop) return;
            _handleBack();
          },
          child: scaffoldBody,
        );
      },
    );
  }
}
