import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/ai_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../models/subject.dart';
import '../utils/app_theme.dart';
import 'package:tnpsc_group_book/utils/app_language.dart';
import '../services/notification_service.dart';
import '../services/firestore_service.dart';
import '../services/hive_service.dart';
import 'topic_detail_screen.dart';
import 'sub_topic_screen.dart';
import 'mock_test_screen.dart';
import 'mistake_bank_screen.dart';
import 'bookmark_screen.dart';
import 'history_screen.dart';
import 'ai_smart_prep_screen.dart';
import 'ai_tutor_screen.dart';
import 'quiz_screen.dart';
import 'leaderboard_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/ad_banner.dart';
import '../services/version_service.dart';

class SubjectScreen extends StatefulWidget {
  const SubjectScreen({super.key});

  @override
  State<SubjectScreen> createState() => _SubjectScreenState();
}

class _SubjectScreenState extends State<SubjectScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  bool get _isQuizDay {
    final now = DateTime.now();
    return now.weekday == DateTime.sunday ||
           now.weekday == DateTime.tuesday ||
           now.weekday == DateTime.thursday ||
           now.weekday == DateTime.saturday;
  }

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
        
        return SafeArea(
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

                return Scaffold(
                  body: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Stats Row
                        Padding(
                          padding: const EdgeInsets.only(left: 20.0, right: 20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${AppLanguage.getString('greeting')}, $userName!  👋",
                                style: AppTheme.getStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : AppTheme.textMainColor,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 5),
                                child: Text(
                                  AppLanguage.getString('ready_to_crack'),
                                  style: AppTheme.getStyle(
                                    fontSize: 16,
                                    color: isDark ? Colors.white70 : AppTheme.textSecondaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Reward points display
                        // Padding(
                        //   padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
                        //   child: ValueListenableBuilder(
                        //     valueListenable: Hive.box(HiveService.userBoxName).listenable(),
                        //     builder: (context, box, child) {
                        //       int points = box.get('totalScore', defaultValue: 0) as int;
                        //       return Row(
                        //         children: [
                        //           Icon(Icons.star, color: Colors.amber),
                        //           const SizedBox(width: 6),
                        //           Text('${AppLanguage.getString('points')}: $points',
                        //             style: AppTheme.getStyle(
                        //               fontSize: 16,
                        //               fontWeight: FontWeight.bold,
                        //               color: isDark ? Colors.white : AppTheme.textMainColor,
                        //             ),
                        //           ),
                        //         ],
                        //       );
                        //     },
                        //   ),
                        // ),
                        const SizedBox(height: 2),
                        Divider(endIndent: 20, indent: 20, color: isDark ? Colors.white : AppTheme.textMainColor, thickness: 0.25),

                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.only(left: 20.0,right: 20),
                          child: _buildMockCard(context),
                        ),
                        // // Horizontal Scroll Highlight (Exam Categories)
                        // Padding(
                        //   padding: const EdgeInsets.symmetric(horizontal: 20),
                        //   child: Text(
                        //     AppLanguage.getString('old_test_papers'),
                        //     style: AppTheme.getStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.textMainColor),
                        //   ),
                        // ),
                        // const SizedBox(height: 16),
                        //
                        // SizedBox(
                        //   height: 110,
                        //   child: ListView(
                        //     scrollDirection: Axis.horizontal,
                        //     padding: const EdgeInsets.symmetric(horizontal: 20),
                        //     physics: const BouncingScrollPhysics(),
                        //     children: [
                        //       _buildHorizontalExamCard(context, "tnpsc", "📜", Colors.indigo),
                        //       _buildHorizontalExamCard(context, "trb", "🎓", Colors.teal),
                        //       _buildHorizontalExamCard(context, "tet", "📝", Colors.orange),
                        //       _buildHorizontalExamCard(context, "net", "🌐", Colors.blue),
                        //       _buildHorizontalExamCard(context, "set", "🏛️", Colors.purple),
                        //       _buildHorizontalExamCard(context, "vao", "💼", Colors.brown),
                        //     ],
                        //   ),
                        // ),

                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
                          child: Text(
                            AppLanguage.getString('subjects'),
                            style: AppTheme.getStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? AppTheme.secondaryColor : AppTheme.textMainColor),
                          ),
                        ),

                        // Subjects Grid
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 1.0,
                            ),
                            itemCount: tnpscSubjects.length,
                            itemBuilder: (context, index) {
                              final subject = tnpscSubjects[index];
                              return AnimationConfiguration.staggeredGrid(
                                position: index,
                                duration: const Duration(milliseconds: 375),
                                columnCount: 2,
                                child: ScaleAnimation(
                                  child: FadeInAnimation(
                                    child: _SubjectCard(subject: subject),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 50),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
      },
    );
  }

  Widget _buildMockCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    bool _isQuizDay = const [2, 4, 6, 7].contains(DateTime.now().weekday);
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
            color: Colors.purple.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("🧠", style: TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  AppLanguage.getString('mock_quiz'),
                  style: AppTheme.getStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                margin: const EdgeInsets.only(left: 25, right: 25, top: 8),
                triggerMode: TooltipTriggerMode.tap,
                message: AppLanguage.languageNotifier.value == 'ta'
                    ? "வினாடி வினா அட்டவணை: ஞாயிறு, செவ்வாய், வியாழன், சனி"
                    : "Quiz Schedule: Sunday, Tuesday, Thursday, Saturday",
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: Colors.white70,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "${AppLanguage.getString('general_tamil')}  --->  25",
            style: AppTheme.getStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            "${AppLanguage.getString('general_studies')}  --->  15",
            style: AppTheme.getStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            "${AppLanguage.getString('aptitude')}  --->  10",
            style: AppTheme.getStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
          ),
          const SizedBox(height: 10),
          Text(
            AppLanguage.getString('mock_quiz_ready'),
            style: AppTheme.getStyle(color: Colors.white.withOpacity(0.9), fontSize: 15),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: !_isQuizDay || HiveService.isMockQuizDone()
                  ? null
                  : () => Navigator.push(context, MaterialPageRoute(builder: (context) => QuizScreen(subjectTitle: AppLanguage.getString('mock_quiz')))).then((_) => setState(() {})),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 5,
              ),
              child: Text(
                !_isQuizDay
                    ? (AppLanguage.languageNotifier.value == 'ta' ? "இன்று வினாடி வினா இல்லை" : "No Quiz Today")
                    : HiveService.isMockQuizDone()
                    ? AppLanguage.getString('completed')
                    : AppLanguage.getString('start_quiz'),
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          )
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
        boxShadow: [BoxShadow(color: colors.first.withAlpha(77), blurRadius: 8)],
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
              ? [color.withAlpha(51), color.withAlpha(102)]
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
          border: Border.all(color: Colors.white.withAlpha(26)),
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
}

class _SubjectCard extends StatelessWidget {
  final Subject subject;
  const _SubjectCard({required this.subject, Key? key}) : super(key: key);

  void _showTopicsBottomSheet(BuildContext context) {
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
                            fontSize: 16,
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
                  Flexible(
                    child: Text(
                      AppLanguage.getString('select_category'),
                      style: AppTheme.getStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white70 : AppTheme.textSecondaryColor,
                      ),
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
                          if (topic == 'இலக்கணம்1') {
                            // Directly open quiz for Grammar topic
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => QuizScreen(
                                  subjectTitle: subject.title,
                                  category: topic,
                                ),
                              ),
                            );
                          } else if (subject.getSubTopics(idx).isNotEmpty) {
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
                            color: subject.color.withAlpha(26),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: subject.color.withAlpha(51), width: 1),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  topic,
                                  style: AppTheme.getStyle(
                                    fontSize: 18,
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

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        if (subject.topics.isNotEmpty) {
          _showTopicsBottomSheet(context);
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
      },
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
                    color: subject.color.withAlpha(26),
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