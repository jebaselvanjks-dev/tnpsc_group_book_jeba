import 'package:flutter/material.dart';

import '../models/question.dart';
import '../services/firestore_service.dart';
import '../utils/app_theme.dart';
import '../utils/app_icons.dart';
import '../utils/app_language.dart';
import 'quiz_screen.dart';

class BookmarkScreen extends StatefulWidget {
  const BookmarkScreen({super.key});

  @override
  State<BookmarkScreen> createState() => _BookmarkScreenState();
}

class _BookmarkScreenState extends State<BookmarkScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = true;
  List<Question> _bookmarks = [];

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    setState(() => _isLoading = true);
    final bookmarks = await _firestoreService.getBookmarks();
    setState(() {
      _bookmarks = bookmarks;
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
          AppLanguage.getString('bookmarks'),
          style: AppTheme.getStyle(
            fontWeight: FontWeight.bold, fontSize: 18
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _bookmarks.isEmpty
              ? _buildEmptyState(isDark)
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _bookmarks.length,
                  physics: const BouncingScrollPhysics(),
                  itemBuilder: (context, index) {
                    final q = _bookmarks[index];
                    return _buildBookmarkCard(q, isDark, index);
                  },
                ),
      bottomNavigationBar: !_isLoading && _bookmarks.isNotEmpty
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
                        subjectTitle: AppLanguage.getString('bookmarks'),
                      ),
                    ),
                  ).then((_) => _loadBookmarks());
                },
                icon: const AppIcon(AppIcons.play, color: Colors.white),
                label: Text(
                  AppLanguage.getString('start_now'),
                  style: AppTheme.getStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
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
            Text("🔖", style: AppTheme.getStyle(fontSize: 64)),
            const SizedBox(height: 24),
            Text(
              textAlign: TextAlign.center,
              AppLanguage.getString('no_bookmarks_title'),
              style: AppTheme.getStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.textMainColor),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                AppLanguage.getString('no_bookmarks_desc'),
                textAlign: TextAlign.center,
                style: AppTheme.getStyle(fontSize: 15, color: isDark ? Colors.white60 : Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookmarkCard(Question q, bool isDark, int index) {
    return Dismissible(
      key: Key(q.question),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const AppIcon(AppIcons.delete, color: Colors.white, size: 28),
      ),
      onDismissed: (direction) async {
        await _firestoreService.toggleBookmark(q);
        setState(() {
          _bookmarks.removeAt(index);
        });
      },
      child: Container(
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
      ),
    );
  }
}
