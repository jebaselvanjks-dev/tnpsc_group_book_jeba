import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_log.dart';

import 'auth_local_api.dart';
import 'auth_status_service.dart';
import '../config/password_email_config.dart';
import 'password_email_service.dart';

/// Auth API: Cloud Functions first, Firestore fallback if functions not deployed.
class AuthService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  static bool _useLocalFallback(FirebaseFunctionsException e) {
    final msg = (e.message ?? '').toUpperCase();
    if (msg == 'EMAIL_NOT_REGISTERED' ||
        msg == 'WRONG_CURRENT_PASSWORD' ||
        msg == 'INVALID_EMAIL' ||
        msg == 'WEAK_PASSWORD' ||
        msg == 'NOT_SIGNED_IN' ||
        msg == 'EMAIL_NOT_CONFIGURED') {
      return false;
    }
    return e.code == 'not-found' ||
        e.code == 'unavailable' ||
        e.code == 'deadline-exceeded' ||
        msg.contains('NOT_FOUND') ||
        msg.contains('FUNCTION') ||
        msg.isEmpty;
  }

  static Future<void> saveUserAuth({
    required String email,
    required String password,
    required String name,
    required String uid,
    required bool isSignUp,
  }) async {
    try {
      await _functions.httpsCallable('saveUserAuth').call({
        'email': email.trim(),
        'password': password,
        'name': name,
        'uid': uid,
        'action': isSignUp ? 'register' : 'login',
      });
    } on FirebaseFunctionsException catch (e) {
      AppLog.e('AuthService.saveUserAuth: ${e.code} ${e.message}');
      if (_useLocalFallback(e)) {
        await AuthLocalApi.saveUserAuth(
          email: email,
          password: password,
          name: name,
          uid: uid,
          isSignUp: isSignUp,
        );
        return;
      }
      rethrow;
    }
  }

  /// Returns message key: PASSWORD_EMAIL_SENT or RESET_LINK_SENT (fallback).
  static Future<String> forgotPassword({required String email}) async {
    final trimmed = email.trim();
    try {
      await _functions.httpsCallable('forgotPassword').call({
        'email': trimmed,
      });
      await AuthStatusService.setMustChangePassword(trimmed, true);
      return 'PASSWORD_EMAIL_SENT';
    } on FirebaseFunctionsException catch (e) {
      AppLog.e('AuthService.forgotPassword: ${e.code} ${e.message}');
      if (_useLocalFallback(e)) {
        if (PasswordEmailConfig.canSendPasswordEmail) {
          return PasswordEmailService.sendForgotPasswordEmail(trimmed);
        }
        throw FirebaseFunctionsException(
          code: 'failed-precondition',
          message: 'EMAIL_SETUP_REQUIRED',
        );
      }
      rethrow;
    }
  }

  static Future<void> changePassword({
    required String email,
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'user-not-found');
    }

    if (currentPassword == newPassword) {
      throw FirebaseFunctionsException(
        code: 'invalid-argument',
        message: 'SAME_AS_OLD_PASSWORD',
      );
    }

    try {
      await _functions.httpsCallable('changePassword').call({
        'email': email.trim(),
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });
      await AuthStatusService.clearMustChangePassword(email);
    } on FirebaseFunctionsException catch (e) {
      AppLog.e('AuthService.changePassword: ${e.code} ${e.message}');
      if (_useLocalFallback(e)) {
        await AuthLocalApi.changePassword(
          email: email,
          currentPassword: currentPassword,
          newPassword: newPassword,
        );
        await AuthStatusService.clearMustChangePassword(email);
        return;
      }
      rethrow;
    }
  }

  static String messageFromException(Object e, {bool ta = false}) {
    if (e is FirebaseFunctionsException) {
      final msg = (e.message ?? '').toUpperCase();
      switch (msg) {
        case 'INVALID_EMAIL':
          return ta
              ? 'தவறான மின்னஞ்சல் முகவரி. சரியான email உள்ளிடவும்.'
              : 'Invalid email address. Please enter a valid email.';
        case 'EMAIL_NOT_REGISTERED':
          return ta
              ? 'இந்த மின்னஞ்சல் பதிவு செய்யப்படவில்லை. Sign Up செய்து புதிய கணக்கு உருவாக்கவும்.'
              : 'This email is not registered. Please Sign Up to create an account.';
        case 'EMAIL_NOT_CONFIGURED':
          return ta
              ? 'மின்னஞ்சல் சேவை அமைக்கப்படவில்லை. Admin-ஐ தொடர்பு கொள்ளுங்கள்.'
              : 'Email service is not configured on server. Contact admin.';
        case 'EMAIL_SETUP_REQUIRED':
          return ta
              ? 'மின்னஞ்சல் அமைப்பு இல்லை. Firebase Blaze + Functions deploy அல்லது Apps Script URL-ஐ config-ல் சேர்க்கவும்.'
              : 'Email not configured. Upgrade Firebase to Blaze and deploy functions, OR set Apps Script URL in password_email_config.dart';
        case 'EMAIL_SEND_FAILED':
          return ta
              ? 'மின்னஞ்சல் அனுப்ப முடியவில்லை. Gmail / EmailJS அமைப்பை சரிபார்க்கவும்.'
              : 'Could not send email. Check Gmail / EmailJS / Apps Script setup.';
        case 'WRONG_CURRENT_PASSWORD':
          return ta ? 'தற்போதைய கடவுச்சொல் தவறு.' : 'Current password is incorrect.';
        case 'WEAK_PASSWORD':
          return ta
              ? 'கடவுச்சொல் குறைந்தது 6 எழுத்துக்கள்.'
              : 'Password must be at least 6 characters.';
        case 'SAME_AS_OLD_PASSWORD':
          return ta
              ? 'புதிய கடவுச்சொல் பழையதை விட வித்தியாசமாக இருக்க வேண்டும்.'
              : 'New password must be different from current password.';
        case 'NOT_SIGNED_IN':
          return ta ? 'முதலில் உள்நுழையவும்.' : 'Please sign in first.';
        case 'PASSWORD_EMAIL_SENT':
          return ta
              ? 'உங்கள் கடவுச்சொல் மின்னஞ்சலில் அனுப்பப்பட்டது.'
              : 'Your password has been sent to your email.';
        case 'RESET_LINK_SENT':
          return ta
              ? 'கடவுச்சொல் மாற்ற இணைப்பு உங்கள் மின்னஞ்சலுக்கு அனுப்பப்பட்டது.'
              : 'Password reset link sent to your email.';
        default:
          if (e.code == 'not-found' && msg != 'EMAIL_NOT_REGISTERED') {
            return ta
                ? 'API சேவை கிடைக்கவில்லை. மீண்டும் login செய்து முயற்சிக்கவும்.'
                : 'API service unavailable. Please login again and retry.';
          }
          return e.message ?? (ta ? 'பிழை ஏற்பட்டது' : 'Something went wrong');
      }
    }
    if (e is FirebaseAuthException) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return ta ? 'தவறான கடவுச்சொல்.' : 'Incorrect password.';
      }
      if (e.code == 'requires-recent-login') {
        return ta
            ? 'பாதுகாப்புக்காக மீண்டும் உள்நுழைந்து முயற்சிக்கவும்.'
            : 'For security, sign out and sign in again, then try.';
      }
      if (e.code == 'user-not-found') {
        return ta
            ? 'இந்த மின்னஞ்சல் பதிவு செய்யப்படவில்லை. Sign Up செய்யவும்.'
            : 'Email not registered. Please Sign Up.';
      }
    }
    return ta ? 'பிழை ஏற்பட்டது' : 'Something went wrong';
  }

  static String messageForForgotResult(String key, {bool ta = false}) {
    switch (key) {
      case 'RESET_LINK_SENT':
        return messageFromException(
          FirebaseFunctionsException(code: 'ok', message: 'RESET_LINK_SENT'),
          ta: ta,
        );
      default:
        return messageFromException(
          FirebaseFunctionsException(code: 'ok', message: 'PASSWORD_EMAIL_SENT'),
          ta: ta,
        );
    }
  }
}
