import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import '../utils/app_log.dart';
import '../utils/app_theme.dart';
import '../utils/app_language.dart';
import '../widgets/app_logo.dart';
import '../main.dart';
import 'login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';
import '../services/google_auth_service.dart';
import '../services/hive_service.dart';


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
      // 1. Core Services Setup
      // Note: Core initializeServices() is now called in main() for faster startup,
      // but we wait a bit here to ensure the Splash UI is actually visible to the user.
      AppLog.d("AI_DEBUG: [Splash] Services initialized in main. Ensuring UI visibility...");
      await Future.delayed(const Duration(milliseconds: 800));

      // 2. Auth Session Check
      AppLog.d("AI_DEBUG: [Splash] Waiting for Firebase Auth Session...");
      
      // Step A: Check local persistence flag
      final bool wasLoggedIn = HiveService.isLoggedIn();
      AppLog.d("AI_DEBUG: [Splash] Local login status: $wasLoggedIn");

      // Step B: Give Firebase ample time (up to 5 seconds) to restore its session.
      // Firebase Auth is very good at persisting sessions on its own if valid.
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        user = await FirebaseAuth.instance.authStateChanges().firstWhere(
          (u) => u != null,
          orElse: () => null,
        ).timeout(
          const Duration(seconds: 5), 
          onTimeout: () => null,
        );
      }

      // Step C: Decision Logic
      // We ONLY attempt manual Google restoration if Firebase failed AND we have no other choice.
      // To avoid the popup you mentioned, we skip this if Hive says we were logged in,
      // trusting that Firebase will eventually sync or the user can re-log manually if needed.
      if (user == null && wasLoggedIn) {
        AppLog.d("AI_DEBUG: [Splash] Firebase null but Hive true. Entering app as guest/cached user.");
      }

      bool shouldAllowEntry = user != null || wasLoggedIn;

      AppLog.d("AI_DEBUG: [Splash] Decision: user=${user?.email}, wasLoggedIn=$wasLoggedIn -> entry=$shouldAllowEntry");

      // 3. Conditional Background Tasks
      if (user != null) {
        AppLog.d("AI_DEBUG: [Splash] Triggering background services for logged-in user...");
        initializeBackgroundServices(); // Non-blocking
      }

      // 4. Smooth Transition
      await Future.delayed(const Duration(milliseconds: 500));
      FlutterNativeSplash.remove();

      if (!mounted) return;

      final nextScreen = shouldAllowEntry ? const MainWrapper() : const LoginScreen();
      AppLog.d("AI_DEBUG: [Splash] Navigating to ${nextScreen.runtimeType}");
      
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    } catch (e, stack) {
      AppLog.e("AI_DEBUG: [Splash] Fatal startup error: $e", e, stack);
      FlutterNativeSplash.remove();
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
        // AI_DEBUG: Using a solid color that matches the logo background for a "fitted" look
        // The logo has a very dark navy background.
        return Scaffold(
          body: Container(
            width: double.infinity,
            color: const Color(0xFF02091A), // Exact navy from logo background
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Golden Background / Glow
                    Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        
                        gradient: RadialGradient(
                          colors: [
                            AppTheme.secondaryColor.withValues(alpha: 0.2),
                            AppTheme.secondaryColor.withValues(alpha: 0.05),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    const AppLogo(
                      size: 150,
                      borderRadius: 0, 
                      showShadow: false
                    ),
                  ],
                ),
                const SizedBox(height: 10),
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
