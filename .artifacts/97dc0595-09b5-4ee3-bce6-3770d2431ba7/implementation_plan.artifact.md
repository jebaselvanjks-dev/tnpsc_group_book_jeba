# Fix Build Failure: Target Stable AGP 8.1.4 and Kotlin 1.9.24

We are hitting a persistent `AndroidLocationsBuildService` creation failure with AGP 8.2.2 and above in this environment. To bypass this, we will move to **AGP 8.1.4**, which is a widely used stable version that preceded the major service-creation changes in 8.2+.

To maintain compatibility with plugins like `cloud_functions`, we will use **Kotlin 1.9.24**, which provides the necessary `JvmTarget.fromTarget()` API. We will use **Gradle 8.4** to satisfy Flutter's internal script requirements.

## Proposed Changes

### [Android Configuration]

#### [MODIFY] [settings.gradle.kts](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/android/settings.gradle.kts)
- Set `com.android.application` version to `8.1.4`.
- Set `org.jetbrains.kotlin.android` version to `1.9.24`.

#### [MODIFY] [gradle-wrapper.properties](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/android/gradle/wrapper/gradle-wrapper.properties)
- Set `distributionUrl` to Gradle `8.4-all`.

## Verification Plan

### Manual Verification
- Run `./gradlew assembleDebug` in the `android` directory.
- Run `flutter run`.
