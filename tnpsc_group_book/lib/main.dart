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

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // 1. Critical local-only initializations (Fast)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize DeepLinkService immediately to catch early links
  DeepLinkService().init();

  // Initialize Hive immediately as it's needed for UI state
  await HiveService.init();
  
  // Load local preferences
  await AppTheme.loadThemePreference();
  await AppTheme.loadFontSizePreference();

  // 2. Network/Heavy initializations (In Background)
  // Move everything else to a non-blocking background initialization
  _initServicesInBackground();
  
  runApp(const TNPSCPrepApp());
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

class _MainWrapperState extends State<MainWrapper> {
  int _selectedIndex = 0;
  bool _isExiting = false;

  @override
  void initState() {
    super.initState();
    // Centralized app-level checks
    WidgetsBinding.instance.addPostFrameCallback((_) {
      VersionService.checkForUpdate(context);
      FirestoreService().updateStreak();
    });
  }

  final List<Widget> _screens = [
    const HomeScreen(),
    const SubjectScreen(),
    const LeaderboardScreen(),
    const ProfileScreen(),
  ];

  Future<void> _handleBackNavigation() async {
    debugPrint("AI_DEBUG: [MainWrapper] _handleBackNavigation called. Current index: $_selectedIndex, isExiting: $_isExiting");
    if (_isExiting) {
      debugPrint("AI_DEBUG: [MainWrapper] Already in exiting state, ignoring.");
      return;
    }

    // 1. If not on Home tab, switch to Home tab
    if (_selectedIndex != 0) {
      debugPrint("AI_DEBUG: [MainWrapper] Not on Home tab (index $_selectedIndex). Switching to Home (index 0).");
      setState(() {
        _selectedIndex = 0;
      });
      return;
    }

    // 2. If on Home tab, show exit confirmation
    debugPrint("AI_DEBUG: [MainWrapper] On Home tab. Showing exit confirmation dialog.");
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
              debugPrint("AI_DEBUG: [MainWrapper] User chose NOT to exit.");
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
              debugPrint("AI_DEBUG: [MainWrapper] User chose YES to exit.");
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
      debugPrint("AI_DEBUG: [MainWrapper] Executing SystemNavigator.pop()");
      SystemNavigator.pop();
    } else {
      debugPrint("AI_DEBUG: [MainWrapper] Resetting isExiting to false.");
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
            debugPrint("AI_DEBUG: [MainWrapper] Global PopScope triggered. didPop: $didPop");
            if (didPop) return;
            _handleBackNavigation();
          },
          child: Scaffold(
            body: IndexedStack(
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
                    iconSize: 24,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    duration: const Duration(milliseconds: 400),
                    tabBackgroundColor: AppTheme.secondaryColor.withOpacity(0.1),
                    color: Colors.grey,
                    tabs: [
                      GButton(icon: Icons.home_rounded, text: AppLanguage.getString('home')),
                      GButton(icon: Icons.menu_book_sharp, text: AppLanguage.getString('book')),
                      GButton(icon: Icons.emoji_events_rounded, text: AppLanguage.getString('rank')),
                      GButton(icon: Icons.person_rounded, text: AppLanguage.getString('profile')),
                    ],
                    selectedIndex: _selectedIndex,
                    onTabChange: (index) {
                      debugPrint("AI_DEBUG: [MainWrapper] Tab changed to index $index");
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
