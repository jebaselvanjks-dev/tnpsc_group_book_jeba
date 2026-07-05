import 'package:flutter/material.dart';

import '../utils/app_theme.dart';
import '../utils/app_language.dart';
import '../services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isDaily = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {
        _isDaily = _tabController.index == 0;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<String>(
      valueListenable: AppLanguage.languageNotifier,
      builder: (context, lang, child) {
        return Column(
          children: [
            // Custom AppBar for Tab inside MainWrapper
            Container(
              color: isDark ? Colors.black : Colors.white,
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Text(
                    AppLanguage.getString('leaderboard'),
                    style: AppTheme.getStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                      color: isDark ? Colors.white : AppTheme.textMainColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TabBar(
                    controller: _tabController,
                    labelColor: AppTheme.secondaryColor,
                    unselectedLabelColor: isDark ? Colors.white : Colors.grey,
                    indicatorColor: AppTheme.secondaryColor,
                    indicatorWeight: 3,
                    dividerHeight: 0.1,
                    dividerColor: isDark ? Colors.white : Colors.grey,
                    tabs: [
                      Tab(
                        child: Text(
                          AppLanguage.getString('daily'),
                          textAlign: TextAlign.center,
                          style: AppTheme.getStyle(fontSize: 13),
                          maxLines: 2,
                        ),
                      ),
                      Tab(
                        child: Text(
                          AppLanguage.getString('mock'),
                          textAlign: TextAlign.center,
                          style: AppTheme.getStyle(fontSize: 13),
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  TabBarView(
                    controller: _tabController,
                    children: const [
                      _LeaderboardList(isDaily: true),
                      _LeaderboardList(isDaily: false),
                    ],
                  ),
                  // User's own rank at the bottom
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: _MyRankStickyCard(isDaily: _isDaily),
                  ),
                ],
              ),
            ),
          ],
        );
      }
    );
  }
}

class _MyRankStickyCard extends StatefulWidget {
  final bool isDaily;
  const _MyRankStickyCard({required this.isDaily});

  @override
  State<_MyRankStickyCard> createState() => _MyRankStickyCardState();
}

class _MyRankStickyCardState extends State<_MyRankStickyCard> {
  late Future<Map<String, dynamic>?> _future;

  @override
  void initState() {
    super.initState();
    _loadFuture();
  }

