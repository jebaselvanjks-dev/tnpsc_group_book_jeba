import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import '../models/question.dart';
import '../models/subject.dart';
import '../utils/app_theme.dart';

class SharePoster extends StatefulWidget {
  final Question question;
  final Subject subject;
  final int dayIndex;
  final bool showCorrectAnswer;
  final int? timerSeconds;
  final int? maxTimerSeconds;
  final bool showFooter;

  const SharePoster({
    super.key,
    required this.question,
    required this.subject,
    required this.dayIndex,
    this.showCorrectAnswer = false,
    this.timerSeconds,
    this.maxTimerSeconds,
    this.showFooter = false,
  });

  @override
  State<SharePoster> createState() => _SharePosterState();
}

class _SharePosterState extends State<SharePoster> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(SharePoster oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showCorrectAnswer && !oldWidget.showCorrectAnswer) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.showCorrectAnswer) {
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String backgroundImage = 'asset/images/sharequiz${widget.dayIndex}.png';
    const Color goldColor = Color(0xFFFFD700);

    return Container(
      width: 475,
      height: 900,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(color: Colors.black),
      child: Stack(
        children: [
          _buildPosterBackground(backgroundImage),
          AnimationLimiter(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: AnimationConfiguration.toStaggeredList(
                duration: const Duration(milliseconds: 400),
                childAnimationBuilder: (widget) => SlideAnimation(
                  verticalOffset: 20.0,
                  child: FadeInAnimation(child: widget),
                ),
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
                  if (widget.timerSeconds != null && !widget.showCorrectAnswer)
                    Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: _buildPosterTimer(),
                    ),
                  if (widget.showFooter)
                    Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: _buildPosterFooter(),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPosterTimer() {
    final int seconds = widget.timerSeconds ?? 0;
    final int maxSeconds = widget.maxTimerSeconds ?? 10;
    final double progress = seconds / maxSeconds;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "TIME REMAINING",
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: seconds < 4 ? Colors.red.withValues(alpha: 0.2) : Colors.white10,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "0:0$seconds",
                style: TextStyle(
                  color: seconds < 4 ? Colors.redAccent : Colors.amber,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFeatures: const [ui.FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Stack(
          children: [
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            TweenAnimationBuilder<double>(
              duration: const Duration(seconds: 1),
              tween: Tween<double>(begin: progress, end: progress),
              curve: Curves.linear,
              builder: (context, value, child) {
                return Container(
                  width: 370 * value, // Based on design width
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: value < 0.4
                          ? [Colors.redAccent, Colors.orangeAccent]
                          : [Colors.amber, Colors.orange],
                    ),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: (value < 0.4 ? Colors.redAccent : Colors.orange)
                            .withValues(alpha: 0.5),
                        blurRadius: 8,
                      )
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPosterFooter() {
    return Column(
      children: [
        const Text(
          "DOWNLOAD TNPSC MASTER APP",
          style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: 3),
        ),
        const SizedBox(height: 8),
        Text(
          "LINK IN BIO / PLAY STORE",
          style: AppTheme.getStyle(
              color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 24, ignoreScale: true),
        ),
      ],
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
    final String qEn = widget.question.questionEn ?? widget.question.question;
    final String qTa = widget.question.questionTa ?? "";
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
                    AnimatedTextKit(
                      animatedTexts: [
                        TyperAnimatedText(
                          qEn,
                          textStyle: AppTheme.getStyle(
                            fontSize: qFontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.3,
                            ignoreScale: true,
                          ),
                          speed: const Duration(milliseconds: 20),
                        ),
                      ],
                      totalRepeatCount: 1,
                      isRepeatingAnimation: false,
                    ),
                    if (qTa.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: AnimatedTextKit(
                          animatedTexts: [
                            TyperAnimatedText(
                              qTa,
                              textStyle: AppTheme.getStyle(
                                fontSize: qFontSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.tealAccent,
                                height: 1.3,
                                ignoreScale: true,
                              ),
                              speed: const Duration(milliseconds: 20),
                            ),
                          ],
                          totalRepeatCount: 1,
                          isRepeatingAnimation: false,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AnimationLimiter(
            child: Column(
              children: AnimationConfiguration.toStaggeredList(
                duration: const Duration(milliseconds: 300),
                childAnimationBuilder: (widget) => SlideAnimation(
                  horizontalOffset: 30.0,
                  child: FadeInAnimation(child: widget),
                ),
                children: widget.question.displayOptions.asMap().entries.map((entry) {
                  int idx = entry.key;
                  String label = String.fromCharCode(65 + idx);
                  bool isCorrect = idx == widget.question.correctOptionIndex;

                  String optEn = "";
                  String optTa = "";

                  if (widget.question.optionsEn != null &&
                      idx < widget.question.optionsEn!.length &&
                      widget.question.optionsEn![idx].isNotEmpty) {
                    optEn = widget.question.optionsEn![idx];
                  }
                  if (widget.question.optionsTa != null &&
                      idx < widget.question.optionsTa!.length &&
                      widget.question.optionsTa![idx].isNotEmpty) {
                    optTa = widget.question.optionsTa![idx];
                  }
                  if (optEn.isEmpty && optTa.isEmpty) {
                    optEn = widget.question.options[idx];
                  }

                  bool highlight = widget.showCorrectAnswer && isCorrect;

                  Widget optionWidget = Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: highlight ? Colors.green.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: highlight ? Colors.greenAccent : Colors.white60,
                          width: highlight ? 2 : 1,
                        ),
                        boxShadow: highlight ? [
                          BoxShadow(color: Colors.green.withValues(alpha: 0.2), blurRadius: 8)
                        ] : null,
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
                            const Icon(Icons.verified_rounded, color: Colors.greenAccent, size: 18),
                        ],
                      ),
                    ),
                  );

                  if (highlight) {
                    return ScaleTransition(
                      scale: _pulseAnimation,
                      child: optionWidget,
                    );
                  }

                  return optionWidget;
                }).toList(),
              ),
            ),
          ),
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
      width: 100,
      height: 210,
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
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      ignoreScale: true),
                ),
                Text(
                  sub,
                  style: AppTheme.getStyle(
                      fontSize: 10,
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
