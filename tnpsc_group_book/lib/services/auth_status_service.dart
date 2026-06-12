import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'hive_service.dart';

/// Tracks whether user must change password before using the app (e.g. after forgot-password email).
class AuthStatusService {
  static String _key(String email) =>
      'must_change_password_${email.trim().toLowerCase()}';

  static Future<void> setMustChangePassword(String email, bool value) async {
    final norm = email.trim().toLowerCase();
    await Hive.box(HiveService.userBoxName).put(_key(norm), value);

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: norm)
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      await snap.docs.first.reference.set(
        {'mustChangePassword': value},
        SetOptions(merge: true),
      );
    }
  }

  static Future<bool> mustChangePassword(String email) async {
    final norm = email.trim().toLowerCase();
    final local = Hive.box(HiveService.userBoxName).get(_key(norm));
    if (local == true) return true;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: norm)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return false;
      return snap.docs.first.data()['mustChangePassword'] == true;
    } catch (_) {
      return local == true;
    }
  }

  static Future<void> clearMustChangePassword(String email) async {
    await setMustChangePassword(email, false);
  }
}
