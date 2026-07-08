import 'package:flutter/material.dart';
import 'app_theme.dart';

class AppIcons {
  // Navigation
  static const IconData back = Icons.arrow_back_ios_rounded;
  static const IconData forward = Icons.arrow_forward_ios_rounded;
  static const IconData close = Icons.close_rounded;
  static const IconData home = Icons.home_rounded;
  static const IconData menu = Icons.menu_rounded;
  static const IconData settings = Icons.settings_rounded;
  static const IconData profile = Icons.person_rounded;
  static const IconData leaderboard = Icons.emoji_events_rounded;
  static const IconData books = Icons.menu_book_sharp;

  // Actions
  static const IconData save = Icons.save_rounded;
  static const IconData edit = Icons.edit_rounded;
  static const IconData delete = Icons.delete_outline_rounded;
  static const IconData refresh = Icons.refresh_rounded;
  static const IconData share = Icons.share_rounded;
  static const IconData search = Icons.search_rounded;
  static const IconData add = Icons.add_rounded;
  static const IconData check = Icons.check_circle_rounded;
  static const IconData uncheck = Icons.circle_outlined;
  static const IconData play = Icons.play_arrow_rounded;
  static const IconData stop = Icons.stop_circle_rounded;
  static const IconData timer = Icons.timer_outlined;
  static const IconData lock = Icons.lock_outline_rounded;
  static const IconData unlock = Icons.lock_open_rounded;
  static const IconData logout_rounded = Icons.logout_rounded;

  // Features
  static const IconData ai = Icons.auto_awesome_rounded;
  static const IconData quiz = Icons.quiz_outlined;
  static const IconData calendar = Icons.calendar_month_rounded;
  static const IconData feedback = Icons.feedback_rounded;
  static const IconData star = Icons.star_rounded;
  static const IconData idea = Icons.lightbulb_outline_rounded;
  static const IconData person = Icons.person_outline_rounded;
  static const IconData group = Icons.people_alt_rounded;
  static const IconData tts = Icons.volume_up_rounded;
  static const IconData history = Icons.history_rounded;
}

class AppIcon extends StatelessWidget {
  final IconData icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  const AppIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: AppTheme.fontSizeFactorNotifier,
      builder: (context, factor, child) {
        // If size is provided, scale it. 
        // If size is null, Icon will use IconTheme.of(context).size which is already scaled in AppTheme.
        final double? scaledSize = size != null ? size! * factor : null;
        
        return Icon(
          icon,
          size: scaledSize,
          color: color,
          semanticLabel: semanticLabel,
        );
      },
    );
  }
}
