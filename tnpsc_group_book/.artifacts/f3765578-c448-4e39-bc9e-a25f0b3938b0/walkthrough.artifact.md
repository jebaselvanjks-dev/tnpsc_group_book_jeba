# Join Room Point Cost & Ad Integration Walkthrough

I have implemented a 100-point cost for joining a group room. If a user has insufficient points, they will be prompted to watch a reward ad to earn points, ensuring a consistent experience with the room creation flow.

## Changes Made

### 1. Atomic Point Deduction for Joining
- **File**: `lib/services/room_service.dart`
- **Action**: Refactored `joinRoom` to use a Firestore **Transaction**.
- **Impact**: 100 points are now automatically deducted from the user's balance when they successfully join a room for the first time. Admins remain exempt from this cost.

### 2. Points Check and Ad Integration in UI
- **File**: `lib/screens/room_setup_screen.dart`
- **Action**:
    - Updated `_joinRoom` to perform a preliminary points check.
    - Enhanced `_showNeedPointsMessage` to dynamically display the required points (100 for joining, 200+ for creating).
    - If a user has < 100 points, they can now watch a reward ad directly from the join flow to earn 50 points.
- **Impact**: Users are guided to earn points if they can't afford to join a room. The reward for watching an ad in this context is now **100 points**, allowing them to join a room immediately after one ad.

### 3. UI Description Update
- **File**: `lib/screens/room_setup_screen.dart`
- **Action**: Updated the "Join Room" section description to clearly state that joining costs 100 points.
- **Impact**: Improved transparency for users.

## Verification Results

- [x] **Point Deduction**: Verified that 100 points are deducted from both Firestore and the local UI upon joining.
- [x] **Insufficient Points Flow**: Verified that the "Points Required" dialog appears with an ad button when a user has fewer than 100 points.
- [x] **Admin Exemption**: Verified that users with admin credentials are not charged for joining.
- [x] **Re-join Protection**: Verified that re-joining a room the user is already in does not result in a second charge.

> [!NOTE]
> **Ad Limit**: Users can watch up to 3 reward ads per day to earn points for joining or creating rooms.

render_diffs(file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/services/room_service.dart)
render_diffs(file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/screens/room_setup_screen.dart)
