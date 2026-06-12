import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/subject.dart';
import '../utils/app_theme.dart';
import 'package:tnpsc_group_book/utils/app_language.dart';
import '../services/notification_service.dart';
import '../services/firestore_service.dart';
import '../services/hive_service.dart';
import 'quiz_screen.dart';
import 'sub_topic_screen.dart';
import 'mock_test_screen.dart';
import 'mistake_bank_screen.dart';
import 'bookmark_screen.dart';
import 'history_screen.dart';
import 'ai_smart_prep_screen.dart';
import 'ai_tutor_screen.dart';
import 'topic_detail_screen.dart';
import 'leaderboard_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/ad_banner.dart';
import '../services/version_service.dart';
import '../services/tts_service.dart';
import 'room_setup_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      VersionService.checkForUpdate(context);
      _firestoreService.updateStreak();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLanguage.languageNotifier,
      builder: (context, lang, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            child: FutureBuilder<DocumentSnapshot?>(
              future: _firestoreService.getUserData(),
              builder: (context, snapshot) {
                String userName = AppLanguage.getString('user_fallback');
                int streak = 0;
                int totalPoints = 0;

                if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
                  var data = snapshot.data!.data() as Map<String, dynamic>;
                  userName = data['name'] ?? AppLanguage.getString('user_fallback');
                  streak = data['streak'] ?? 0;
                  totalPoints = data['totalScore'] ?? 0;
                } else {
                  var cachedData = HiveService.getCachedUserData();
                  if (cachedData != null) {
                    userName = cachedData['name'] ?? AppLanguage.getString('user_fallback');
                    streak = cachedData['streak'] ?? 0;
                    totalPoints = cachedData['totalScore'] ?? 0;
                  }
                }

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Section (Greeting & Stats)
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${AppLanguage.getString('greeting')}, \n$userName! 👋",
                                    style: AppTheme.getStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? AppTheme.secondaryColor : AppTheme.textMainColor,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    AppLanguage.getString('ready_to_crack'),
                                    style: AppTheme.getStyle(
                                      fontSize: 14,
                                      color: isDark ? Colors.white70 : AppTheme.textSecondaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _buildHeaderStat(
                                  icon: Icons.local_fire_department_rounded,
                                  label: "$streak ${AppLanguage.getString('days')}",
                                  colors: [Colors.orange, Colors.deepOrange],
                                ),
                                const SizedBox(height: 12),
                                ValueListenableBuilder(
                                    valueListenable: Hive.box(
                                      HiveService.userBoxName,
                                    ).listenable(),
                                    builder: (context, box, child) {
                                      int points =
                                      box.get('totalScore', defaultValue: 0) as int;
                                      return _buildHeaderStat(
                                        icon: Icons.stars_rounded,
                                        label: "$points pts",
                                        colors: [Colors.blue, Colors.indigo],
                                      );})
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Listening Now Mini Player
                      ValueListenableBuilder<String?>(
                        valueListenable: TtsService.currentTextNotifier,
                        builder: (context, playingText, _) {
                          if (playingText == null) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            child: _buildMiniPlayer(context, playingText, isDark),
                          );
                        },
                      ),

                      // Main Content
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Daily Quiz Highlight
                            _buildDailyQuizCard(context, isDark),
                            const SizedBox(height: 32),
                            Row(
                                  children: [
                                    _buildQuickActionCard(context, title: AppLanguage.getString('mistake_bank'), icon: "📝", color: Colors.orange, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MistakeBankScreen()))),
                                    const SizedBox(width: 12),
                                    _buildQuickActionCard(context, title: AppLanguage.getString('saved_quizzes'), icon: "🔖", color: Colors.indigo, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BookmarkScreen()))),
                                    const SizedBox(width: 12),
                                    _buildQuickActionCard(context, title: AppLanguage.getString('group_test_lobby'), icon: "👥", color: Colors.green, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RoomSetupScreen()))),
                                  ],
                                ),
                            const SizedBox(height: 32),

                            // Smart Weak Area Analysis Card
                            _buildSmartWeakAreaAnalysis(context, isDark),

                            const SizedBox(height: 50),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildMiniPlayer(BuildContext context, String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor.withOpacity(0.8), AppTheme.primaryColor],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.spatial_audio_off_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLanguage.getString('listening_now'),
                  style: GoogleFonts.outfit(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => TtsService.stop(),
            icon: const Icon(Icons.stop_circle_rounded, color: Colors.white, size: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStat({required IconData icon, required String label, required List<Color> colors}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: colors.first.withOpacity(0.3), blurRadius: 8)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyQuizCard(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [isDark ? AppTheme.primaryColor : AppTheme.primaryColorLight, isDark ? AppTheme.secondaryColor : AppTheme.secondaryColorLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("🧠", style: TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  AppLanguage.getString('daily_quiz'),
                  style: AppTheme.getStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            AppLanguage.getString('today_quiz_ready'),
            style: AppTheme.getStyle(color: Colors.white.withOpacity(0.9), fontSize: 15),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: HiveService.isDailyQuizDone()
                ? null
                : () async {
                    if (await VersionService.isUpdateRequired()) {
                      if (context.mounted) VersionService.showUpdateDialogIfNeeded(context);
                      return;
                    }
                    if (context.mounted) {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => QuizScreen(subjectTitle: AppLanguage.getString('daily_quiz')))).then((_) => setState(() {}));
                    }
                  },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 5,
              ),
              child: Text(
                HiveService.isDailyQuizDone() ? AppLanguage.getString('completed') : AppLanguage.getString('start_quiz'),
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildHorizontalExamCard(BuildContext context, String key, String icon, Color color) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => MockTestScreen(category: key))),
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark 
              ? [color.withOpacity(0.2), color.withOpacity(0.4)]
              : [color.withOpacity(0.7), color],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Text(icon, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(height: 8),
            Text(
              AppLanguage.getString(key),
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(BuildContext context, {required String title, required String icon, required Color color, required VoidCallback onTap}) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? color.withOpacity(0.15) : color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTheme.getStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : color.darken(),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMasteryList(BuildContext context, bool isDark) {
    return FutureBuilder<Map<String, double>>(
      future: _firestoreService.getMasteryData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(20.0),
            child: CircularProgressIndicator(),
          ));
        }

        final mastery = snapshot.data ?? {};
        
        // Use tnpscSubjects list to ensure real data matches our app's categories
        final displaySubjects = tnpscSubjects.where((s) => mastery.containsKey(s.titleEn) || mastery.containsKey(s.titleTa) || mastery.containsKey(s.id)).toList();

        if (displaySubjects.isEmpty && mastery.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
            ),
            child: Text(
              AppLanguage.getString('no_mastery_data') ?? "Complete quizzes to see your mastery progress!",
              textAlign: TextAlign.center,
              style: AppTheme.getStyle(color: Colors.grey, fontSize: 14),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Show top 6 subjects from our list
              ...tnpscSubjects.take(6).map((subject) {
                // Try to find mastery by English title, Tamil title, or ID
                double progress = mastery[subject.titleEn] ?? mastery[subject.titleTa] ?? mastery[subject.id] ?? 0.0;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () => openSubject(context, subject),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: _buildMasteryRow(subject.title, progress, subject.color),
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSmartWeakAreaAnalysis(BuildContext context, bool isDark) {
    bool isTamil = AppLanguage.languageNotifier.value == 'ta';
    
    final tamilPerf = HiveService.getCategoryPerformance('general_tamil');
    final gsPerf = HiveService.getCategoryPerformance('general_studies');
    final aptitudePerf = HiveService.getCategoryPerformance('aptitude');

    if (tamilPerf['total'] == 0 && gsPerf['total'] == 0 && aptitudePerf['total'] == 0) {
      return const SizedBox.shrink();
    }

    // Determine weakest area
    String weakestCategory = "";
    double lowestPercent = 101;

    void checkWeakest(String key, Map<String, dynamic> perf) {
      if (perf['total'] > 0) {
        double correctPercent = perf['correctPercent'];
        if (correctPercent < lowestPercent) {
          lowestPercent = correctPercent;
          weakestCategory = key;
        }
      }
    }

    checkWeakest("general_tamil", tamilPerf);
    checkWeakest("general_studies", gsPerf);
    checkWeakest("aptitude", aptitudePerf);

    String recommendation = "";
    if (weakestCategory.isNotEmpty && lowestPercent < 75) {
      String catName = "";
      if (weakestCategory == 'general_tamil') catName = isTamil ? 'பொது தமிழ்' : 'General Tamil';
      else if (weakestCategory == 'general_studies') catName = isTamil ? 'பொது அறிவு' : 'General Studies';
      else if (weakestCategory == 'aptitude') catName = isTamil ? 'கணிதத் திறன்' : 'Aptitude';

      recommendation = AppLanguage.getString('focus_recommendation').replaceAll('{category}', catName);
    } else if (lowestPercent >= 75) {
      recommendation = AppLanguage.getString('excellent_work');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Strength Insights
        Text(
          AppLanguage.getString('your_strength'),
          style: AppTheme.getStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? AppTheme.secondaryColor : AppTheme.textMainColor),
        ),
        const SizedBox(height: 16),
        // Group the progress items one-by-one with clear separation
        _buildHomeCategoryProgress(
          context,
          categoryKey: "general_tamil",
          correct: tamilPerf['correct']!,
          total: tamilPerf['total']!,
          icon: Icons.translate_rounded,
          color: Colors.blue,
        ),
        _buildHomeCategoryProgress(
          context,
          categoryKey: "general_studies",
          correct: gsPerf['correct']!,
          total: gsPerf['total']!,
          icon: Icons.school_rounded,
          color: Colors.purple,
        ),
        _buildHomeCategoryProgress(
          context,
          categoryKey: "aptitude",
          correct: aptitudePerf['correct']!,
          total: aptitudePerf['total']!,
          icon: Icons.calculate_rounded,
          color: Colors.orange,
        ),
        
        if (recommendation.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: (lowestPercent < 75 ? Colors.orange : Colors.green).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: (lowestPercent < 75 ? Colors.orange : Colors.green).withValues(alpha: 0.2)),
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
      ],
    );
  }

  Widget _buildHomeCategoryProgress(
    BuildContext context, {
    required String categoryKey,
    required int correct,
    required int total,
    required IconData icon,
    required Color color,
  }) {
    // If there are no attempts, hide the widget.
    if (total == 0) return const SizedBox.shrink();

    bool isDark = Theme.of(context).brightness == Brightness.dark;
    bool isTamil = AppLanguage.languageNotifier.value == 'ta';

    // Calculate stats
    int attempted = total;
    int wrong = attempted - correct;
    double correctPercentage = attempted > 0 ? (correct / attempted) * 100 : 0;
    double wrongPercentage = attempted > 0 ? (wrong / attempted) * 100 : 0;

    // Determine progress color based on overall accuracy (same as before)
    double accuracy = correctPercentage;
    Color progressColor = Colors.redAccent;
    if (accuracy >= 75) {
      progressColor = Colors.green;
    } else if (accuracy >= 50) {
      progressColor = Colors.orange;
    }

    // Category name localization
    String categoryName = "";
    if (categoryKey == 'general_tamil')
      categoryName = isTamil ? 'பொது தமிழ்' : 'General Tamil';
    else if (categoryKey == 'general_studies')
      categoryName = isTamil ? 'பொது அறிவு' : 'General Studies';
    else if (categoryKey == 'aptitude')
      categoryName = isTamil ? 'கணிதத் திறன் & மனத்திறன்' : 'Aptitude & Mental Ability';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(24),
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
                    child: Icon(icon, color: color, size: 18),
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
                      // maxLines: 1,
                      // overflow: TextOverflow.ellipsis,
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
              const SizedBox(height: 12),
              // Sub-info row (Optional detail)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isTamil ? "$correct / $total சரி" : "$correct / $total Correct",
                    style: AppTheme.getStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                  Text(
                    isTamil ? "$wrong தவறு" : "$wrong Wrong",
                    style: AppTheme.getStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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

  Widget _buildMasteryRow(String label, double targetProgress, Color color) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: targetProgress),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    label, 
                    style: AppTheme.getStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text("${(value * 100).toInt()}%", style: AppTheme.getStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value,
                backgroundColor: color.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 8,
              ),
            ),
          ],
        );
      },
    );
  }
}

