# Implementation Plan - Staggered "Light" Animations for Poster Boxes

The goal is to add subtle, professional-grade entrance animations to all containers (boxes) within the `SharePoster` widget. This will make the transition between quizzes in the promotion video feel more dynamic and high-end.

## User Review Required

> [!NOTE]
> I will be using the existing `flutter_staggered_animations` package to ensure a smooth, staggered effect where elements appear one after another in a controlled sequence. The animations will be kept "light" (fast durations and subtle offsets) to maintain readability.

## Proposed Changes

### [Widgets]

#### [MODIFY] [share_poster.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/widgets/share_poster.dart)
- Wrap the main content in an `AnimationLimiter`.
- Apply `AnimationConfiguration.staggeredList` to the children of the main `Column`.
- Add `FadeInAnimation` and `SlideAnimation` (subtle vertical offset) to:
    - Poster Header
    - Question & Options Section
    - Sidebar Icons Row
    - Bottom Mockup & Battle Section Row
- Ensure option boxes also have a staggered entrance within the question section.

## Verification Plan

### Manual Verification
1. Open **Admin Dashboard** > **Promote App (Video Format)**.
2. Observe how the poster elements "slide in" when a new quiz starts.
3. Verify that the animations are fast enough to not interfere with the 10-second timer.
4. Confirm that the video recording captures these staggered entrances correctly.
