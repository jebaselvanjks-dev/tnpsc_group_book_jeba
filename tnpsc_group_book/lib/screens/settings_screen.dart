import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_theme.dart';
import '../utils/app_language.dart';
import '../services/ai_service.dart';
import '../services/firestore_service.dart';
import '../models/subject.dart';
import 'admin_panel_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:tnpsc_group_book/screens/bookmark_screen.dart';
import 'package:tnpsc_group_book/screens/feedback_screen.dart';
import 'package:intl/intl.dart';
import '../services/hive_service.dart';
import 'package:tnpsc_group_book/services/reward_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _userName = "";
  final FirestoreService _firestoreService = FirestoreService();

  bool get _isAdmin {
    final user = FirebaseAuth.instance.currentUser;
    return user?.phoneNumber == '+918754236411' || user?.email == 'adminjeba@gmail.com' || user?.email == 'kjebaselvan987@gmail.com';
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
    // Pre-load rewarded ad when settings is opened
    RewardService.loadRewardedAd();
  }

  Future<void> _loadUserData() async {
    // 1. Check Hive first
    String? name = HiveService.getUserName();
    if (name == null || name.isEmpty) {
      final cachedData = HiveService.getCachedUserData();
      if (cachedData != null) {
        name = cachedData['name'] ?? "";
      }
    }

    // 2. If still empty, check Firestore
    if (name == null || name.isEmpty) {
      final userDoc = await _firestoreService.getUserData();
      if (userDoc != null && userDoc.exists) {
        name = (userDoc.data() as Map<String, dynamic>)['name'] ?? "";
      }
    }

    if (mounted) {
      setState(() {
        _userName = name ?? AppLanguage.getString('user_fallback');
      });
    }
  }

  void _showEditNameDialog() {
    if (!HiveService.canUpdateName()) {
      DateTime? nextUpdate = HiveService.getLastNameUpdateDate()?.add(const Duration(days: 30));
      String dateStr = nextUpdate != null ? DateFormat('dd MMM yyyy').format(nextUpdate) : "next month";
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLanguage.languageNotifier.value == 'ta'
                ? 'பெயரை மாதம் ஒருமுறை மட்டுமே மாற்ற முடியும். அடுத்த மாற்றம்: $dateStr'
                : 'Name can only be changed once a month. Next update available: $dateStr',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final TextEditingController nameController = TextEditingController(text: _userName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(AppLanguage.languageNotifier.value == 'ta' ? 'பெயரை மாற்றவும்' : 'Edit Name',
          style: AppTheme.getStyle(fontSize: 18, color: isDarkMode ? AppTheme.secondaryColor : Colors.black),),
        content: TextField(
          controller: nameController,
          maxLength: 25,
          decoration: InputDecoration(
            hintText: AppLanguage.languageNotifier.value == 'ta' ? 'உங்கள் பெயரை உள்ளிடவும்' : 'Enter your name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(AppLanguage.getString('cancel'))),
          ElevatedButton(
            onPressed: () async {
              String newName = nameController.text.trim();
              if (newName.isNotEmpty && newName != _userName) {
                await HiveService.updateUserName(newName);
                await _firestoreService.updateProfileName(newName);
                if (mounted) {
                  setState(() => _userName = newName);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLanguage.languageNotifier.value == 'ta' ? 'பெயர் மாற்றப்பட்டது!' : 'Name updated successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(AppLanguage.languageNotifier.value == 'ta' ? 'சேமி' : 'Save', style: AppTheme.getStyle(fontSize: 14, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: AppTheme.secondaryColorLight.withOpacity(0.1),
            child: const Icon(Icons.person_rounded, size: 40, color: AppTheme.secondaryColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLanguage.languageNotifier.value == 'ta' ? 'வணக்கம்,' : 'Hello,',
                  style: AppTheme.getStyle(fontSize: 14, color: Colors.grey),
                ),
                Text(
                  _userName.isEmpty ? AppLanguage.getString('user_fallback') : _userName,
                  style: AppTheme.getStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.textMainColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _showEditNameDialog,
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppTheme.secondaryColor.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.edit_rounded, size: 20, color: AppTheme.cardColor),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Current theme handling
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<String>(
      valueListenable: AppLanguage.languageNotifier,
      builder: (context, lang, child) {
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: Container(
                // padding: const EdgeInsets.all(0),
                child: Icon(Icons.arrow_back_ios_rounded, size: 25, color: isDarkMode ? Colors.white : Colors.black),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(AppLanguage.getString('settings')),
          ),
          body: ValueListenableBuilder<ThemeMode>(
            valueListenable: AppTheme.themeNotifier,
            builder: (context, currentMode, _) {
              return ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  _buildProfileSection(isDarkMode),

                  // Rewards Section
                  Text(
                    AppLanguage.getString('rewards_gifts'),
                    style: AppTheme.getStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.accentColor),
                  ),
                  const SizedBox(height: 10),
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: AppTheme.themeNotifier,
                    builder: (context, _, __) {
                      final int watchCount = HiveService.getRewardAdWatchCountToday();
                      final bool canWatch = HiveService.canWatchRewardAdToday();
                      
                      return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 3,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: canWatch 
                                ? [Colors.orange.shade50, Colors.white]
                                : [Colors.grey.shade100, Colors.white],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: canWatch ? Colors.orange : Colors.grey, 
                                shape: BoxShape.circle
                              ),
                              child: const Icon(Icons.card_giftcard_rounded, color: Colors.white),
                            ),
                            title: Text(
                              canWatch 
                                ? AppLanguage.getString('watch_ad_points')
                                : (lang == 'ta' ? 'இன்றைய வரம்பு முடிந்தது' : 'Daily Limit Reached'),
                              style: AppTheme.getStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold, 
                                color: canWatch ? AppTheme.textMainColor : Colors.grey
                              ),
                            ),
                            subtitle: Text(
                              canWatch 
                                ? (lang == 'ta' ? 'மீதமுள்ளது: ${3 - watchCount}/3' : 'Remaining: ${3 - watchCount}/3')
                                : (lang == 'ta' ? 'நாளை மீண்டும் முயலவும்' : 'Try again tomorrow'),
                              style: AppTheme.getStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
                            ),
                            trailing: Icon(
                              Icons.play_circle_fill_rounded, 
                              color: canWatch ? Colors.orange : Colors.grey, 
                              size: 30
                            ),
                            onTap: canWatch ? () {
                              RewardService.showRewardAdIfAllowed(
                                fixedRewardAmount: 50,
                                useLimit: true,
                                onRewardEarned: () {
                                  setState(() {}); // Refresh UI to update count
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(lang == 'ta' ? 'வாழ்த்துக்கள்! 50 புள்ளிகள் கிடைத்துள்ளன!' : 'Success! You earned 50 points!'), 
                                      backgroundColor: Colors.orange
                                    )
                                  );
                                },
                              );
                            } : null,
                          ),
                        ),
                      );
                    }
                  ),
                  const SizedBox(height: 24),

                  // // Study Tools Section
                  // Text(
                  //   AppLanguage.getString('revision_tools'),
                  //   style: GoogleFonts.outfit(
                  //     fontSize: 18,
                  //     fontWeight: FontWeight.bold,
                  //     color: AppTheme.primaryColor,
                  //   ),
                  // ),
                  // const SizedBox(height: 10),
                  // Card(
                  //   shape: RoundedRectangleBorder(
                  //     borderRadius: BorderRadius.circular(16),
                  //   ),
                  //   elevation: 2,
                  //   child: ListTile(
                  //     leading: Container(
                  //       padding: const EdgeInsets.all(8),
                  //       decoration: BoxDecoration(
                  //         color: Colors.amber.withOpacity(0.1),
                  //         shape: BoxShape.circle,
                  //       ),
                  //       child: const Icon(Icons.bookmark_rounded, color: Colors.amber),
                  //     ),
                  //     title: Text(AppLanguage.getString('saved_questions')),
                  //     subtitle: Text(AppLanguage.getString('saved_questions_desc')),
                  //     trailing: const Icon(Icons.chevron_right_rounded),
                  //     onTap: () {
                  //       Navigator.push(
                  //         context,
                  //         MaterialPageRoute(builder: (context) => const BookmarkScreen()),
                  //       );
                  //     },
                  //   ),
                  // ),
                  // const SizedBox(height: 20),
                  // Help & Feedback Section
                  Text(
                    AppLanguage.getString('support'),
                    style: AppTheme.getStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.accentColor),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.feedback_rounded, color: Colors.blue),
                      ),
                      title: Text(AppLanguage.getString('feedback_support')),
                      subtitle: Text(AppLanguage.getString('report_bugs')),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const FeedbackScreen()));
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // App Settings Section
                  Text(
                    lang == 'ta' ? 'ஆப் அமைப்புகள்' : 'App Settings',
                    style: AppTheme.getStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.accentColor),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                    child: Column(
                      children: [
                        SwitchListTile(
                          secondary: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
                            child: const Icon(Icons.vibration_rounded, color: Colors.orange),
                          ),
                          title: Text(lang == 'ta' ? 'அதிர்வு (Vibration)' : 'Vibration Feedback'),
                          subtitle: Text(lang == 'ta' ? 'சரியான/தவறான பதில்களுக்கு அதிர்வை இயக்கு' : 'Vibrate on correct/wrong answers'),
                          value: HiveService.isVibrationEnabled(),
                          activeThumbColor: AppTheme.secondaryColor,
                          onChanged: (bool value) async {
                            await HiveService.setVibrationEnabled(value);
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                  // const SizedBox(height: 20),
                  //  // General Settings Section
                  // Text(
                  //   AppLanguage.getString('language'),
                  //   style: GoogleFonts.outfit(
                  //         ),
                  //       ),
                  //     ],
                  //   ),
                  // ),
                  // const SizedBox(height: 20),
                  // // Theme Settings Section
                  // Text(
                  //   AppLanguage.getString('appearance'),
                  //   style: GoogleFonts.outfit(
                  //     fontSize: 18,
                  //     fontWeight: FontWeight.bold,
                  //     color: AppTheme.primaryColor,
                  //   ),
                  // ),
                  // const SizedBox(height: 10),
                  // Card(
                  //   shape: RoundedRectangleBorder(
                  //     borderRadius: BorderRadius.circular(16),
                  //   ),
                  //   elevation: 2,
                  //   child: Column(
                  //     children: [
                  //       SwitchListTile(
                  //         title: Text(AppLanguage.getString('dark_theme')),
                  //         subtitle: Text(AppLanguage.getString('dark_theme_desc')),
                  //         secondary: Container(
                  //           padding: const EdgeInsets.all(8),
                  //           decoration: BoxDecoration(
                  //             color: AppTheme.primaryColor.withOpacity(0.1),
                  //             shape: BoxShape.circle,
                  //           ),
                  //           child: Icon(
                  //             isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  //             color: AppTheme.primaryColor,
                  //           ),
                  //         ),
                  //         value: currentMode == ThemeMode.dark ||
                  //             (currentMode == ThemeMode.system && isDarkMode),
                  //         onChanged: (bool value) {
                  //           if (value) {
                  //             AppTheme.setThemeMode(ThemeMode.dark);
                  //           } else {
                  //             AppTheme.setThemeMode(ThemeMode.light);
                  //           }
                  //         },
                  //       ),
                  //       const Divider(height: 1, thickness: 1),
                  //       ListTile(
                  //         title: Text(AppLanguage.getString('system_theme')),
                  //         subtitle: Text(AppLanguage.getString('system_theme_desc')),
                  //         trailing: currentMode == ThemeMode.system
                  //             ? const Icon(Icons.check_circle, color: AppTheme.primaryColor)
                  //             : const SizedBox.shrink(),
                  //         onTap: () {
                  //           AppTheme.setThemeMode(ThemeMode.system);
                  //         },
                  //       ),
                  //     ],
                  //   ),
                  // ),
                  if (_isAdmin) ...[
                    const SizedBox(height: 20),
                    // Admin Settings Section
                    Text(
                      AppLanguage.getString('admin_panel'),
                      style: AppTheme.getStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.accentColor),
                    ),
                    const SizedBox(height: 10),
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.dashboard_customize_rounded, color: Colors.indigo),
                            title: Text(AppLanguage.getString('admin_dashboard_label')),
                            subtitle: Text(AppLanguage.getString('manage_q_desc')),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminPanelScreen()));
                            },
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.cloud_upload_rounded, color: Colors.blue),
                            title: Text(AppLanguage.getString('upload_local_q')),
                            subtitle: Text(AppLanguage.getString('sync_local_firestore')),
                            onTap: () async {
                              final firestoreService = FirestoreService();
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => const Center(child: CircularProgressIndicator()),
                              );

                              try {
                                await firestoreService.uploadAllLocalQuestions();
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(
                                    context,
                                  ).showSnackBar(SnackBar(content: Text(AppLanguage.getString('sync_success')), backgroundColor: Colors.green));
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("${AppLanguage.getString('upload_failed')}: $e"), backgroundColor: Colors.red),
                                  );
                                }
                              }
                            },
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.delete_sweep_rounded, color: Colors.red),
                            title: Text(AppLanguage.getString('clear_cloud_data')),
                            subtitle: Text(AppLanguage.getString('wipe_firestore_desc')),
                            onTap: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text(AppLanguage.getString('clear_confirm_title')),
                                  content: Text(AppLanguage.getString('clear_confirm_desc')),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppLanguage.getString('cancel'))),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: Text(AppLanguage.getString('delete_everything'), style: AppTheme.getStyle(fontSize: 14, color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );

                              if (confirmed == true) {
                                showDialog(
                                  context: context,
                                  builder: (context) => const Center(child: CircularProgressIndicator()),
                                );
                                try {
                                  final db = FirebaseFirestore.instance;
                                  final quizzes = await db.collection('quizzes').get();
                                  for (var doc in quizzes.docs) {
                                    await doc.reference.delete();
                                  }
                                  final subjects = await db.collection('subject_questions').get();
                                  for (var doc in subjects.docs) {
                                    await doc.reference.delete();
                                  }

                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(AppLanguage.getString('data_cleared')), backgroundColor: Colors.orange),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text("${AppLanguage.getString('clear_failed')}: $e"), backgroundColor: Colors.red),
                                    );
                                  }
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_isAdmin) ...[
                    const SizedBox(height: 20),
                    // Storage Settings Section
                    Text(
                      AppLanguage.getString('storage_offline'),
                      style: AppTheme.getStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.accentColor),
                    ),
                  ],
                  if (_isAdmin) ...[
                    const SizedBox(height: 10),
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.storage_rounded, color: Colors.teal),
                            title: Text(AppLanguage.getString('clear_offline_data')),
                            subtitle: Text(AppLanguage.getString('clear_cache_desc')),
                            trailing: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                            onTap: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text(AppLanguage.getString('clear_offline_data') + "?"),
                                  content: Text(AppLanguage.getString('clear_cache_warning')),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppLanguage.getString('cancel'))),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: Text(AppLanguage.getString('clear_action'), style: AppTheme.getStyle(fontSize: 14, color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );

                              if (confirmed == true) {
                                await HiveService.clearCache();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(
                                    context,
                                  ).showSnackBar(SnackBar(content: Text(AppLanguage.getString('cache_cleared_success'))));
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }
}
