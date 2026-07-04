import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tnpsc_group_book/utils/app_language.dart';
import 'package:tnpsc_group_book/utils/app_theme.dart';

class VersionService {
  static const String _playStoreUrl = "https://play.google.com/store/apps/details?id=com.tnpsc.master";
  static int? _requiredVersion;

  static Future<bool> isUpdateRequired() async {
    try {
      if (_requiredVersion == null) {
        final doc = await FirebaseFirestore.instance.collection('settings').doc('app_config').get();
        if (doc.exists) {
          _requiredVersion = doc.data()?['required_version_code'] as int?;
        }
      }
      
      if (_requiredVersion == null) return false;

      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      // Using buildNumber (int) for reliable comparison
      int currentVersion = int.parse(packageInfo.version.replaceAll(".", ""));
      
      debugPrint("API: Version Check: $_requiredVersion");
      debugPrint("CURRENT: Version Check: $currentVersion");
      debugPrint("CURRENT: Version Check: ${currentVersion != _requiredVersion}");
      // Returns true if versions are NOT equal
      return currentVersion != _requiredVersion;
    } catch (e) {
      debugPrint("AI_DEBUG: Version check error: $e");
      return false; 
    }
  }

  static Future<void> checkForUpdate(BuildContext context) async {
    bool updateRequired = await isUpdateRequired();
    if (updateRequired && context.mounted) {
      _showUpdateDialog(context, mandatory: true);
    }
  }

  static Future<void> showUpdateDialogIfNeeded(BuildContext context) async {
    bool updateRequired = await isUpdateRequired();
    if (updateRequired && context.mounted) {
      _showUpdateDialog(context, mandatory: true);
    }
  }

  static void _showUpdateDialog(BuildContext context, {bool mandatory = false}) {
    showDialog(
      context: context,
      barrierDismissible: !mandatory,
      builder: (context) => PopScope(
        canPop: !mandatory,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(AppLanguage.getString(mandatory ? 'update_required_title' : 'update_available')),
          content: Text(
            AppLanguage.getString(mandatory ? 'update_required_desc' : 'update_desc'),
            style: AppTheme.getStyle(fontSize: 16),
          ),
          actions: [
            if (!mandatory)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLanguage.getString('close_btn'), style: AppTheme.getStyle(fontSize: 14, color: Colors.grey[600])),
              ),
            TextButton(
              onPressed: () async {
                final Uri url = Uri.parse(_playStoreUrl);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              child: Text(AppLanguage.getString('update_now'), style: AppTheme.getStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue)),
            ),
          ],
        ),
      ),
    );
  }
}
