import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/ai_service.dart';
import '../services/hive_service.dart';
import '../services/reward_service.dart';
import '../services/firestore_service.dart';
import '../utils/app_theme.dart';
import '../utils/app_language.dart';

class AiTutorScreen extends StatefulWidget {
  const AiTutorScreen({super.key});

  @override
  State<AiTutorScreen> createState() => _AiTutorScreenState();
}

class _AiTutorScreenState extends State<AiTutorScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  final ScrollController _scrollController = ScrollController();
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    RewardService.loadRewardedAd();
  }

  void _sendMessage() async {
    String userText = _controller.text.trim();
    if (userText.isEmpty) return;

    if (!HiveService.canUseAi()) {
      _showLocalResponse(userText);
      return;
    }

    setState(() {
      _messages.add(ChatMessage(text: userText, isUser: true));
      _isTyping = true;
      _controller.clear();
    });
    _scrollToBottom();

    await _getAiResponse(userText);
  }

  Future<void> _getAiResponse(String userText) async {
    try {
      String? response = await AiService.chatWithAi(userText).timeout(
        const Duration(seconds: 12),
        onTimeout: () => null,
      );

      if (response == null) {
        await _showLocalResponse(userText);
      } else {
        await HiveService.incrementAiUsage();
        _addAiMessage(response);
      }
    } catch (e) {
      await _showLocalResponse(userText);
    }
  }

  Future<void> _showLocalResponse(String query) async {
    String localData = await _searchLocalDatabase(query);
    _addAiMessage(localData);
  }

  void _addAiMessage(String text) {
    if (mounted) {
      setState(() {
        _isTyping = false;
        _messages.add(ChatMessage(text: text, isUser: false));
      });
      _scrollToBottom();
    }
  }

  Future<String> _searchLocalDatabase(String query) async {
    try {
      String results = "";
      String lowerQuery = query.toLowerCase().trim();

      final studyDocs = await _db.collection('subject_study_material').get();
      int count = 0;
      for (var doc in studyDocs.docs) {
        Map<String, dynamic> data = doc.data();
        List material = data['material'] ?? [];
        for (var item in material) {
          String content = (item['content'] ?? "").toString().toLowerCase();
          if (content.contains(lowerQuery)) {
            results += "📌 ${item['title']}\n${item['content']}\n\n";
            count++;
            if (count >= 3) break;
          }
        }
        if (count >= 3) break;
      }

      if (results.isEmpty) {
        return AppLanguage.languageNotifier.value == 'ta'
            ? "மன்னிக்கவும், AI தற்போது கிடைக்கவில்லை. உங்கள் பாடப்புத்தகங்களில் இதற்கான தகவல் இல்லை."
            : "Sorry, AI is currently unavailable and I couldn't find this in your study materials.";
      }

      String prefix = AppLanguage.languageNotifier.value == 'ta'
          ? "🎯 உங்கள் பாடக்குறிப்புகளில் இருந்து:\n\n"
          : "🎯 From your study materials:\n\n";
      return prefix + results;
    } catch (e) {
      return "Search error: $e";
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
          AppLanguage.getString('ai_tutor'),
          style: AppTheme.getStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : AppTheme.textMainColor),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
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
