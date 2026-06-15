import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_theme.dart';
import '../utils/app_language.dart';
import '../services/firestore_service.dart';
import '../services/ai_service.dart';
import 'quiz_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/tts_service.dart';
import '../services/hive_service.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class TopicDetailScreen extends StatefulWidget {
  final String topic;
  final String category;
  final List<String>? allTopics;
  final int? currentIndex;

  const TopicDetailScreen({
    super.key,
    required this.topic,
    required this.category,
    this.allTopics,
    this.currentIndex,
  });

  @override
  State<TopicDetailScreen> createState() => _TopicDetailScreenState();
}

class _TopicDetailScreenState extends State<TopicDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isGenerating = false;
  int _visibleItems = 10; // Number of items to show initially
  int? _currentlyReadingIndex;
  int? _lastStoppedIndex;
  final ItemScrollController _itemScrollController = ItemScrollController();
  List<Map<String, dynamic>> _material = [];

  bool _isLoading = true;
  double _speedRate = 0.5;
  int _repeatCount = 1;
  int _currentRepeatCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
    _speedRate = HiveService.getTtsSpeed();
    _repeatCount = HiveService.getTtsRepeat();
    TtsService.onComplete = () {
      if (_currentlyReadingIndex != null) {
        _handleAudioComplete();
      }
    };
  }

  Future<void> _fetchInitialData() async {
    final data = await _firestoreService.getStudyMaterial(widget.topic);
    if (mounted) {
      setState(() {
        _material = data;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    TtsService.stop();
    TtsService.stopBackgroundMode();
    TtsService.onComplete = null;
    super.dispose();
  }

  void _playNext() async {
    if (!mounted) return;
    
    // Auto-fetch more if near the end
    if (_currentlyReadingIndex != null && _currentlyReadingIndex! >= _material.length - 2) {
      if (isAdmin && !_isGenerating) {
        _generateMoreInBackground();
      }
    }

    if (_currentlyReadingIndex != null && _currentlyReadingIndex! < _material.length - 1) {
      int nextIndex = _currentlyReadingIndex! + 1;
      
      // Auto-expand visible items if needed
      if (nextIndex >= _visibleItems) {
        setState(() {
          _visibleItems += 10;
        });
      }

      String lang = AppLanguage.languageNotifier.value;
      String nextContent = lang == 'ta' 
          ? (_material[nextIndex]['tamil'] ?? _material[nextIndex]['content'] ?? '') 
          : (_material[nextIndex]['english'] ?? _material[nextIndex]['content'] ?? '');

      setState(() {
        _currentlyReadingIndex = nextIndex;
      });

      TtsService.speak(nextContent);
      _scrollToIndex(nextIndex);
    } else {
      TtsService.stopBackgroundMode();
      setState(() {
        _currentlyReadingIndex = null;
        _lastStoppedIndex = null;
      });
    }
  }

  void _scrollToIndex(int index) {
    if (_itemScrollController.isAttached) {
      _itemScrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.1, // Positions the item near the top
      );
    }
  }

  void _togglePlayAll(String lang) {
    if (_currentlyReadingIndex != null) {
      TtsService.stop();
      TtsService.stopBackgroundMode();
      if (mounted) {
        setState(() {
          _lastStoppedIndex = _currentlyReadingIndex;
          _currentlyReadingIndex = null;
        });
      }
    } else {
      _playFromIndex(_lastStoppedIndex ?? 0, lang);
    }
  }

  void _playFromIndex(int index, String lang) async {
    if (_material.isNotEmpty) {
      if (index >= _material.length) {
        index = 0;
      }
      
      // Auto-expand visible items if starting index is beyond current visible limit
      if (index >= _visibleItems) {
        setState(() {
          _visibleItems = index + 10;
        });
      }

      String content = lang == 'ta' 
          ? (_material[index]['tamil'] ?? _material[index]['content'] ?? '') 
          : (_material[index]['english'] ?? _material[index]['content'] ?? '');
      
      // Check background permission
      bool? bgEnabled = HiveService.getBackgroundAudioEnabled();
      if (bgEnabled == null) {
        final result = await _showBackgroundAudioDialog();
        if (result != null) {
          bgEnabled = result;
        }
      }

      if (bgEnabled == true) {
        await TtsService.startBackgroundMode();
      } else {
        await TtsService.stopBackgroundMode();
      }

      if (mounted) {
        setState(() {
          _currentlyReadingIndex = index;
          _currentRepeatCount = 0; // reset repeat counter
        });
      }
      TtsService.speak(content);
      _scrollToIndex(index);
    }
  }

  void _toggleSingleAudio(int index, String content) async {
    if (_currentlyReadingIndex == index) {
      TtsService.stop();
      TtsService.stopBackgroundMode();
      if (mounted) {
        setState(() {
          _lastStoppedIndex = index;
          _currentlyReadingIndex = null;
        });
      }
    } else {
      bool? bgEnabled = HiveService.getBackgroundAudioEnabled();
      if (bgEnabled == null) {
        final result = await _showBackgroundAudioDialog();
        if (result != null) {
          bgEnabled = result;
        }
      }

      if (bgEnabled == true) {
        await TtsService.startBackgroundMode();
      } else {
        await TtsService.stopBackgroundMode();
      }

      if (mounted) {
        setState(() {
          _currentlyReadingIndex = index;
          _currentRepeatCount = 0; // reset repeat counter
        });
      }
      TtsService.speak(content);
    }
  }

  void _handleAudioComplete() {
    if (!mounted) return;
    setState(() {
      _currentRepeatCount++;
    });

    if (_currentRepeatCount < _repeatCount) {
      // Play current item again
      String lang = AppLanguage.languageNotifier.value;
      int index = _currentlyReadingIndex!;
      String content = lang == 'ta'
          ? (_material[index]['tamil'] ?? _material[index]['content'] ?? '')
          : (_material[index]['english'] ?? _material[index]['content'] ?? '');
      TtsService.speak(content);
    } else {
      setState(() {
        _currentRepeatCount = 0;
      });
      _playNext();
    }
  }

  void _showAudioSettingsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            bool isDark = Theme.of(context).brightness == Brightness.dark;
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.tune_rounded, color: AppTheme.secondaryColor),
                          const SizedBox(width: 10),
                          Text(
                            AppLanguage.getString('audio_settings'),
                            style: AppTheme.getStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  
                  // Speed Option Label
                  Text(
                    AppLanguage.getString('voice_speed'),
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Speed Chips Row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [0.25, 0.4, 0.5, 0.6, 0.75, 1.0].map((rate) {
                        bool isSelected = _speedRate == rate;
                        String label;
                        if (rate == 0.5) {
                          label = '1.0x (${AppLanguage.getString('normal_speed')})';
                        } else {
                          label = '${(rate * 2.0).toStringAsFixed(1).replaceAll('.0', '')}x';
                        }
                        
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(
                              label,
                              style: TextStyle(
                                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: AppTheme.secondaryColor,
                            backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.blue.withOpacity(0.05),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected ? AppTheme.secondaryColor : (isDark ? Colors.white.withOpacity(0.1) : Colors.blue.withOpacity(0.1)),
                              ),
                            ),
                            onSelected: (selected) async {
                              if (selected) {
                                setModalState(() {
                                  _speedRate = rate;
                                });
                                setState(() {
                                  _speedRate = rate;
                                });
                                await HiveService.setTtsSpeed(rate);
                                await TtsService.setSpeed(rate);
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Repeat Option Label
                  Text(
                    AppLanguage.getString('repeat_count'),
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Repeat Chips Row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [1, 2, 3, 5, 10].map((repeatVal) {
                        bool isSelected = _repeatCount == repeatVal;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(
                              repeatVal == 1 
                                  ? AppLanguage.getString('no_repeat') 
                                  : AppLanguage.getString('repeat_x_times').replaceAll('{count}', '$repeatVal'),
                              style: TextStyle(
                                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: AppTheme.secondaryColor,
                            backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.blue.withOpacity(0.05),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected ? AppTheme.secondaryColor : (isDark ? Colors.white.withOpacity(0.1) : Colors.blue.withOpacity(0.1)),
                              ),
                            ),
                            onSelected: (selected) async {
                              if (selected) {
                                setModalState(() {
                                  _repeatCount = repeatVal;
                                });
                                setState(() {
                                  _repeatCount = repeatVal;
                                  _currentRepeatCount = 0;
                                });
                                await HiveService.setTtsRepeat(repeatVal);
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<bool?> _showBackgroundAudioDialog() async {
    if (!mounted) return null;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark 
            ? Theme.of(context).cardColor 
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.volume_up_rounded, color: AppTheme.secondaryColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                AppLanguage.getString('bg_audio_title'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          AppLanguage.getString('bg_audio_desc'),
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54,
            fontSize: 14.5,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              AppLanguage.getString('no'),
              style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text(AppLanguage.getString('yes')),
          ),
        ],
      ),
    );

    if (result != null) {
      await HiveService.setBackgroundAudioEnabled(result);
    }
    return result;
  }

  void _generateMoreInBackground() async {
    if (_isGenerating) return;
    // We don't set _isGenerating = true here because we want it to be silent
    bool success = await AiService.generateStudyMaterial(
      widget.topic,
      category: widget.category,
    );
    if (success) {
      final newData = await _firestoreService.getStudyMaterial(widget.topic);
      if (mounted) {
        setState(() {
          _material = newData;
        });
      }
    }
  }

  bool get isAdmin {
    final user = FirebaseAuth.instance.currentUser;
    return user?.phoneNumber == '+918754236411' || 
           user?.email == 'adminjeba@gmail.com' ||
           user?.email == 'kjebaselvan987@gmail.com';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<String>(
      valueListenable: AppLanguage.languageNotifier,
      builder: (context, lang, child) {
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: Container(
                  // padding: const EdgeInsets.all(0),
                  child: Icon(Icons.arrow_back_ios_rounded, size: 25, color: isDark ? Colors.white : Colors.black),
                ),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(widget.topic),
              bottom: TabBar(
                tabs: [
                  Tab(text: AppLanguage.getString('exam')),
                  Tab(text: AppLanguage.getString('study')),
                ],
                indicatorColor: AppTheme.primaryColor,
                labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
            ),
            body: TabBarView(
              children: [
                // Tab 1: Quiz/Exam
                QuizScreen(
                  subjectTitle: widget.topic,
                  category: widget.category, // Pass the main subject category
                  allTopics: widget.allTopics,
                  currentIndex: widget.currentIndex,
                  hideAppBar: true,
                ),
                // Tab 2: Study Material/Explanation
                _buildStudyTab(lang),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildStudyTab(String lang) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_material.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_awesome_rounded, size: 60, color: Colors.amber),
            const SizedBox(height: 20),
            Text(AppLanguage.getString('study_material_preparing')),
              const SizedBox(height: 20),
              _isGenerating
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: () async {
                        if (!mounted) return;
                        setState(() => _isGenerating = true);
                        bool success = await AiService.generateStudyMaterial(
                          widget.topic,
                          category: widget.category,
                        );
                        if (success) {
                          await _fetchInitialData();
                        }
                        if (!mounted) return;
                        setState(() => _isGenerating = false);
                      },
                      child: Text(AppLanguage.getString('generate_ai')),
                    ),
          ],
        ),
      );
    }

    final visibleMaterial = _material.take(_visibleItems).toList();
    final hasMoreItems = _material.length > _visibleItems;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16.0,right: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLanguage.getString('audio_guide'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.tune_rounded, color: AppTheme.secondaryColor, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: _showAudioSettingsBottomSheet,
                tooltip: AppLanguage.getString('audio_settings'),
              ),
            ],
          ),
        ),
        // Play All Toggle
        if (_material.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 16.0,right: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [

                if (_currentlyReadingIndex != null)
                  ElevatedButton.icon(
                    onPressed: () => _togglePlayAll(lang),
                    icon: const Icon(Icons.stop_rounded),
                    label: Text(AppLanguage.getString('stop_audio')),
                    style: ElevatedButton.styleFrom(
                      textStyle: const TextStyle(fontSize: 12.5),
                      padding: const EdgeInsets.only(left: 10, right: 10),
                      backgroundColor: Colors.red.withOpacity(0.1),
                      foregroundColor: Colors.red,
                      elevation: 0,
                    ),
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_lastStoppedIndex != null) ...[
                        ElevatedButton.icon(
                          onPressed: () => _playFromIndex(_lastStoppedIndex!, lang),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: Text(AppLanguage.getString('resume_audio')),
                          style: ElevatedButton.styleFrom(
                            textStyle: const TextStyle(fontSize: 12.5),
                            padding: const EdgeInsets.only(left: 10, right: 10),
                            backgroundColor: AppTheme.secondaryColor.withOpacity(0.1),
                            foregroundColor: AppTheme.secondaryColor,
                            elevation: 0,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      ElevatedButton.icon(
                        onPressed: () {
                          if (_lastStoppedIndex != null) {
                            setState(() {
                              _lastStoppedIndex = null;
                            });
                          }
                          _playFromIndex(0, lang);
                        },
                        icon: Icon(_lastStoppedIndex != null ? Icons.replay_rounded : Icons.play_arrow_rounded),
                        label: Text(_lastStoppedIndex != null 
                            ? AppLanguage.getString('play_from_start') 
                            : AppLanguage.getString('listen_all')),
                        style: ElevatedButton.styleFrom(
                          textStyle: const TextStyle(fontSize: 12.5),
                          padding: const EdgeInsets.only(left: 10, right: 10),
                          backgroundColor: AppTheme.secondaryColor.withOpacity(0.1),
                          foregroundColor: AppTheme.secondaryColor,
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        Expanded(
          child: ScrollablePositionedList.builder(
            itemScrollController: _itemScrollController,
            padding: const EdgeInsets.all(16),
            itemCount: visibleMaterial.length + (hasMoreItems || isAdmin ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == visibleMaterial.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      if (hasMoreItems)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _visibleItems += 10;
                              });
                            },
                            icon: const Icon(Icons.expand_more_rounded),
                            label: Text(AppLanguage.getString('show_more')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.secondaryColor.withOpacity(0.1),
                              foregroundColor: AppTheme.secondaryColor,
                              elevation: 0,
                            ),
                          ),
                        ),
                      if (isAdmin)
                        _isGenerating
                            ? const CircularProgressIndicator()
                            : OutlinedButton.icon(
                                onPressed: () async {
                                  if (!mounted) return;
                                  setState(() => _isGenerating = true);
                                  bool success = await AiService.generateStudyMaterial(
                                    widget.topic,
                                    category: widget.category,
                                  );
                                  if (success) {
                                    await _fetchInitialData();
                                  }
                                  if (!mounted) return;
                                  setState(() => _isGenerating = false);
                                },
                                icon: const Icon(Icons.add_circle_outline_rounded),
                                label: Text(AppLanguage.getString('more_details')),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                    ],
                  ),
                );
              }

              final item = visibleMaterial[index];
              final String content = lang == 'ta' 
                  ? (item['tamil'] ?? item['content'] ?? '') 
                  : (item['english'] ?? item['content'] ?? '');
              
              final bool isHighlighted = _currentlyReadingIndex == index;
              
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isHighlighted 
                      ? AppTheme.primaryColor.withOpacity(0.15)
                      : (isDark ? Colors.white.withOpacity(0.05) : Colors.blue.withOpacity(0.05)),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isHighlighted 
                        ? AppTheme.primaryColor 
                        : (isDark ? Colors.white.withOpacity(0.1) : Colors.blue.withOpacity(0.1)),
                    width: isHighlighted ? 2 : 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isHighlighted ? AppTheme.secondaryColor : AppTheme.secondaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        "${index + 1}",
                        style: TextStyle(
                          color: isHighlighted ? Colors.white : AppTheme.secondaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            content,
                            style: AppTheme.getStyle(
                              fontSize: 15,
                              height: 1.6,
                              color: isHighlighted 
                                  ? (isDark ? Colors.white : Colors.black)
                                  : (isDark ? Colors.white.withOpacity(0.9) : Colors.black87),
                              fontWeight: isHighlighted ? FontWeight.w500 : FontWeight.normal,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (isHighlighted && _repeatCount > 1)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.secondaryColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppTheme.secondaryColor.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.repeat_rounded,
                                        size: 14,
                                        color: AppTheme.secondaryColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        "${_currentRepeatCount + 1}/$_repeatCount",
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.secondaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                const SizedBox(),
                              IconButton(
                                onPressed: () => _toggleSingleAudio(index, content),
                                icon: Icon(
                                  isHighlighted 
                                      ? Icons.stop_circle_rounded 
                                      : Icons.play_circle_filled_rounded,
                                  color: AppTheme.secondaryColor,
                                  size: 28,
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
            },
          ),
        ),
      ],
    );
  }
}
