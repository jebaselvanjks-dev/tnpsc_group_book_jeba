# Implementation Plan - Persistent Multiple Room Cards

This plan enables the app to track and display both a "Hosted Room" and the "Last Joined Room" simultaneously. It ensures that rooms stay visible until they are finished or expire, even after restarting the app.

## User Review Required

> [!IMPORTANT]
> **Data Structure Change**: A new field `last_joined_room` will be added to the User document in Firestore to distinguish between rooms you create and rooms you join.
>
> **Logic Changes**:
> - **Hosted Room**: Always shows the active room you created.
> - **Joined Room**: Shows the most recent room you joined (that you are not hosting).
> - **Replacement**: Joining a new room will replace the previous "Joined Room" card.
> - **Cleanup**: Cards will disappear automatically once you finish the test or the room status changes to 'finished'.

## Proposed Changes

### Room Service

#### [MODIFY] [room_service.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/services/room_service.dart)
- **`createRoom`**: Update `last_room_played` but do not modify `last_joined_room`.
- **`joinRoom`**: Update both `last_room_played` and `last_joined_room`.
- **`getActiveJoinedRoom`**:
    - Change logic to fetch room details using `last_joined_room`.
    - Ensure it only returns the room if the user is a player and has not finished.
- **`getActiveHostRoom`**: Ensure it correctly identifies the room the user is hosting today.

### Room Setup UI

#### [MODIFY] [room_setup_screen.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/screens/room_setup_screen.dart)
- Verify `_checkActiveRoom` correctly fetches both types of rooms.
- The UI already has conditional logic for both cards; ensure it works seamlessly with the new service methods.

## Verification Plan

### Automated Tests
- Build verification.

### Manual Verification
1. **Scenario 1**: Join Room A. Verify "Joined Room" card appears.
2. **Scenario 2**: Create Room B. Verify "Active Room" card appears AND "Joined Room A" card stays visible.
3. **Scenario 3**: Join Room C. Verify "Joined Room A" card is replaced by "Joined Room C".
4. **Scenario 4**: Finish Room B (as host). Verify "Active Room" card disappears.
5. **Scenario 5**: Finish Room C (as player). Verify "Joined Room" card disappears.
6. **Scenario 6**: Close and reopen app. Verify both cards persist if rooms are still active.
