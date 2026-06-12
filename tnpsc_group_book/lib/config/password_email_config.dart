/// Forgot-password email setup (Cloud Functions need Firebase Blaze plan).
///
/// **Option A – Apps Script (free, recommended on Spark plan)**
/// 1. Firebase Console → Service accounts → Generate new private key (JSON)
/// 2. Open `apps_script/ForgotPassword.gs` in https://script.google.com
/// 3. Script properties: `SERVICE_ACCOUNT_JSON` = full JSON key content
/// 4. Deploy → Web app → Anyone → paste URL below
///
/// **Option B – Firebase Blaze + Cloud Functions**
/// Upgrade project, then: `firebase functions:config:set gmail.user="..." gmail.password="app-password"`
/// and `firebase deploy --only functions`
///
/// **Option C – EmailJS** (https://www.emailjs.com) – email only; pair with Apps Script URL for login sync.
class PasswordEmailConfig {
  /// Web App URL from Google Apps Script deployment.
  static const String appsScriptWebAppUrl = 'https://script.google.com/macros/s/AKfycbwtWOfAgB6EAWyxY9gV-yXxoygXGwBgq_W6aXvU7vfhUxtLk1EV5k5uoM0Zp_G1NnhMzQ/exec';

  static const String emailJsServiceId = '';
  static const String emailJsTemplateId = '';
  static const String emailJsPublicKey = '';

  static bool get hasAppsScript => appsScriptWebAppUrl.trim().isNotEmpty;

  static bool get hasEmailJs =>
      emailJsServiceId.isNotEmpty &&
      emailJsTemplateId.isNotEmpty &&
      emailJsPublicKey.isNotEmpty;

  static bool get canSendPasswordEmail => hasAppsScript || hasEmailJs;
}
