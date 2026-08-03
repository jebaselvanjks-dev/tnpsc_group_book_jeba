# Fix Room Time Editing to Preserve Date

The goal is to ensure that when editing the room time range in the `WaitingRoomScreen`, only the time (hours/minutes) is updated, and the original date of the room is strictly preserved.

## User Review Required

> [!IMPORTANT]
> This change ensures that if a room is scheduled for a future date, editing the time will NOT reset the date to "today". It will use the year, month, and day from the existing room start time.

## Proposed Changes

### Waiting Room Screen

#### [MODIFY] [waiting_room_screen.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/screens/waiting_room_screen.dart)

- Update `_editRoomTime` validation for "Start Time" to use the existing room's date instead of forcing "today" via `AppDate.getISTTodayWithTime`.
- Ensure all validations in the time editor respect the `baseDate` (original room date).

## Verification Plan

### Manual Verification
1.  Open a room lobby.
2.  Click the "Edit" icon near the time range.
3.  Change the start or end time.
4.  Verify that the saved time reflects the new hours/minutes but keeps the original date.
5.  If the room is for a future date (simulated), verify that editing the time doesn't cause a "Cannot select past time" error incorrectly.
