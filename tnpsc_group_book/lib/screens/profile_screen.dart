import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/hive_service.dart';
import '../utils/app_theme.dart';
import '../utils/app_language.dart';
import '../services/firestore_service.dart';
import 'settings_screen.dart';
import 'login_screen.dart';
import 'admin_panel_screen.dart';
import 'premium_plans_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/credential_storage.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
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
      debugPrint("Error loading app version: $e");
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
        user?.email == 'admin@tnpscmaster.com' ||
        user?.email == 'kjebaselvan987@gmail.com';
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<String>(
      valueListenable: AppLanguage.languageNotifier,
      builder: (context, lang, child) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            title: Text(AppLanguage.getString('profile')),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_rounded),
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
          body: ValueListenableBuilder<ThemeMode>(
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
                    padding: const EdgeInsets.all(20.0),
                    children: [
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
                                    ? const Icon(
                                        Icons.person_rounded,
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
                                    ? AppTheme.cardColor
                                    : AppTheme.textMainColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              email,
                              style: AppTheme.getStyle(
                                fontSize: 14,
                                color: isDark
                                    ? AppTheme.cardColor
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
                                  box.get('quizzesCompleted', defaultValue: 0) as int;
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

                      // // VIP Premium Membership Banner (Deactivated / Promoted Free VIP)
                      // GestureDetector(
                      //   onTap: () {
                      //     ScaffoldMessenger.of(context).showSnackBar(
                      //       SnackBar(
                      //         content: Text(
                      //           lang == 'ta' ? 'VIP அம்சங்கள் முழுமையாக அன்லாக் செய்யப்பட்டுள்ளன!' : 'VIP features are fully unlocked for you!',
                      //         ),
                      //         backgroundColor: AppTheme.primaryColor,
                      //       ),
                      //     );
                      //   },
                      //   child: Container(
                      //     decoration: BoxDecoration(
                      //       gradient: const LinearGradient(
                      //         colors: [Color(0xFFD4AF37), Color(0xFFE5BA73)],
                      //         begin: Alignment.topLeft,
                      //         end: Alignment.bottomRight,
                      //       ),
                      //       borderRadius: BorderRadius.circular(20),
                      //       boxShadow: [
                      //         BoxShadow(
                      //           color: AppTheme.secondaryColor.withOpacity(0.2),
                      //           blurRadius: 10,
                      //           offset: const Offset(0, 5),
                      //         )
                      //       ],
                      //     ),
                      //     padding: const EdgeInsets.all(16),
                      //     child: Row(
                      //       children: [
                      //         Container(
                      //           padding: const EdgeInsets.all(10),
                      //           decoration: const BoxDecoration(
                      //             color: Colors.black12,
                      //             shape: BoxShape.circle,
                      //           ),
                      //           child: const Icon(Icons.workspace_premium_rounded, color: Colors.black87, size: 24),
                      //         ),
                      //         const SizedBox(width: 16),
                      //         Expanded(
                      //           child: Column(
                      //             crossAxisAlignment: CrossAxisAlignment.start,
                      //             children: [
                      //               Text(
                      //                 lang == 'ta' ? 'VIP பிரீமியம் ஆக்டிவ்' : 'VIP Premium Active',
                      //                 style: GoogleFonts.outfit(
                      //                   color: Colors.black87,
                      //                   fontSize: 16,
                      //                   fontWeight: FontWeight.bold,
                      //                 ),
                      //               ),
                      //               const SizedBox(height: 2),
                      //               Text(
                      //                 lang == 'ta' ? 'அனைத்து விளம்பரமில்லா & மாதிரி தேர்வுகள் அன்லாக்!' : 'All mock tests & ad-free experience unlocked!',
                      //                 style: GoogleFonts.outfit(
                      //                   color: Colors.black54,
                      //                   fontSize: 11,
                      //                 ),
                      //               ),
                      //             ],
                      //           ),
                      //         ),
                      //         const Icon(Icons.check_circle_rounded, color: Colors.black54, size: 16),
                      //       ],
                      //     ),
                      //   ),
                      // ),
                      // const SizedBox(height: 30),

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
                                child: const Icon(
                                  Icons.language_rounded,
                                  color: Colors.blue,
                                ),
                              ),
                              title: const Text("தமிழ் / English"),
                              trailing: Switch(
                                value: lang == 'en',
                                activeColor: AppTheme.secondaryColor,
                                onChanged: (val) => AppLanguage.changeLanguage(
                                  val ? 'en' : 'ta',
                                ),
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
                                child: const Icon(
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
                                    child: const Icon(
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
                                        icon: const Icon(
                                          Icons.remove_circle_outline_rounded,
                                        ),
                                        onPressed: fontSizeFactor > 0.81
                                            ? () => AppTheme.setFontSizeFactor(
                                                fontSizeFactor - 0.1,
                                              )
                                            : null,
                                      ),
                                      Text(
                                        "${(fontSizeFactor * 100).round()}%",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.add_circle_outline_rounded,
                                        ),
                                        onPressed: fontSizeFactor < 1.39
                                            ? () => AppTheme.setFontSizeFactor(
                                                fontSizeFactor + 0.1,
                                              )
                                            : null,
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
                            // ListTile(
                            //   leading: const Icon(Icons.settings_suggest_rounded, color: Colors.blue),
                            //     title: Text(AppLanguage.getString('app_settings')),
                            //     subtitle: Text(AppLanguage.getString('admin_controls_desc')),
                            //   trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                            //   onTap: () {
                            //     Navigator.push(
                            //       context,
                            //       MaterialPageRoute(builder: (context) => const SettingsScreen()),
                            //     );
                            //   },
                            // ),
                            if (_isAdmin) ...[
                              // const Divider(height: 1),
                              ListTile(
                                leading: const Icon(
                                  Icons.admin_panel_settings_rounded,
                                  color: Colors.blueGrey,
                                ),
                                title: Text(
                                  AppLanguage.getString('admin_panel'),
                                ),
                                trailing: const Icon(
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
                              leading: const Icon(
                                Icons.update,
                                color: Colors.grey,
                              ),
                              title: Text(AppLanguage.getString('app_version')),
                              trailing: Text(_appVersion),
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(
                                Icons.info_outline_rounded,
                                color: Colors.grey,
                              ),
                              title: Text(AppLanguage.getString('about_app')),
                              trailing: const Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.grey,
                              ),
                              onTap: () =>
                                  _launchURL('https://tnpscmasterapp.blogspot.com/2026/06/about-app.html'),
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(
                                Icons.privacy_tip_outlined,
                                color: Colors.grey,
                              ),
                              title: Text(
                                AppLanguage.getString('privacy_policy'),
                              ),
                              trailing: const Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.grey,
                              ),
                              onTap: () => _launchURL(
                                'https://tnpscmasterapp.blogspot.com/2026/06/privacy-policy.html',
                              ),
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(
                                Icons.logout_rounded,
                                color: Colors.redAccent,
                              ),
                              title: Text(
                                AppLanguage.getString('logout'),
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onTap: () async {
                                final email =
                                    FirebaseAuth.instance.currentUser?.email;
                                if (email != null) {
                                  await CredentialStorage.clearPassword(email);
                                }
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
}
