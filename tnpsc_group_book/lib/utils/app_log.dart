import 'package:flutter/foundation.dart';

class AppLog {
  /// Set this to false to hide all debug logs across the app
  static bool showDebugLogs = false;

  /// Logs a debug message if showDebugLogs is true
  static void d(String message) {
    if (showDebugLogs) {
      debugPrint(message);
    }
  }

  /// Logs an error message (always visible for easier troubleshooting)
  static void e(String message, [dynamic error, StackTrace? stackTrace]) {
    debugPrint("ERROR: $message");
    if (error != null) debugPrint(error.toString());
    if (stackTrace != null) debugPrint(stackTrace.toString());
  }
}
