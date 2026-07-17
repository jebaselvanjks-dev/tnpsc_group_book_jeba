# Plan: Fix Admin Quiz Shuffling and Cast Errors

The goal is to stop the quiz type from shuffling in Admin mode and fix the Map casting error in `FirestoreService`.

## User Review Required

> [!IMPORTANT]
> - **Admin Consistency:** I will remove the `types.shuffle()` and `Random()` logic for Admins in `getDailyRotatingQuiz`. Admins will now see the same deterministic daily rotation as regular users.
> - **Error Fix:** I will fix the `_Map<dynamic, dynamic>` to `Map<String, dynamic>` casting error in `_sanitizeForHive`.

## Proposed Changes

### [firestore_service.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/services/firestore_service.dart)

#### [MODIFY] [firestore_service.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/services/firestore_service.dart)
- Update `_sanitizeForHive`: Change `data.map((key, value) => ...)` to return a `Map<String, dynamic>`.
- Update `getDailyRotatingQuiz`:
    - Remove the special `if (isAdmin)` block that shuffles and picks random questions.
    - Let Admins use the same deterministic logic as users so they see consistent topics for the day.

## Verification Plan

### Manual Verification
- Trigger the share poster multiple times as an Admin and verify the topic stays consistent for the day (e.g., "General Studies").
- Check logs to ensure no "Server fetch failed after retries" due to casting errors.
