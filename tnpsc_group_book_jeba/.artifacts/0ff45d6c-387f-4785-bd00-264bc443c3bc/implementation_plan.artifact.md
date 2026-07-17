# Implementation Plan - Crash Prevention & App Stability

The goal is to implement robust error handling and safety checks to prevent the app from crashing during initialization, network failures, or user interactions.

## Proposed Changes

### Global Stability
#### [MODIFY] [main.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/main.dart)
- Add a custom `ErrorWidget.builder` to prevent the "Grey Screen of Death" in production.
- Implement `FlutterError.onError` and `PlatformDispatcher.instance.onError` to catch uncaught errors.
- Strengthen `initializeServices` with a global try-catch.

### Initialization & Navigation Safety
#### [MODIFY] [splash_screen.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/screens/splash_screen.dart)
- Ensure `_navigateToHome` always completes even if initialization partially fails.
- Add `mounted` checks before all `Navigator` calls.

#### [MODIFY] [login_screen.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/screens/login_screen.dart)
#### [MODIFY] [quiz_screen.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/screens/quiz_screen.dart)
- Audit all async callbacks for `mounted` checks before using `context`.
- Improve error handling around Firestore and Ad interactions.

### Service Reliability
#### [MODIFY] [reward_service.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/services/reward_service.dart)
- Remove potential infinite recursion in `showRewardAd`.
- Add safety checks for null or disposed ad objects.

## Verification Plan

### Manual Verification
1. **Force Init Failure**: Temporarily mock `Firebase.initializeApp` to throw an error. Verify the app still launches (even if it shows an error on the login/home screen).
2. **Stress Test Navigation**: Rapidly click "Back" and "Next" in the Quiz screen during ad loading. Verify no crashes occur.
3. **Trigger Flutter Error**: Introduce a deliberate `null` error in a widget's build method. Verify the new custom Error UI is shown instead of a grey screen.
