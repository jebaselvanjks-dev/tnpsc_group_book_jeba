# Update Explanation Unlocking Logic

Update the cost of unlocking explanations in the quiz screen and provide a fallback rewarded ad option if the user has insufficient points.

## User Review Required

> [!NOTE]
> The unlock cost is increasing from 30 to 40 points. Users with fewer than 40 points will now see an option to watch a rewarded ad to unlock the explanation for free.

## Proposed Changes

### Quiz Screen

#### [MODIFY] [quiz_screen.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/screens/quiz_screen.dart)
- Update `_unlockHint` method:
    - Change `cost` from 30 to 40.
    - If user points < 40, show a dialog offering to watch a Rewarded Ad.
    - If the ad is watched (or skipped by failure), unlock the hint.
    - Update the UI label to show `(40 pts)`.

## Verification Plan

### Manual Verification
1.  **With 40+ Points**: Tap "Show Hint". Verify it asks for 40 points and deducts them upon confirmation.
2.  **With < 40 Points**: Tap "Show Hint". Verify it informs you that you need 40 points and offers a "Watch Ad" button.
3.  **Ad Flow**: Watch the ad. Verify the explanation appears immediately after the ad is dismissed.
