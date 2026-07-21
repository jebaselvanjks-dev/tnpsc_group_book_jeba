import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../utils/app_language.dart';

class AppErrorWidget extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;
  final bool isFullScreen;

  const AppErrorWidget({
    super.key,
    this.message,
    this.onRetry,
    this.isFullScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: isFullScreen ? 60 : 40,
            ),
            const SizedBox(height: 16),
            Text(
              message ?? AppLanguage.getString('error_generic'),
              style: AppTheme.getStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppTheme.textMainColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              AppLanguage.languageNotifier.value == 'ta'
                  ? "மீண்டும் முயற்சிக்கவும் அல்லது சிறிது நேரம் கழித்து வரவும்."
                  : "Please try again or come back later.",
              textAlign: TextAlign.center,
              style: AppTheme.getStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : AppTheme.textSecondaryColor,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(
                  AppLanguage.languageNotifier.value == 'ta' ? "மீண்டும் முயற்சி செய்" : "Retry",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (isFullScreen) {
      return Scaffold(body: SafeArea(child: content));
    }
    return content;
  }
}
