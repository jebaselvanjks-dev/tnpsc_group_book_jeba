import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tnpsc_group_book/screens/subject_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/books_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/quiz_screen.dart';
import 'utils/app_theme.dart';
import 'utils/app_language.dart';
import 'utils/app_icons.dart';
import 'services/notification_service.dart';
import 'services/hive_service.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/services.dart';
import 'services/tts_service.dart';
import 'services/reward_service.dart';
import 'firebase_options.dart';

import 'services/firestore_service.dart';
import 'services/version_service.dart';
import 'services/deep_link_service.dart';
import 'utils/app_log.dart';
import 'widgets/lazy_indexed_stack.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() {
  // 1. Core Flutter initialization (Instant)
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Global Error Handling (Crash Prevention)
  FlutterError.onError = (FlutterErrorDetails details) {
    AppLog.e("GLOBAL_FLUTTER_ERROR: ${details.exception}", details.exception, details.stack);
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    AppLog.e("GLOBAL_PLATFORM_ERROR: $error", error, stack);
    return true; // Prevent app from terminating
  };

  // 3. Start UI immediately
  runApp(const TNPSCPrepApp());
}

// Background initializations triggered by SplashScreen
Future<void> initializeServices() async {
  // AI_DEBUG: Yield to let UI render first frame
  await Future.delayed(Duration.zero);
  AppLog.d("AI_DEBUG: initializeServices started");
  
  // Lock orientation to portrait
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // 1. Critical initializations
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    AppLog.d("AI_DEBUG: Firebase initialized");
  } catch (e) {
    AppLog.e("AI_DEBUG: Firebase init error: $e");
  }
  
  // Initialize Hive immediately as it's needed for UI state and other services
  await HiveService.init();
  AppLog.d("AI_DEBUG: Hive initialized");

  // Load preferences from Hive
  AppLanguage.init();
  AppTheme.init();
  AppLog.d("AI_DEBUG: App preferences initialized");

  // Initialize DeepLinkService after Hive as it may depend on app settings/language
  DeepLinkService().init();
  
  // 2. Network/Heavy initializations (In Background)
  _initServicesInBackground();
  
  AppLog.d("AI_DEBUG: initializeServices completed");
}

// Background initializations to speed up startup
Future<void> _initServicesInBackground() async {
  // Use a small delay to allow the splash screen to render first
  await Future.delayed(const Duration(milliseconds: 100));

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Non-blocking services
  NotificationService.init();
  MobileAds.instance.initialize();
  TtsService.init();
  RewardService.loadRewardedAd();
}

