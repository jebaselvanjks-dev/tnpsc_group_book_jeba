/// Razorpay API configuration.
///
/// 1. https://dashboard.razorpay.com → Settings → API Keys
/// 2. Copy Key ID (rzp_test_* or rzp_live_*) — no spaces
/// 3. Paste below — never put Key Secret in the app
class PaymentConfig {
  static const String razorpayKeyId = 'rzp_test_6527658900001005';

  static const String appName = 'TNPSC Group Book';

  static String get normalizedKeyId =>
      razorpayKeyId.replaceAll(RegExp(r'\s+'), '').trim();

  static bool _isPlaceholder(String key) {
    if (key.isEmpty) return true;
    final upper = key.toUpperCase();
    return upper.contains('YOUR_KEY') ||
        upper.contains('PASTE_YOUR') ||
        upper.contains('PASTE_KEY') ||
        upper.endsWith('_HERE') ||
        key == 'rzp_test_' ||
        key == 'rzp_live_';
  }

  static bool get isConfigured {
    final key = normalizedKeyId;
    if (_isPlaceholder(key)) return false;
    return key.startsWith('rzp_test_') || key.startsWith('rzp_live_');
  }

  static String configurationMessage({bool ta = false}) {
    if (isConfigured) return '';
    if (ta) {
      return 'Razorpay Key ID set pannala.\n'
          'lib/config/payment_config.dart open panni\n'
          'unga Key ID paste pannunga.\n'
          '(Dashboard → Settings → API Keys)';
    }
    return 'Razorpay Key ID not set.\n'
        'Open lib/config/payment_config.dart and replace\n'
        'rzp_test_PASTE_YOUR_KEY_HERE with your Key ID from\n'
        'Dashboard → Settings → API Keys.';
  }
}
