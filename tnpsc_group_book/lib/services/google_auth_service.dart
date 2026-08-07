import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../utils/app_log.dart';
import 'hive_service.dart';

class GoogleAuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static bool _isInitialized = false;

  /// Initializes the Google Sign-In plugin with the required Web Client ID for Credential Manager.
  static Future<void> initializePlugin() async {
    if (_isInitialized) return;
    try {
      AppLog.d('AI_DEBUG: Initializing GoogleSignIn instance...');
      await _googleSignIn.initialize(
        serverClientId: '384136070006-mk6ul67oeqanp7qe7i61lcdr1k89ac5n.apps.googleusercontent.com',
      );
      _isInitialized = true;
    } catch (e) {
      AppLog.e('AI_DEBUG: Error initializing GoogleSignIn: $e');
    }
  }

  /// Attempts to restore a previous Google session and signs into Firebase if found.
  /// Mandatory for persistent login in v7.2.0+.
  static Future<User?> restorePreviousSignIn() async {
    try {
      await initializePlugin();
      AppLog.d('AI_DEBUG: [GoogleAuth] Attempting lightweight authentication...');
      
      // Add a strict timeout to prevent hanging the splash screen
      final future = _googleSignIn.attemptLightweightAuthentication();
      if (future == null) {
        AppLog.e('AI_DEBUG: [GoogleAuth] attemptLightweightAuthentication returned null');
        return null;
      }

      final GoogleSignInAccount? googleUser = await future.timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          AppLog.e('AI_DEBUG: [GoogleAuth] Lightweight authentication TIMED OUT');
          return null;
        }
      );
      
      if (googleUser != null) {
        AppLog.d('AI_DEBUG: [GoogleAuth] Restored Google account: ${googleUser.email}. Signing into Firebase...');
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        
        if (googleAuth.idToken == null) {
          AppLog.e('AI_DEBUG: [GoogleAuth] idToken is null. Cannot sign in to Firebase.');
          return null;
        }

        final OAuthCredential credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );
        
        final UserCredential userCredential = await _auth.signInWithCredential(credential);
        AppLog.d('AI_DEBUG: [GoogleAuth] Firebase sign-in SUCCESS for ${userCredential.user?.email}');
        return userCredential.user;
      }
      
      AppLog.d('AI_DEBUG: [GoogleAuth] No Google session found to restore.');
      return null;
    } catch (e) {
      AppLog.e('AI_DEBUG: [GoogleAuth] Error during session restoration: $e');
      return null;
    }
  }

  static Future<UserCredential?> signInWithGoogle() async {
    try {
      // Ensure plugin is initialized
      await initializePlugin();

      // Prompt the user to select a Google account
      GoogleSignInAccount? googleUser;
      try {
        AppLog.d('AI_DEBUG: Calling authenticate()...');
        googleUser = await _googleSignIn.authenticate();
        
        if (googleUser == null) {
          AppLog.d('AI_DEBUG: Google Sign-In was canceled by the user.');
          return null;
        }
        
        AppLog.d('AI_DEBUG: Sign-In success: ${googleUser.email}');
      } catch (e) {
        AppLog.e('AI_DEBUG: Google Sign In Error during authenticate: $e');
        
        if (e is GoogleSignInException && e.code == GoogleSignInExceptionCode.canceled) {
          AppLog.d('AI_DEBUG: User canceled the sign-in flow.');
          return null;
        }
        rethrow;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      AppLog.d('AI_DEBUG: Got idToken: ${googleAuth.idToken != null}');

      // Create a new credential using idToken
      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      AppLog.d('AI_DEBUG: Signing in to Firebase...');
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      AppLog.d('AI_DEBUG: Firebase sign-in success: ${userCredential.user?.uid}');
      
      return userCredential;
    } catch (e) {
      AppLog.e('AI_DEBUG: Error during Google Sign-In caught in service: $e');
      rethrow;
    }
  }

  static Future<void> signOut() async {
    try {
      await HiveService.resetSessionLeaderboardFetched();
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      AppLog.e('Error during Sign-Out: $e');
    }
  }
}
