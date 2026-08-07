# Implementation Plan - Fix Persistent Login Issue

The app currently fails to persist the login session across restarts, forcing users to log in every time. This is likely due to the late initialization of Firebase and Google Sign-In services, and the lack of a "silent" restoration of the Google authentication state required by `google_sign_in` v7.2.0+.

## User Review Required

> [!IMPORTANT]
> This change moves the initialization of core services (Firebase, Hive) from the `SplashScreen` to the `main()` function. This will slightly increase the duration of the native splash screen before the Flutter `SplashScreen` appears, but it ensures that authentication states are restored as early as possible.

## Proposed Changes

### Core Initialization & Startup Flow

#### [MODIFY] [main.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/main.dart)
- Update `main()` to be `async`.
- Move the call to `initializeServices()` into `main()` and `await` it.
- Remove the manual removal of splash from `SplashScreen` if it's already handled elsewhere, or keep it consistent.
- Ensure `GoogleSignIn.instance.initialize()` is called during startup (optional but recommended for v7+).

#### [MODIFY] [splash_screen.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/screens/splash_screen.dart)
- Simplify `_navigateToHome()` since services will already be initialized.
- Enhance the authentication check:
    - Increase timeout for `authStateChanges()` to 3-4 seconds for better reliability on slower devices.
    - If `FirebaseAuth` user is still null, attempt `GoogleAuthService.restorePreviousSignIn()` (using `attemptLightweightAuthentication`).

### Authentication Services

#### [MODIFY] [google_auth_service.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/services/google_auth_service.dart)
- Add `restorePreviousSignIn()` method using `_googleSignIn.attemptLightweightAuthentication()`.
- This ensures that if the Google session is still valid on the device, it is "activated" so `FirebaseAuth` can potentially pick it up or we can re-authenticate.

## Verification Plan

### Manual Verification
1.  **Fresh Login**: Open the app, log in with Google. Verify home screen opens.
2.  **App Restart**: Close the app completely (kill the process). Open it again. Verify it bypasses the login screen and goes directly to the home screen.
3.  **Hot Restart**: Perform a Hot Restart in Android Studio. Verify the session is maintained.
4.  **Logout**: Log out from the profile screen. Restart the app. Verify it stays on the login screen.
