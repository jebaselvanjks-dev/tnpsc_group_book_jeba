# Walkthrough - Logging Centralization

I have successfully centralized the logging system across the project by refactoring all direct `debugPrint` calls to use the `AppLog` utility. This allows you to control the visibility of debug logs globally from a single file.

## Changes Made

### Centralized Toggle in [app_log.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/utils/app_log.dart)
- Set `showDebugLogs` to `false` by default to hide debug logs as requested.
- You can toggle this back to `true` whenever you need to see debug information in the console.

### Refactored Files
The following files were updated to use `AppLog` instead of direct `debugPrint` or `print`:
- `lib/screens/login_screen.dart`
- `lib/screens/profile_screen.dart`
- `lib/screens/room_setup_screen.dart`
- `lib/screens/ai_smart_prep_screen.dart`
- `lib/services/auth_service.dart`
- `lib/services/content_sync_service.dart`
- `lib/services/deep_link_service.dart`
- `lib/services/google_auth_service.dart`
- `lib/services/password_email_service.dart`
- `lib/services/firestore_service.dart`
- `lib/utils/app_language.dart`

## How it Works

1. **Debug Logs**: Use `AppLog.d("message")`. These will only appear if `AppLog.showDebugLogs` is set to `true`.
2. **Error Logs**: Use `AppLog.e("error message")`. These will **always** appear in the console, ensuring you don't miss critical failures even when debug logs are hidden.

## Verification
- Verified using `grep` that no direct `debugPrint` or `print` calls remain in the project source code (except within the `AppLog` class itself).
- Confirmed that the `AppLog.d` method correctly checks the `showDebugLogs` boolean before printing.
