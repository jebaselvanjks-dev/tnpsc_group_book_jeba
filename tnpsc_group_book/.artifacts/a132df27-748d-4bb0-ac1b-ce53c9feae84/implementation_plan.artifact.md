# Implementation Plan - Instant Launch & Smooth Resume

The goal is to make the app feel "instant" when opening from a cold start (closed) and completely smooth when resuming from the background.

## User Review Required

> [!IMPORTANT]
> **Launch Strategy**: I will move non-critical service initializations to a secondary background phase that starts *after* the first frame of the Home screen is rendered. This significantly reduces the time the user spends looking at the Splash screen.

> [!NOTE]
> **Resume Logic**: I will add a "throttling" mechanism to app-level checks (like updates and streak sync) so they don't fire every single time the app is minimized/maximized, which can cause micro-stutters.

## Proposed Changes

### 1. Cold Start Optimization (Fast Splash)

*   **`main.dart` [MODIFY]**:
    *   Split `initializeServices` into `critical` and `lazy` tiers.
    *   Only `Firebase` and `Hive` (Auth & Theme) remain in the critical path.
    *   Move `DeepLinkService`, `TTS`, and `Ads` to the post-launch phase.
*   **`SplashScreen` [MODIFY]**:
    *   Remove the hardcoded 1000ms delay.
    *   Navigate as soon as critical services are ready.
    *   Use a smoother `FadeTransition` for the transition to the main app.

### 2. Warm Start Optimization (Smooth Resume)

*   **`main.dart` (MainWrapper) [MODIFY]**:
    *   Implement a `_lastCheckTime` timestamp.
    *   Only run `VersionService` and `StreakUpdate` if the app has been in the background for more than 15 minutes. This prevents lag during "accidental" minimizations.
*   **`HiveService` [MODIFY]**:
    *   Optimize the initial cleanup logic to run in a low-priority microtask.

### 3. UI Smoothness

*   **`HomeScreen` [MODIFY]**:
    *   Ensure the `FutureBuilder` uses cached data immediately so the screen isn't empty when the app resumes.

---

### [Component: Services & Main]

#### [MODIFY] [main.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/main.dart)
- Split service initialization.
- Add resume throttling to `MainWrapper`.

#### [MODIFY] [splash_screen.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/screens/splash_screen.dart)
- Optimize timing and transition.

#### [MODIFY] [hive_service.dart](file:///C:/Users/ADMIN/StudioProjects/tnpsc_group_book_jeba/tnpsc_group_book/lib/services/hive_service.dart)
- Make initialization even lighter.

## Verification Plan

### Manual Verification
- **Cold Start**: Close the app completely and time the launch. It should reach the Home screen in under 2 seconds.
- **Warm Start**: Minimize the app while on a subject screen, wait a few seconds, and resume. It should be instantaneous with no "hiccup".
- **Stress Test**: Rapidly minimize/maximize 10 times to ensure no redundant network calls are triggered.
