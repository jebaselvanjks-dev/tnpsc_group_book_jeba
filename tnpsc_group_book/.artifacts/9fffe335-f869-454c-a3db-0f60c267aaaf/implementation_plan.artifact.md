# Implementation Plan - Remove Unwanted & Redundant Code

This plan focuses on cleaning up the codebase by removing unused imports, redundant private methods (especially after the IST refactor), and unused UI components identified during recent tasks.

## User Review Required

> [!NOTE]
> This is a cleanup task and does not introduce new features. It improves maintainability and reduces binary size slightly by removing dead code.

## Proposed Changes

### Global Utilities & Services

#### [MODIFY] [room_service.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/services/room_service.dart)
- Remove unused imports: `package:intl/intl.dart` and `package:flutter/foundation.dart`.
- Remove redundant `_getISTNow()` method and replace remaining internal calls with `AppDate.getISTNow()`.
- Remove unnecessary cast at line 735.

#### [MODIFY] [firestore_service.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/services/firestore_service.dart)
- Replace all internal `_getISTNow()` calls with `AppDate.getISTNow()`.
- Remove the redundant `_getISTNow()` method.

#### [MODIFY] [ai_service.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/services/ai_service.dart)
- Remove the unreferenced `_getISTNow()` method.

---

### Screens & UI Components

#### [MODIFY] [room_setup_screen.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/screens/room_setup_screen.dart)
- Remove unused imports: `package:intl/intl.dart`, `../models/subject.dart`, `admin_quiz_manage_screen.dart`, and `package:cloud_firestore/cloud_firestore.dart`.

#### [MODIFY] [waiting_room_screen.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/screens/waiting_room_screen.dart)
- Remove unused method `_buildPosterFeatures`.
- Clean up redundant null check for `image` after screenshot capture (analyzer says it's never null).

#### [MODIFY] [profile_screen.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/screens/profile_screen.dart)
- Remove unused local variable `displayTitle`.
- Remove unused method `_buildPosterMainBranding`.

## Verification Plan

### Automated Tests
- Run `flutter analyze` to ensure no new warnings or errors are introduced.
- Verify the app builds successfully.

### Manual Verification
- Verify that Room Creation and Waiting Room still work correctly (since IST logic was touched).
- Verify that Share Posters in Profile and Results still generate correctly.
