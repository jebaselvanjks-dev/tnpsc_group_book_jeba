# High-Quality Video and Image Export for Admin Promotion

The user wants the downloads (video and images) from the `AdminPromoteScreen` to be in "high quality" (crisp and clear). Currently, video recording uses a low pixel ratio (1.5), which results in blurry output on high-resolution screens. Image sharing uses a 4.0 pixel ratio, which is decent but can be improved.

## User Review Required

> [!IMPORTANT]
> Increasing the `pixelRatio` for video recording significantly increases memory usage and processing time during the "Saving Video" phase. I've set it to **2.5**, which produces a crisp ~1200p width video. Higher values like 4.0 or 5.0 might cause crashes on some mobile devices due to encoder limitations.

## Proposed Changes

### [Admin Promotion Screen](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/screens/admin_promote_screen.dart)

#### [MODIFY] [admin_promote_screen.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/screens/admin_promote_screen.dart)

- Increase `pixelRatio` in `_startRecording` from `1.5` to **`2.5`** for professional video quality.
- Increase `pixelRatio` in `_shareCurrentQuiz` from `4.0` to **`5.0`** for ultra-high-resolution images.
- Adjust the `ConstrainedBox` in `_shareCurrentQuiz` to match the `SharePoster`'s design width (475) to prevent unnecessary scaling before the high-res capture.
- Ensure `FittedBox` in the UI doesn't compromise the recording resolution by providing a stable rendering environment.

## Verification Plan

### Manual Verification
- Start a recording in `AdminPromoteScreen`.
- Verify the "Saving Video" phase completes successfully.
- Check the saved video in the gallery for clarity and crispness.
- Perform a "Share" action and verify the generated image is high-resolution and not blurry.
- Check the video/image on a high-DPI device to ensure no pixelation.
