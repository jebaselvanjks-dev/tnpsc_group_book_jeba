import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/question.dart';
import '../utils/app_theme.dart';
import '../utils/app_language.dart';

class WeakAreaScreen extends StatelessWidget {
  final List<Question> questions;
  final List<int?> selectedAnswers;

  const WeakAreaScreen({
    Key? key,
    required this.questions,
    required this.selectedAnswers,
  }) : super(key: key);

  // Compute wrong answer counts per subject
  Map<String, int> _computeWeakCounts() {
    final Map<String, int> counts = {};
    for (int i = 0; i < questions.length; i++) {
      final int? selected = selectedAnswers[i];
      if (selected == null || selected != questions[i].correctOptionIndex) {
        final String subject = questions[i].subject ?? 'General';
        counts[subject] = (counts[subject] ?? 0) + 1;
      }
    }
    return counts;
  }

  List<BarChartGroupData> _buildBarGroups(Map<String, int> data) {
    final List<String> subjects = data.keys.toList();
    return List.generate(subjects.length, (index) {
      final String subject = subjects[index];
      final int value = data[subject] ?? 0;
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: value.toDouble(),
            color: AppTheme.primaryColor,
            width: 20,
            borderRadius: BorderRadius.zero,
          ),
        ],
        showingTooltipIndicators: const [0],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, int> weakCounts = _computeWeakCounts();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final List<String> subjects = weakCounts.keys.toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: isDark ? Colors.white : AppTheme.textMainColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Smart Weak Area Analysis'),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: weakCounts.isEmpty
            ? Center(
                child: Text(
                  AppLanguage.getString('none') ?? 'None',
                  style: GoogleFonts.outfit(fontSize: 18),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'முன்னிலை அறிய வேண்டிய பகுதிகள்',
                    style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: subjects.length,
                      itemBuilder: (context, index) {
                        final String subject = subjects[index];
                        final int count = weakCounts[subject] ?? 0;
                        final int maxCount = weakCounts.values.reduce((a, b) => a > b ? a : b);
                        final double progress = maxCount == 0 ? 0 : count / maxCount;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                subject,
                                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              LinearProgressIndicator(
                                value: progress,
                                backgroundColor: isDark ? Colors.white10 : Colors.grey.shade300,
                                color: AppTheme.primaryColor,
                                minHeight: 12,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Wrong answers: $count',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'மொத்த தவறுகள்: ${weakCounts.values.reduce((a, b) => a + b)}',
                    style: GoogleFonts.outfit(fontSize: 16),
                  ),
                ],
              ),
      ),
    );
  }
}
