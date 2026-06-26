# Implementation Plan - Admin Quiz Management

Add a feature for admins to preview, edit, and manage daily and mock quizzes.

## Proposed Changes

### Admin Management

#### [NEW] [admin_quiz_manage_screen.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/screens/admin_quiz_manage_screen.dart)

- Create a screen to list and edit quizzes.
- Features:
    - Date selection (default to next day).
    - Quiz type toggle (Daily Quiz vs. Mock Quiz).
    - Fetch quiz data from Firestore based on date and type.
    - List all questions with their options, correct index, and explanation.
    - Edit button for each question:
        - Open a dialog to edit the question text (Bilingual format: English\nTamil).
        - Edit each of the 4 options (Bilingual format: English / Tamil).
        - Edit the explanation (Bilingual format: English. Tamil.).
        - Change the correct option index (0-3).
    - Save button to update the entire quiz document in Firestore.

#### [admin_panel_screen.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/screens/admin_panel_screen.dart)

- Add a new card for "Manage Quizzes".
- Link this card to the new `AdminQuizManageScreen`.

---

### UI/UX Improvements for Admin

- Use a clean, card-based layout for the question list.
- Add "Regenerate" button within the management screen to trigger AI generation for a specific date if it doesn't exist.

## Verification Plan

### Manual Verification
- Log in as an admin and navigate to the new "Manage Quizzes" tool.
- Select a future date and verify that existing quizzes are loaded.
- Edit a question, option, and explanation, then save and verify the changes in Firestore.
- Test the "Regenerate" functionality to ensure it correctly calls the `AiService` for the selected date.
