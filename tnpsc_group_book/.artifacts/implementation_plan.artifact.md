# Implementation Plan - Admin Promote App (Video Format)

The goal is to add a new function in the Admin Panel that displays 3 quizzes one by one in a "video-style" promotion format (Story/Reel style). Each quiz will show for 5 seconds, followed by the correct answer being revealed.

## User Review Required

> [!NOTE]
> The "Video Format" will be implemented as a sequential UI animation. This allows the admin to use a screen recorder to capture the content for social media promotion.

## Proposed Changes

### [Component] Widgets & UI Utilities

#### [NEW] [share_poster.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/widgets/share_poster.dart)
- Extract the poster building logic from `ProfileScreen` into a standalone, reusable widget.
- Add `showCorrectAnswer` parameter to highlight the correct option when needed.
- Support `ignoreScale` for text to ensure consistent layout across devices during capture.

---

### [Component] Admin Features

#### [NEW] [admin_promote_screen.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/screens/admin_promote_screen.dart)
- Implement the "Video Format" sequence.
- State management for:
    - Current quiz index (1 to 3).
    - Timer (5s countdown).
    - "Answer Revealed" state.
- Automated flow: Quiz 1 (5s) -> Reveal (2s) -> Quiz 2 (5s) -> Reveal (2s) -> Quiz 3 (5s) -> Reveal (End).

#### [MODIFY] [admin_panel_screen.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/screens/admin_panel_screen.dart)
- Add a new management card: **"Promote App (Video Format)"**.
- Icon: `Icons.video_library_rounded`.
- Color: `Colors.redAccent`.

---

### [Component] Profile Screen Cleanup

#### [MODIFY] [profile_screen.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/screens/profile_screen.dart)
- Replace local `_buildSharePoster` and helper methods with the new `SharePoster` widget.
- Ensure the share preview functionality remains intact.

## Verification Plan

### Automated Tests
- N/A (UI-centric visual flow).

### Manual Verification
1. **Admin Panel**:
    - Verify the new "Promote App" card exists.
2. **Promote Screen**:
    - Open the screen and ensure it fetches 3 unique quizzes.
    - Observe the 5s timer and ensure the correct answer is highlighted after it ends.
    - Verify it transitions smoothly to the next quiz.
    - Verify the "Share Poster" style is maintained (colors, logos, subject branding).
3. **Profile Share**:
    - Go to Profile -> Share with Friends.
    - Ensure the share poster still generates correctly without any layout breakage.
