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
      // 1. Pick a deterministic question based on the current date
      final now = AppDate.getISTNow();
      final seed = now.year * 10000 + now.month * 100 + now.day;
      final random = Random(seed);
      final question = defaultRoomQuestions[random.nextInt(defaultRoomQuestions.length)];

      // 2. Find a matching subject for the question (fallback to random if not found)
      Subject subject = tnpscSubjects[random.nextInt(tnpscSubjects.length)];
      if (question.subject != null) {
        try {
          subject = tnpscSubjects.firstWhere(
            (s) => s.titleEn.toLowerCase().contains(question.subject!.toLowerCase()) ||
                   s.titleTa.toLowerCase().contains(question.subject!.toLowerCase())
          );
        } catch (_) {}
      }

      // 3. Capture the poster
      final Uint8List? imageBytes = await _screenshotController.captureFromWidget(
        Material(
          child: Directionality(
            textDirection: ui.TextDirection.ltr,
            child: _buildSharePoster(question, subject, dayIndex: now.weekday),
          ),
        ),
        pixelRatio: 3.0,
        delay: const Duration(milliseconds: 100),
        targetSize: const Size(400, 700),
      );

      if (imageBytes != null) {
        final directory = await getTemporaryDirectory();
        final imagePath = await File('${directory.path}/share_quiz.png').create();
        await imagePath.writeAsBytes(imageBytes);

        String shareText = AppLanguage.languageNotifier.value == 'ta'
            ? "இந்தக் கேள்வியை உங்களால் தீர்க்க முடியுமா? TNPSC தேர்வுகளுக்குத் தயாராக இந்த ஆப்பை உடனே பதிவிறக்கம் செய்யுங்கள்! 📚\n\nபதிவிறக்கம்: https://play.google.com/store/apps/details?id=com.tnpsc.groupbook.tnpsc_group_book"
            : "Can you solve this? Download the app now to prepare for TNPSC exams! 📚\n\nDownload: https://play.google.com/store/apps/details?id=com.tnpsc.groupbook.tnpsc_group_book";

        await Share.shareXFiles([XFile(imagePath.path)], text: shareText);
      }
    } catch (e) {
      AppLog.e("Error sharing app: $e");
    }
  }

  Widget _buildSharePoster(Question question, Subject subject, {required int dayIndex}) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Deterministic background image based on day of week
    String backgroundImage = 'asset/images/sharequiz$dayIndex.png';

    return Container(
      width: 400,
      height: 700, // Increased height to accommodate options
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101F42) : Colors.white,
      ),
      child: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              backgroundImage,
              fit: BoxFit.cover,
            ),
          ),

          // Content Overlay
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Logo
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(subject.icon, color: subject.color, size: 24),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              subject.title,
                              style: AppTheme.getStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber,
                              ),
                            ),
                          ),
                          const SizedBox(width: 25),
                        ],
                      ),
                    ),
                    Container(
                      width: 70,
                      height: 70,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 3,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'asset/images/logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const AppIcon(Icons.school, size: 40, color: AppTheme.primaryColor),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 25),

                // Question Container
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row(
                      //   children: [
                      //     Icon(subject.icon, color: subject.color, size: 24),
                      //     const SizedBox(width: 10),
                      //     Expanded(
                      //       child: Text(
                      //         subject.title,
                      //         style: AppTheme.getStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70),
                      //       ),
                      //     ),
                      //   ],
                      // ),
                      // const Divider(color: Colors.white24, height: 20),
                      Text(
                        question.displayQuestion,
                        style: AppTheme.getStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 20),
                      ...question.displayOptions.asMap().entries.map((entry) {
                        int idx = entry.key;
                        String option = entry.value;
                        bool isCorrect = idx == question.correctOptionIndex;
                        String label = String.fromCharCode(65 + idx); // A, B, C, D
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: isCorrect ? Colors.green : Colors.amber,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  label,
                                  style: AppTheme.getStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isCorrect ? Colors.white : Colors.black,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  option,
                                  style: AppTheme.getStyle(
                                    fontSize: 15,
                                    color: isCorrect ? Colors.greenAccent : Colors.white,
                                    fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                              if (isCorrect) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
                              ]
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),

                Spacer()
                // const SizedBox(height: 30),
                //
                // // Download Prompt
                // Text(
                //   isTamil ? "ஆப்பை பதிவிறக்கம் செய்து விளையாடுங்கள்!" : "Download the app and start playing!",
                //   textAlign: TextAlign.center,
                //   style: AppTheme.getStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold),
                // ),
                // const SizedBox(height: 10),
                // Text(
                //   "TNPSC GROUP BOOK",
                //   style: AppTheme.getStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white).copyWith(letterSpacing: 2),
                // ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
