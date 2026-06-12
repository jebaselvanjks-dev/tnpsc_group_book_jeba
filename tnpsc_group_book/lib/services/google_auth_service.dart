import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class GoogleAuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static bool _isInitialized = false;

  static Future<UserCredential?> signInWithGoogle() async {
    try {
      // Initialize the plugin only once
      if (!_isInitialized) {
        await _googleSignIn.initialize();
        _isInitialized = true;
      }

      // Prompt the user to select a Google account
      GoogleSignInAccount? googleUser;
      try {
        debugPrint('AI_DEBUG: Calling authenticate()...');
        googleUser = await _googleSignIn.authenticate();
        debugPrint('AI_DEBUG: Authenticate success: ${googleUser.email}');
      } catch (e) {
        debugPrint('AI_DEBUG: Authenticate error type: ${e.runtimeType}');
        debugPrint('AI_DEBUG: Authenticate error: $e');
        if (e is GoogleSignInException && e.code == GoogleSignInExceptionCode.canceled) {
          debugPrint('Google Sign-In was canceled by the user.');
          return null;
        }
        rethrow;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      debugPrint('AI_DEBUG: Got idToken: ${googleAuth.idToken != null}');

      // Create a new credential using idToken
      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      debugPrint('AI_DEBUG: Signing in to Firebase...');
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      debugPrint('AI_DEBUG: Firebase sign-in success: ${userCredential.user?.uid}');
      
      return userCredential;
    } catch (e) {
      debugPrint('AI_DEBUG: Error during Google Sign-In caught in service: $e');
      rethrow;
    }
  }

  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      debugPrint('Error during Sign-Out: $e');
    }
  }
}
