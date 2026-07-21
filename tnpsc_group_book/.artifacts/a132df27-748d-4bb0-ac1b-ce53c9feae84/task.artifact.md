# Implementation Task List - Instant Launch & Smooth Resume

- [x] Split `initializeServices` in `main.dart` into Critical and Lazy tiers
- [x] Add resume throttling (15-min rule) to `MainWrapper` in `main.dart`
- [x] Optimize `SplashScreen` for faster navigation and remove hardcoded delays
- [x] Ensure `HiveService` cleanup doesn't block main thread
- [x] Add loading feedback to Profile Share button
- [x] Verify startup speed and resume performance
