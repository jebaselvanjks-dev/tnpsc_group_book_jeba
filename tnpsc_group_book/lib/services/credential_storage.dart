import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores the last password used on this device (per email) so Change Password can show it.
/// API only keeps bcrypt hash — plaintext cannot be fetched from server.
class CredentialStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );

  static String _key(String email) =>
      'saved_password_${email.trim().toLowerCase()}';

  static Future<void> savePassword({
    required String email,
    required String password,
  }) async {
    if (email.trim().isEmpty || password.isEmpty) return;
    await _storage.write(key: _key(email), value: password);
  }

  static Future<String?> getPassword(String email) async {
    if (email.trim().isEmpty) return null;
    return _storage.read(key: _key(email));
  }

  static Future<void> clearPassword(String email) async {
    if (email.trim().isEmpty) return;
    await _storage.delete(key: _key(email));
  }

  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
