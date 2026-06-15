import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tnpsc_group_book/utils/app_language.dart';
import '../services/hive_service.dart';

class AppTheme {
  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);
  static final ValueNotifier<double> fontSizeFactorNotifier = ValueNotifier(0.8);

  /// Dark theme backgrounds (used across app + native splash)
  static const Color darkBgColor = Color(0xFF030611);
  static const Color darkSurfaceColor = Color(0xFF101F42);

  static const Color primaryColor = Color(0xFF0F2D59); // Premium Deep Navy Blue
  static const Color primaryColorLight = Color(0xFF2C4568); // Premium Deep Navy Blue
  static const Color secondaryColor = Color(0xFFD4AF37); // Premium Gold
  static const Color secondaryColorLight = Color(0xFFCAB577); // Premium Gold
  static const Color accentColor = Color(0xFFE5BA73); // Soft Golden Amber Accent
  static const Color backgroundColor = Color(0xFFF4F6F9); // Soft Light Blue/Slate White
  static const Color cardColor = Colors.white;
  static const Color textMainColor = Color(0xFF14203C); // Very Dark Navy Slate
  static const Color textSecondaryColor = Color(0xFF475569); // Slate Grey

  // Glassmorphism constants
  static Color glassWhite(BuildContext context) => 
    Theme.of(context).brightness == Brightness.dark 
      ? Colors.white.withOpacity(0.08) 
      : Colors.white;
  
  static Color glassBorder(BuildContext context) => 
    Theme.of(context).brightness == Brightness.dark 
      ? Colors.white.withOpacity(0.12) 
      : Colors.grey.withOpacity(0.1);

  static ThemeData get lightTheme => _buildTheme(Brightness.light);
  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    bool isDark = brightness == Brightness.dark;
    bool isTamil = AppLanguage.languageNotifier.value == 'ta';
    double sizeOffset = isTamil ? -1.5 : 0;
    
    // Choose font family based on language
    TextTheme baseTextTheme = isTamil 
      ? GoogleFonts.notoSansTamilTextTheme() 
      : GoogleFonts.outfitTextTheme();

    Color mainTextColor = isDark ? Colors.white : textMainColor;
    Color secTextColor = isDark ? Colors.white70 : textSecondaryColor;

    Color themePrimary = isDark ? secondaryColor : primaryColor; // Gold in dark mode, Navy in light mode
    Color themeSecondary = isDark ? primaryColor : secondaryColor;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: themePrimary,
      colorScheme: ColorScheme.fromSeed(
        brightness: brightness,
        seedColor: themePrimary,
        primary: themePrimary,
        secondary: themeSecondary,
        tertiary: accentColor,
        surface: isDark ? darkSurfaceColor : backgroundColor,
      ),
      scaffoldBackgroundColor: isDark ? darkBgColor : backgroundColor,
      textTheme: baseTextTheme.copyWith(
        displayLarge: baseTextTheme.displayLarge?.copyWith(
          fontSize: (32 + sizeOffset) * fontSizeFactorNotifier.value,
          fontWeight: FontWeight.bold,
          color: mainTextColor,
        ),
        displayMedium: baseTextTheme.displayMedium?.copyWith(
          fontSize: (28 + sizeOffset) * fontSizeFactorNotifier.value,
          fontWeight: FontWeight.bold,
          color: mainTextColor,
        ),
        displaySmall: baseTextTheme.displaySmall?.copyWith(
          fontSize: (24 + sizeOffset) * fontSizeFactorNotifier.value,
          fontWeight: FontWeight.bold,
          color: mainTextColor,
        ),
        headlineLarge: baseTextTheme.headlineLarge?.copyWith(
          fontSize: (22 + sizeOffset) * fontSizeFactorNotifier.value,
          fontWeight: FontWeight.bold,
          color: mainTextColor,
        ),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          fontSize: (20 + sizeOffset) * fontSizeFactorNotifier.value,
          fontWeight: FontWeight.bold,
          color: mainTextColor,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          fontSize: (20 + sizeOffset) * fontSizeFactorNotifier.value,
          fontWeight: FontWeight.w600,
          color: mainTextColor,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          fontSize: (18 + sizeOffset) * fontSizeFactorNotifier.value,
          fontWeight: FontWeight.w600,
          color: mainTextColor,
        ),
        titleSmall: baseTextTheme.titleSmall?.copyWith(
          fontSize: (16 + sizeOffset) * fontSizeFactorNotifier.value,
          fontWeight: FontWeight.w600,
          color: mainTextColor,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          fontSize: (16 + sizeOffset) * fontSizeFactorNotifier.value,
          color: mainTextColor,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          fontSize: (14 + sizeOffset) * fontSizeFactorNotifier.value,
          color: secTextColor,
        ),
        bodySmall: baseTextTheme.bodySmall?.copyWith(
          fontSize: (12 + sizeOffset) * fontSizeFactorNotifier.value,
          color: secTextColor,
        ),
        labelLarge: baseTextTheme.labelLarge?.copyWith(
          fontSize: (14 + sizeOffset) * fontSizeFactorNotifier.value,
          color: secTextColor,
        ),
        labelMedium: baseTextTheme.labelMedium?.copyWith(
          fontSize: (12 + sizeOffset) * fontSizeFactorNotifier.value,
          color: secTextColor,
        ),
        labelSmall: baseTextTheme.labelSmall?.copyWith(
          fontSize: (10 + sizeOffset) * fontSizeFactorNotifier.value,
          color: secTextColor,
        ),
      ),
      cardTheme: CardThemeData(
        color: isDark ? darkSurfaceColor : cardColor,
        elevation: 4,
        shadowColor: isDark ? Colors.black54 : Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: (isTamil ? GoogleFonts.notoSansTamil() : GoogleFonts.outfit()).copyWith(
          color: mainTextColor,
          fontSize: (20 + sizeOffset) * fontSizeFactorNotifier.value,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: mainTextColor),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: themePrimary,
          foregroundColor: isDark ? darkBgColor : Colors.white,
          disabledBackgroundColor: isDark ? Colors.white12 : Colors.grey.shade300,
          disabledForegroundColor: isDark ? Colors.white24 : Colors.grey.shade500,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: (isTamil ? GoogleFonts.notoSansTamil() : GoogleFonts.outfit()).copyWith(
            fontSize: 16 * fontSizeFactorNotifier.value,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  static Future<void> loadThemePreference() async {
    final saved = HiveService.getThemeMode();
    if (saved != null) {
      themeNotifier.value = saved;
    }
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    themeNotifier.value = mode;
    await HiveService.saveThemeMode(mode);
  }

  static Future<void> loadFontSizePreference() async {
    fontSizeFactorNotifier.value = HiveService.getFontSizeFactor();
  }

  static Future<void> setFontSizeFactor(double factor) async {
    double rounded = double.parse(factor.toStringAsFixed(1));
    fontSizeFactorNotifier.value = rounded;
    await HiveService.setFontSizeFactor(rounded);
  }

  // Helper for bilingual text styling
  static TextStyle getStyle({
    required double fontSize,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
    double? height,
  }) {
    bool isTamil = AppLanguage.languageNotifier.value == 'ta';
    
    // Reduce Tamil font size by 1.5 as requested
    double adjustedSize = isTamil ? fontSize - 1.5 : fontSize;
    
    // Apply global font scaling factor
    adjustedSize = adjustedSize * fontSizeFactorNotifier.value;
    
    // Use Outfit for English, Noto Sans Tamil for Tamil
    if (isTamil) {
      return GoogleFonts.notoSansTamil(
        fontSize: adjustedSize,
        fontWeight: fontWeight,
        color: color,
        height: height ?? 1.4, // Tamil needs slightly more line height
      );
    } else {
      return GoogleFonts.outfit(
        fontSize: adjustedSize,
        fontWeight: fontWeight,
        color: color,
        height: height ?? 1.2,
      );
    }
  }
}

