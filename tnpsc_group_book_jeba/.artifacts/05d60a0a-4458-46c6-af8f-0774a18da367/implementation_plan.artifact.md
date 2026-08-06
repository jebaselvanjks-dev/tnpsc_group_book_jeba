# Implementation Plan - Fix Build & SDK 37 Migration

Resolve build failures caused by `flutter_secure_storage` upgrade, SDK 37 requirement, and Kotlin version deprecation.

## User Review Required

> [!IMPORTANT]
> - **SDK 37 Upgrade**: We are increasing `compileSdk` and `targetSdk` to 37 to support the latest `flutter_secure_storage`.
> - **API Change**: `flutter_secure_storage` version 11+ has removed the `encryptedSharedPreferences` parameter as it is now enabled by default. We will update the code to reflect this.
> - **Kotlin 2.2.20**: Upgrading Kotlin to the recommended version for Flutter 3.44+.

## Proposed Changes

### [Build Configuration]

#### [MODIFY] [settings.gradle.kts](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/android/settings.gradle.kts)
- Upgrade `org.jetbrains.kotlin.android` version to `2.2.20`.

#### [MODIFY] [build.gradle.kts (App)](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/android/app/build.gradle.kts)
- Set `compileSdk = 37`.
- Set `targetSdk = 37`.

### [Services]

#### [MODIFY] [credential_storage.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/services/credential_storage.dart)
- Remove `encryptedSharedPreferences: true` from `AndroidOptions` constructor to fix compilation error.

## Verification Plan

### Automated Tests
- Run `flutter clean` then `flutter run` to verify the build.

### Manual Verification
- Confirm auth persistence works correctly (token/password reading and writing).