void openSubject(BuildContext context, Subject subject) {
  if (subject.topics.isNotEmpty) {
    showSubjectTopicsBottomSheet(context, subject);
  } else {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TopicDetailScreen(
          topic: subject.title,
          category: "General",
        ),
      ),
    );
  }
}

void showSubjectTopicsBottomSheet(BuildContext context, Subject subject) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      bool isDark = Theme.of(context).brightness == Brightness.dark;
      
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.glassWhite(context),
              border: Border(
                top: BorderSide(color: AppTheme.glassBorder(context), width: 0),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        subject.title,
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppTheme.textMainColor,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: isDark ? Colors.white : Colors.black),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  AppLanguage.getString('select_category'),
                  style: AppTheme.getStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white70 : AppTheme.textSecondaryColor,
                  ),
                ),
                const SizedBox(height: 24),
                ...subject.topics.asMap().entries.map((entry) {
                  int idx = entry.key;
                  String topic = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        if (subject.getSubTopics(idx).isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SubTopicScreen(subject: subject, topicIndex: idx),
                            ),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TopicDetailScreen(
                                topic: topic,
                                category: subject.title,
                              ),
                            ),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: subject.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: subject.color.withOpacity(0.2), width: 1),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                topic,
                                style: AppTheme.getStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : AppTheme.textMainColor,
                                ),
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios_rounded, color: subject.color, size: 18),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _SubjectCard extends StatelessWidget {
  final Subject subject;
  const _SubjectCard({required this.subject});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => openSubject(context, subject),
      borderRadius: BorderRadius.circular(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.glassWhite(context),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.glassBorder(context), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: subject.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(subject.icon, color: subject.color, size: 28),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        subject.title,
                        textAlign: TextAlign.center,
                        style: AppTheme.getStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppTheme.textMainColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subject.subtitle,
                        textAlign: TextAlign.center,
                        style: AppTheme.getStyle(
                          fontSize: 12,
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : AppTheme.textSecondaryColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  final String title;
  final String subject;
  final String edition;

  const _BookCard({
    required this.title,
    required this.subject,
    required this.edition,
  });

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                width: 1,
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    Icons.auto_stories_rounded,
                    size: 60,
                    color: isDark ? Colors.white24 : Colors.black12,
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white : Colors.black,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "PDF",
                      style: GoogleFonts.outfit(
                        color: isDark ? Colors.black : Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subject,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: isDark ? Colors.white60 : Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            edition,
            style: GoogleFonts.outfit(
              fontSize: 10,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }
}

extension ColorExtension on Color {
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsv = HSVColor.fromColor(this);
    final hsvDark = hsv.withValue((hsv.value - amount).clamp(0.0, 1.0));
    return hsvDark.toColor();
  }
}
