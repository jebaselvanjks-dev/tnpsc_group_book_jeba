# Implementation Plan - Global Debug Log Toggle

Standardize all debug logging across the application by introducing a central `AppLog` utility. This will allow the user to toggle all `AI_DEBUG` and other `debugPrint` logs from a single location.

## User Review Required

> [!NOTE]
> I will focus on wrapping statements that start with `AI_DEBUG:` as these seem to be the primary target for toggling. Standard error logs will remain visible unless they are part of a debug-specific flow.

## Proposed Changes

### Utility: AppLog

#### [NEW] [app_log.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/utils/app_log.dart)

- Create a central class `AppLog` with a toggle `showDebugLogs`.
- Provide a `debug` method that wraps `debugPrint`.

```dart
import 'package:flutter/foundation.dart';

class AppLog {
  /// Set this to false to hide all debug logs across the app
  static bool showDebugLogs = true;

  /// Logs a debug message if showDebugLogs is true
  static void d(String message) {
    if (showDebugLogs) {
      debugPrint(message);
    }
  }

  /// Logs an error message (always visible)
  static void e(String message, [dynamic error, StackTrace? stackTrace]) {
    debugPrint("ERROR: $message");
    if (error != null) debugPrint(error.toString());
    if (stackTrace != null) debugPrint(stackTrace.toString());
  }
}
```

### Application-wide Updates

- Update `main.dart`, `RoomService`, `AiService`, `FirestoreService`, and other files to use `AppLog.d()` instead of direct `debugPrint()` or `print()` calls for debug-level information.

#### [room_service.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/services/room_service.dart)
- Remove `showAiDebugLogs` and use `AppLog.d`.

#### [ai_service.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/services/ai_service.dart)
- Replace `print("AI_DEBUG: ...")` with `AppLog.d("AI_DEBUG: ...")`.

---

## Verification Plan

### Automated Tests
- Run `flutter analyze` to ensure all imports and method calls are correct.

### Manual Verification
1. Set `AppLog.showDebugLogs = false`.
2. Navigate through the app (Home, Quiz, Room Setup).
3. Verify that the console is clean of `AI_DEBUG` logs.
4. Set it to `true` and verify logs return.
