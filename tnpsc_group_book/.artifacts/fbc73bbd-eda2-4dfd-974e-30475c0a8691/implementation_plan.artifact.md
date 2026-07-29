# Perfect Logo Fitting for Android Launch Screen

This plan optimizes the native Android launch files to ensure the logo is perfectly centered and the background is consistent without any distortion.

## Proposed Changes

### 1. Optimize Pre-Android 12 Splash Screen

#### [MODIFY] [launch_background.xml](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/android/app/src/main/res/drawable/launch_background.xml)
- Change the background layer from a bitmap to the solid color `@color/launch_background`. This prevents the background from stretching or having "seams".
- Keep the logo (`@drawable/splash`) centered.
- Update this in all versions (`drawable`, `drawable-v21`, `drawable-night`, etc.) to ensure consistency.

### 2. Verify Android 12+ Styles

#### [VERIFY] [styles.xml](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/android/app/src/main/res/values-v31/styles.xml)
- Confirmed that `windowSplashScreenBackground` matches `#02091A`.
- Confirmed that `windowSplashScreenAnimatedIcon` uses `@drawable/android12splash`.
- *Note: On Android 12+, the system automatically handles the "fitting" of the icon within a standard safe zone.*

## Verification Plan

### Manual Verification
1.  **Launch on Old Android**: Verify that the background is a solid, clean `#02091A` and the logo is centered.
2.  **Launch on Android 12+**: Verify that the system splash screen shows the centered logo correctly.
3.  **Night Mode**: Verify that the dark mode splash screen is consistent with the light mode (since we are using a dark navy for both).
