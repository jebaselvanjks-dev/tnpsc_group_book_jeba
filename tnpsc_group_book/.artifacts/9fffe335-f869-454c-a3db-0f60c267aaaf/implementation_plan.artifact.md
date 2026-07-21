# Implementation Plan - Fixed Share Poster Scaling

The goal is to fix the font scaling of all shareable posters (Image Cards) to exactly 90% (0.9) and ensure they do not change even if the user modifies the global app font size settings.

## User Review Required

> [!IMPORTANT]
> This change ensures that generated images remain consistent and professional across all devices, regardless of user-specific font preferences.

## Proposed Changes

### Poster Capture Logic

#### [MODIFY] [profile_screen.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/screens/profile_screen.dart)
- Update `_shareAppWithRandomQuiz` capture to use `textScaler: const TextScaler.linear(0.9)`.
- Ensure all `getStyle` calls in `_buildSharePoster`, `_buildPosterHeader`, `_buildPosterQuestionSection`, `_buildBattleFeature`, and `_buildSidebarItem` use `ignoreScale: true`.

#### [MODIFY] [waiting_room_screen.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/screens/waiting_room_screen.dart)
- Ensure all `getStyle` calls in `_buildShareCard`, `_buildPosterHeader`, `_buildPosterRoomCodeSection`, `_buildInfoItem`, `_buildPosterCTA`, and `_buildPosterMockups` use `ignoreScale: true`.

#### [MODIFY] [result_screen.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/screens/result_screen.dart)
- Ensure all `getStyle` calls in `_buildShareablePoster` and `_buildPosterStat` use `ignoreScale: true`.

## Verification Plan

### Manual Verification
1.  **Global Scaling Independence**: Change the App Font Size to 140% in Settings.
2.  **Poster Generation**: Share an invitation from the Waiting Room and a random quiz from the Profile.
3.  **Visual Check**: Verify that the text in the generated images is NOT oversized and remains at the intended 0.9 scale.
