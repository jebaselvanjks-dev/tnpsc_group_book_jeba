import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // Log User Login
  static Future<void> logLogin(String method) async {
    await _analytics.logLogin(loginMethod: method);
  }

  // Log Quiz Start
  static Future<void> logQuizStarted(String subject) async {
    await _analytics.logEvent(
      name: 'quiz_started',
      parameters: {
        'subject': subject,
      },
    );
  }

  // Log Quiz Completion
  static Future<void> logQuizCompleted(String subject, int score, int total) async {
    await _analytics.logEvent(
      name: 'quiz_completed',
      parameters: {
        'subject': subject,
        'score': score,
        'total_questions': total,
        'accuracy': (score / total) * 100,
      },
    );
  }

  // Log Feedback
  static Future<void> logFeedbackSent() async {
    await _analytics.logEvent(name: 'feedback_submitted');
  }

  // Log Bookmark
  static Future<void> logBookmarkAdded(String subject) async {
    await _analytics.logEvent(
      name: 'bookmark_added',
      parameters: {'subject': subject},
    );
  }
}
