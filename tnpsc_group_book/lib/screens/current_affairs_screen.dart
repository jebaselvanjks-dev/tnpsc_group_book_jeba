import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:tnpsc_group_book/models/current_affairs.dart';
import 'package:tnpsc_group_book/services/ai_service.dart';
import 'package:tnpsc_group_book/services/firestore_service.dart';
import 'package:tnpsc_group_book/services/tts_service.dart';
import 'package:tnpsc_group_book/utils/app_date.dart';
import 'package:tnpsc_group_book/utils/app_language.dart';
import 'package:tnpsc_group_book/utils/app_theme.dart';
import 'package:tnpsc_group_book/widgets/ad_banner.dart';
import '../utils/app_icons.dart';
import '../utils/app_log.dart' show AppLog;

class CurrentAffairsScreen extends StatefulWidget {
  const CurrentAffairsScreen({super.key});

  @override
  State<CurrentAffairsScreen> createState() => _CurrentAffairsScreenState();
}

class _CurrentAffairsScreenState extends State<CurrentAffairsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = true;
  bool _isGenerating = false;
  List<CurrentAffairsPoint> _points = [];
  bool _isListeningAll = false;
  int _currentListeningIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadData();
    TtsService.init();
  }

  bool get _isAdmin {
    final user = FirebaseAuth.instance.currentUser;
    return user?.phoneNumber == '+918754236411' ||
        user?.email == 'adminjeba@gmail.com' ||
        user?.email == 'kjebaselvan987@gmail.com';
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);
      final data = await _firestoreService.getCurrentAffairs();
      if (mounted) {
        setState(() {
          _points = data.map((e) => CurrentAffairsPoint.fromMap(e)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading news: $e")),
        );
      }
    }
  }

  void _generateDailyNews() async {
    if (_isGenerating) return;
    setState(() => _isGenerating = true);
    
    try {
      // Use IST Now to ensure consistency
      DateTime istNow = AppDate.getISTNow();
      AppLog.d("AI_DEBUG: Admin manually triggering Current Affairs for ${AppDate.format(istNow)}");
      
      bool success = await AiService.generateAndSaveDailyCurrentAffairs(istNow);
      if (success) {
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("News refreshed / generated successfully!")),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Could not generate news. Please try again.")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _playPoint(CurrentAffairsPoint point, int index) {
    if (TtsService.isSpeaking(point.displayContent)) {
      TtsService.stop();
      setState(() {
        _currentListeningIndex = -1;
        _isListeningAll = false;
      });
    } else {
      setState(() {
        _currentListeningIndex = index;
      });
      TtsService.speak(point.displayContent);
    }
  }

  void _playAll() async {
    if (_isListeningAll) {
      TtsService.stop();
      setState(() {
        _isListeningAll = false;
        _currentListeningIndex = -1;
      });
      return;
    }

    setState(() {
      _isListeningAll = true;
      _currentListeningIndex = 0;
    });

    _speakSequentially(0);
  }

  void _speakSequentially(int index) {
    if (index >= _points.length || !_isListeningAll) {
      setState(() {
        _isListeningAll = false;
        _currentListeningIndex = -1;
      });
      return;
    }

    setState(() {
      _currentListeningIndex = index;
    });

    TtsService.onComplete = () {
      if (_isListeningAll) {
        _speakSequentially(index + 1);
      }
    };

    TtsService.speak(_points[index].displayContent);
  }

  @override
  void dispose() {
    TtsService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBgColor : AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          AppLanguage.getString('current_affairs'),
          style: AppTheme.getStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const AppIcon(AppIcons.back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_points.isNotEmpty)
            IconButton(
              icon: AppIcon(
                _isListeningAll ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded,
                color: AppTheme.secondaryColorLight,
              ),
              onPressed: _playAll,
              tooltip: AppLanguage.getString('listen_all'),
            ),
        ],
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _points.isEmpty
              ? Center(
                  child: Text(
                    AppLanguage.getString('no_results_today'),
                    style: AppTheme.getStyle(fontSize: 14, color: Colors.grey),
                  ),
                )
              : AnimationLimiter(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _points.length + (_points.length ~/ 5),
                    itemBuilder: (context, index) {
                      // Insert Ads every 5 points
                      if (index > 0 && (index + 1) % 6 == 0) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: AdBanner(),
                        );
                      }

                      // Adjust index to account for inserted ads
                      int actualIndex = index - (index ~/ 6);
                      final point = _points[actualIndex];
                      final isListening = _currentListeningIndex == actualIndex;

                      return AnimationConfiguration.staggeredList(
                        position: index,
                        duration: const Duration(milliseconds: 375),
                        child: SlideAnimation(
                          verticalOffset: 50.0,
                          child: FadeInAnimation(
                            child: _buildPointCard(point, actualIndex, isListening, isDark),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: _points.isNotEmpty ? FloatingActionButton.extended(
        onPressed: _playAll,
        backgroundColor: AppTheme.primaryColor,
        icon: AppIcon(_isListeningAll ? Icons.stop : Icons.volume_up, color: Colors.white),
        label: Text(
          _isListeningAll ? AppLanguage.getString('stop_audio') : AppLanguage.getString('listen_all'),
          style: AppTheme.getStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ) : null,
      bottomNavigationBar: _isAdmin
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurfaceColor : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  )
                ],
              ),
              child: SafeArea(
                child: ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _generateDailyNews,
                  icon: _isGenerating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(
                    _isGenerating ? "Generating..." : "Generate AI News (Admin)",
                    style: AppTheme.getStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildPointCard(CurrentAffairsPoint point, int index, bool isListening, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isListening 
            ? AppTheme.primaryColor.withOpacity(0.5) 
            : (isDark ? Colors.white10 : Colors.grey.shade200),
          width: isListening ? 2 : 1,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColorLight.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  point.category.toUpperCase(),
                  style: AppTheme.getStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.secondaryColorLight,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                point.date,
                style: AppTheme.getStyle(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _playPoint(point, index),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isListening ? AppTheme.primaryColor : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: AppIcon(
                    isListening ? Icons.pause_rounded : Icons.volume_up_rounded,
                    size: 16,
                    color: isListening ? Colors.white : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            point.displayTitle,
            style: AppTheme.getStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppTheme.textMainColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            point.displayContent,
            style: AppTheme.getStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : AppTheme.textSecondaryColor,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
