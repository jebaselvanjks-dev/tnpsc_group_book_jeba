import 'package:flutter/material.dart';
import '../constants/app_assets.dart';
import '../utils/app_theme.dart';
import '../utils/app_icons.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final double borderRadius;
  final bool showShadow;

  const AppLogo({
    super.key,
    this.size = 120,
    this.borderRadius = 24,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.asset(
        AppAssets.logo,
        height: size,
        width: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: size,
            width: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: AppIcon(
              Icons.menu_book_rounded,
              size: size * 0.5,
              color: AppTheme.secondaryColor,
            ),
          );
        },
      ),
    );

    if (!showShadow) return image;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: AppTheme.secondaryColor.withValues(alpha: 0.25),
            blurRadius: 30,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: image,
    );
  }
}
