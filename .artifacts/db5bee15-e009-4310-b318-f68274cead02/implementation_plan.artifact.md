# Achievement Badges System Implementation

The goal is to implement a streak-based achievement system for daily quiz attempts. Users will receive badges for maintaining streaks of 7, 14, and 30 days. These badges will be displayed in the global leaderboard to encourage consistent participation.

## User Review Required

> [!IMPORTANT]
> The badges will be displayed in the global leaderboard. To do this, we need to store the current streak in the leaderboard score document. Existing leaderboard entries won't show badges until those users complete another quiz and their score is updated.

## Proposed Changes

### [Component] Firestore & Data Model

#### [MODIFY] [firestore_service.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/services/firestore_service.dart)
- Update `saveQuizResult` to fetch the current streak from Hive and include it in the `scoreData` sent to the leaderboard collections (`daily_$today` and `weekly_$monday`).
- This ensures that when a user appears on the leaderboard, their current streak is available for UI display.

### [Component] User Interface

#### [MODIFY] [leaderboard_screen.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/screens/leaderboard_screen.dart)
- Add a `_buildBadge` helper method to the `_LeaderboardList` state (similar to the one in `room_leaderboard_screen.dart`).
- Update the leaderboard list item to display badges based on the `streak` field in the user data:
    - 7+ Days: "7+ Days Streak" badge.
    - 14+ Days: "14+ Days Streak" badge.
    - 30+ Days: "30+ Days Streak" badge.
- Update `_MyRankStickyCard` to also show the user's current badge if they have one.

### [Component] Localization & Themes

#### [MODIFY] [app_language.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/utils/app_language.dart)
- Add strings for badge labels:
    - `streak_7`: "7+ Days Streak" / "7+ நாட்கள் தொடர்ச்சி"
    - `streak_14`: "14+ Days Streak" / "14+ நாட்கள் தொடர்ச்சி"
    - `streak_30`: "30+ Days Streak" / "30+ நாட்கள் தொடர்ச்சி"

## Verification Plan

### Automated Tests
- No automated tests available for Firestore integration in this environment, but I will verify the code structure and logic.

### Manual Verification
1.  Complete a daily quiz and verify that the `streak` is included in the leaderboard document in Firestore.
2.  Open the Leaderboard screen.
3.  Observe that users with streaks >= 7 have badges next to their names.
4.  Verify that the badges are localized (Tamil/English).
