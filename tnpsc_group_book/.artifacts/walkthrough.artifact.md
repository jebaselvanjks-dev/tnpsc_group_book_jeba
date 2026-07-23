# Walkthrough - Admin Promote App (Video Format)

I have implemented a new feature for the admin to generate app promotion content in a "Video Format" (Story/Reel style). This feature displays 3 quizzes sequentially with a 5-second timer for each, followed by the correct answer reveal.

## Changes Made

### 1. Extracted Reusable `SharePoster` Widget
- **[share_poster.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/widgets/share_poster.dart)**: The poster layout previously tied to `ProfileScreen` is now a standalone widget.
- **Answer Reveal Support**: Added a `showCorrectAnswer` flag to highlight the correct option on the poster.
- **Layout Fix**: Provided a fixed `450x800` size to ensure the widget works correctly inside `FittedBox` and other layout-constrained environments, preventing "size.isFinite" errors.

### 2. Implemented Admin Promote Screen
- **[admin_promote_screen.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/screens/admin_promote_screen.dart)**: A new full-screen automated sequence.
    - Fetches 3 quizzes from Firestore (Daily rotating or general pool).
    - Starts a 5-second countdown timer.
    - Highlights the correct answer for 2 seconds before automatically transitioning to the next quiz.
    - Includes a progress bar at the top and a restart option at the end.

### 3. Integrated into Admin Dashboard
- **[admin_panel_screen.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/screens/admin_panel_screen.dart)**: Added a new tool card "Promote App (Video Format)" under Management Tools.

### 4. Code Cleanup in Profile Screen
- **[profile_screen.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/screens/profile_screen.dart)**: Removed ~350 lines of redundant UI code by utilizing the new `SharePoster` widget.

## Verification Results

### Manual Test Steps
1. Navigate to **Admin Dashboard**.
2. Tap on **Promote App (Video Format)**.
3. Observe the sequence:
    - **Quiz 1** appears with a 5s countdown.
    - Correct answer is highlighted in green with a "Correct Answer!" badge.
    - Automatically transitions to **Quiz 2** after a short pause.
    - Repeats for **Quiz 3**.
4. Verified that the **Profile Screen "Share with Friends"** function still works perfectly and generates the same high-quality poster as before.

> [!TIP]
> Use a screen recorder on your device to capture this sequence. It's perfectly timed for Instagram Stories or WhatsApp Status to promote the app!
