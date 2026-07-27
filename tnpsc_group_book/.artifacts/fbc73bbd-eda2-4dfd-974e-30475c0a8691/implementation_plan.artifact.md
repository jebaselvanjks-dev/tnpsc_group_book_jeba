# Final App Size and Smoothness Optimization Plan

This plan focuses on making the app even smaller and smoother after the initial improvements.

## User Review Required

> [!IMPORTANT]
> I am proposing to remove the **`lottie`** package (~3MB impact) and replace the confetti animation with a much lighter alternative.
>
> I also strongly recommend converting your large images to **WebP** manually. I've provided the exact steps below.

## Proposed Changes

### 1. Smoothness Optimizations

#### [MODIFY] [subject_screen.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/screens/subject_screen.dart)
- Wrap `_SubjectCard` and the Daily Mock Card in `RepaintBoundary`. This significantly reduces GPU work during scrolling.

#### [MODIFY] [result_screen.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/screens/result_screen.dart)
- Remove `Lottie` usage.
- (Optional) Replace with a simple `CustomPainter` confetti or just a static high-quality "Victory" icon.

### 2. Dependency Removal

#### [MODIFY] [pubspec.yaml](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/pubspec.yaml)
- Remove `lottie`.

### 3. Asset Optimization (User Action Required)

The following 7 files are taking up **12.5 MB** of your 69MB app bundle:
- `asset/images/sharequiz1.png` to `sharequiz7.png`

**Instruction for User:**
1. Go to [Squoosh.app](https://squoosh.app/).
2. Upload `sharequiz1.png`, select "WebP" and set quality to 75%.
3. Download as `sharequiz1.webp`.
4. Repeat for all 7 files.
5. Replace the PNGs in your project.

## Verification Plan

### Automated Tests
- Run `flutter analyze` to ensure no broken references.
- Run `flutter pub get`.

### Manual Verification
1. **Cold Start**: Verify startup speed.
2. **Scrolling**: Verify list smoothness in Subjects and Home.
3. **Build Size**: Check the new `.aab` size.
