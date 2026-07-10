import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tnpsc_group_book/utils/app_icons.dart';
import '../models/subject.dart';
import '../models/question.dart';
import '../services/hive_service.dart';
import '../utils/app_log.dart';
import '../utils/app_theme.dart';
import '../utils/app_date.dart';
import '../utils/app_language.dart';
import '../services/firestore_service.dart';
import 'settings_screen.dart';
import 'login_screen.dart';
import 'admin_panel_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/credential_storage.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  final FirestoreService _firestoreService = FirestoreService();
  final user = FirebaseAuth.instance.currentUser;
  String _appVersion = "1.0.0";

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = packageInfo.version;
        });
      }
    } catch (e) {
      AppLog.e("Error loading app version: $e");
    }
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not launch $urlString')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  bool get _isAdmin {
    return user?.phoneNumber == '+918754236411' ||
        user?.email == 'adminjeba@gmail.com' ||
        user?.email == 'kjebaselvan987@gmail.com';
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<String>(
      valueListenable: AppLanguage.languageNotifier,
      builder: (context, lang, child) {
        return Column(
          children: [
            // Custom Header for Profile inside MainWrapper
            Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 10,
                left: 20,
                right: 20,
                bottom: 10,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const AppIcon(AppIcons.back, color: Colors.transparent),
                    onPressed: () {},
                  ),
                  Text(
                    AppLanguage.getString('profile'),
                    style: AppTheme.getStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      color: isDark ? Colors.white : AppTheme.textMainColor,
                    ),
                  ),
                  IconButton(
                    icon: const AppIcon(AppIcons.settings),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: ValueListenableBuilder<ThemeMode>(
                valueListenable: AppTheme.themeNotifier,
                builder: (context, currentMode, _) {
                  return FutureBuilder<List<dynamic>>(
                    future: Future.wait([
                      _firestoreService.getUserData(),
                      _firestoreService.getUserGlobalRank(),
                    ]),
                    builder: (context, snapshot) {
                      final userDataDoc = snapshot.data?[0] as DocumentSnapshot?;
                      final int globalRank = snapshot.data?[1] as int? ?? 0;
                      final userData = userDataDoc?.data() as Map<String, dynamic>?;

                      // Extract data with defaults
                      final String name =
                          userData?['name'] ??
                          user?.displayName ??
                          AppLanguage.getString('user_fallback');
                      final String email =
                          userData?['email'] ??
                          user?.email ??
                          AppLanguage.getString('no_email_linked');
                      final String totalScore = (userData?['totalScore'] ?? 0)
                          .toString();
                      final String rankVal = globalRank > 0
                          ? globalRank.toString()
                          : "--";

                      return ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        children: [
                          const SizedBox(height: 10),
                          // Profile Header
                          Center(
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppTheme.accentColor,
                                      width: 2,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 40,
                                    backgroundColor: AppTheme.primaryColor
                                        .withOpacity(0.1),
                                    backgroundImage: user?.photoURL != null
                                        ? NetworkImage(user!.photoURL!)
                                        : null,
                                    child: user?.photoURL == null
                                        ? const AppIcon(
                                            AppIcons.person,
                                            size: 40,
                                            color: AppTheme.primaryColor,
                                          )
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  name,
                                  style: AppTheme.getStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : AppTheme.textMainColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  email,
                                  style: AppTheme.getStyle(
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.white70
                                        : AppTheme.textSecondaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 15),

                          // Stats Row
                          Row(
                            children: [
                              ValueListenableBuilder(
                                valueListenable: Hive.box(
                                  HiveService.userBoxName,
                                ).listenable(),
                                builder: (context, box, child) {
                                  int count =
                                      box.get('quizzesCompleted', defaultValue: 0)
                                          as int;
                                  return _buildStatBox(
                                    context,
                                    AppLanguage.getString('quizzes'),
                                    "$count",
                                    Colors.blue,
                                  );
                                },
                              ),
                              const SizedBox(width: 16),
                              ValueListenableBuilder(
                                valueListenable: Hive.box(
                                  HiveService.userBoxName,
                                ).listenable(),
                                builder: (context, box, child) {
                                  int points =
                                      box.get('totalScore', defaultValue: 0) as int;
                                  return _buildStatBox(
                                    context,
                                    AppLanguage.getString('points'),
                                    "$points",
                                    Colors.green,
                                  );
                                },
                              ),
                              const SizedBox(width: 16),
                              _buildStatBox(
                                context,
                                AppLanguage.getString('rank'),
                                rankVal,
                                Colors.orange,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Quick Settings Section
                          Text(
                            AppLanguage.getString('quick_settings'),
                            style: AppTheme.getStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.accentColor,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                            color: isDark
                                ? Theme.of(context).cardColor
                                : Colors.white,
                            child: Column(
                              children: [
                                ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const AppIcon(
                                      Icons.language_rounded,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  title: const Text("தமிழ் / English"),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      lang == 'ta'
                                          ? Text(
                                              "தமிழ்",
                                              style: AppTheme.getStyle(
                                                fontSize: 10,
                                                fontWeight: lang == 'ta'
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                                color: lang == 'ta'
                                                    ? AppTheme.secondaryColor
                                                    : Colors.grey,
                                              ),
                                            )
                                          : Text(
                                              "English",
                                              style: AppTheme.getStyle(
                                                fontSize: 10,
                                                fontWeight: lang == 'en'
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                                color: lang == 'en'
                                                    ? AppTheme.secondaryColor
                                                    : Colors.grey,
                                              ),
                                            ),
                                      Switch(
                                        value: lang == 'en',
                                        activeColor: AppTheme.secondaryColor,
                                        inactiveThumbColor: AppTheme.secondaryColor,
                                        onChanged: (val) =>
                                            AppLanguage.changeLanguage(
                                              val ? 'en' : 'ta',
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const AppIcon(
                                      Icons.dark_mode_rounded,
                                      color: Colors.purple,
                                    ),
                                  ),
                                  title: Text(AppLanguage.getString('dark_theme')),
                                  trailing: Switch(
                                    value:
                                        currentMode == ThemeMode.dark ||
                                        (currentMode == ThemeMode.system && isDark),
                                    activeColor: AppTheme.secondaryColor,
                                    onChanged: (val) {
                                      AppTheme.setThemeMode(
                                        val ? ThemeMode.dark : ThemeMode.light,
                                      );
                                    },
                                  ),
                                ),
                                const Divider(height: 1),
                                ValueListenableBuilder<double>(
                                  valueListenable: AppTheme.fontSizeFactorNotifier,
                                  builder: (context, fontSizeFactor, _) {
                                    return ListTile(
                                      leading: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const AppIcon(
                                          Icons.format_size_rounded,
                                          color: Colors.orange,
                                        ),
                                      ),
                                      title: Text(
                                        AppLanguage.getString('font_size'),
                                      ),
                                      // subtitle: Text(AppLanguage.getString('font_size_desc')),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            onPressed: fontSizeFactor > 0.81
                                                ? () => AppTheme.setFontSizeFactor(
                                                    fontSizeFactor - 0.1,
                                                  )
                                                : null,
                                            icon: const AppIcon(Icons.remove_circle_outline_rounded),
                                          ),
                                          Text(
                                            "${(fontSizeFactor * 100).round()}%",
                                            style: AppTheme.getStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: fontSizeFactor < 1.39
                                                ? () => AppTheme.setFontSizeFactor(
                                                    fontSizeFactor + 0.1,
                                                  )
                                                : null,
                                            icon: const AppIcon(Icons.add_circle_outline_rounded),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Others
                          Text(
                            AppLanguage.getString('more'),
                            style: AppTheme.getStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.accentColor,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                            color: isDark
                                ? Theme.of(context).cardColor
                                : Colors.white,
                            child: Column(
                              children: [
                                if (_isAdmin) ...[
                                  ListTile(
                                    leading: const AppIcon(
                                      Icons.admin_panel_settings_rounded,
                                      color: Colors.blueGrey,
                                    ),
                                    title: Text(
                                      AppLanguage.getString('admin_panel'),
                                    ),
                                    trailing: const AppIcon(
                                      Icons.chevron_right_rounded,
                                      color: Colors.grey,
                                    ),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const AdminPanelScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                  const Divider(height: 1),
                                ],
                                ListTile(
                                  leading: const AppIcon(
                                    Icons.update,
                                    color: Colors.grey,
                                  ),
                                  title: Text(AppLanguage.getString('app_version')),
                                  trailing: Text(_appVersion,
                                    style: AppTheme.getStyle(
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.white70
                                      : Colors.black54,
                                    fontWeight: FontWeight.w600,
                                  ),),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const AppIcon(
                                    Icons.info_outline_rounded,
                                    color: Colors.grey,
                                  ),
                                  title: Text(AppLanguage.getString('about_app')),
                                  trailing: const AppIcon(
                                    Icons.chevron_right_rounded,
                                    color: Colors.grey,
                                  ),
                                  onTap: () => _launchURL(
                                    'https://tnpscmasterapp.blogspot.com/2026/06/about-app.html',
                                  ),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const AppIcon(
                                    Icons.privacy_tip_outlined,
                                    color: Colors.grey,
                                  ),
                                  title: Text(
                                    AppLanguage.getString('privacy_policy'),
                                  ),
                                  trailing: const AppIcon(
                                    Icons.chevron_right_rounded,
                                    color: Colors.grey,
                                  ),
                                  onTap: () => _launchURL(
                                    'https://tnpscmasterapp.blogspot.com/2026/06/privacy-policy.html',
                                  ),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const AppIcon(
                                    Icons.share_rounded,
                                    color: Colors.blueAccent,
                                  ),
                                  title: Text(
                                    AppLanguage.languageNotifier.value == 'ta' ? 'நண்பர்களுடன் பகிர்க' : 'Share with Friends',
                                    style: AppTheme.getStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueAccent,
                                    ),
                                  ),
                                  trailing: const AppIcon(
                                    Icons.chevron_right_rounded,
                                    color: Colors.grey,
                                  ),
                                  onTap: _shareAppWithRandomQuiz,
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: AppIcon(
                                    AppIcons.logout_rounded ?? Icons.logout_rounded, // fallback if not defined
                                    color: Colors.redAccent,
                                  ),
                                  title: Text(
                                    AppLanguage.getString('logout'),
                                    style: AppTheme.getStyle(
                                      fontSize: 16,
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onTap: () async {
                                    bool? confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Text(AppLanguage.getString('logout_confirm_title')),
                                        content: Text(AppLanguage.getString('logout_confirm_desc')),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: Text(AppLanguage.getString('cancel')),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            child: Text(
                                              AppLanguage.getString('logout'),
                                              style: AppTheme.getStyle(fontSize: 15,
                                                color: Colors.redAccent,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirmed != true) return;

                                    final email = FirebaseAuth.instance.currentUser?.email;
                                    if (email != null) {
                                      await CredentialStorage.clearPassword(email);
                                    }
                                    await HiveService.resetSessionLeaderboardFetched();
                                    await FirebaseAuth.instance.signOut();
                                    if (mounted) {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const LoginScreen(),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 30),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatBox(
    BuildContext context,
    String title,
    String value,
    Color color,
  ) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(
              value,
              textAlign: TextAlign.center,
              style: AppTheme.getStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTheme.getStyle(
                fontSize: 12,
                color: isDark ? Colors.white70 : AppTheme.textSecondaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareAppWithRandomQuiz() async {
    try {
      // 1. Determine the scheduled subject for the current day
      final now = AppDate.getISTNow();
      String targetSubjectTitle;
      switch (now.weekday) {
        case 1: // Monday
        case 5: // Friday
          targetSubjectTitle = "General Tamil";
          break;
        case 2: // Tuesday
        case 6: // Saturday
          targetSubjectTitle = "General Studies";
          break;
        case 3: // Wednesday
        case 7: // Sunday
          targetSubjectTitle = "Aptitude";
          break;
        case 4: // Thursday
          targetSubjectTitle = "Current Affairs";
          break;
        default:
          targetSubjectTitle = "General Tamil";
      }

      // 2. Filter questions matching the scheduled subject
      List<Question> filteredQuestions = defaultRoomQuestions.where((q) {
        if (q.subject == null) return false;
        return q.subject!.toLowerCase().contains(targetSubjectTitle.toLowerCase());
      }).toList();

      // Fallback if no questions found for the specific subject
      if (filteredQuestions.isEmpty) {
        filteredQuestions = defaultRoomQuestions;
      }

      // 3. Pick a deterministic question from the filtered list based on the date
      final seed = now.year * 10000 + now.month * 100 + now.day;
      final random = Random(seed);
      final question = filteredQuestions[random.nextInt(filteredQuestions.length)];

      // 4. Find the actual Subject object for the poster header
      Subject subject = tnpscSubjects[0]; // fallback
      try {
        subject = tnpscSubjects.firstWhere(
          (s) => s.titleEn.toLowerCase().contains(targetSubjectTitle.toLowerCase())
        );
      } catch (_) {
        if (question.subject != null) {
          try {
            subject = tnpscSubjects.firstWhere(
              (s) => s.titleEn.toLowerCase().contains(question.subject!.toLowerCase()) ||
                     s.titleTa.toLowerCase().contains(question.subject!.toLowerCase())
            );
          } catch (_) {}
        }
      }

      // 5. Capture the poster with high quality settings
      final Uint8List? imageBytes = await _screenshotController.captureFromWidget(
        Material(
          color: Colors.black, // Dark base to match poster theme
          child: Directionality(
            textDirection: ui.TextDirection.ltr,
            child: _buildSharePoster(question, subject, dayIndex: now.weekday),
          ),
        ),
        pixelRatio: 4.0, // High density for sharp text and graphics (400 * 4 = 1600px width)
        delay: const Duration(milliseconds: 500), // More time to ensure all assets/fonts are fully loaded
        targetSize: const Size(400, 700),
      );

      if (imageBytes != null) {
        if (mounted) {
          _showSharePreviewDialog(imageBytes);
        }
      }
    } catch (e) {
      AppLog.e("Error sharing app: $e");
    }
  }

  Future<void> _showSharePreviewDialog(Uint8List imageBytes) async {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    String shareText = AppLanguage.languageNotifier.value == 'ta'
        ? "இந்தக் கேள்வியை உங்களால் தீர்க்க முடியுமா? TNPSC தேர்வுகளுக்குத் தயாராக இந்த ஆப்பை உடனே பதிவிறக்கம் செய்யுங்கள்! 📚\n\nபதிவிறக்கம்: https://play.google.com/store/apps/details?id=com.tnpsc.groupbook.tnpsc_group_book"
        : "Can you solve this? Download the app now to prepare for TNPSC exams! 📚\n\nDownload: https://play.google.com/store/apps/details?id=com.tnpsc.groupbook.tnpsc_group_book";

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurfaceColor : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppLanguage.languageNotifier.value == 'ta' ? "முன்னோட்டம்" : "Share Preview",
                          style: AppTheme.getStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppTheme.textMainColor,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  // Image Preview
                  Flexible(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.black12,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Image.memory(
                          imageBytes,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  // Footer
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);
                          try {
                            final directory = await getTemporaryDirectory();
                            final imagePath = await File('${directory.path}/share_quiz.png').create();
                            await imagePath.writeAsBytes(imageBytes);
                            await Share.shareXFiles([XFile(imagePath.path)], text: shareText);
                          } catch (e) {
                            AppLog.e("Error sharing from dialog: $e");
                          }
                        },
                        icon: const Icon(Icons.share_rounded, size: 20),
                        label: Text(
                          AppLanguage.languageNotifier.value == 'ta' ? "இப்போதே பகிர்க" : "Share Now",
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSharePoster(Question question, Subject subject, {required int dayIndex}) {
    String backgroundImage = 'asset/images/sharequiz$dayIndex.png';
    const Color goldColor = Color(0xFFFFD700);

    return Container(
      width: 400,
      height: 700,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(color: Colors.black),
      child: Stack(
        children: [
          _buildPosterBackground(backgroundImage),
          _buildPosterHeader(subject, goldColor),
          _buildPosterQuestionSection(question, goldColor),
          _buildPosterSidebar(),
          _buildPosterMockup(),
          _buildPosterMainBranding(goldColor),
          _buildPosterBattleSection(goldColor),
        ],
      ),
    );
  }

  Widget _buildPosterBackground(String imagePath) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(imagePath, fit: BoxFit.cover),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.9),
                ],
              ),
            ),
          ),
        ),
        // Additional glow effects
        Positioned(
          top: -100,
          right: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue.withOpacity(0.15),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPosterHeader(Subject subject, Color goldColor) {
    return Positioned(
      top: 20,
      left: 20,
      right: 20,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.menu_book_rounded, color: goldColor, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        subject.titleTa,
                        style: AppTheme.getStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 44),
                  child: Text(
                    "தினமும் படி, வெற்றியை வெல்லு!",
                    style: AppTheme.getStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 75,
            height: 75,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: goldColor, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: goldColor.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                )
              ],
              gradient: const RadialGradient(
                colors: [Color(0xFF2A2A2A), Color(0xFF000000)],
              ),
            ),
            child: ClipOval(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Image.asset(
                  'asset/images/logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPosterQuestionSection(Question question, Color goldColor) {
    return Positioned(
      top: 90,
      left: 15,
      right: 120,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF030611).withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.blue.withOpacity(0.1), blurRadius: 10)
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Text("Q.", style: AppTheme.getStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        question.questionEn ?? question.question,
                        style: AppTheme.getStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.3,
                        ),
                      ),
                      if (question.questionTa != null && question.questionTa!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            question.questionTa!,
                            style: AppTheme.getStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white70,
                              height: 1.3,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...question.displayOptions.asMap().entries.map((entry) {
              int idx = entry.key;
              String label = String.fromCharCode(65 + idx);
              bool isCorrect = idx == question.correctOptionIndex;

              String optEn = "";
              String optTa = "";

              if (question.optionsEn != null && idx < question.optionsEn!.length && question.optionsEn![idx].isNotEmpty) {
                optEn = question.optionsEn![idx];
              }
              if (question.optionsTa != null && idx < question.optionsTa!.length && question.optionsTa![idx].isNotEmpty) {
                optTa = question.optionsTa![idx];
              }
              if (optEn.isEmpty && optTa.isEmpty) {
                optEn = question.options[idx];
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isCorrect ? Colors.green.withOpacity(0.5) : Colors.white10,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isCorrect ? Colors.green : goldColor,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          label,
                          style: AppTheme.getStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Wrap(
                          children: [
                            if (optEn.isNotEmpty)
                              Text(
                                optTa.isNotEmpty ? "$optEn / " : optEn,
                                style: AppTheme.getStyle(
                                  fontSize: 11,
                                  color: isCorrect ? Colors.greenAccent : Colors.white,
                                  fontWeight: isCorrect ? FontWeight.bold : FontWeight.w500,
                                ),
                              ),
                            if (optTa.isNotEmpty)
                              Text(
                                optTa,
                                style: AppTheme.getStyle(
                                  fontSize: 10,
                                  color: isCorrect ? Colors.greenAccent : Colors.white70,
                                  fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (isCorrect)
                        const Icon(Icons.verified_rounded, color: Colors.green, size: 16),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildPosterSidebar() {
    return Positioned(
      top: 110,
      right: 15,
      width: 95,
      child: Column(
        children: [
          _buildSidebarItem(Icons.people_alt_rounded, "LIVE QUIZ", "DAILY\nLIVE BATTLES", const Color(0xFF9C27B0)),
          _buildSidebarItem(Icons.emoji_events_rounded, "RANK", "ON LIVE\nLEADERBOARD", const Color(0xFF03A9F4)),
          _buildSidebarItem(Icons.card_giftcard_rounded, "WIN POINTS", "& EXCITING\nREWARDS", const Color(0xFFFF9800)),
          _buildSidebarItem(Icons.verified_user_rounded, "100% FREE", "TO PLAY", const Color(0xFF4CAF50)),
          SizedBox(height: 15,),
          Column(
            children: [
              Image.network(
                'https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png',
                height: 35,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPosterMockup() {
    return Positioned(
      bottom: 0,
      left: 20,
      child: Container(
        width: 130,
        height: 250,
        decoration: BoxDecoration(
          color: const Color(0xFF030611),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white24, width: 4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.8),
              blurRadius: 30,
              offset: const Offset(0, 15),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.asset(
            'asset/images/homeScreenLayout.jpg',
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Widget _buildPosterMainBranding(Color goldColor) {
    return Positioned(
      bottom: 180,
      left: 170,
      right: 15,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.school_rounded, color: Colors.white70, size: 40),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "TNPSC",
                    style: AppTheme.getStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 0.9,
                    ),
                  ),
                  Text(
                    "MASTER",
                    style: AppTheme.getStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 0.9,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              const Icon(Icons.emoji_events_rounded, color: Color(0xFFE5BA73), size: 40),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [goldColor, const Color(0xFFE5BA73)]),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [BoxShadow(color: goldColor.withOpacity(0.3), blurRadius: 10)],
            ),
            child: Text(
              "Group 1 | Group 2 | Group 4 | VAO",
              textAlign: TextAlign.center,
              style: AppTheme.getStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.black,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPosterBattleSection(Color goldColor) {
    return Positioned(
      bottom: 0,
      left: 170,
      right: 15,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.4), blurRadius: 6)],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.sensors, color: Colors.white, size: 10),
                      const SizedBox(width: 4),
                      Text("LIVE", style: AppTheme.getStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  "LIVE GROUP BATTLE",
                  style: AppTheme.getStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Divider(color: Colors.white24, thickness: 1, height: 1),
            ),
            _buildBattleFeature(Icons.groups_rounded, "REAL-TIME MULTIPLAYER QUIZ", "நண்பர்களுடன் நேரடி வினாடி வினா"),
            _buildBattleFeature(Icons.leaderboard_rounded, "LIVE LEADERBOARD", "நேரடி தரவரிசை"),
            _buildBattleFeature(Icons.psychology_rounded, "DAILY TNPSC PRACTICE", "தினசரி TNPSC பயிற்சி"),
            _buildBattleFeature(Icons.bolt_rounded, "IMPROVE SPEED & ACCURACY", "வேகம் மற்றும் துல்லியத்தை மேம்படுத்துங்கள்"),
            _buildBattleFeature(Icons.stars_rounded, "LEARN & COMPETE", "கற்றலும் போட்டியும் ஒன்றாக!"),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String title, String sub, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Container(
        width: 85,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTheme.getStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        sub,
                        style: AppTheme.getStyle(fontSize: 8, color: Colors.white70, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBattleFeature(IconData icon, String title, String sub) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFFD700), size: 14),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.getStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  sub,
                  style: AppTheme.getStyle(fontSize: 8, color: Colors.greenAccent, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
