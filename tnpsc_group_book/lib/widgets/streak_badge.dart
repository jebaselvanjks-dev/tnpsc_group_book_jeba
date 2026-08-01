import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../utils/app_language.dart';

class StreakBadge extends StatelessWidget {
  final int streak;
  const StreakBadge({super.key, required this.streak});

  @override
  Widget build(BuildContext context) {
    if (streak < 7) return const SizedBox.shrink();

    String icon = '🎖️';
    String labelKey = 'streak_7';
    Color color = Colors.orange;

    if (streak >= 30) {
      icon = '👑';
      labelKey = 'streak_30';
      color = Colors.purple;
    } else if (streak >= 14) {
      icon = '🛡️';
      labelKey = 'streak_14';
      color = Colors.blue;
    }

    return Container(
      margin: const EdgeInsets.only(right: 6, top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: AppTheme.getStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            AppLanguage.getString(labelKey),
            style: AppTheme.getStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
