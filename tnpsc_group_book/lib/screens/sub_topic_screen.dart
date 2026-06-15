import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../models/subject.dart';
import '../utils/app_theme.dart';
import 'package:tnpsc_group_book/utils/app_language.dart';
import 'quiz_screen.dart';
import 'topic_detail_screen.dart';

class SubTopicScreen extends StatelessWidget {
  final Subject subject;
  final int topicIndex;

  const SubTopicScreen({
    super.key,
    required this.subject,
    required this.topicIndex,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLanguage.languageNotifier,
      builder: (context, lang, child) {
        final subTopics = subject.getSubTopics(topicIndex);
        final parentTopic = subject.topics[topicIndex];
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: isDark ? Colors.black : Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_rounded, color: isDark ? Colors.white : AppTheme.textMainColor),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              parentTopic,
              style: AppTheme.getStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: isDark ? Colors.white : AppTheme.textMainColor,
              ),
            ),
            centerTitle: true,
          ),
          body: ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            itemCount: subTopics.length + 1, // +1 for the description text
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    AppLanguage.getString('select_topic_desc'),
                    textAlign: TextAlign.center,
                    style: AppTheme.getStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : AppTheme.textSecondaryColor,
                    ),
                  ),
                );
              }

              final topicIndex = index - 1;
              final topic = subTopics[topicIndex];
              return AnimationConfiguration.staggeredList(
                position: topicIndex,
                duration: const Duration(milliseconds: 375),
                child: SlideAnimation(
                  verticalOffset: 30.0,
                  child: FadeInAnimation(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: _buildTopicCard(context, topic, subTopics, topicIndex, parentTopic, isDark),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTopicCard(BuildContext context, String topic, List<String> allTopics, int index, String parentTopic, bool isDark) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TopicDetailScreen(
              topic: topic,
              category: parentTopic,
              allTopics: allTopics,
              currentIndex: index,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.1) : subject.color.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                if (!isDark) BoxShadow(
                  color: subject.color.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    topic,
                    style: AppTheme.getStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppTheme.textMainColor,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: subject.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: subject.color,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
