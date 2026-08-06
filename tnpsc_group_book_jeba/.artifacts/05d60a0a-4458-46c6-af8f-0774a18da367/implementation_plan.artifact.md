# Implementation Plan - Telegram Poll Share Feature

Add the ability to share quizzes to Telegram in a text-based "Poll Format" with randomized question selection.

## User Review Required

> [!IMPORTANT]
> - **Poll Format**: Telegram's native share intent only supports text and URLs. We will generate a structured text message with emojis (1️⃣, 2️⃣, etc.) that mimics a poll format, which is standard for Telegram groups.
> - **Randomization**: We will add a feature to pick a completely random quiz from the pool for sharing, satisfying the "random ah varanum" requirement.

## Proposed Changes

### [Utils/Services]

#### [NEW] [share_utils.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/utils/share_utils.dart)
- Create a utility class to handle poll text generation.
- Method: `generateTelegramPollText(Question q)`:
    - Formats the question (Tamil & English).
    - Lists options with number emojis.
    - Appends the app download link.

### [UI Components]

#### [MODIFY] [admin_promote_screen.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/screens/admin_promote_screen.dart)
- Add a new side icon button: **"Poll Share"**.
- Implement `_shareAsTextPoll()`:
    - Picks a random quiz from the `_quizzes` list or the global pool.
    - Uses `Share.share` with the formatted poll text.
- Add a **"New Quiz"** button to refresh the randomized pool manually.

#### [MODIFY] [profile_screen.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/screens/profile_screen.dart)
- Update the share dialog (preview) to include a "Share as Text Poll" button alongside the "Share Now" (image) button.

### [Localization]

#### [MODIFY] [app_language.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/utils/app_language.dart)
- Add keys for "Share as Poll", "Random Quiz", etc.

## Verification Plan

### Automated Tests
- Unit test for `generateTelegramPollText` to ensure bilingual support and correct emoji indexing.

### Manual Verification
- Go to Admin Promote Screen -> Click "Poll Share" -> Select Telegram -> Verify text structure.
- Go to Profile -> Share -> Choose "Text Poll" -> Verify randomization.
