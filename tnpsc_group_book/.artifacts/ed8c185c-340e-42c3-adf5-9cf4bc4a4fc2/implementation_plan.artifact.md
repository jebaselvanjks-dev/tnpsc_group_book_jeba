# Implementation Plan - Optimized Ad Preloading & Interstitial Ads

The goal is to optimize the ad preloading mechanism for Rewarded ads and introduce Interstitial ads that will be displayed upon quiz completion. This will help maximize impressions and revenue.

## User Review Required

> [!WARNING]
> **Ad ID Provided**: The ID you sent (`ca-app-pub-9952621231526514~4848368118`) is the **App ID**. I still need the **Interstitial Ad Unit ID** (it should have a `/` in the middle). I will use the **Test ID** for now, and you can replace it with the real one later.

## Proposed Changes

### [Reward Service](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/services/reward_service.dart)

#### [MODIFY] [reward_service.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/services/reward_service.dart)

- **Interstitial Ad Integration**:
    - Add `_interstitialAd` and `_isInterstitialLoaded` variables.
    - Implement `loadInterstitialAd()` with a Test ID and logic to prevent redundant loading.
    - Implement `showInterstitialAd({required VoidCallback onDismissed})`.
- **Preloading Optimization**:
    - Add `_isRewardedLoading` and `_isInterstitialLoading` flags.
    - Automatically trigger a new load request inside the dismissal callbacks for both ad types.
    - Implement a simple retry mechanism for failed loads (delay then retry).

### [Main Entry](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/main.dart)

#### [MODIFY] [main.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/main.dart)

- Update `_initServicesInBackground` to call both `RewardService.loadRewardedAd()` and `RewardService.loadInterstitialAd()`.

### [Quiz Screen](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/screens/quiz_screen.dart)

#### [MODIFY] [quiz_screen.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/screens/quiz_screen.dart)

- **Show Ad on Submit**: Update `_submitQuiz`.
    - If `isDailyOrMock`, show **Rewarded Ad** (points).
    - Otherwise (Standard Quiz), show **Interstitial Ad** before navigating to the result screen.

## Verification Plan

### Manual Verification
1. **Startup**: Check logs for both ad types loading successfully.
2. **Standard Quiz**: Complete a subject quiz and verify an Interstitial ad shows.
3. **Daily Quiz**: Complete a Daily Quiz and verify a Rewarded ad shows.
4. **Sequential Preload**: Watch any ad and verify a new load request is immediately triggered.

### Automated Tests
- No specific automated tests required for UI-based ad flows, but logging will be used for verification.
