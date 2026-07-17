import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../utils/app_log.dart';
import '../utils/app_theme.dart';
import '../utils/app_language.dart';
import '../main.dart'; // To navigate to MainWrapper
import '../widgets/app_logo.dart';
import '../services/notification_service.dart';
import '../services/google_auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  bool _isExiting = false;

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    final ta = AppLanguage.languageNotifier.value == 'ta';

    try {
      final userCredential = await GoogleAuthService.signInWithGoogle();
      if (userCredential != null && userCredential.user != null) {
        await _initializeUserInFirestore(userCredential.user);
        _navigateToHome();
      } else {
        setState(() => _isLoading = false);
        // User canceled sign-in
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError(ta ? 'Google உள்நுழைவு தோல்வியடைந்தது.' : 'Google Sign-In failed.');
    }
  }

  Future<void> _initializeUserInFirestore(User? user) async {
    if (user == null) return;
    final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final docSnapshot = await userDoc.get();

    if (!docSnapshot.exists) {
      final name = user.displayName ?? AppLanguage.getString('user_fallback');
          
      await userDoc.set({
        'name': name,
        'email': user.email,
        'streak': 1,
        'points': 0,
        'totalScore': 0,
        'lastActive': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await userDoc.update({
        'lastActive': FieldValue.serverTimestamp(),
      });
    }

    await NotificationService.saveFCMToken();
  }

  void _navigateToHome() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MainWrapper()),
    );
  }

  Future<void> _showExitDialog(BuildContext context) async {
    if (_isExiting) return;
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
      _isExiting = true;
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLanguage.languageNotifier,
      builder: (context, lang, child) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final ta = lang == 'ta';

        return PopScope(
          canPop: _isExiting,
          onPopInvokedWithResult: (didPop, result) {
            AppLog.d("AI_DEBUG: [LoginScreen] PopScope triggered. didPop: $didPop");
            if (didPop) return;
            _showExitDialog(context);
          },
          child: Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Center(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const AppLogo(size: 100, showShadow: false),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      AppLanguage.getString('welcome_title'),
                      style: AppTheme.getStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppTheme.textMainColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ta ? 'உள்நுழைந்து உங்களின் TNPSC தயாரிப்பைத் தொடரவும்.' : 'Login to continue your TNPSC preparation.',
                      style: AppTheme.getStyle(
                        fontSize: 15,
                        color: isDark ? Colors.white70 : AppTheme.textSecondaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),

                    // Google Sign-In Button
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _handleGoogleSignIn,
                        icon: _isLoading 
                          ? const SizedBox(
                              width: 20, 
                              height: 20, 
                              child: CircularProgressIndicator(strokeWidth: 2)
                            )
                          : ValueListenableBuilder<double>(
                              valueListenable: AppTheme.fontSizeFactorNotifier,
                              builder: (context, factor, child) {
                                return FaIcon(
                                  FontAwesomeIcons.google, 
                                  color: Colors.red,
                                  size: 24 * factor,
                                );
                              },
                            ),
                        label: Text(
                          ta ? 'Google மூலம் தொடரவும்' : 'Continue with Google',
                          style: AppTheme.getStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: isDark ? Colors.white30 : Colors.black12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ));
      },
    );
  }
}
