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
  
  // 1. Critical initializations (Fast & Local)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  await HiveService.init();
  await NotificationService.init();
  await AppTheme.loadThemePreference();
  await AppTheme.loadFontSizePreference();
  DeepLinkService().init();

  // 2. Start heavy/network initializations in background
  _initServicesInBackground();
  
  runApp(const TNPSCPrepApp());
}

// Background initializations to speed up startup
Future<void> _initServicesInBackground() async {
  // These don't need to block the UI from starting
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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLanguage.languageNotifier,
      builder: (context, lang, child) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            
            // 1. If not on Home tab, switch to Home tab
            if (_selectedIndex != 0) {
              setState(() {
                _selectedIndex = 0;
              });
              return;
            }
            
            // 2. If on Home tab, show exit confirmation
            final shouldPop = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF101F42) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Text(
                  AppLanguage.getString('exit_app_title'),
                  style: AppTheme.getStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                  ),
                ),
                content: Text(
                  AppLanguage.getString('exit_app_desc'),
                  style: AppTheme.getStyle(
                    fontSize: 16,
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(
                      AppLanguage.getString('no'),
                      style: AppTheme.getStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(AppLanguage.getString('yes')),
                  ),
                ],
              ),
            );

            if (shouldPop ?? false) {
              SystemNavigator.pop();
            }
          },
          child: Scaffold(
            body: IndexedStack(
              index: _selectedIndex,
              children: _screens,
            ),
            // floatingActionButton: FloatingActionButton(
            //   backgroundColor: AppTheme.secondaryColor,
            //   child: const Icon(Icons.format_size_rounded),
            //   onPressed: () {
            //     showModalBottomSheet(
            //       context: context,
            //       builder: (context) {
            //         return ValueListenableBuilder<double>(
            //           valueListenable: AppTheme.fontSizeFactorNotifier,
            //           builder: (context, factor, _) {
            //             return Padding(
            //               padding: const EdgeInsets.all(16),
            //               child: Row(
            //                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //                 children: [
            //                   const Text('Font Size', style: TextStyle(fontWeight: FontWeight.bold)),
            //                   Row(
            //                     children: [
            //                       IconButton(
            //                         icon: const Icon(Icons.remove),
            //                         onPressed: factor > 0.81 ? () => AppTheme.setFontSizeFactor(factor - 0.1) : null,
            //                       ),
            //                       Text('${(factor * 100).round()}%'),
            //                       IconButton(
            //                         icon: const Icon(Icons.add),
            //                         onPressed: factor < 1.39 ? () => AppTheme.setFontSizeFactor(factor + 0.1) : null,
            //                       ),
            //                     ],
            //                   ),
            //                 ],
            //               ),
            //             );
            //           },
            //         );
            //       },
            //     );
            //   },
            // ),
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
