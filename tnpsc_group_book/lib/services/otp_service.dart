import 'dart:convert';
import 'dart:math';

class OtpService {
  static final _random = Random.secure();

  /// Generates a 6-digit random OTP
  static String generateOtp() {
    final number = 100000 + _random.nextInt(900000);
    return number.toString();
  }

  /// Generates a highly secure, deterministic hidden password for Firebase Auth
  /// User never sees this password, it is used behind the scenes for OTP login.
  static String getDeterministicPassword(String email) {
    final norm = email.trim().toLowerCase();
    // A complex deterministic string
    final rawString = 'TNPSC_OTP_SECURE_${norm}_2026!@#\$%^';
    // Base64 encode it so it passes any password complexity rules
    final encoded = base64Encode(utf8.encode(rawString));
    // Ensure it's long enough and strong
    return 'Otp@$encoded';
  }
}
