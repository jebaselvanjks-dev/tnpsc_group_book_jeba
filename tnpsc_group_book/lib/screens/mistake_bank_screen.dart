import 'package:flutter/material.dart';

import 'package:tnpsc_group_book/services/tts_service.dart';
import '../models/question.dart';
import '../services/firestore_service.dart';
import '../utils/app_theme.dart';
import '../utils/app_icons.dart';
import '../utils/app_language.dart';
import 'quiz_screen.dart';

class MistakeBankScreen extends StatefulWidget {
  const MistakeBankScreen({super.key});

  @override
  State<MistakeBankScreen> createState() => _MistakeBankScreenState();
}

class _MistakeBankScreenState extends State<MistakeBankScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = true;
  List<Question> _mistakes = [];

  @override
  void initState() {
    super.initState();
    _loadMistakes();
  }

  Future<void> _loadMistakes() async {
    setState(() => _isLoading = true);
    final mistakes = await _firestoreService.getMistakes();
    setState(() {
      _mistakes = mistakes;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: AppIcon(AppIcons.back, color: isDark ? Colors.white : AppTheme.textMainColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLanguage.getString('mistake_bank'),style: AppTheme.getStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          // IconButton(
          //   icon: Icon(TtsService.currentTextNotifier.value == "mistake_bank_all" ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded, color: AppTheme.secondaryColor),
          //   onPressed: () async {
          //     if (TtsService.currentTextNotifier.value == "mistake_bank_all") {
          //       TtsService.stop();
          //     } else {
          //       TtsService.stop();
          //       String fullText = "";
          //       for (var q in _mistakes) {
          //         fullText += q.question + ". Correct Answer is " + q.options[q.correctOptionIndex] + ". ";
          //       }
          //       TtsService.speak(fullText);
          //       // Tag it so we can show stop icon
          //       TtsService.currentTextNotifier.value = "mistake_bank_all";
          //     }
          //     setState(() {});
          //   },
          // )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _mistakes.isEmpty
              ? _buildEmptyState(isDark)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                  itemCount: _mistakes.length,
                  physics: const BouncingScrollPhysics(),
                  itemBuilder: (context, index) {
                    final q = _mistakes[index];
                    return _buildMistakeCard(q, isDark);
                  },
                ),
      bottomNavigationBar: !_isLoading && _mistakes.isNotEmpty
          ? Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              decoration: BoxDecoration(
                color: isDark ? Colors.black : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  )
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => QuizScreen(
                        subjectTitle: AppLanguage.getString('mistake_bank'),
                      ),
                    ),
                  ).then((_) => _loadMistakes());
                },
                icon: const AppIcon(AppIcons.play, color: Colors.white),
                label: Text(
                  AppLanguage.getString('reattempt_all'),
                  textAlign: TextAlign.center,
                  style: AppTheme.getStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade800,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 100),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("🎉", style: AppTheme.getStyle(fontSize: 64)),
            const SizedBox(height: 24),
            Text(
              AppLanguage.getString('no_mistakes_title'),
              textAlign: TextAlign.center,
              style: AppTheme.getStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.textMainColor),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                AppLanguage.getString('no_mistakes_desc'),
                textAlign: TextAlign.center,
                style: AppTheme.getStyle(fontSize: 15, color: isDark ? Colors.white60 : Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMistakeCard(Question q, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
        boxShadow: isDark ? [] : [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            q.question.replaceAll('?', '?\n'),
            style: AppTheme.getStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppTheme.textMainColor),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const AppIcon(AppIcons.check, color: Colors.green, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "${AppLanguage.getString('correct_answer')}: ${q.options[q.correctOptionIndex]}",
                    style: AppTheme.getStyle(fontSize: 14, color: isDark ? Colors.green.shade200 : Colors.green.shade800, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