  @override
  void didUpdateWidget(_MyRankStickyCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDaily != widget.isDaily) {
      _loadFuture();
    }
  }

  void _loadFuture() {
    final FirestoreService firestoreService = FirestoreService();
    setState(() {
      _future = firestoreService.getUserBestResultToday(isDaily: widget.isDaily);
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<String>(
      valueListenable: AppLanguage.languageNotifier,
      builder: (context, lang, child) {
        return FutureBuilder<Map<String, dynamic>?>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data == null) return const SizedBox.shrink();
            final data = snapshot.data!;
            return Stack(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [isDark ? AppTheme.primaryColor : AppTheme.primaryColorLight, isDark ? AppTheme.secondaryColor : AppTheme.secondaryColorLight],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 15,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLanguage.getString('best_performance_today'),
                                style: AppTheme.getStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                "${AppLanguage.getString('you_label')}: ${data['userName'] ?? AppLanguage.getString('anonymous')}",
                                style: AppTheme.getStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 5),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "${AppLanguage.getString('score')}: ${data['score']}/${data['totalQuestions'] ?? (widget.isDaily ? 20 : 50)}",
                              style: AppTheme.getStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Builder(
                              builder: (context) {
                                int totalSec = data['timeTaken'] ?? 0;
                                int min = totalSec ~/ 60;
                                int sec = totalSec % 60;
                                String timeDisplay = min > 0
                                    ? "$min ${AppLanguage.getString('min')} $sec ${AppLanguage.getString('sec')}"
                                    : "$sec ${AppLanguage.getString('sec')}";
                                return Text(
                                  timeDisplay,
                                  style: AppTheme.getStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        // Refresh button
                        IconButton(
                          padding: EdgeInsets.all(0),
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          onPressed: () {
                            _loadFuture();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}



class _LeaderboardList extends StatefulWidget {
  final bool isDaily;
  const _LeaderboardList({required this.isDaily});

  @override
  State<_LeaderboardList> createState() => _LeaderboardListState();
}

class _LeaderboardListState extends State<_LeaderboardList> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _loadData(forceRefresh: true); // Force fresh fetch on init
  }

  @override
  void didUpdateWidget(_LeaderboardList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDaily != widget.isDaily) {
      _loadData(forceRefresh: true);
    }
  }

  void _loadData({required bool forceRefresh}) {
    final firestoreService = FirestoreService();
    _future = firestoreService.getLeaderboard(isDaily: widget.isDaily, forceRefresh: forceRefresh);
  }

  Future<void> _onRefresh() async {
    setState(() {
      _loadData(forceRefresh: true);
    });
    // Wait for the future to complete
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ValueListenableBuilder<String>(
      valueListenable: AppLanguage.languageNotifier,
      builder: (context, lang, child) {
        return RefreshIndicator(
          onRefresh: _onRefresh,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("🏆", style: AppTheme.getStyle(fontSize: 60)),
                        const SizedBox(height: 16),
                        Text(
                          AppLanguage.getString('no_results_today'),
                          style: AppTheme.getStyle(fontSize: 18, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          lang == 'ta' ? 'தேர்வை முடித்து முதலில் இங்கே வரவும்!' : 'Finish a quiz and be the first one here!',
                          style: AppTheme.getStyle(fontSize: 14, color: Colors.grey.shade400),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _onRefresh,
                          icon: const Icon(Icons.refresh),
                          label: Text(lang == 'ta' ? 'மீண்டும் ஏற்றவும்' : 'Refresh'),
                        )
                      ],
                    ),
                  ),
                );
              }

              final users = snapshot.data!;
              return ListView.builder(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 120),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  bool isTop3 = index < 3;
                  String timeDisplay = "${user['timeTaken'] ?? 0} ${AppLanguage.getString('sec')}";
                  if (user['timeTaken'] != null) {
                    int totalSec = user['timeTaken'];
                    int min = totalSec ~/ 60;
                    int sec = totalSec % 60;
                    if (min > 0) {
                      timeDisplay = "$min ${AppLanguage.getString('min')} $sec ${AppLanguage.getString('sec')}";
                    } else {
                      timeDisplay = "$sec ${AppLanguage.getString('sec')}";
                    }
                  }
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isTop3
                          ? (index == 0 ? Colors.amber.withOpacity(0.1) :
                             index == 1 ? Colors.blueGrey.withOpacity(0.1) :
                             Colors.orangeAccent.withOpacity(0.1))
                          : Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isTop3
                            ? (index == 0 ? Colors.amber :
                               index == 1 ? Colors.blueGrey :
                               Colors.orangeAccent).withOpacity(0.3)
                            : Colors.grey.withOpacity(0.1),
                      ),
                      boxShadow: [
                        if (isTop3)
                          BoxShadow(
                            color: (index == 0 ? Colors.amber :
                                   index == 1 ? Colors.blueGrey :
                                   Colors.orangeAccent).withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                      ],
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 40,
                          child: isTop3
                              ? Text(
                                  index == 0 ? "🥇" : index == 1 ? "🥈" : "🥉",
                                  style: AppTheme.getStyle(fontSize: 24),
                                  textAlign: TextAlign.center,
                                )
                              : Text(
                                  "#${index + 1}",
                                  style: AppTheme.getStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user["userName"] ?? AppLanguage.getString('anonymous'),
                                style: AppTheme.getStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppTheme.textMainColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.timer_outlined, size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    timeDisplay,
                                    style: AppTheme.getStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            "${user['score']}/${user['totalQuestions'] ?? (widget.isDaily ? 20 : 50)}",
                            style: AppTheme.getStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
