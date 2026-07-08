import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/question.dart';
import '../utils/app_theme.dart';
import '../utils/app_language.dart';
import '../services/ai_service.dart';
import '../widgets/bilingual_text.dart';

class ReviewScreen extends StatelessWidget {
  final List<Question> questions;
  final List<int?> selectedAnswers;

  const ReviewScreen({
    super.key,
    required this.questions,
    required this.selectedAnswers,
  });

  // Helper to format bilingual text (English / Tamil)
  String _formatBilingual(String raw) {
    return AppLanguage.formatBilingual(raw);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLanguage.languageNotifier,
      builder: (context, lang, child) {
        bool isDark = Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_rounded, color: isDark ? Colors.white : AppTheme.textMainColor),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(AppLanguage.getString('review_answers'), style: AppTheme.getStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          body: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: questions.length,
            itemBuilder: (context, index) {
              final q = questions[index];
              final selectedIdx = selectedAnswers[index];
              final isCorrect = selectedIdx == q.correctOptionIndex;
              final isUnanswered = selectedIdx == null;

              return Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? Theme.of(context).cardColor : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question text with Status Icon
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isUnanswered 
                                ? Colors.orange.withOpacity(0.1) 
                                : (isCorrect ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1)),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isUnanswered 
                                ? Icons.horizontal_rule_rounded 
                                : (isCorrect ? Icons.check_rounded : Icons.close_rounded),
                            color: isUnanswered ? Colors.orange : (isCorrect ? Colors.green : Colors.red),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: BilingualText(
                            en: q.questionEn,
                            ta: q.questionTa,
                            legacy: q.question,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : AppTheme.textMainColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // Your Answer
                    if (!isUnanswered && !isCorrect) ...[
                      _buildAnswerRow(
                        context, 
                        AppLanguage.getString('your_answer'), 
                        selectedIdx!,
                        q,
                        Colors.red, 
                        Icons.cancel_rounded
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Correct Answer
                    _buildAnswerRow(
                      context, 
                      isCorrect ? AppLanguage.getString('your_answer_correct') : AppLanguage.getString('correct_answer_label'), 
                      q.correctOptionIndex,
                      q,
                      Colors.green, 
                      Icons.check_circle_rounded
                    ),

                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),

                    // Explanation
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lightbulb_outline_rounded, color: Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLanguage.getString('explanation'),
                                style: AppTheme.getStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              BilingualText(
                                en: q.explanationEn,
                                ta: q.explanationTa,
                                legacy: q.explanation,
                                fontSize: 14,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                              // const SizedBox(height: 12),
                              // TextButton.icon(
                              //   onPressed: () => _showAiExplanation(context, q),
                              //   icon: const Icon(Icons.auto_awesome, size: 16),
                              //   label: Text(AppLanguage.getString('ask_ai_explain')),
                              //   style: TextButton.styleFrom(
                              //     backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                              //     foregroundColor: AppTheme.primaryColor,
                              //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              //   ),
                              // ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showAiExplanation(BuildContext context, Question q) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      "AI Deep Insight",
                      style: AppTheme.getStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<String>(
                future: AiService.explainQuestion(q.question, q.options, q.options[q.correctOptionIndex]),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(AppLanguage.getString('ai_thinking')),
                        ],
                      ),
                    );
                  }
                  return SingleChildScrollView(
                    child: Text(
                      snapshot.data ?? "Failed to load explanation.",
                      style: AppTheme.getStyle(
                        fontSize: 16,
                        height: 1.6,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerRow(BuildContext context, String label, int optionIndex, Question q, Color color, IconData icon) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    String? optEn;
    String? optTa;
    if (q.optionsEn != null && optionIndex < q.optionsEn!.length) {
      optEn = q.optionsEn![optionIndex];
      optTa = q.optionsTa![optionIndex];
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTheme.getStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                BilingualText(
                  en: optEn,
                  ta: optTa,
                  legacy: q.options[optionIndex],
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
