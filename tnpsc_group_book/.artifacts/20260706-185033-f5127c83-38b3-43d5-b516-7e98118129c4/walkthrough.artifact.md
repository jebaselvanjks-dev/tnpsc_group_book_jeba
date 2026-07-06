# Walkthrough - Global Log Toggle Implementation

I have implemented a central logging system that allows you to toggle **all** debug logs across the entire application from a single place.

## Changes

### 1. Central Logging Utility: [app_log.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/utils/app_log.dart)
- Created a new `AppLog` class.
- Added `showDebugLogs` boolean toggle (default: `true`).
- `AppLog.d(message)`: Logs debug info only if the toggle is true.
- `AppLog.e(message, error)`: Logs errors (always visible).

### 2. Service Updates
- **[RoomService](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/services/room_service.dart)**: Replaced `debugPrint` and removed the local `showAiDebugLogs` flag.
- **[AiService](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/services/ai_service.dart)**: Replaced all `print` and `debugPrint` calls with `AppLog.d`.
- **[FirestoreService](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/services/firestore_service.dart)**: Replaced all `debugPrint` and `print` calls with `AppLog.d` or `AppLog.e`.

### 3. UI Updates
- **[main.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/main.dart)**: Updated `MainWrapper` back navigation and tab change logs to use `AppLog.d`.

## How to use

To disable all debug logs, simply change the value in `lib/utils/app_log.dart`:

```dart
class AppLog {
  static bool showDebugLogs = false; // Change to false to hide all logs
  // ...
}
```

## Verification Summary
- **Static Analysis**: Verified `AiService`, `FirestoreService`, and `RoomService` for syntax correctness.
- **Central Control**: All major background services and navigation events are now controlled by the central `AppLog` toggle.
