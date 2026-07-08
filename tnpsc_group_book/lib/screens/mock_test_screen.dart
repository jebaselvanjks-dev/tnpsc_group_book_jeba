import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_theme.dart';
import '../utils/app_language.dart';
import '../services/hive_service.dart';
import 'quiz_screen.dart';
import '../services/version_service.dart';

class MockTestScreen extends StatelessWidget {
  final String? category;
  const MockTestScreen({super.key, this.category});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLanguage.languageNotifier,
      builder: (context, lang, child) {
        bool isDark = Theme.of(context).brightness == Brightness.dark;

        Query query = FirebaseFirestore.instance.collection('mock_tests');
        if (category != null) {
          query = query.where('category', isEqualTo: category);
        }
        query = query.orderBy('createdAt', descending: true);

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: isDark ? Colors.black : Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: isDark ? Colors.white : Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              category != null 
                  ? "${AppLanguage.getString(category!)} ${AppLanguage.getString('mock_tests_title')}"
                  : AppLanguage.getString('mock_tests_title'),
              style: AppTheme.getStyle(
                fontWeight: FontWeight.bold, fontSize: 18
              ),
            ),
            centerTitle: true,
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: query.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.assignment_late_outlined, size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        AppLanguage.getString('no_mock_tests'),
                        style: AppTheme.getStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              final tests = snapshot.data!.docs;
              final now = DateTime.now();

              return ListView.builder(
                padding: const EdgeInsets.all(24.0),
                itemCount: tests.length + 1,
                itemBuilder: (context, index) {
                  if (index == tests.length) return const SizedBox(height: 100);

                  final test = tests[index].data() as Map<String, dynamic>;
                  final title = test['title'] ?? AppLanguage.getString('mock_test');
                  final totalQ = test['totalQuestions'] ?? 50;
                  
                  final Timestamp? availableFromTs = test['availableFrom'];
                  final DateTime availableFrom = availableFromTs?.toDate() ?? now;
                  final DateTime expiryDate = availableFrom.add(const Duration(days: 3));

                  bool isLocked = now.isBefore(availableFrom);
                  bool isExpired = now.isAfter(expiryDate);
                  bool isAllowedDay = const [2, 4, 6, 7].contains(now.weekday);

                  String statusText = AppLanguage.getString('available');
                  
                  if (isLocked) {
                    int days = availableFrom.difference(now).inDays + 1;
                    statusText = AppLanguage.getString('unlocks_in').replaceAll('{days}', days.toString());
                  } else if (isExpired) {
                    statusText = AppLanguage.getString('previous_test');
                  } else {
                    int days = expiryDate.difference(now).inDays + 1;
                    statusText = AppLanguage.getString('active_now').replaceAll('{days}', days.toString());
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _buildMockTestBanner(
                      context, 
                      title, 
                      totalQ, 
                      statusText, 
                      isLocked,
                      isExpired
                    ),
                  );
                },
              );
            },
          ),
        );
      }
    );
  }

  Widget _buildMockTestBanner(
    BuildContext context, 
    String title, 
    int questionsCount, 
    String statusText, 
    bool isLocked,
    bool isExpired
  ) {
bool isAllowedDay = const [2, 4, 6, 7].contains(DateTime.now().weekday);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isLocked 
              ? [Colors.grey.shade600, Colors.grey.shade800] 
              : isExpired
                ? [Colors.blueGrey.shade400, Colors.blueGrey.shade600]
                : [Colors.purple.shade400, Colors.deepPurple.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (isLocked || isExpired) ? Colors.black12 : Colors.purple.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              statusText,
              style: AppTheme.getStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white).copyWith(letterSpacing: 1.5),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTheme.getStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
              ),
              if (isLocked) const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 28),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.help_outline_rounded, color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Text(AppLanguage.getString('questions_count_label').replaceAll('{count}', questionsCount.toString()), style: AppTheme.getStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(width: 16),
              const Icon(Icons.timer_outlined, color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Text(AppLanguage.getString('one_hour'), style: AppTheme.getStyle(color: Colors.white70, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (isLocked || !isAllowedDay) ? null : () async {
                if (await VersionService.isUpdateRequired()) {
                  if (context.mounted) VersionService.showUpdateDialogIfNeeded(context);
                  return;
                }
                if (context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => QuizScreen(
                        subjectTitle: title,
                        isMockTest: true,
                      ),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: (isLocked || !isAllowedDay) ? Colors.grey : (isExpired ? Colors.blueGrey : Colors.deepPurple),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text(
                (isLocked || !isAllowedDay) ? AppLanguage.getString('locked') : (isExpired ? AppLanguage.getString('review_previous_test') : AppLanguage.getString('start_mock_test')), 
                style: AppTheme.getStyle(fontWeight: FontWeight.bold, fontSize: 16)
              ),
            ),
          )
        ],
      ),
    );
  }
}
