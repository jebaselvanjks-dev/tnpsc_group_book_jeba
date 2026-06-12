import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_theme.dart';
import '../utils/app_language.dart';
import '../services/ai_service.dart';
import '../services/firestore_service.dart';
import '../models/subject.dart';
import 'admin_panel_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tnpsc_group_book/screens/bookmark_screen.dart';
import 'package:tnpsc_group_book/screens/feedback_screen.dart';
import 'package:intl/intl.dart';
import '../services/hive_service.dart';
import 'package:tnpsc_group_book/services/reward_service.dart';
import 'premium_plans_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool get _isAdmin {
    final user = FirebaseAuth.instance.currentUser;
    return user?.phoneNumber == '+918754236411' || user?.email == 'admin@tnpscmaster.com' || user?.email == 'kjebaselvan987@gmail.com';
  }

  @override
  void initState() {
    super.initState();
    // Pre-load rewarded ad when settings is opened
    RewardService.loadRewardedAd();
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
                  // VIP Premium Membership Banner (Deactivated / Promoted Free VIP)
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
                  //   child: Card(
                  //     shape: RoundedRectangleBorder(
                  //       borderRadius: BorderRadius.circular(20),
                  //     ),
                  //     elevation: 4,
                  //     shadowColor: AppTheme.secondaryColor.withOpacity(0.3),
                  //     child: Container(
                  //       decoration: BoxDecoration(
                  //         gradient: const LinearGradient(
                  //           colors: [AppTheme.primaryColor, Color(0xFF0F2D59), Color(0xFF1E3A8A)],
                  //           begin: Alignment.topLeft,
                  //           end: Alignment.bottomRight,
                  //         ),
                  //         borderRadius: BorderRadius.circular(20),
                  //         border: Border.all(color: AppTheme.secondaryColor.withOpacity(0.4), width: 1.5),
                  //       ),
                  //       child: Padding(
                  //         padding: const EdgeInsets.all(20.0),
                  //         child: Row(
                  //           children: [
                  //             Container(
                  //               padding: const EdgeInsets.all(12),
                  //               decoration: BoxDecoration(
                  //                 color: AppTheme.secondaryColor.withOpacity(0.15),
                  //                 shape: BoxShape.circle,
                  //               ),
                  //               child: const Icon(Icons.workspace_premium_rounded, color: AppTheme.secondaryColor, size: 30),
                  //             ),
                  //             const SizedBox(width: 16),
                  //             Expanded(
                  //               child: Column(
                  //                 crossAxisAlignment: CrossAxisAlignment.start,
                  //                 children: [
                  //                   Text(
                  //                     lang == 'ta' ? 'VIP பிரீமியம் ஆக்டிவ்' : 'VIP Premium Active',
                  //                     style: GoogleFonts.outfit(
                  //                       color: Colors.white,
                  //                       fontSize: 18,
                  //                       fontWeight: FontWeight.bold,
                  //                     ),
                  //                   ),
                  //                   const SizedBox(height: 4),
                  //                   Text(
                  //                     lang == 'ta'
                  //                       ? 'விளம்பரங்கள் இல்லா படிப்பு, மாதிரி தேர்வுகள் மற்றும் கூடுதல் குரூப் தேர்வுகள்!'
                  //                       : 'Ad-Free study, all mock tests, and daily room matches!',
                  //                     style: GoogleFonts.outfit(
                  //                       color: Colors.white70,
                  //                       fontSize: 12,
                  //                     ),
                  //                   ),
                  //                 ],
                  //               ),
                  //             ),
                  //             const SizedBox(width: 8),
                  //             const Icon(Icons.check_circle_rounded, color: Colors.white70, size: 16),
                  //           ],
                  //         ),
                  //       ),
                  //     ),
                  //   ),
                  // ),
                  // const SizedBox(height: 24),

                  // Rewards Section
                  Text(
                    AppLanguage.getString('rewards_gifts'),
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.accentColor),
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
                              style: TextStyle(
                                fontWeight: FontWeight.bold, 
                                color: canWatch ? AppTheme.textMainColor : Colors.grey
                              ),
                            ),
                            subtitle: Text(
                              canWatch 
                                ? (lang == 'ta' ? 'மீதமுள்ளது: ${3 - watchCount}/3' : 'Remaining: ${3 - watchCount}/3')
                                : (lang == 'ta' ? 'நாளை மீண்டும் முயலவும்' : 'Try again tomorrow'),
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor),
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
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.accentColor),
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
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.accentColor),
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
                            leading: const Icon(Icons.auto_awesome, color: Colors.amber),
                            title: Text(AppLanguage.getString('gen_ai_quizzes')),
                            subtitle: Text(AppLanguage.getString('create_today_tomorrow')),
                            onTap: () async {
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => Center(
                                  child: Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(20.0),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const CircularProgressIndicator(),
                                          const SizedBox(height: 16),
                                          Text(AppLanguage.getString('ai_gen_3days')),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );

                              try {
                                String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
                                String tomorrow = DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 1)));
                                final db = FirebaseFirestore.instance;
                                final todayQuery = await db.collection('quizzes').where('date', isEqualTo: today).get();
                                final tomorrowQuery = await db.collection('quizzes').where('date', isEqualTo: tomorrow).get();

                                if (todayQuery.docs.isNotEmpty && tomorrowQuery.docs.isNotEmpty) {
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(AppLanguage.getString('quizzes_exist')), backgroundColor: Colors.blue),
                                    );
                                  }
                                  return;
                                }

                                int successCount = 0;
                                for (int i = 0; i < 7; i++) {
                                  DateTime targetDate = DateTime.now().add(Duration(days: i));
                                  bool success = await AiService.generateAndSaveDailyQuiz(targetDate);
                                  if (success) successCount++;
                                  if (i < 2) await Future.delayed(const Duration(seconds: 6));
                                }

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(AppLanguage.getString('gen_success_count').replaceAll('{count}', successCount.toString())),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("${AppLanguage.getString('error_prefix')}: $e"), backgroundColor: Colors.red),
                                  );
                                }
                              }
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
                                      child: Text(AppLanguage.getString('delete_everything'), style: const TextStyle(color: Colors.red)),
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
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.accentColor),
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
                                      child: Text(AppLanguage.getString('clear_action'), style: const TextStyle(color: Colors.red)),
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
