# Implementation Plan - YouTube Shorts UI & Daily Topic Rotation

Enhance the "Promote App" feature to generate YouTube Shorts style content with automated daily topic rotation and high-impact UI elements.

## Proposed Changes

### [Component] Firestore Service

#### [MODIFY] [firestore_service.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/services/firestore_service.dart)
- Add `getRandomQuizzesByTopic(String topic, int limit)`:
    - Queries the `quizzes` collection.
    - Filters by `quiz_type` or `subject` matching the topic string.
    - Returns a list of `Question` objects.

### [Component] Admin Features

#### [MODIFY] [admin_promote_screen.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/screens/admin_promote_screen.dart)
- **Topic Rotation Logic**:
    - Aggregate all `topicsTa` from `tnpscSubjects`.
    - Select a topic based on `daysSinceEpoch % totalTopics`.
- **YouTube Shorts UI**:
    - Add a "DAILY TNPSC CHALLENGE" header.
    - Add a "LIKE & SUBSCRIBE" overlay (semi-transparent).
    - Add a "DOWNLOAD LINK IN BIO" footer.
    - Improve the "Correct Answer" reveal with a larger, more celebratory animation.
    - Add a "Current Topic" badge (e.g., "Today: இலக்கணம்").
- **Share Integration**:
    - Add a `triggerShare` call for the currently visible quiz.

### [Component] UI Widgets

#### [MODIFY] [share_poster.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/widgets/share_poster.dart)
- Add an optional `watermark` or `promotionText` parameter.
- Refine layout for 9:16 aspect ratio recording.

## Verification Plan

### Manual Verification
1.  **Topic Check**: Open the screen and verify it says "Today's Topic: [Subject Name]".
2.  **Rotation Check**: Change device date to tomorrow and verify the topic changes to the next one in the list.
3.  **UI Check**: Ensure the "Subscribe" and "Download App" labels are visible and don't overlap with question content.
4.  **Answer Check**: Verify the 5s timer still works and highlights the correct answer in green.
