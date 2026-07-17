import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import '../utils/app_log.dart';
import '../utils/app_theme.dart';
import '../utils/app_language.dart';
import '../widgets/app_logo.dart';
import '../main.dart';
import 'login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // AI_DEBUG: Wait for first frame to show logo before starting heavy init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigateToHome();
    });
  }

  Future<void> _navigateToHome() async {
    try {
      // AI_DEBUG: Brief pause to ensure logo is painted smoothly
      await Future.delayed(const Duration(milliseconds: 100));

      // 1. Run all critical services in background while splash is showing
      // Using a timeout to ensure splash doesn't hang forever
      final initFuture = initializeServices().timeout(
        const Duration(seconds: 10),
        onTimeout: () => AppLog.e("AI_DEBUG: Service initialization timed out!"),
      );
      
      // 2. Wait for a minimum time for the animation (1.0s)
      final delayFuture = Future.delayed(const Duration(milliseconds: 1000));
      
      // AI_DEBUG: Await both. This ensures services are ready AND the user sees the logo.
      await Future.wait([initFuture, delayFuture]);
    } catch (e) {
      AppLog.e("AI_DEBUG: Error during splash initialization: $e");
    }

    if (!mounted) return;
    
    try {
      User? user = FirebaseAuth.instance.currentUser;
      
      if (user != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainWrapper()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } catch (e) {
      AppLog.e("AI_DEBUG: Navigation error in SplashScreen: $e");
      // Fallback: If Firebase fails, try to go to Login anyway
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLanguage.languageNotifier,
      builder: (context, lang, child) {
        return Scaffold(
          body: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.darkBgColor, AppTheme.darkSurfaceColor],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AppLogo(size: 120),
                const SizedBox(height: 30),
                AnimatedTextKit(
                  animatedTexts: [
                    TypewriterAnimatedText(
                      AppLanguage.getString('app_title'),
                      textStyle: AppTheme.getStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ).copyWith(letterSpacing: 2),
                      speed: const Duration(milliseconds: 50),
                    ),
                  ],
                  totalRepeatCount: 1,
                ),
                const SizedBox(height: 10),
                Text(
                  AppLanguage.getString('tagline'),
                  style: AppTheme.getStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }
}
