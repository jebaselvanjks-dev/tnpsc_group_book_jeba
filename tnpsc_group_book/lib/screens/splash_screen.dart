import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
      // 1. Run all critical services in background
      // AI_DEBUG: Using a reduced timeout to prevent hanging
      await initializeServices().timeout(
        const Duration(seconds: 5),
        onTimeout: () => AppLog.e("AI_DEBUG: Service initialization timed out!"),
      );

      // AI_DEBUG: Wait a moment for the system splash to feel "fitted" before removing
      await Future.delayed(const Duration(seconds: 1));
      FlutterNativeSplash.remove();
    } catch (e) {
      AppLog.e("AI_DEBUG: Error during splash initialization: $e");
      FlutterNativeSplash.remove();
    }

    if (!mounted) return;
    
    try {
      User? user = FirebaseAuth.instance.currentUser;
      
      // Navigate using a custom smooth Fade transition instead of default Slide
      final nextScreen = user != null ? const MainWrapper() : const LoginScreen();
      
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
    } catch (e) {
      AppLog.e("AI_DEBUG: Navigation error in SplashScreen: $e");
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
