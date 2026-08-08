# Persistent Multiple Room Cards Walkthrough

I have updated the room management logic to support displaying both a hosted room and a joined room simultaneously, ensuring they persist until finished or expired.

## Changes Made

### 1. New Tracking Field: `last_joined_room`
Updated [RoomService.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/services/room_service.dart) to track the last room a user joined separately from the room they are hosting.
- **`joinRoom`**: Now saves the room ID to `last_joined_room` in the user's Firestore document.
- **`getActiveJoinedRoom`**: Fetches the room details using the `last_joined_room` ID. It ensures:
    - The user is not the host of this room (to avoid duplicate cards).
    - The room is still in 'waiting' or 'active' status.
    - The user has not finished the test yet.

### 2. Multi-Card Support in UI
Modified [RoomSetupScreen.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/screens/room_setup_screen.dart) to allow both types of rooms to be visible at once.
- **Removed Creation Block**: Users can now create a new room even if they are currently in a joined room.
- **Persistence**: Both `getActiveHostRoom` and `getActiveJoinedRoom` are called in `initState`, ensuring cards appear immediately when the app is opened.

### 3. Replacement Logic
- When a user joins a new room, the `last_joined_room` field is updated, effectively replacing the previous "Joined Room" card with the new one.
- The "Join Room" section remains visible even when a joined room exists, allowing users to switch to a different room code at any time.

## Verification Results

> [!TIP]
> **Persistence**: If you create a room and join another user's room, you will see two distinct cards. If you close and reopen the app, both cards will still be there as long as the rooms are active.

| Action | Result |
| :--- | :--- |
| **Join Room A** | "Joined Room" card appears. |
| **Create Room B** | "Active Room" card appears; "Joined Room A" remains. |
| **Join Room C** | "Joined Room A" card is replaced by "Joined Room C". |
| **Finish Test** | The corresponding card disappears automatically. |
| **Room Expires** | The card disappears once the host finishes the room. |

render_diffs(file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/services/room_service.dart)
render_diffs(file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/screens/room_setup_screen.dart)
