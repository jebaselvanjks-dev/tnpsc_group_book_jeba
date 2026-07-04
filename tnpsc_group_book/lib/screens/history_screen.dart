import 'package:flutter/material.dart';

import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../utils/app_theme.dart';
import '../utils/app_language.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final history = await _firestoreService.getUserHistory();
    setState(() {
      _history = history;
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
          icon: Icon(Icons.arrow_back_ios_rounded, color: isDark ? Colors.white : AppTheme.textMainColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLanguage.getString('my_history'),
          style: AppTheme.getStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: isDark ? Colors.white : AppTheme.textMainColor,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? _buildEmptyState(isDark)
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _history.length,
                  physics: const BouncingScrollPhysics(),
                  itemBuilder: (context, index) {
                    final item = _history[index];
                    return _buildHistoryCard(item, isDark);
                  },
                ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 100),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("📊", style: AppTheme.getStyle(fontSize: 64)),
            const SizedBox(height: 24),
            Text(
              textAlign: TextAlign.center,
              AppLanguage.getString('no_history_title'),
              style: AppTheme.getStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.textMainColor),
            ),
            const SizedBox(height: 12),
            Text(
              AppLanguage.getString('no_history_desc'),
              textAlign: TextAlign.center,
              style: AppTheme.getStyle(fontSize: 15, color: isDark ? Colors.white60 : Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> item, bool isDark) {
    final DateTime timestamp = item['timestamp']?.toDate() ?? DateTime.now();
    final String dateStr = DateFormat('MMM dd, yyyy • hh:mm a').format(timestamp);
    final int score = item['score'] ?? 0;
    final int total = item['totalQuestions'] ?? 0;
    final double percentage = total > 0 ? (score / total) * 100 : 0;
    final String subject = item['subject'] ?? 'Quiz';
    final Color scoreColor = _getScoreColor(percentage);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
        boxShadow: isDark ? [] : [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: scoreColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                "${percentage.toInt()}%",
                style: AppTheme.getStyle(
                  color: scoreColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject == "Daily Quiz" ? AppLanguage.getString('daily_quiz') : subject,
                  style: AppTheme.getStyle(fontSize: 17, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.textMainColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  dateStr,
                  style: AppTheme.getStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.grey.shade500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "$score/$total",
                style: AppTheme.getStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: scoreColor,
                ),
              ),
              Text(
                AppLanguage.getString('points'),
                style: AppTheme.getStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey.shade500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(double percentage) {
    if (percentage >= 80) return Colors.teal.shade400;
    if (percentage >= 50) return Colors.orange.shade400;
    return Colors.red.shade400;
  }
}
