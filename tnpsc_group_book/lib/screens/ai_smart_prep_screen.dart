import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/ai_service.dart';
import '../services/firestore_service.dart';
import '../services/hive_service.dart';
import '../services/reward_service.dart';
import '../utils/app_log.dart';
import '../utils/app_theme.dart';
import '../utils/app_language.dart';

class AiSmartPrepScreen extends StatefulWidget {
  const AiSmartPrepScreen({super.key});

  @override
  State<AiSmartPrepScreen> createState() => _AiSmartPrepScreenState();
}

class _AiSmartPrepScreenState extends State<AiSmartPrepScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  final ScrollController _scrollController = ScrollController();
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  int _messageCount = 0;

  @override
  void initState() {
    super.initState();
    RewardService.loadRewardedAd();
  }

  void _sendMessage() async {
    String userText = _controller.text.trim();
    if (userText.isEmpty) return;

    if (!HiveService.canUseAi()) {
      AppLog.d("AI_LIMIT: Daily limit reached. Switching to local database for: $userText");
      _showLocalResponse(userText);
      return;
    }

    setState(() {
      _messages.add(ChatMessage(text: userText, isUser: true));
      _isTyping = true;
      _controller.clear();
      _messageCount++;
    });
    _scrollToBottom();

    // Trigger Ad every 5 messages
    if (_messageCount % 5 == 0) {
      RewardService.showRewardAd(onRewardEarned: () => _handleHybridResponse(userText));
    } else {
      _handleHybridResponse(userText);
    }
  }

  Future<void> _handleHybridResponse(String userText) async {
    AppLog.d("HYBRID_DEBUG: Starting process for: $userText");
    
    try {
      // 1. Fetch relevant context
      String contextData = await _firestoreService.getSearchContext(userText);
      
      // 2. Try AI First
      String? aiResponse = await AiService.chatWithAppContext(userText, contextData).timeout(
        const Duration(seconds: 12),
        onTimeout: () => null, // Explicitly return null on timeout
      );

      if (aiResponse == null) {
        AppLog.d("HYBRID_DEBUG: AI Failed or Null. Switching to local database.");
        await _showLocalResponse(userText);
      } else {
        AppLog.d("HYBRID_DEBUG: AI Success. Showing AI response.");
        await HiveService.incrementAiUsage();
        if (mounted) {
          setState(() {
            _isTyping = false;
            _messages.add(ChatMessage(text: aiResponse, isUser: false));
          });
          _scrollToBottom();
        }
      }
    } catch (e) {
      AppLog.e("HYBRID_DEBUG: Error in hybrid handler: $e");
      await _showLocalResponse(userText);
    }
  }

  Future<void> _showLocalResponse(String query) async {
    String localResults = await _searchLocalDatabase(query);
    if (mounted) {
      setState(() {
        _isTyping = false;
        _messages.add(ChatMessage(text: localResults, isUser: false));
      });
      _scrollToBottom();
    }
  }

  Future<String> _searchLocalDatabase(String query) async {
    try {
      String results = "";
      String lowerQuery = query.toLowerCase().trim();

      // Search Study Materials
      final studyDocs = await _db.collection('subject_study_material').get();
      int studyFound = 0;
      for (var doc in studyDocs.docs) {
        Map<String, dynamic> data = doc.data();
        String subject = (data['subject'] ?? "").toString().toLowerCase();
        List material = data['material'] ?? [];
        
        bool subjectMatch = subject.contains(lowerQuery);
        for (var item in material) {
          String title = (item['title'] ?? "").toString().toLowerCase();
          String content = (item['content'] ?? "").toString().toLowerCase();
          
          if (subjectMatch || title.contains(lowerQuery) || content.contains(lowerQuery)) {
            results += "📖 *${item['title']}*\n${item['content']}\n\n";
            studyFound++;
            if (studyFound >= 5) break;
          }
        }
        if (studyFound >= 5) break;
      }

      // Search Questions
      if (studyFound < 2) {
        final questionDocs = await _db.collection('subject_questions').get();
        int questionsFound = 0;
        for (var doc in questionDocs.docs) {
          Map<String, dynamic> data = doc.data();
          List questions = data['questions'] ?? [];
          for (var q in questions) {
            String qTextEn = (q['question_en'] ?? "").toString().toLowerCase();
            String qTextTa = (q['question_ta'] ?? "").toString().toLowerCase();
            String qTextLegacy = (q['question'] ?? "").toString().toLowerCase();

            if (qTextEn.contains(lowerQuery) || qTextTa.contains(lowerQuery) || qTextLegacy.contains(lowerQuery)) {
              String displayQ = q['question_en'] != null ? "${q['question_en']}\n${q['question_ta']}" : (q['question'] ?? "");
              String displayE = q['explanation_en'] != null ? "${q['explanation_en']} ${q['explanation_ta']}" : (q['explanation'] ?? "");
              
              results += "❓ *Question:*\n$displayQ\n\n✅ *Explanation:*\n$displayE\n\n";
              questionsFound++;
              if (questionsFound >= 3) break;
            }
          }
          if (questionsFound >= 3) break;
        }
      }

      if (results.isEmpty) {
        return AppLanguage.languageNotifier.value == 'ta' 
            ? "மன்னிக்கவும், இதற்கான தகவல்கள் உங்கள் ஆப்பில் இல்லை. தயவுசெய்து 'History' அல்லது 'Tamil' போன்ற பாடங்களின் பெயர்களைத் தேடவும்."
            : "I couldn't find information for '$query' in your app. Please try searching for subjects like 'History' or 'Tamil'.";
      }

      String prefix = AppLanguage.languageNotifier.value == 'ta'
          ? "🎯 உங்கள் டேட்டாபேஸில் இருந்து:\n\n"
          : "🎯 From your local database:\n\n";
          
      return prefix + results;
    } catch (e) {
      return "Local search error: $e";
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: isDark ? Colors.white : AppTheme.textMainColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLanguage.getString('ai_smart_prep'),
          style: AppTheme.getStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : AppTheme.textMainColor),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.manage_search_rounded, color: Colors.cyan),
            onPressed: () {
              if (_controller.text.isNotEmpty) {
                 _showLocalResponse(_controller.text);
                 _controller.clear();
              }
            },
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty 
              ? _buildWelcomeState(isDark)
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) => _messages[index],
                ),
          ),
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.cyan)),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    AppLanguage.getString('ai_thinking'),
                    style: AppTheme.getStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          _buildInputArea(isDark),
        ],
      ),
    );
  }

  Widget _buildWelcomeState(bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.cyan.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, size: 64, color: Colors.cyan),
            ),
            const SizedBox(height: 32),
            Text(
              "Smart Syllabus Chat",
              textAlign: TextAlign.center,
              style: AppTheme.getStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.textMainColor),
            ),
            const SizedBox(height: 16),
            Text(
              "Ask anything! I search your saved data first, then use AI to explain. If AI is slow, I'll show your data instantly.",
              textAlign: TextAlign.center,
              style: AppTheme.getStyle(fontSize: 15, color: isDark ? Colors.white60 : Colors.grey.shade600, height: 1.5),
            ),
            const SizedBox(height: 40),
            _buildSuggestionChip("History", isDark),
            _buildSuggestionChip("Thirukkural", isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(String text, bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      child: OutlinedButton(
        onPressed: () {
          _controller.text = text;
          _sendMessage();
        },
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          side: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: isDark ? Colors.white.withOpacity(0.02) : Colors.white,
        ),
        child: Text(
          text,
          style: AppTheme.getStyle(color: isDark ? Colors.white70 : AppTheme.textMainColor, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildInputArea(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
              ),
              child: TextField(
                controller: _controller,
                style: AppTheme.getStyle(fontSize: 15, color: isDark ? Colors.white : AppTheme.textMainColor),
                decoration: InputDecoration(
                  hintText: AppLanguage.getString('ask_ai_hint'),
                  hintStyle: AppTheme.getStyle(fontSize: 13.5, color: isDark ? Colors.white38 : Colors.grey.shade400),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Colors.cyan, Colors.teal]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage extends StatelessWidget {
  final String text;
  final bool isUser;

  const ChatMessage({super.key, required this.text, required this.isUser});

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLanguage.getString('copied_to_clipboard') ?? "Copied to clipboard"),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.cyan.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.cyan, size: 14),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () => _copyToClipboard(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  gradient: isUser 
                    ? const LinearGradient(colors: [Colors.cyan, Colors.teal])
                    : null,
                  color: isUser 
                    ? null 
                    : (isDark ? Colors.white.withOpacity(0.08) : Colors.white),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(24),
                    topRight: const Radius.circular(24),
                    bottomLeft: Radius.circular(isUser ? 24 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 24),
                  ),
                  boxShadow: [
                    if (!isUser) BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                    if (isUser) BoxShadow(
                      color: Colors.cyan.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                  border: !isUser ? Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100) : null,
                ),
                child: Text(
                  text,
                  style: AppTheme.getStyle(
                    fontSize: 15,
                    color: isUser ? Colors.white : (isDark ? Colors.white.withOpacity(0.9) : AppTheme.textMainColor),
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.cyan.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_outline_rounded, color: Colors.cyan, size: 14),
            ),
          ],
        ],
      ),
    );
  }
}
