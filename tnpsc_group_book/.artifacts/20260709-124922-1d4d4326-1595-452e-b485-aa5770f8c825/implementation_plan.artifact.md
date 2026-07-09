# Implementation Plan - Restoring Mock Quiz Schedule with Info BottomSheet

This plan addresses the request to restore the Sunday, Tuesday, Thursday, Saturday schedule for the Mock Quiz in `SubjectScreen`, while keeping the recently added information bottom sheet functionality.

## Proposed Changes

### SubjectScreen Component

I will restore the schedule logic and UI elements while maintaining the bottom sheet integration.

#### [subject_screen.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/screens/subject_screen.dart)

- Restore the schedule tooltip in the `_buildMockCard` header.
- Restore the `_isQuizDay` check in the `ElevatedButton`'s `onPressed` logic.
- Update the button text to show "No Quiz Today" when it's not a scheduled day.

```dart
  Widget _buildMockCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool _isQuizDay = const [2, 4, 6, 7].contains(DateTime.now().weekday);

    // ...
    // Restore Tooltip with schedule
    // ...

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: !_isQuizDay || HiveService.isMockQuizDone()
                  ? null
                  : () => _showQuizInfoBottomSheet(context, AppLanguage.getString('mock_quiz'), isDark),
              // ...
              child: Text(
                !_isQuizDay
                    ? (AppLanguage.languageNotifier.value == 'ta' ? "இன்று வினாடி வினா இல்லை" : "No Quiz Today")
                    : HiveService.isMockQuizDone()
                        ? AppLanguage.getString('completed')
                        : AppLanguage.getString('start_quiz'),
                style: AppTheme.getStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          )
  }
```

## Verification Plan

### Manual Verification
- Navigate to the `Subjects` screen.
- Verify the information icon (tooltip) is back in the `Mock Quiz` card header.
- Tap the info icon and verify it shows the correct schedule.
- If today is NOT Sun/Tue/Thu/Sat, verify the "Start Quiz" button says "No Quiz Today" and is disabled.
- If today IS a quiz day, verify tapping "Start Quiz" opens the info bottom sheet.
- Check both light and dark modes.
