# Implementation Plan - Upgrade Video Recording to 4K Quality

Increase the recording resolution of promotional videos to 4K (Vertical 2160x3840) and optimize the frame rate for high-quality output.

## User Review Required

> [!WARNING]
> Recording in 4K at 60+ FPS is extremely hardware-intensive.
> 1. **Device Heat**: Older devices may heat up or lag during recording.
> 2. **Processing Time**: Saving a 4K video will take significantly longer than before.
> 3. **Compatibility**: While I can set the target to 120 FPS as requested, most mobile video encoders are capped at 60 FPS. I recommend **60 FPS** for the best balance of smoothness and stability.

## Proposed Changes

### Screens

#### [MODIFY] [admin_promote_screen.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/screens/admin_promote_screen.dart)
- Update `WidgetRecorderController` initialization to `targetFps: 60` (High-end standard).
- Calculate the necessary `pixelRatio` to reach 4K.
    - Base widget width: 450.
    - Target 4K Vertical width: 2160.
    - **Required Pixel Ratio: 4.8** ($2160 / 450 = 4.8$).
- Update `_startRecording` to use `pixelRatio: 4.8`.

## Verification Plan

### Manual Verification
- Perform a test recording on a high-end device.
- Check the video properties in the gallery to verify the resolution is approximately $2160 \times 3840$.
- Ensure there is no significant stuttering in the final exported MP4.
