# Walkthrough - Telegram Poll Share & Randomized Quiz

I have implemented the "Telegram Poll" sharing feature and randomized quiz selection for both the Admin Promote and Profile screens.

## Changes Made

### 1. New Utility for Poll Text
- Created `ShareUtils.generateTelegramPollText(Question q)` in [share_utils.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/utils/share_utils.dart).
- This utility generates a structured text message with number emojis (1️⃣, 2️⃣, etc.) and bilingual support, making it perfect for sharing as a "poll" in Telegram groups.

### 2. Admin Promote Screen Enhancements
- Added a **"Poll Share"** button to the side menu. This allows admins to share the current quiz directly to Telegram in the new poll format.
- Added a **"Random"** button that refreshes the current view with a completely new set of 3 random quizzes from the pool, satisfying the "random ah varanum" requirement.

### 3. Profile Screen Share Options
- Updated the share preview dialog to offer two distinct choices:
    - **Share as Image**: Maintains the beautiful poster format.
    - **Share as Poll (Telegram)**: Uses the new text-based poll format.
- Both options now correctly award 50 points to the user upon successful sharing.

### 4. Localization
- Added `share_as_poll` and `random_quiz` keys to `AppLanguage` for full bilingual support in the UI.

## Verification Results

> [!TIP]
> - The poll format is specifically designed for Telegram where users can easily copy-paste or bots can interpret the structured text.
> - Randomization is truly random for manual refreshes, while maintaining time-slot consistency for daily defaults.

---
**Feature ready for use.** You can now promote randomized quizzes as interactive polls on Telegram!
