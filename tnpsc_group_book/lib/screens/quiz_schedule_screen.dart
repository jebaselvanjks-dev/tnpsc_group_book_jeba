import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:tnpsc_group_book/utils/app_theme.dart';
import '../utils/app_date.dart';
import 'package:tnpsc_group_book/utils/app_icons.dart';

class QuizScheduleScreen extends StatelessWidget {
  const QuizScheduleScreen({Key? key}) : super(key: key);

  Future<List<Map<String, dynamic>>> _fetchUpcomingQuizzes() async {
    final todayStr = AppDate.getTodayString();
    final snapshot = await FirebaseFirestore.instance
        .collection('quizzes')
        .where('date', isGreaterThanOrEqualTo: todayStr)
        .orderBy('date')
        .get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: AppIcon(AppIcons.back, color: isDark ? Colors.white : AppTheme.textMainColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Quiz Schedule', style: AppTheme.getStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF0A0E21),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchUpcomingQuizzes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No upcoming quizzes found.'));
          }
          final quizzes = snapshot.data!;
          return ListView.separated(
            itemCount: quizzes.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.grey),
            itemBuilder: (context, index) {
              final quiz = quizzes[index];
              final date = quiz['date'] ?? 'Unknown';
              final title = quiz['title'] ?? 'Untitled Quiz';
              return ListTile(
                leading: const AppIcon(AppIcons.calendar, color: Colors.amberAccent),
                title: Text(date, style: AppTheme.getStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                subtitle: Text(title, style: AppTheme.getStyle(fontSize: 14, color: Colors.white70)),
                trailing: const AppIcon(AppIcons.forward, color: Colors.white70),
                onTap: () {
                  // Optionally navigate to a detail view later
                },
              );
            },
          );
        },
      ),
    );
  }
}
