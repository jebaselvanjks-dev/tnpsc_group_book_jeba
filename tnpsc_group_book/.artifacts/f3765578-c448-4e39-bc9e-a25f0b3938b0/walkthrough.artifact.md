# Room Time Validation & Self-Paced Play Walkthrough

I have updated the group room (Room) system to adhere strictly to India Standard Time (IST), persist user time preferences, and allow for flexible starting within a set time window.

## Changes Made

### 1. Persistent Time Preferences
- Added `saveRoomTimePreference` and `getRoomTimePreference` to `HiveService`.
- The `RoomSetupScreen` now remembers the last selected end time.
- Selecting a Start Time automatically updates the End Time to `Start + 1 hour`, which is then saved for future use.

### 2. Strict IST Validation
- `RoomService.createRoom` now verifies that the `startTime` is not in the past and is strictly for the current day (IST).
- Added `invalid_date_error` handling to prevent creating rooms for future or past days.
- Time pickers in the UI now block selection of past times relative to IST now.

### 3. Single Active Membership
- Added `getActiveJoinedRoom()` to `RoomService` to check if a user is currently participating in an unfinished room.
- `createRoom` and `joinRoom` now block the user if they are already in an active room, preventing multi-room conflicts.

### 4. Self-Paced Play Window
- `WaitingRoomScreen` now features a background timer that checks the current time against the room's `startTime` and `endTime`.
- When the current time is within the window, a **"Start Quiz"** button is enabled for **all players** (not just the host).
- This allows groups to play flexibly as soon as the match time arrives.

## Verification Results

- [x] **IST Consistency**: All time calculations use `AppDate.getISTNow()`.
- [x] **Preference Loading**: Verified that the end time persists across app restarts.
- [x] **Membership Protection**: Users are successfully blocked from joining a second room if the first is incomplete.
- [x] **Time Window Logic**: The "Start Quiz" button activates automatically when the `startTime` is reached.

> [!TIP]
> **Midnight Cap**: If you select a start time late in the day (e.g., 11:30 PM), the end time will be automatically capped at 11:59 PM to ensure the room stays within the current date.

render_diffs(file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/services/room_service.dart)
render_diffs(file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/screens/room_setup_screen.dart)
render_diffs(file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/screens/waiting_room_screen.dart)
render_diffs(file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/services/hive_service.dart)
