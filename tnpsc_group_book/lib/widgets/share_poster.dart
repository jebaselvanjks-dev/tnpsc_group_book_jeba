import 'package:flutter/material.dart';
import '../models/question.dart';
import '../models/subject.dart';
import '../utils/app_theme.dart';

class SharePoster extends StatelessWidget {
  final Question question;
  final Subject subject;
  final int dayIndex;
  final bool showCorrectAnswer;

  const SharePoster({
    super.key,
    required this.question,
    required this.subject,
    required this.dayIndex,
    this.showCorrectAnswer = false,
  });

  @override
  Widget build(BuildContext context) {
    String backgroundImage = 'asset/images/sharequiz$dayIndex.png';
    const Color goldColor = Color(0xFFFFD700);

    return Container(
      width: 450,
      height: 800,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(color: Colors.black),
      child: Stack(
        children: [
          _buildPosterBackground(backgroundImage),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 30),
              _buildPosterHeader(goldColor),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildPosterQuestionSection(goldColor)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _buildPosterSidebar(),
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 15, bottom: 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildPosterMockup(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        children: [
                          _buildPosterBattleSection(goldColor),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
                  Colors.black.withValues(alpha: 0.7),
                  Colors.black.withValues(alpha: 0.3),
                  Colors.black.withValues(alpha: 0.9),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -100,
          right: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue.withValues(alpha: 0.15),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPosterHeader(Color goldColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: goldColor, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: goldColor.withValues(alpha: 0.3),
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
                padding: const EdgeInsets.all(8.0),
                child: Image.asset(
                  'asset/images/logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "TNPSC Master: Group 1, 2, 4",
                        style: AppTheme.getStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          ignoreScale: true,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "தினமும் படி, வெற்றியை வெல்லு!",
                        style: AppTheme.getStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                          ignoreScale: true,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: Image.network(
                        'https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png',
                        height: 35,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPosterQuestionSection(Color goldColor) {
    final String qEn = question.questionEn ?? question.question;
    final String qTa = question.questionTa ?? "";
    final int totalLength = qEn.length + qTa.length;

    double qFontSize = 14;
    double optFontSize = 13;

    if (totalLength > 250) {
      qFontSize = 10.5;
      optFontSize = 10;
    } else if (totalLength > 180) {
      qFontSize = 13.5;
      optFontSize = 13;
    } else if (totalLength > 120) {
      qFontSize = 15;
      optFontSize = 14;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF030611).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.blue.withValues(alpha: 0.1), blurRadius: 10)
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
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Text("Q.",
                    style: AppTheme.getStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        ignoreScale: true)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      qEn,
                      style: AppTheme.getStyle(
                        fontSize: qFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.3,
                        ignoreScale: true,
                      ),
                    ),
                    if (qTa.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          qTa,
                          style: AppTheme.getStyle(
                            fontSize: qFontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.tealAccent,
                            height: 1.3,
                            ignoreScale: true,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...question.displayOptions.asMap().entries.map((entry) {
            int idx = entry.key;
            String label = String.fromCharCode(65 + idx);
            bool isCorrect = idx == question.correctOptionIndex;

            String optEn = "";
            String optTa = "";

            if (question.optionsEn != null &&
                idx < question.optionsEn!.length &&
                question.optionsEn![idx].isNotEmpty) {
              optEn = question.optionsEn![idx];
            }
            if (question.optionsTa != null &&
                idx < question.optionsTa!.length &&
                question.optionsTa![idx].isNotEmpty) {
              optTa = question.optionsTa![idx];
            }
            if (optEn.isEmpty && optTa.isEmpty) {
              optEn = question.options[idx];
            }

            bool highlight = showCorrectAnswer && isCorrect;

            return Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: highlight ? Colors.green.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: highlight ? Colors.green : Colors.white60,
                    width: highlight ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: highlight ? Colors.green : goldColor,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        label,
                        style: AppTheme.getStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            ignoreScale: true),
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
                                fontSize: optFontSize,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                ignoreScale: true,
                              ),
                            ),
                          if (optTa.isNotEmpty)
                            Text(
                              optTa,
                              style: AppTheme.getStyle(
                                fontSize: optFontSize,
                                color: Colors.tealAccent,
                                fontWeight: FontWeight.w500,
                                ignoreScale: true,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (highlight)
                      const Icon(Icons.verified_rounded, color: Colors.green, size: 16),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildPosterSidebar() {
    return Padding(
      padding: const EdgeInsets.only(top: 5.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildSidebarItem(Icons.people_alt_rounded, "LIVE QUIZ",
              "DAILY\nLIVE BATTLES", const Color(0xFF9C27B0)),
          _buildSidebarItem(Icons.emoji_events_rounded, "RANK",
              "ON LIVE\nLEADERBOARD", const Color(0xFF03A9F4)),
          _buildSidebarItem(Icons.card_giftcard_rounded, "WIN POINTS",
              "EXCITING\nREWARDS", const Color(0xFFFF9800)),
          _buildSidebarItem(Icons.verified_user_rounded, "100% FREE", "TO PLAY",
              const Color(0xFF4CAF50)),
        ],
      ),
    );
  }

  Widget _buildPosterMockup() {
    return Container(
      width: 120,
      height: 250,
      decoration: BoxDecoration(
        color: const Color(0xFF030611),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFFFFD700).withValues(alpha: 0.8), width: 2.3),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(10, 15),
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
    );
  }

  Widget _buildPosterBattleSection(Color goldColor) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white30),
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
                  boxShadow: [
                    BoxShadow(color: Colors.red.withValues(alpha: 0.4), blurRadius: 6)
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sensors, color: Colors.white, size: 9),
                    const SizedBox(width: 4),
                    Text("LIVE",
                        style: AppTheme.getStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            ignoreScale: true)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                "LIVE GROUP BATTLE",
                style: AppTheme.getStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    ignoreScale: true),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Divider(color: Colors.white24, thickness: 1, height: 1),
          ),
          _buildBattleFeature(Icons.groups_rounded, "REAL-TIME MULTIPLAYER QUIZ",
              "நண்பர்களுடன் நேரடி வினாடி வினா"),
          _buildBattleFeature(
              Icons.leaderboard_rounded, "LIVE LEADERBOARD", "நேரடி தரவரிசை"),
          _buildBattleFeature(
              Icons.psychology_rounded, "DAILY TNPSC PRACTICE", "தினசரி TNPSC பயிற்சி"),
          _buildBattleFeature(Icons.bolt_rounded, "IMPROVE SPEED & ACCURACY",
              "வேகம் மற்றும் துல்லியத்தை மேம்படுத்துங்கள்"),
          _buildBattleFeature(
              Icons.stars_rounded, "LEARN & COMPETE", "கற்றலும் போட்டியும் ஒன்றாக!"),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(
      IconData icon, String title, String sub, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Container(
        width: 85,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
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
                        style: AppTheme.getStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            ignoreScale: true),
                      ),
                      Text(
                        sub,
                        style: AppTheme.getStyle(
                            fontSize: 8,
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                            ignoreScale: true),
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
                  style: AppTheme.getStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      ignoreScale: true),
                ),
                Text(
                  sub,
                  style: AppTheme.getStyle(
                      fontSize: 8.5,
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.w600,
                      ignoreScale: true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
