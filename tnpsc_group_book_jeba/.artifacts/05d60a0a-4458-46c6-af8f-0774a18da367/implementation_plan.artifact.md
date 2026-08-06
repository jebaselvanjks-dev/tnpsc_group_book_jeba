# Implementation Plan - AGP 9.0 & R8 Optimization

Improve app performance and memory usage by upgrading to Android Gradle Plugin 9.0 and enabling advanced R8/Resource Shrinking features as recommended by Google Play.

## User Review Required

> [!IMPORTANT]
> - **AGP 9.0 Upgrade**: Upgrading to AGP 9.0 requires a minimum Gradle version of 9.1.0.
> - **R8 Full Mode**: Enabling Full Mode allows R8 to be more aggressive in shrinking and optimization. This might require additional `-keep` rules if reflection is used in ways not already covered. (Hive and Models are already kept in `proguard-rules.pro`).
> - **Resource Shrinking**: We will enable the latest optimized resource shrinking implementation.

## Proposed Changes

### [Build Configuration]

#### [MODIFY] [settings.gradle.kts](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/android/settings.gradle.kts)
- Upgrade `com.android.application` version from `8.11.1` to `9.0.0`.
- Upgrade `org.jetbrains.kotlin.android` if needed (keeping `2.2.20` for now as it's AGP 9.0 compatible).

#### [MODIFY] [gradle-wrapper.properties](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/android/gradle/wrapper/gradle-wrapper.properties)
- Upgrade `distributionUrl` to use Gradle `9.1.0`.

#### [MODIFY] [gradle.properties](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/android/gradle.properties)
- Add `android.enableR8.fullMode=true`.
- Ensure `android.r8.optimizedResourceShrinking=true` is present.
- Set `android.newDsl=true` (or remove the `false` override) to adopt AGP 9.0 standards.
- Set `android.builtInKotlin=true` (or remove the `false` override).

#### [MODIFY] [build.gradle.kts (App)](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/android/app/build.gradle.kts)
- Verify `isMinifyEnabled = true` and `isShrinkResources = true`.
- Update any DSL if the `newDsl` triggers errors.

### [ProGuard]

#### [MODIFY] [proguard-rules.pro](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/android/app/proguard-rules.pro)
- Add any necessary keep rules for common Flutter plugins if Full Mode causes issues (though standard rules are usually sufficient).

## Verification Plan

### Automated Tests
- Run `./gradlew assembleRelease` to ensure the project builds correctly with the new plugin and R8 settings.
- Check build logs for any R8 warnings or errors.

### Manual Verification
- Test the release build on a device to ensure:
    - App starts normally (no reflection issues with Hive).
    - Current Affairs and AI features work (Firestore/JSON parsing is fine).
    - Ads show up (AdMob is kept).
