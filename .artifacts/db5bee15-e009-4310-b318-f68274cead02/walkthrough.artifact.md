# Achievement Badges System Walkthrough

I have implemented a new Achievement Badges system that rewards users for maintaining daily quiz streaks. These badges are now visible in the global leaderboard, fostering healthy competition and consistency.

## Changes Made

### 1. Achievement Logic & Data Integration
- **Firestore Service**: Updated `saveQuizResult` to capture the user's current streak from local storage and save it along with their score in the Firestore leaderboard collections.
- **Data Persistence**: Ensured that streaks are correctly synchronized between Hive (local) and Firestore (cloud) so that badges are always accurate.

### 2. Localization
- Added new strings to `app_language.dart` for both Tamil and English:
    - **7+ Days**: "7+ Days Streak" / "7+ நாட்கள் தொடர்ச்சி"
    - **14+ Days**: "14+ Days Streak" / "14+ நாட்கள் தொடர்ச்சி"
    - **30+ Days**: "30+ Days Streak" / "30+ நாட்கள் தொடர்ச்சி"

### 3. User Interface Enhancements
- **New Widget**: Created [streak_badge.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/widgets/streak_badge.dart), a reusable component that displays colorful badges based on the streak count.
- **Leaderboard Screen**:
    - Integrated `StreakBadge` into the leaderboard list items.
    - Added the badge display to the "My Rank" sticky card at the bottom of the screen.
- **Visual Design**:
    - 7+ Days: Orange badge with 🎖️ icon.
    - 14+ Days: Blue badge with 🛡️ icon.
    - 30+ Days: Purple badge with 👑 icon.

### 6. Read/Write Control & Optimization
- **Read Optimization (Rank Caching)**: The calculated rank is now cached in Hive. If the user's score hasn't changed, the app will reuse the cached rank instead of performing a new `count()` query on the server.
- **Write Optimization (Smart Updates)**: Leaderboard writes only occur if the user achieves a new best score OR if they maintain the same score but increase their streak (to update their badge and tie-breaker position). This significantly reduces Firestore write operations.

## Verification Results

- Verified that `FirestoreService` correctly bundles the `streak` field in the leaderboard score document.
- Verified that `LeaderboardScreen` renders the badges correctly based on the `streak` value.
- Confirmed that the sorting logic correctly prioritizes Score first, then Streak as a tie-breaker, without skipping any records.
- Verified that the user's current rank is accurately calculated and displayed at the bottom of the screen.
- Confirmed that Hive caching for Rank effectively reduces redundant Firestore network requests.
- Confirmed that the badges are properly localized when switching between Tamil and English.

> [!NOTE]
> Badges will appear for users as they complete new quizzes and update their leaderboard positions. Existing entries in the leaderboard that were created before this update will not show badges until they are refreshed by a new quiz completion.
