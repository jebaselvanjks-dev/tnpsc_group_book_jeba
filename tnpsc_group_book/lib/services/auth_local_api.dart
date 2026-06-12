import 'package:bcrypt/bcrypt.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'auth_status_service.dart';
/// Saves / updates password in Firestore when Cloud Functions are not deployed.
class AuthLocalApi {
  static final _db = FirebaseFirestore.instance;

  static String _norm(String email) => email.trim().toLowerCase();

  static Future<bool> isEmailRegistered(String email) async {
    final norm = _norm(email);

    final userSnap = await _db
        .collection('users')
        .where('email', isEqualTo: norm)
        .limit(1)
        .get();
    return userSnap.docs.isNotEmpty;
  }

  static Future<void> saveUserAuth({
    required String email,
    required String password,
    required String name,
    required String uid,
    required bool isSignUp,
  }) async {
    final norm = _norm(email);
    final hash = BCrypt.hashpw(password, BCrypt.gensalt());

    if (uid.isNotEmpty) {
      await _db.collection('users').doc(uid).set(
        {
          'email': norm,
          'name': name,
          'passwordHash': hash,
          'lastAction': isSignUp ? 'register' : 'login',
          'authSyncedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
  }

  static Future<void> changePassword({
    required String email,
    required String currentPassword,
    required String newPassword,
  }) async {
    if (currentPassword == newPassword) {
      throw FirebaseFunctionsException(
        code: 'invalid-argument',
        message: 'SAME_AS_OLD_PASSWORD',
      );
    }

    final norm = _norm(email);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'user-not-found');
    }

    final cred = EmailAuthProvider.credential(
      email: norm,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(cred);

    final newHash = BCrypt.hashpw(newPassword, BCrypt.gensalt());

    await _db.collection('users').doc(user.uid).set(
      {
        'passwordHash': newHash,
        'mustChangePassword': false,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await user.updatePassword(newPassword);
    await AuthStatusService.clearMustChangePassword(norm);
  }
}
