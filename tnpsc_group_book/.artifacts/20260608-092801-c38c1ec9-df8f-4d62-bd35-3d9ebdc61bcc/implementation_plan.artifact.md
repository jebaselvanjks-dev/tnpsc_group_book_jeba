# Leaderboard Fix and Mock Test Integration

Ensure the leaderboard displays correctly on all devices and that mock test results are properly saved to dedicated leaderboards.

## User Review Required

> [!IMPORTANT]
> The current logic for Mock Test leaderboards uses a dynamic ID based on the day (e.g., `Tuesday_2024-03-19`). If a user takes multiple mock tests in one window, the latest score overwrites the previous one.

## Proposed Changes

### Firestore Service Component

Update the logic for saving results and fetching leaderboards.

#### [firestore_service.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book/lib/services/firestore_service.dart)

- **Fix `getLeaderboard`**: Ensure it consistently fetches data and handles cache better to prevent empty lists on some devices.
- **Enhanced `saveQuizResult`**:
    - Ensure `Daily Quiz` updates both daily and weekly leaderboards.
    - Ensure `Mock Quiz` (from `mock_tests` collection) updates specialized scheduled leaderboards.
- **Added `_getMockLeaderboardDocId`**: Helper to generate consistent IDs for mock test leaderboards based on the current testing window.

---

### UI Components

#### [leaderboard_screen.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book/lib/screens/leaderboard_screen.dart)

- Ensure the leaderboard lists trigger a refresh properly.
- Added support for displaying more than 10 users if needed (currently limited to 10).

## Verification Plan

### Automated Tests
- No existing unit tests for Firestore logic found.
- Manual verification via Debug Console logs is the primary method.

### Manual Verification
1. **Leaderboard Display**: Open the leaderboard on multiple devices/emulators and verify that the "Daily" and "Weekly" tabs show data.
2. **Daily Quiz Submission**: Complete a daily quiz and verify that the score appears on the leaderboard.
3. **Mock Test Submission**: Complete a mock test and verify that it updates the specific mock leaderboard (checked via Firestore console or debug logs).
4. **Refresh Action**: Use the pull-to-refresh on the leaderboard and verify it fetches the latest server data.
