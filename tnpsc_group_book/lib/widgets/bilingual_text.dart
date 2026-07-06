import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../utils/app_language.dart';

class BilingualText extends StatelessWidget {
  final String? en;
  final String? ta;
  final String? legacy;
  final double fontSize;
  final FontWeight fontWeight;
  final Color? color;
  final bool showBoth;

  const BilingualText({
    super.key,
    this.en,
    this.ta,
    this.legacy,
    this.fontSize = 16,
    this.fontWeight = FontWeight.normal,
    this.color,
    this.showBoth = true,
  });

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    String currentLang = AppLanguage.languageNotifier.value;

    String displayEn = en ?? "";
    String displayTa = ta ?? "";
    
    // estructured fields or legacy splitting
    if (displayEn.isEmpty && displayTa.isEmpty && legacy != null) {
      var parsed = AppLanguage.parseBilingual(legacy!);
      displayEn = parsed['en']!;
      displayTa = parsed['ta']!;
    }
    
    // Safety check: if one is empty but the other isn't, use the available one for both to avoid empty lines
    if (displayEn.isEmpty && displayTa.isNotEmpty) displayEn = displayTa;
    if (displayTa.isEmpty && displayEn.isNotEmpty) displayTa = displayEn;

    // 1. If only one language is requested and available
    if (!showBoth) {
      if (currentLang == 'ta') {
        return Text(
          displayTa.isNotEmpty ? displayTa : displayEn,
          style: AppTheme.getStyle(fontSize: fontSize, fontWeight: fontWeight, color: color),
        );
      } else {
        return Text(
          displayEn,
          style: AppTheme.getStyle(fontSize: fontSize, fontWeight: fontWeight, color: color),
        );
      }
    }

    // 2. Show both nicely separated
    if (displayEn == displayTa || displayTa.isEmpty) {
      return Text(
        displayEn,
        style: AppTheme.getStyle(fontSize: fontSize, fontWeight: fontWeight, color: color),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          displayEn,
          style: AppTheme.getStyle(
            fontSize: fontSize, 
            fontWeight: fontWeight, 
            color: color ?? (isDark ? Colors.white : AppTheme.textMainColor),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          displayTa,
          style: AppTheme.getStyle(
            fontSize: fontSize - 1, 
            fontWeight: FontWeight.w500, 
            color: color?.withValues(alpha: 0.8) ?? (isDark ? Colors.white70 : Colors.black54),
          ),
        ),
      ],
    );
  }
}
