# Implementation Plan - Join Room Point Cost & Ad Integration

The goal is to implement a 100-point cost for joining a room. If a user has insufficient points, they will be prompted to watch a reward ad to earn points, consistent with the room creation flow.

## User Review Required

> [!IMPORTANT]
> **Join Cost**: Joining ANY room will cost **100 points** for non-admin users.
>
> **Ad Flow**: If a user tries to join with < 100 points, a dialog will appear allowing them to watch an ad to earn 50 points (standard reward amount). They can watch up to 3 ads per day to gather enough points.

## Proposed Changes

### [Room Service](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/services/room_service.dart)

#### [MODIFY] [room_service.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/services/room_service.dart)

- **Define Constant**: Add `static const int roomJoinCostPoints = 100;`.
- **Refactor `joinRoom`**:
    - Implement a Firestore **Transaction** to ensure atomic point deduction and room entry.
    - Logic:
        1. Fetch user points and admin status.
        2. Check if user is already a member (no double charge).
        3. If not admin and not already a member, verify ≥ 100 points.
        4. Deduct 100 points and add to `players` collection.
        5. Return `'success'`, `'insufficient_points'`, or error codes.

### [Room Setup Screen](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/screens/room_setup_screen.dart)

#### [MODIFY] [room_setup_screen.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/screens/room_setup_screen.dart)

- **UI Helper**: Update `_showNeedPointsMessage` to accept an optional `requiredPoints` parameter to dynamically show "100 points" vs "200+ points".
- **Join Logic**:
    - Add a preliminary points check in `_joinRoom`.
    - If points < 100, trigger `_showNeedPointsMessage(requiredPoints: 100)`.
    - Handle the `'insufficient_points'` response from the service.

## Verification Plan

### Manual Verification
1. **Join with Points**: Join a room with 500 points. Verify balance becomes 400.
2. **Join without Points**: Try joining with 20 points. Verify the "Points Required" dialog appears with the "Earn 50 Points" ad button.
3. **Watch Ad**: Watch the ad from the join flow. Verify points increase by 50.
4. **Admin Check**: Join as admin. Verify 0 points deducted.

### Automated Tests
- I will verify the transaction logic in `RoomService` handles concurrent joins correctly.
