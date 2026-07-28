# Walkthrough - Updated Explanation Unlocking Logic

I have updated the logic for viewing question explanations during a quiz. This change encourages point usage while providing a free alternative via ads.

## Changes Made

### 1. Updated Unlock Cost
- Increased the cost to view an explanation from 30 points to **40 points**.
- Updated the button label in the quiz screen to reflect this: **Show Hint (40 pts)**.

### 2. Smart Fallback Logic
- **With 40+ Points**: Users are asked to confirm spending 40 points to see the explanation.
- **With < 40 Points**: Instead of blocking the user, the app now shows an "Insufficient Points" dialog.
- **Rewarded Ad Option**: From this dialog, users can choose to **watch a rewarded ad** to unlock the explanation for free.
- **Resilience**: If the ad fails to load, the explanation is unlocked anyway to ensure a smooth user experience.

## Verification Results

### Code Integrity
- **`flutter analyze`**: Confirmed no syntax errors or broken references were introduced.
- **Logic Check**: Verified the `_unlockHint` method correctly handles both the point deduction path and the rewarded ad path.

## User Experience Impact
- **Point Economy**: Strengthens the value of earning points through quizzes.
- **Accessibility**: Users can still access explanations even if they run out of points, provided they are willing to watch a short ad.
