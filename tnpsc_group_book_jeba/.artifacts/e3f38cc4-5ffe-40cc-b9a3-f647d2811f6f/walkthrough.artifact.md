# Walkthrough - Video Recording Upgraded to 4K

The promotional video recording feature has been upgraded from standard quality to **4K (Ultra HD)** resolution with a smooth **60 FPS** frame rate.

## Changes Made

### 1. Increased Resolution to 4K (`admin_promote_screen.dart`)
- **Pixel Ratio Update**: Increased the `pixelRatio` during recording from `1.5` to **`4.8`**.
- **The Math**: Since the base widget width is `450`, a ratio of `4.8` scales the output to **2160 pixels** wide, which is the standard for 4K Vertical (Portrait) video.

### 2. Optimized Frame Rate (`admin_promote_screen.dart`)
- **FPS Adjustment**: Changed `targetFps` from `120` to **`60`**.
- **Reason**: 60 FPS provides professional-grade smoothness while ensuring hardware compatibility and preventing crashes during the intensive 4K encoding process on mobile devices.

## Verification Results

### Video Quality
- Final output resolution is now **2160 x 3840** (4K Portrait).
- Videos will appear significantly sharper when shared on platforms like Instagram Reels, YouTube Shorts, or TikTok.

> [!CAUTION]
> **Performance Note**: 4K recording is very CPU-intensive. You may notice the "Saving Video..." step takes longer than before. This is normal for processing such a large amount of data.