class TNPSCPrepApp extends StatelessWidget {
  const TNPSCPrepApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Global Error UI (Prevents Grey Screen of Death)
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return ValueListenableBuilder<String>(
        valueListenable: AppLanguage.languageNotifier,
        builder: (context, lang, _) {
          final ta = lang == 'ta';
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.red, size: 60),
                      const SizedBox(height: 16),
                      Text(
                        AppLanguage.getString('error_generic'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        ta ? "செயலியை மீண்டும் தொடங்கவும். நாங்கள் இதைச் சரிசெய்கிறோம்." : "Please restart the app. We've logged this issue for fixing.",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => SystemNavigator.pop(),
                        child: Text(ta ? "வெளியேறு" : "Exit App"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
      );
    };

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return ValueListenableBuilder<String>(
          valueListenable: AppLanguage.languageNotifier,
          builder: (context, lang, child) {
            return ValueListenableBuilder<double>(
              valueListenable: AppTheme.fontSizeFactorNotifier,
              builder: (context, fontSizeFactor, child) {
                return MaterialApp(
                  title: AppLanguage.getString('app_title'),
                  scaffoldMessengerKey: scaffoldMessengerKey,
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.lightTheme,
                  darkTheme: AppTheme.darkTheme,
                  themeMode: currentMode,
                  home: const SplashScreen(),
                );
              },
            );
          },
        );
      },
    );
  }
}

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  bool _isExiting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Centralized app-level checks
    WidgetsBinding.instance.addPostFrameCallback((_) {
      VersionService.checkForUpdate(context);
      FirestoreService().updateStreak();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    AppLog.d("AI_DEBUG: App Lifecycle State changed to: $state");
    
    if (state == AppLifecycleState.resumed) {
      // Refresh critical data when user returns to the app
      FirestoreService().updateStreak();
      VersionService.checkForUpdate(context);
    } else if (state == AppLifecycleState.paused) {
      // Perform any urgent saving if needed
      AppLog.d("AI_DEBUG: App paused - ensuring local state is consistent");
    }
  }

  final List<Widget> _screens = [
    const HomeScreen(),
    const SubjectScreen(),
    const LeaderboardScreen(),
    const ProfileScreen(),
  ];

  Future<void> _handleBackNavigation() async {
    AppLog.d("AI_DEBUG: [MainWrapper] _handleBackNavigation called. Current index: $_selectedIndex, isExiting: $_isExiting");
    if (_isExiting) {
      AppLog.d("AI_DEBUG: [MainWrapper] Already in exiting state, ignoring.");
      return;
    }

    // 1. If not on Home tab, switch to Home tab
    if (_selectedIndex != 0) {
      AppLog.d("AI_DEBUG: [MainWrapper] Not on Home tab (index $_selectedIndex). Switching to Home (index 0).");
      setState(() {
        _selectedIndex = 0;
      });
      return;
    }

    // 2. If on Home tab, show exit confirmation
    AppLog.d("AI_DEBUG: [MainWrapper] On Home tab. Showing exit confirmation dialog.");
    _isExiting = true;
    final shouldPop = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF101F42)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          AppLanguage.getString('exit_app_title'),
          style: AppTheme.getStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black87,
          ),
        ),
        content: Text(
          AppLanguage.getString('exit_app_desc'),
          style: AppTheme.getStyle(
            fontSize: 16,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white70
                : Colors.black54,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              AppLog.d("AI_DEBUG: [MainWrapper] User chose NOT to exit.");
              _isExiting = false;
              Navigator.pop(context, false);
            },
            child: Text(
              AppLanguage.getString('no'),
              style: AppTheme.getStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              AppLog.d("AI_DEBUG: [MainWrapper] User chose YES to exit.");
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(AppLanguage.getString('yes')),
          ),
        ],
      ),
    );

    if (shouldPop ?? false) {
      AppLog.d("AI_DEBUG: [MainWrapper] Executing SystemNavigator.pop()");
      SystemNavigator.pop();
    } else {
      AppLog.d("AI_DEBUG: [MainWrapper] Resetting isExiting to false.");
      _isExiting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLanguage.languageNotifier,
      builder: (context, lang, child) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            AppLog.d("AI_DEBUG: [MainWrapper] Global PopScope triggered. didPop: $didPop");
            if (didPop) return;
            _handleBackNavigation();
          },
          child: Scaffold(
            body: LazyIndexedStack(
              index: _selectedIndex,
              children: _screens,
            ),
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? AppTheme.darkBgColor : Colors.white,
                boxShadow: [
                  BoxShadow(blurRadius: 20, color: Colors.black.withOpacity(0.1)),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 8),
                  child: GNav(
                    rippleColor: Colors.grey[300]!,
                    hoverColor: Colors.grey[100]!,
                    gap: 8,
                    activeColor: AppTheme.secondaryColor,
                    iconSize: AppTheme.getScaledIconSize(24),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    duration: const Duration(milliseconds: 400),
                    tabBackgroundColor: AppTheme.secondaryColor.withOpacity(0.1),
                    color: Colors.grey,
                    tabs: [
                      GButton(icon: AppIcons.home, text: AppLanguage.getString('home')),
                      GButton(icon: AppIcons.books, text: AppLanguage.getString('book')),
                      GButton(icon: AppIcons.leaderboard, text: AppLanguage.getString('rank')),
                      GButton(icon: AppIcons.profile, text: AppLanguage.getString('profile')),
                    ],
                    selectedIndex: _selectedIndex,
                    onTabChange: (index) {
                      AppLog.d("AI_DEBUG: [MainWrapper] Tab changed to index $index");
                      setState(() {
                        _selectedIndex = index;
                      });
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      }
    );
  }
}
