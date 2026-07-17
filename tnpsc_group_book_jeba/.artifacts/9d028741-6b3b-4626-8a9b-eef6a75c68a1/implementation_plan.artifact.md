# Implementation Plan - Fix Share Function and Poster Content in Profile Screen

The goal is to fix the share functionality in `profile_screen.dart` and ensure the generated poster matches the provided design perfectly. The user mentioned "image constant function", which likely refers to ensuring the poster's content and styling remain consistent (constant) regardless of user settings like font scale, and fixing the broken share implementation.

## User Review Required

> [!IMPORTANT]
> The share implementation currently uses a non-existent `SharePlus` API, which causes a crash or failure when sharing. I will replace it with the correct `Share.shareXFiles` API.

> [!NOTE]
> I will decouple the poster's font styling from the app's global font scaling. This ensures the shared image always looks professional and doesn't overflow if the user has set a very large font size in the app settings.

## Proposed Changes

### [Component Name] Profile Screen & Poster Generation

#### [MODIFY] [profile_screen.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/screens/profile_screen.dart)

- **Fix Share Logic**: Replace `SharePlus.instance.share(params)` with `Share.shareXFiles`.
- **Poster Consistency**: Update `_buildSharePoster` and its sub-widgets to use fixed font sizes and styles, ignoring the user's global `fontSizeFactor`.
- **Header Fix**: Correctly use (or remove unused) `displayTitle` and ensure the branding matches the provided image.
- **Visual Refinement**:
    - Adjust the circular logo's padding and size.
    - Ensure the "Google Play" badge is high quality.
    - Verify background image selection.

## Verification Plan

### Automated Tests
- I will verify the code compiles by checking for syntax errors in the modified file.
- Since this is a UI and sharing task, manual verification by the user is required to see the final output.

### Manual Verification
- The user should trigger the "Share with Friends" action in the Profile screen.
- Verify that the Preview Dialog shows a correctly formatted poster.
- Verify that clicking "Share Now" opens the system share sheet without errors.
- Verify that the shared image looks consistent even if the app's font size is changed.
