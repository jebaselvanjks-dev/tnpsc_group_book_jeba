import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';

import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../models/question.dart';
import '../utils/app_theme.dart';
import '../utils/app_language.dart';
import '../main.dart'; // To navigate Home
import 'review_screen.dart';
import 'package:lottie/lottie.dart';
import '../widgets/ad_banner.dart';
import '../services/reward_service.dart';
import '../services/hive_service.dart';
import '../utils/app_log.dart';

class ResultScreen extends StatefulWidget {
  final int score;
  final int totalQuestions;
  final int timeTakenSeconds;
  final List<Question> questions;
  final List<int?> selectedAnswers;
  final List<String>? allTopics;
  final int? currentIndex;
  final String? category;
  final String? subjectTitle;

  const ResultScreen({
    super.key,
    required this.score,
    required this.totalQuestions,
    required this.timeTakenSeconds,
    required this.questions,
    required this.selectedAnswers,
    this.allTopics,
    this.currentIndex,
    this.category,
    this.subjectTitle,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();

  bool get _isDailyOrMock {
    final title = widget.subjectTitle;
    if (title == null) return false;
    final lowerTitle = title.toLowerCase();
    return title == "Daily Quiz" ||
        title == AppLanguage.getString('daily_quiz') ||
        lowerTitle.contains("daily");
  }

  @override
  void initState() {
    super.initState();
    // Save results locally for Home Screen analysis
    _saveResultsLocally();

    // Show rewarded ad on Daily Quiz completion
    if (HiveService.isDailyQuizDone()) {
      RewardService.loadRewardedAd();
      Future.delayed(const Duration(seconds: 1), () {
        RewardService.showRewardAdIfAllowed(
          onRewardEarned: () {
            AppLog.d("Ad reward earned on result screen");
          },
        );
      });
    }
  }

  void _saveResultsLocally() {
    // Only record performance statistics for Daily Quizzes
    final bool isDailyQuiz = widget.subjectTitle == "Daily Quiz" || 
                           widget.subjectTitle == AppLanguage.getString('daily_quiz');
    
    if (!isDailyQuiz) return;

    // Reset all categories first to ensure we only show the LATEST quiz results
    HiveService.updateCategoryPerformance('general_tamil', 0, 0);
    HiveService.updateCategoryPerformance('general_studies', 0, 0);
    HiveService.updateCategoryPerformance('aptitude', 0, 0);

    int tamilTotal = 0;
    int tamilCorrect = 0;
    int gsTotal = 0;
    int gsCorrect = 0;
    int aptitudeTotal = 0;
    int aptitudeCorrect = 0;

    for (int i = 0; i < widget.questions.length; i++) {
      final q = widget.questions[i];
      final selected = widget.selectedAnswers[i];
      final isCorrect = selected != null && selected == q.correctOptionIndex;

      String category = 'general_studies';
      final qType = q.quizType?.toLowerCase() ?? "";
      final qSub = q.subject?.toLowerCase() ?? "";
      final qText = "${q.questionEn ?? ""} ${q.questionTa ?? ""} ${q.question}".toLowerCase();

      // DEBUG: Log question metadata
      AppLog.d("AI_DEBUG_RESULT: Q$i -> type: '$qType', sub: '$qSub', text: '${qText.substring(0, qText.length > 20 ? 20 : qText.length)}...'");

      // Improved Hierarchy: Check keywords in type, subject, AND question text
      if (qType.contains('aptitude') || qSub.contains('aptitude') || qSub.contains('math') || qSub.contains('mental') || qText.contains('கணித') || qText.contains('aptitude') || qText.contains('எண்') || qText.contains('திறன்')) {
        category = 'aptitude';
      } else if (qType.contains('general_tamil') || qSub.contains('tamil') || qText.contains('தமிழ்')) {
        category = 'general_tamil';
      } else {
        category = 'general_studies';
      }

      AppLog.d("AI_DEBUG_RESULT: -> Final Category: $category");

      if (category == 'general_tamil') {
        tamilTotal++;
        if (isCorrect) tamilCorrect++;
      } else if (category == 'aptitude') {
        aptitudeTotal++;
        if (isCorrect) aptitudeCorrect++;
      } else {
        gsTotal++;
        if (isCorrect) gsCorrect++;
      }
    }

    AppLog.d("AI_DEBUG_STATS: Tamil: $tamilCorrect/$tamilTotal, GS: $gsCorrect/$gsTotal, Aptitude: $aptitudeCorrect/$aptitudeTotal");

    if (tamilTotal > 0) HiveService.updateCategoryPerformance('general_tamil', tamilCorrect, tamilTotal);
    if (gsTotal > 0) HiveService.updateCategoryPerformance('general_studies', gsCorrect, gsTotal);
    if (aptitudeTotal > 0) HiveService.updateCategoryPerformance('aptitude', aptitudeCorrect, aptitudeTotal);
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remSeconds = seconds % 60;

    if (minutes > 0) {
      return '$minutes ${AppLanguage.getString('min')} $remSeconds ${AppLanguage.getString('sec')}';
    }
    return '$remSeconds ${AppLanguage.getString('sec')}';
  }

  Future<void> _shareScorecard() async {
    try {
      final Uint8List? image = await _screenshotController.captureFromWidget(_buildShareablePoster(), delay: const Duration(milliseconds: 100));

      if (image != null) {
        final directory = await getTemporaryDirectory();
        final imagePath = await File('${directory.path}/scorecard.png').create();
        await imagePath.writeAsBytes(image);

        String shareText = AppLanguage.getString(
          'share_text',
        ).replaceAll('{score}', widget.score.toString()).replaceAll('{total}', widget.totalQuestions.toString());

        await Share.shareXFiles([XFile(imagePath.path)], text: shareText);
      }
    } catch (e) {
      AppLog.d("AI_DEBUG: Share error: $e");
    }
  }

  Widget _buildShareablePoster() {
    return Container(
      width: 400,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppTheme.primaryColor, Colors.indigo.shade900], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 80),
          const SizedBox(height: 20),
          Text(
            AppLanguage.getString('app_title').toUpperCase(),
            style: AppTheme.getStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white).copyWith(letterSpacing: 2),
          ),
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              children: [
                Text(
                  "${widget.score} / ${widget.totalQuestions}",
                  style: AppTheme.getStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(AppLanguage.getString('correct_answers'), style: AppTheme.getStyle(color: Colors.white70, fontSize: 16)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildPosterStat(AppLanguage.getString('time'), _formatTime(widget.timeTakenSeconds)),
                    _buildPosterStat(
                      AppLanguage.getString('accuracy'),
                      "${((widget.score / widget.totalQuestions) * 100).toStringAsFixed(1)}%",
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Text(
            AppLanguage.getString('prepare_anywhere'),
            style: AppTheme.getStyle(fontSize: 14, color: Colors.white70).copyWith(fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 10),
          Text(
            AppLanguage.getString('download_app'),
            style: AppTheme.getStyle(fontSize: 14, color: Colors.amber, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildPosterStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: AppTheme.getStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
        ),
        Text(label, style: AppTheme.getStyle(fontSize: 12, color: Colors.white70)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLanguage.languageNotifier,
      builder: (context, lang, child) {
        bool isDark = Theme.of(context).brightness == Brightness.dark;
        double accuracy = (widget.score / widget.totalQuestions) * 100;
        int attempted = widget.selectedAnswers.where((a) => a != null).length;
        int missed = widget.totalQuestions - attempted;

        // Determine performance message
        String message = AppLanguage.getString('good_effort');
        Color scoreColor = Colors.orange;
        if (accuracy >= 80) {
          message = AppLanguage.getString('outstanding');
          scoreColor = Colors.green;
        } else if (accuracy >= 50) {
          message = AppLanguage.getString('well_done');
          scoreColor = AppTheme.primaryColor;
        } else {
          scoreColor = Colors.redAccent;
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            AppLog.d("AI_DEBUG: [ResultScreen] PopScope triggered. didPop: $didPop");
            if (didPop) return;
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const MainWrapper()),
              (route) => false,
            );
          },
          child: Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 10.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // const SizedBox(height: 15),
                    // Trophy / Icon with Lottie
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        if (accuracy >= 50)
                          Lottie.network(
                            'https://assets2.lottiefiles.com/packages/lf20_touohxv0.json', // Confetti animation
                            width: 200,
                            height: 200,
                            repeat: false,
                          ),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(color: scoreColor.withOpacity(0.1), shape: BoxShape.circle),
                          child: Icon(accuracy >= 50 ? Icons.emoji_events_rounded : Icons.military_tech_rounded, color: scoreColor, size: 80),
                        ),
                      ],
                    ),
                    // const SizedBox(height: 16),
          Text(
            message,
            style: AppTheme.getStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppTheme.textMainColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLanguage.getString('quiz_completed'),
            textAlign: TextAlign.center,
            style: AppTheme.getStyle(fontSize: 16, color: isDark ? Colors.white70 : AppTheme.textSecondaryColor),
          ),
                    const SizedBox(height: 25),

                    // Stats Cards
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              context,
                              icon: Icons.check_circle_outline_rounded,
                              title: AppLanguage.getString('score'),
                              value: "${widget.score} / ${widget.totalQuestions}",
                              color: isDark ? AppTheme.cardColor : AppTheme.textSecondaryColor,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              context,
                              icon: Icons.timer_outlined,
                              title: AppLanguage.getString('time'),
                              value: _formatTime(widget.timeTakenSeconds),
                              color: Colors.purple,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_isDailyOrMock) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                context,
                                icon: Icons.track_changes_rounded,
                                title: AppLanguage.getString('accuracy'),
                                value: "${accuracy.toStringAsFixed(1)}%",
                                color: Colors.green,
                              ),
                            ),

                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildStatCard(
                                context,
                                icon: Icons.cancel_outlined,
                                title: AppLanguage.getString('missed_quiz'),
                                value: "${missed} / ${widget.totalQuestions}",
                                color: Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                context,
                                icon: Icons.speed_rounded,
                                title: AppLanguage.getString('speed'),
                                value: widget.timeTakenSeconds > 0
                                    ? AppLanguage.getString(
                                        'sec_per_q',
                                      ).replaceAll('{val}', (widget.timeTakenSeconds / widget.totalQuestions).toStringAsFixed(1))
                                    : AppLanguage.getString('na'),
                                color: Colors.orange,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildStatCard(
                                context,
                                icon: Icons.insights_outlined,
                                title: AppLanguage.getString('smart_weak_analysis'),
                                value: _determineWeakArea(),
                                color: Colors.limeAccent,
                                onTap: () {
                                  _showWeakAreaAnalysisBottomSheet(context);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                context,
                                icon: Icons.track_changes_rounded,
                                title: AppLanguage.getString('accuracy'),
                                value: "${accuracy.toStringAsFixed(1)}%",
                                color: Colors.green,
                              ),
                            ),

                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildStatCard(
                                context,
                                icon: Icons.speed_rounded,
                                title: AppLanguage.getString('speed'),
                                value: widget.timeTakenSeconds > 0
                                    ? AppLanguage.getString(
                                        'sec_per_q',
                                      ).replaceAll('{val}', (widget.timeTakenSeconds / widget.totalQuestions).toStringAsFixed(1))
                                    : AppLanguage.getString('na'),
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // Action Buttons
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      // height: 55,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        child: ElevatedButton.icon(
                          onPressed: _shareScorecard,
                          icon: const Icon(Icons.share_rounded, color: Colors.white),
                          label: Padding(
                            padding: const EdgeInsets.only(top: 8.0, bottom: 8),
                            child: Text(
                              AppLanguage.getString('share_scorecard'),
                              style: AppTheme.getStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo[400],
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ReviewScreen(questions: widget.questions, selectedAnswers: widget.selectedAnswers),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                side: BorderSide(color: isDark ? Colors.white70 : AppTheme.textMainColor.withOpacity(0.5)),
                              ),
                              child: Text(
                                AppLanguage.getString('review_answers'),
                                style: AppTheme.getStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white70 : AppTheme.textMainColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      // height: 55,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (context) => const MainWrapper()),
                              (route) => false,
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: isDark ? Colors.white30 : Colors.grey.shade300, width: 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8.0, bottom: 8),
                            child: Text(
                              AppLanguage.getString('go_home'),
                              style: AppTheme.getStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : AppTheme.textMainColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Center(child: AdBanner()),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ));
      },
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    VoidCallback? onTap,
  }) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    Widget card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: AppTheme.getStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.textMainColor),
          ),
          const SizedBox(height: 4),
          Text(title, style: AppTheme.getStyle(fontSize: 13, color: isDark ? Colors.white70 : AppTheme.textSecondaryColor)),
        ],
      ),
    );

    // If the caller wants the card to expand (e.g., within a Row), they can wrap it with Expanded.
    if (onTap != null) {
      return InkWell(onTap: onTap, child: card);
    }
    return card;
  }

  String _determineWeakArea() {
    if (_isDailyOrMock) {
      final isTamil = AppLanguage.languageNotifier.value == 'ta';
      int tamilTotal = 0;
      int tamilCorrect = 0;
      int gsTotal = 0;
      int gsCorrect = 0;
      int aptitudeTotal = 0;
      int aptitudeCorrect = 0;

      for (int i = 0; i < widget.questions.length; i++) {
        final q = widget.questions[i];
        final selected = widget.selectedAnswers[i];
        final isCorrect = selected != null && selected == q.correctOptionIndex;

      String category = 'general_studies';
      final qType = q.quizType?.toLowerCase() ?? "";
      final qSub = q.subject?.toLowerCase() ?? "";
      final qText = "${q.questionEn ?? ""} ${q.questionTa ?? ""} ${q.question}".toLowerCase();

      // Improved Hierarchy: Check keywords
      if (qType.contains('aptitude') || qSub.contains('aptitude') || qSub.contains('math') || qSub.contains('mental') || qText.contains('கணித') || qText.contains('aptitude') || qText.contains('எண்') || qText.contains('திறன்')) {
        category = 'aptitude';
      } else if (qType.contains('general_tamil') || qSub.contains('tamil') || qText.contains('தமிழ்')) {
        category = 'general_tamil';
      } else {
        category = 'general_studies';
      }

        if (category == 'general_tamil') {
          tamilTotal++;
          if (isCorrect) tamilCorrect++;
        } else if (category == 'aptitude') {
          aptitudeTotal++;
          if (isCorrect) aptitudeCorrect++;
        } else {
          gsTotal++;
          if (isCorrect) gsCorrect++;
        }
      }

      double tamilAccuracy = tamilTotal > 0 ? (tamilCorrect / tamilTotal) * 100 : 100.0;
      double gsAccuracy = gsTotal > 0 ? (gsCorrect / gsTotal) * 100 : 100.0;
      double aptitudeAccuracy = aptitudeTotal > 0 ? (aptitudeCorrect / aptitudeTotal) * 100 : 100.0;

      List<String> weakestCategories = [];
      double lowestAcc = 100.0;

      void checkAcc(String key, double acc, int total) {
        if (total > 0) {
          if (acc < lowestAcc) {
            lowestAcc = acc;
            weakestCategories = [key];
          } else if (acc == lowestAcc) {
            weakestCategories.add(key);
          }
        }
      }

      checkAcc('general_tamil', tamilAccuracy, tamilTotal);
      checkAcc('general_studies', gsAccuracy, gsTotal);
      checkAcc('aptitude', aptitudeAccuracy, aptitudeTotal);

      if (weakestCategories.isEmpty || lowestAcc == 100.0) {
        return isTamil ? 'ஏதுமில்லை' : 'None';
      }
      
      List<String> names = weakestCategories.map((k) => _getCategoryName(k, isTamil)).toList();
      return names.join(', ');
    }

    // Fallback to subject-based
    Map<String, int> wrongCounts = {};
    for (int i = 0; i < widget.questions.length; i++) {
      int? selected = widget.selectedAnswers[i];
      if (selected == null || selected != widget.questions[i].correctOptionIndex) {
        String subject = widget.questions[i].subject ?? 'General';
        wrongCounts[subject] = (wrongCounts[subject] ?? 0) + 1;
      }
    }
    if (wrongCounts.isEmpty) {
      return AppLanguage.getString('none') ?? 'None';
    }
    var weak = wrongCounts.entries.reduce((a, b) => a.value > b.value ? a : b);
    return weak.key;
  }

  String _getCategoryName(String key, bool isTamil) {
    return AppLanguage.getString(key);
  }

  Widget _buildCategoryProgress(
    BuildContext context, {
    required String categoryKey,
    required int correct,
    required int total,
    required double accuracy,
    required IconData icon,
    required Color color,
  }) {
    if (total == 0) return const SizedBox.shrink();

    bool isDark = Theme.of(context).brightness == Brightness.dark;
    bool isTamil = AppLanguage.languageNotifier.value == 'ta';

    Color progressColor = Colors.redAccent;
    if (accuracy >= 75) {
      progressColor = Colors.green;
    } else if (accuracy >= 50) {
      progressColor = Colors.orange;
    }

    final double focusPercentage = 100 - accuracy;
    final String categoryName = _getCategoryName(categoryKey, isTamil);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: accuracy / 100),
        duration: const Duration(milliseconds: 1200),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with icon, name and percentage (Mastery style)
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      categoryName,
                      style: AppTheme.getStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppTheme.textMainColor,
                      ),
                    ),
                  ),
                  Text(
                    "${(value * 100).toInt()}%",
                    style: AppTheme.getStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: progressColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Progress bar (Mastery style)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 6,
                  backgroundColor: progressColor.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                ),
              ),
              const SizedBox(height: 10),
              // Detail labels
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isTamil ? "$correct / $total சரி" : "$correct / $total Correct",
                    style: AppTheme.getStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  Text(
                    isTamil ? "${(100 - accuracy).toInt()}% தவறு" : "${(100 - accuracy).toInt()}% Wrong",
                    style: AppTheme.getStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _showWeakAreaAnalysisBottomSheet(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    final isTamil = AppLanguage.languageNotifier.value == 'ta';

    int tamilTotal = 0;
    int tamilCorrect = 0;
    int gsTotal = 0;
    int gsCorrect = 0;
    int aptitudeTotal = 0;
    int aptitudeCorrect = 0;

    for (int i = 0; i < widget.questions.length; i++) {
      final q = widget.questions[i];
      final selected = widget.selectedAnswers[i];
      final isCorrect = selected != null && selected == q.correctOptionIndex;

      String category = 'general_studies';
      final qType = q.quizType?.toLowerCase() ?? "";
      final qSub = q.subject?.toLowerCase() ?? "";
      final qText = "${q.questionEn ?? ""} ${q.questionTa ?? ""} ${q.question}".toLowerCase();

      // Improved Hierarchy: Check keywords
      if (qType.contains('aptitude') || qSub.contains('aptitude') || qSub.contains('math') || qSub.contains('mental') || qText.contains('கணித') || qText.contains('aptitude') || qText.contains('எண்') || qText.contains('திறன்')) {
        category = 'aptitude';
      } else if (qType.contains('general_tamil') || qSub.contains('tamil') || qText.contains('தமிழ்')) {
        category = 'general_tamil';
      } else {
        category = 'general_studies';
      }

      if (category == 'general_tamil') {
        tamilTotal++;
        if (isCorrect) tamilCorrect++;
      } else if (category == 'aptitude') {
        aptitudeTotal++;
        if (isCorrect) aptitudeCorrect++;
      } else {
        gsTotal++;
        if (isCorrect) gsCorrect++;
      }
    }

    double tamilAccuracy = tamilTotal > 0 ? (tamilCorrect / tamilTotal) * 100 : 0.0;
    double gsAccuracy = gsTotal > 0 ? (gsCorrect / gsTotal) * 100 : 0.0;
    double aptitudeAccuracy = aptitudeTotal > 0 ? (aptitudeCorrect / aptitudeTotal) * 100 : 0.0;

    List<String> weakestCategories = [];
    double lowestPercent = 101;

    void checkWeakest(String key, double accuracy, int total) {
      if (accuracy < lowestPercent) {
        lowestPercent = accuracy;
        weakestCategories = [key];
      } else if (accuracy == lowestPercent) {
        weakestCategories.add(key);
      }
    }

    checkWeakest("general_tamil", tamilAccuracy, tamilTotal);
    checkWeakest("general_studies", gsAccuracy, gsTotal);
    checkWeakest("aptitude", aptitudeAccuracy, aptitudeTotal);

    // Note: Result screen always has attempts because a quiz just finished
    String recommendation = "";
    if (weakestCategories.isNotEmpty && lowestPercent < 75) {
      List<String> catNames = [];
      for (var cat in weakestCategories) {
        if (cat == 'general_tamil') catNames.add(isTamil ? 'பொது தமிழ்' : 'General Tamil');
        else if (cat == 'general_studies') catNames.add(isTamil ? 'பொது அறிவு' : 'General Studies');
        else if (cat == 'aptitude') catNames.add(isTamil ? 'கணிதத் திறன்' : 'Aptitude');
      }

      String joinedNames = catNames.join(', ');
      if (catNames.length > 1) {
        recommendation = AppLanguage.getString('focus_recommendation_plural').replaceAll('{categories}', joinedNames);
      } else {
        recommendation = AppLanguage.getString('focus_recommendation').replaceAll('{category}', joinedNames);
      }
    } else if (lowestPercent >= 75 && lowestPercent <= 100) {
      recommendation = AppLanguage.getString('excellent_work');
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 12.0, bottom: 24.0),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF181824) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pull Handle
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              
              // Title Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      isTamil ? "பலவீனமான பகுதி பகுப்பாய்வு" : "Smart Weak Area Analysis",
                      style: AppTheme.getStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppTheme.textMainColor,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: isDark ? Colors.white60 : Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              Text(
                isTamil 
                    ? "உங்கள் பலவீனமான பகுதிகளில் கவனம் செலுத்த வகை வாரியான விவரம்:" 
                    : "Here is your performance breakdown by category to help you focus on your weak areas:",
                textAlign: TextAlign.start,
                style: AppTheme.getStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : AppTheme.textSecondaryColor,
                ),
              ),
              const SizedBox(height: 16),

              // Categories breakdown
              _buildCategoryProgress(
                context,
                categoryKey: "general_tamil",
                correct: tamilCorrect,
                total: tamilTotal,
                accuracy: tamilAccuracy,
                icon: Icons.translate_rounded,
                color: Colors.blue,
              ),
              _buildCategoryProgress(
                context,
                categoryKey: "general_studies",
                correct: gsCorrect,
                total: gsTotal,
                accuracy: gsAccuracy,
                icon: Icons.school_rounded,
                color: Colors.purple,
              ),
              _buildCategoryProgress(
                context,
                categoryKey: "aptitude",
                correct: aptitudeCorrect,
                total: aptitudeTotal,
                accuracy: aptitudeAccuracy,
                icon: Icons.calculate_rounded,
                color: Colors.orange,
              ),

              if (recommendation.isNotEmpty) ...[
                const Divider(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: (lowestPercent < 75 ? Colors.orange : Colors.green).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: (lowestPercent < 75 ? Colors.orange : Colors.green).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        lowestPercent < 75 ? Icons.lightbulb_outline_rounded : Icons.emoji_events_outlined, 
                        color: lowestPercent < 75 ? Colors.orange : Colors.green, 
                        size: 24
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          recommendation,
                          style: AppTheme.getStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: lowestPercent < 75 ? Colors.orange.shade800 : Colors.green.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 24),
              
              // Close Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.white12 : Colors.grey.shade100,
                    foregroundColor: isDark ? Colors.white : AppTheme.textMainColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  child: Text(
                    isTamil ? "மூடு" : "Close",
                    style: AppTheme.getStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
