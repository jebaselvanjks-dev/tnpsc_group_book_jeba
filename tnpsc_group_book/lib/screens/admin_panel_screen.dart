import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/ai_service.dart';
import '../utils/app_theme.dart';
import '../utils/app_language.dart';

import 'admin_feedback_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  bool _isGenerating = false;
  String _currentStatus = "";

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: isDark ? Colors.white : AppTheme.textMainColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Admin Dashboard"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Management Tools",
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // AI Tool Card
            _buildAdminCard(
              context,
              title: "AI & System Tools",
              icon: Icons.settings_suggest_rounded,
              color: Colors.blue,
              onTap: () {},
              extra: Column(
                children: [
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      var box = Hive.box('user_data');
                      String today = DateTime.now().toString().split(' ')[0];
                      await box.put('ai_usage_$today', 0);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("AI Usage Reset for Today!")),
                      );
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text("Reset AI Usage Limit"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.withOpacity(0.1),
                      foregroundColor: Colors.blue,
                      elevation: 0,
                      minimumSize: const Size(double.infinity, 45),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Bulk 7‑day Quizzes
            _buildAdminCard(
              context,
              title: "Bulk Generate 7 Days Quizzes",
              icon: Icons.date_range_rounded,
              color: Colors.orange,
              onTap: _showBulkQuizGenDialog,
            ),
            const SizedBox(height: 12),
            // Bulk 3‑day Quizzes (50‑question each)
            _buildAdminCard(
              context,
              title: "Bulk Generate 5 Days 50‑Question Quizzes",
              icon: Icons.auto_awesome_motion_rounded,
              color: Colors.deepPurple,
              onTap: _showBulk5DaysQuizGenDialog,
            ),
            const SizedBox(height: 12),
            // Manual Content placeholder
            _buildAdminCard(
              context,
              title: "Manual Content",
              icon: Icons.edit_note_rounded,
              color: Colors.green,
              onTap: () {
                // TODO: navigate to manual content editor
              },
            ),
            const SizedBox(height: 12),
            // User Feedbacks
            _buildAdminCard(
              context,
              title: "User Feedbacks",
              icon: Icons.feedback_outlined,
              color: Colors.teal,
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminFeedbackScreen()));
              },
            ),
            if (_isGenerating) ...[
              const SizedBox(height: 24),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Text(_currentStatus,
                  style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAdminCard(BuildContext context,
      {required String title,
      required IconData icon,
      required Color color,
      required VoidCallback onTap,
      Widget? extra}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                ],
              ),
              if (extra != null) extra,
            ],
          ),
        ),
      ),
    );
  }

  // ────── Dialogs ──────

  void _showBulkQuizGenDialog() async {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(AppLanguage.languageNotifier.value == 'ta' ? '7 நாட்களுக்கான வினாக்கள் உருவாகின்றன...' : 'Generating 7 days of quizzes...'),
                ],
              ),
            ),
          ),
        ),
      );

      try {
        int successCount = 0;
        for (int i = 0; i < 7; i++) {
          DateTime targetDate = DateTime.now().add(Duration(days: i));
          String dateStr = DateFormat('yyyy-MM-dd').format(targetDate);

          final db = FirebaseFirestore.instance;
          final existing = await db.collection('quizzes')
              .where('date', isEqualTo: dateStr)
              .where('type', isEqualTo: 'daily_quiz')
              .get();

          if (existing.docs.isEmpty) {
            bool success = await AiService.generateAndSaveDailyQuiz(targetDate);
            if (success) successCount++;
            // Rate limit தவிர்க்க சிறிய இடைவெளி
            await Future.delayed(const Duration(seconds: 5));
          } else {
            successCount++; // ஏற்கனவே இருப்பதால் வெற்றியாகக் கருதப்படும்
          }
        }

        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLanguage.getString('gen_success_count').replaceAll('{count}', successCount.toString())),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("${AppLanguage.getString('error_prefix')}: $e"), backgroundColor: Colors.red),
          );
        }
      }
  }

  void _showBulk5DaysQuizGenDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Bulk Generate 5 Days Quizzes"),
        content: const Text(
            "This will generate 50‑question quizzes for the next 5 scheduled dates. It will also check and regenerate if any of these dates have fewer than 50 questions."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _startBulk5DaysQuizGeneration();
            },
            child: const Text("Start"),
          ),
        ],
      ),
    );
  }

  // ────── Bulk Generation Logic ──────

  Future<void> _startBulkQuizGeneration() async {
    setState(() {
      _isGenerating = true;
      _currentStatus = "Fetching latest quiz date...";
    });

    try {
      // Get most recent quiz date
      final latestQuery = await FirebaseFirestore.instance
          .collection('quizzes')
          .orderBy('date', descending: true)
          .limit(1)
          .get();

      DateTime startDate = DateTime.now();
      if (latestQuery.docs.isNotEmpty) {
        String latestDateStr = latestQuery.docs.first.get('date');
        startDate = DateFormat('yyyy-MM-dd').parse(latestDateStr);
      }

      // Existing dates to avoid duplicates
      final existingSnap = await FirebaseFirestore.instance
          .collection('quizzes')
          .where('date', isGreaterThanOrEqualTo: DateFormat('yyyy-MM-dd').format(startDate))
          .get();
      final existingDates = existingSnap.docs.map((d) => d.get('date') as String).toSet();

      // Determine next 7 dates starting from the day after latest quiz
      List<DateTime> nextDates = [];
      DateTime checkDate = startDate;
      while (nextDates.length < 7) {
        checkDate = checkDate.add(const Duration(days: 1));
        nextDates.add(checkDate);
      }

      // Generate quizzes for each date
      for (int i = 0; i < nextDates.length; i++) {
        DateTime date = nextDates[i];
        String dateStr = DateFormat('yyyy-MM-dd').format(date);

        // Tamil Eligibility – 10 per day (20 questions each)
        for (int t = 0; t < 10; t++) {
          setState(() {
            _currentStatus = "Generating Tamil Quiz ${t + 1}/10 for $dateStr (Day ${i + 1}/7)...";
          });
          debugPrint("[BulkGen] Starting Tamil quiz ${t + 1}/10 for $dateStr");
          bool success = await AiService.generateScheduledQuiz(date, 'general_tamil', count: 20, setIndex: t + 1);
          if (!success) {
            // Try one retry
            success = await AiService.generateScheduledQuiz(date, 'general_tamil', count: 20, setIndex: t + 1);
          }
          if (!success) {
            _handleFailure(dateStr, "Tamil Quiz ${t + 1}");
            return;
          }
        }

        // General Studies – 6 per day (20 questions each)
        for (int g = 0; g < 6; g++) {
          setState(() {
            _currentStatus = "Generating GS Quiz ${g + 1}/6 for $dateStr (Day ${i + 1}/7)...";
          });
          debugPrint("[BulkGen] Starting GS quiz ${g + 1}/6 for $dateStr");
          bool success = await AiService.generateScheduledQuiz(date, 'general_studies', count: 20, setIndex: g + 1);
          if (!success) {
            success = await AiService.generateScheduledQuiz(date, 'general_studies', count: 20, setIndex: g + 1);
          }
          if (!success) {
            _handleFailure(dateStr, "GS Quiz ${g + 1}");
            return;
          }
        }

        // Aptitude & Mental Ability – 4 per day (20 questions each)
        for (int a = 0; a < 4; a++) {
          setState(() {
            _currentStatus = "Generating Aptitude Quiz ${a + 1}/4 for $dateStr (Day ${i + 1}/7)...";
          });
          debugPrint("[BulkGen] Starting Aptitude quiz ${a + 1}/4 for $dateStr");
          bool success = await AiService.generateScheduledQuiz(date, 'aptitude', count: 20, setIndex: a + 1);
          if (!success) {
            success = await AiService.generateScheduledQuiz(date, 'aptitude', count: 20, setIndex: a + 1);
          }
          if (!success) {
            _handleFailure(dateStr, "Aptitude Quiz ${a + 1}");
            return;
          }
        }
      }

      setState(() {
        _isGenerating = false;
        _currentStatus = "Successfully generated 7 days of scheduled quizzes!";
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Bulk quiz generation completed successfully!")));
    } catch (e) {
      setState(() {
        _isGenerating = false;
        _currentStatus = "Error: $e";
      });
      print("AI_DEBUG: Bulk Generation Error: $e");
    }
  }

  Future<void> _startBulk5DaysQuizGeneration() async {
    setState(() {
      _isGenerating = true;
      _currentStatus = "Checking existing mock quizzes...";
    });

    try {
      // Find the next 3 scheduled dates starting from today
      List<DateTime> nextDates = [];
      DateTime checkDate = DateTime.now();
      
      bool isScheduledDay(DateTime d) =>
          d.weekday == DateTime.sunday ||
          d.weekday == DateTime.tuesday ||
          d.weekday == DateTime.thursday ||
          d.weekday == DateTime.saturday;

      while (nextDates.length < 5) {
        if (isScheduledDay(checkDate)) {
          nextDates.add(checkDate);
        }
        checkDate = checkDate.add(const Duration(days: 1));
      }

      // Process each date
      for (int i = 0; i < nextDates.length; i++) {
        DateTime date = nextDates[i];
        String dateStr = DateFormat('yyyy-MM-dd').format(date);
        
        // 1. Check if quiz exists and has at least 50 questions
        final querySnap = await FirebaseFirestore.instance
            .collection('mock_tests')
            .where('date', isEqualTo: dateStr)
            .where('quizType', isEqualTo: 'daily_50_quiz')
            .get();

        bool needsGeneration = true;
        if (querySnap.docs.isNotEmpty) {
          List questions = querySnap.docs.first.get('questions') ?? [];
          if (questions.length >= 50) {
            needsGeneration = false;
            debugPrint("[BulkGen] $dateStr already has ${questions.length} questions. Skipping.");
          } else {
            debugPrint("[BulkGen] $dateStr has only ${questions.length} questions. Regenerating...");
          }
        }

        if (needsGeneration) {
          setState(() {
            _currentStatus = "Generating 50‑Question Quiz for $dateStr (Quiz ${i + 1}/5)...";
          });
          
          bool success = await AiService.generateAndSaveMockQuiz(date);
          
          if (!success) {
            // Retry once if failed
            debugPrint("[BulkGen] Failed first attempt for $dateStr. Retrying...");
            success = await AiService.generateAndSaveMockQuiz(date);
          }

          if (!success) {
            _handleFailure(dateStr, "50‑question mock quiz");
            return;
          }
        }
      }

      setState(() {
        _isGenerating = false;
        _currentStatus = "Successfully verified and generated 5 days of 50‑question quizzes!";
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Bulk 5‑day quiz generation completed successfully!")));
    } catch (e) {
      setState(() {
        _isGenerating = false;
        _currentStatus = "Error: $e";
      });
      print("AI_DEBUG: Bulk 5‑day Generation Error: $e");
    }
  }

  void _handleFailure(String dateStr, String quizType) {
    setState(() {
      _isGenerating = false;
      _currentStatus = "Generation failed on $quizType $dateStr.";
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text("Failed to generate $quizType for $dateStr")));
  }
}
