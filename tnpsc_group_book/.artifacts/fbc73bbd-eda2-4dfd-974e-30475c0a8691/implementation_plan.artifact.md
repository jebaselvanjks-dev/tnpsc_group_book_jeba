# Final Smoothness and Android Cleanup Plan

This plan targets the 3-second "freeze" during app launch and cleans up deprecated Android configurations.

## User Review Required

> [!IMPORTANT]
> I will be moving the initialization of **Google Mobile Ads** and **Notifications** to happen 1.2 seconds after the app is fully visible. This eliminates the startup lag but means ads and notifications might take an extra second to be ready once the Home Screen appears.

## Proposed Changes

### 1. Eliminate Launch Freeze

#### [MODIFY] [main.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/main.dart)
- Increase the delay in `_initServicesInBackground` from 500ms to **1200ms**.
- Move `MobileAds.instance.initialize()` and `NotificationService.init()` deeper into this background task.

### 2. Android Manifest Cleanup

#### [MODIFY] [AndroidManifest.xml](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/android/app/src/main/AndroidManifest.xml)
- Remove `io.flutter.embedding.android.AOTSharedLibraryName`.
- Remove `io.flutter.embedding.android.FlutterAssetsDir`.
- Remove `io.flutter.embedding.android.EnableImpeller`.
- *Note: These are now handled automatically by the Flutter engine or are deprecated. Removing them prevents "unsafe AOT path" errors seen in your logs.*

## Verification Plan

### Automated Tests
- Run `flutter analyze` to ensure no errors.

### Manual Verification
1.  **Cold Start**: Verify the app logo stays visible and the "Typewriter" animation on the Splash Screen is smooth (no freezing).
2.  **Log Check**: Check Logcat to ensure the "External path rejected" and "Skipped frames" errors are gone or significantly reduced.
