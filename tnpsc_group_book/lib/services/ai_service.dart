import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:http/http.dart' as http;

class AiService {
  static List<String>? _cachedApiKeys;
  static List<String>? _cachedPreferredModels;

  // -----------------------------------------------------------------
  // Remote Config fetcher for API key and Model Priority
  // -----------------------------------------------------------------
  static Future<void> _fetchRemoteConfig() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(minutes: 1),
          minimumFetchInterval: Duration.zero,
        ),
      );
      await remoteConfig.fetchAndActivate();

      // 1. API Keys (Rotation support)
      String keysStr = remoteConfig.getString('gemini_api_key');
      if (keysStr.isNotEmpty) {
        _cachedApiKeys =
            keysStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        print("AI_DEBUG: Loaded ${_cachedApiKeys!.length} API keys from Remote Config");
      }

      // 2. Preferred Models
      String modelsStr = remoteConfig.getString('gemini_preferred_models');
      if (modelsStr.isNotEmpty) {
        _cachedPreferredModels =
            modelsStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        print("AI_DEBUG: Preferred Models from Remote Config: $_cachedPreferredModels");
      }
    } catch (e) {
      print("AI_DEBUG: Remote Config Error: $e");
    }
  }

  static Future<List<String>> _getApiKeys() async {
    if (_cachedApiKeys == null || _cachedApiKeys!.isEmpty) {
      await _fetchRemoteConfig();
    }
    return _cachedApiKeys ?? [];
  }

  static Future<List<String>> _getPreferredModels() async {
    if (_cachedPreferredModels == null) {
      await _fetchRemoteConfig();
    }
    // Final hardcoded fallback if Remote Config fails or is empty
    return _cachedPreferredModels ??
        [
          'gemini-2.0-flash',
          'gemini-1.5-flash',
          'gemini-1.5-pro',
          'gemini-2.0-pro-exp',
        ];
  }

  // -----------------------------------------------------------------
  // Core request helper – discovers models, falls back, and returns raw text
  // -----------------------------------------------------------------
  static Future<String?> _generateWithFallback(String prompt) async {
    final apiKeys = await _getApiKeys();
    if (apiKeys.isEmpty) return null;

    // Try each API key in rotation
    for (String apiKey in apiKeys) {
      // 1. Discover available models
      List<String> discoveredModels = [];
      try {
        print("AI_DEBUG: Discovering models with key: ${apiKey.substring(0, 5)}...");
        final listUrl = Uri.parse(
          'https://generativelanguage.googleapis.com/v1/models?key=$apiKey',
        );
        final listRes = await http.get(listUrl).timeout(const Duration(seconds: 10));
        if (listRes.statusCode == 200) {
          final listData = jsonDecode(listRes.body);
          for (var m in listData['models']) {
            String mName = m['name'].toString().replaceFirst('models/', '');
            if (m['supportedGenerationMethods'].contains('generateContent')) {
              discoveredModels.add(mName);
            }
          }
        } else {
          print("AI_DEBUG: Key ${apiKey.substring(0, 5)} discovery failed (${listRes.statusCode}). Trying next key...");
          continue; // Try next API key
        }
      } catch (e) {
        print("AI_DEBUG: Discovery failed for key ${apiKey.substring(0, 5)}: $e");
        continue;
      }

      // 2. Model Priority logic
      final preferredModels = await _getPreferredModels();

      List<String> finalModelsToTry = [];
      for (var p in preferredModels) {
        if (discoveredModels.contains(p)) {
          finalModelsToTry.add(p);
        }
      }
      for (var d in discoveredModels) {
        if (!finalModelsToTry.contains(d)) {
          finalModelsToTry.add(d);
        }
      }
      if (finalModelsToTry.isEmpty) {
        finalModelsToTry = ['gemini-1.5-flash', 'gemini-pro'];
      }

      print("AI_DEBUG: Trying models: $finalModelsToTry");

      // 3. Try each model (v1 then v1beta)
      bool keyFailed = false;
      for (String version in ['v1', 'v1beta']) {
        if (keyFailed) break;
        for (String modelName in finalModelsToTry) {
          try {
            print("AI_DEBUG: REST Call - Trying $modelName on $version...");
            final url = Uri.parse(
              'https://generativelanguage.googleapis.com/$version/models/$modelName:generateContent?key=$apiKey',
            );

            final response = await http
                .post(
                  url,
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({
                    'contents': [
                      {
                        'parts': [
                          {'text': prompt},
                        ],
                      },
                    ],
                    'safetySettings': [
                      {
                        'category': 'HARM_CATEGORY_HARASSMENT',
                        'threshold': 'BLOCK_NONE',
                      },
                      {
                        'category': 'HARM_CATEGORY_HATE_SPEECH',
                        'threshold': 'BLOCK_NONE',
                      },
                      {
                        'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
                        'threshold': 'BLOCK_NONE',
                      },
                      {
                        'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
                        'threshold': 'BLOCK_NONE',
                      },
                    ],
                    'generationConfig': {
                      'responseMimeType': 'application/json',
                      'temperature': 0.9,
                      'topP': 0.95,
                      'topK': 40,
                      'maxOutputTokens': 8192,
                    },
                  }),
                )
                .timeout(const Duration(seconds: 90));

            if (response.statusCode == 200) {
              final data = jsonDecode(response.body);
              final candidate = data['candidates'][0];
              if (candidate['finishReason'] != 'STOP') continue;

              String? text = candidate['content']['parts'][0]['text'];
              if (text != null) {
                text = text.trim();
                if (text.startsWith("```")) {
                  text = text.replaceAll("```json", "").replaceAll("```", "").trim();
                }
                try {
                  jsonDecode(text);
                  return text;
                } catch (e) {
                  continue;
                }
              }
            } else if (response.statusCode == 429 || response.statusCode == 403) {
              print("AI_DEBUG: Key limit reached or invalid (Status: ${response.statusCode}). Switching key...");
              keyFailed = true;
              break;
            } else {
              print("AI_DEBUG: REST FAIL - Status: ${response.statusCode}");
            }
          } catch (e) {
            print("AI_DEBUG: REST Error: $e");
          }
        }
      }
      // If we reach here and keyFailed is true, the outer loop continues to next API key
    }
    return null;
  }

  // -----------------------------------------------------------------
  // Helper to get topics/questions from last 30 days to avoid repeats
  // -----------------------------------------------------------------
  static Future<String> _getRecentQuizContext(String collectionName, int days) async {
    String context = "";
    DateTime cutoff = DateTime.now().subtract(Duration(days: days));
    try {
      final docs = await FirebaseFirestore.instance
          .collection(collectionName)
          .where('createdAt', isGreaterThan: cutoff)
          .orderBy('createdAt', descending: true)
          .limit(20) // Limit to last 20 quizzes to avoid prompt bloat
          .get();
      
      for (var doc in docs.docs) {
        List qs = doc.get('questions') ?? [];
        // Take a few representative questions from each quiz
        for (var q in qs.take(5)) {
          String text = q['question'].toString().split('\n').first;
          if (text.length > 60) text = text.substring(0, 60);
          context += "$text, ";
        }
      }
    } catch (e) {
      print("AI_DEBUG: Context fetch error ($collectionName): $e");
    }
    return context;
  }

  // -----------------------------------------------------------------
  // Daily quiz (10 Tamil, 6 GS, 4 Aptitude) generation
  // -----------------------------------------------------------------
  static Future<bool> generateAndSaveDailyQuiz(DateTime date) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);

    // Get topics from last 30 days to avoid repeats
    String recentContext = await _getRecentQuizContext('quizzes', 30);

    final avoidPrompt = recentContext.isNotEmpty
        ? """
STRICTLY DO NOT create questions that are identical, very similar, or based on these recent questions/topics from the last 30 days:
$recentContext

Rules:
- Do NOT repeat the same question.
- Do NOT repeat the same answer choices with different wording.
- Do NOT repeat the same concept unless it is from a completely different chapter.
"""
        : "";

    final commonRules = """
STRICT QUALITY RULES (MUST FOLLOW)

1. Return ONLY valid JSON.
2. No Markdown.
3. No extra text before or after JSON.
4. Generate NEW and ORIGINAL questions.
5. Never repeat questions, options, explanations, or question patterns.
6. Every question must test a different concept.
7. Questions must be suitable for TNPSC SSLC Standard.
8. Grammar must be 100% correct in BOTH Tamil and English.
9. English must be natural and error-free.
10. Tamil must use proper literary Tamil without spelling mistakes.
11. Do NOT mix Tamil and English in the same sentence.
12. Do NOT use Hindi or any other language.
13. Every question must have exactly four options.
14. Only ONE option must be correct.
15. Verify the correct answer before assigning correctOptionIndex.
16. correctOptionIndex MUST exactly match the correct option (0-3).
17. Explanation must clearly justify why the answer is correct.
18. Explanation must contain:
    - First: Correct English explanation.
    - Next: Correct Tamil explanation.
19. Avoid vague or ambiguous questions.
20. Avoid duplicate option values.
21. Avoid options like "All of the above" or "None of the above".
22. Do not generate trick questions.
23. Ensure every question is unique.
24. Ensure every option is unique.
25. Ensure every explanation is unique.
26. Maintain balanced difficulty.
27. Use proper punctuation.
28. Do not use unnecessary quotation marks.
29. Never invent incorrect historical or scientific facts.
30. Validate every answer before returning JSON.

Before generating the JSON, internally verify:
- Grammar accuracy (Tamil & English)
- No duplicate questions or patterns
- No duplicate options
- Correctness of correctOptionIndex
- Step-by-step math accuracy (for Aptitude)
- Explanation clarity and accuracy

Question format:
English Question
தமிழ் வினா

Option format:
English Option / தமிழ் விருப்பம்

Explanation format:
English explanation.
தமிழ் விளக்கம்.

Output Format:

[
  {
    "question":"...",
    "options":[
      "...",
      "...",
      "...",
      "..."
    ],
    "correctOptionIndex":0,
    "explanation":"..."
  }
]

Return ONLY the final verified JSON array.
""";

    // Prompt definitions ------------------------------------------------
    final promptTamil = """
Generate exactly 10 UNIQUE TNPSC General Tamil MCQs.

Requirements:
- SSLC Standard
- Cover different Samacheer Kalvi chapters.
- Cover different grammar and literature concepts.
- No repeated chapter.
- No repeated question pattern.
$avoidPrompt

$commonRules
""";

    final promptGS = """
Generate exactly 6 UNIQUE TNPSC General Studies MCQs.

Requirements:
Rotate equally between:
- Science
- History
- Geography
- Polity
- Economy
- Current General Knowledge (timeless TNPSC syllabus)

$avoidPrompt

$commonRules
""";

    final promptAptitude = """
Generate exactly 4 UNIQUE TNPSC Aptitude MCQs.

Topics:
- HCF
- LCM
- Ratio
- Percentage
- Profit & Loss
- Time & Work
- Time & Distance
- Simple Interest
- Compound Interest
- Mensuration

Each question must require calculation.

$avoidPrompt

$commonRules
""";

    // --------------------------------------------------------------------
    // Daily quiz generation with quiz_type tagging
    List<dynamic> allQuestions = [];

    // Helper to fetch questions and tag them with a quiz_type
    Future<void> fetchAndTag(
      String prompt,
      String quizType,
      int expectedCount,
    ) async {
      final res = await _generateWithFallback(prompt);
      if (res != null) {
        try {
          // Note: _generateWithFallback already trims and handles code blocks
          List q = jsonDecode(res);

          // Validation: Trim if more, fail if less
          if (q.length > expectedCount) q = q.sublist(0, expectedCount);
          if (q.length < expectedCount) {
            print(
              "AI_DEBUG: Count mismatch for $quizType. Got ${q.length}, expected $expectedCount",
            );
            return;
          }

          allQuestions.addAll(
            q.map((item) => {...item, 'quiz_type': quizType}),
          );
        } catch (e) {
          print("AI_DEBUG: JSON Decode Error in fetchAndTag ($quizType): $e");
        }
      }
    }

    // Fetch each category and tag appropriately
    await fetchAndTag(promptTamil, 'general_tamil', 10);
    await fetchAndTag(promptGS, 'general_studies', 6);
    await fetchAndTag(promptAptitude, 'aptitude', 4);

    if (allQuestions.length != 20) return false; // Ensure exactly 20 total

    // Store / update in Firestore
    final querySnapshot = await FirebaseFirestore.instance
        .collection('quizzes')
        .where('date', isEqualTo: dateStr)
        .where('type', isEqualTo: 'daily_quiz')
        .get();

    final quizData = {
      'date': dateStr,
      'title': "Daily Quiz / தினசரி வினாடி வினா",
      'quizType': 'daily_quiz',
      'questions': allQuestions,
      'type': 'daily_quiz',
      'createdAt': FieldValue.serverTimestamp(),
    };

    if (querySnapshot.docs.isNotEmpty) {
      await querySnapshot.docs.first.reference.set(
        quizData,
        SetOptions(merge: true),
      );
    } else {
      await FirebaseFirestore.instance.collection('quizzes').add(quizData);
    }
    return true;
  }

  // -----------------------------------------------------------------
  // Mock quiz (25 Tamil, 15 GS, 10 Aptitude) generation
  // -----------------------------------------------------------------
  static Future<bool> generateAndSaveMockQuiz(DateTime date) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);

    // Get topics from last 30 days to avoid repeats in mock tests
    String recentContext = await _getRecentQuizContext('mock_tests', 30);

    final avoidPrompt = recentContext.isNotEmpty
        ? """
STRICTLY DO NOT create questions that are identical, very similar, or based on these recent questions/topics from the last 30 days:
$recentContext

Rules:
- Do NOT repeat the same question.
- Do NOT repeat the same answer choices with different wording.
- Do NOT repeat the same concept unless it is from a completely different chapter.
"""
        : "";

    final commonRules = """
STRICT QUALITY RULES (MUST FOLLOW)

1. Return ONLY valid JSON.
2. No Markdown.
3. No extra text before or after JSON.
4. Generate NEW and ORIGINAL questions.
5. Never repeat questions, options, explanations, or question patterns.
6. Every question must test a different concept.
7. Questions must be suitable for TNPSC SSLC Standard.
8. Grammar must be 100% correct in BOTH Tamil and English.
9. English must be natural and error-free.
10. Tamil must use proper literary Tamil without spelling mistakes.
11. Do NOT mix Tamil and English in the same sentence.
12. Do NOT use Hindi or any other language.
13. Every question must have exactly four options.
14. Only ONE option must be correct.
15. Verify the correct answer before assigning correctOptionIndex.
16. correctOptionIndex MUST exactly match the correct option (0-3).
17. Explanation must clearly justify why the answer is correct.
18. Explanation must contain:
    - First: Correct English explanation.
    - Next: Correct Tamil explanation.
19. Avoid vague or ambiguous questions.
20. Avoid duplicate option values.
21. Avoid options like "All of the above" or "None of the above".
22. Do not generate trick questions.
23. Ensure every question is unique.
24. Ensure every option is unique.
25. Ensure every explanation is unique.
26. Maintain balanced difficulty.
27. Use proper punctuation.
28. Do not use unnecessary quotation marks.
29. Never invent incorrect historical or scientific facts.
30. Validate every answer before returning JSON.

Before generating the JSON, internally verify:
- Grammar accuracy (Tamil & English)
- No duplicate questions or patterns
- No duplicate options
- Correctness of correctOptionIndex
- Step-by-step math accuracy (for Aptitude)
- Explanation clarity and accuracy

Question format:
English Question
தமிழ் வினா

Option format:
English Option / தமிழ் விருப்பம்

Explanation format:
English explanation.
தமிழ் விளக்கம்.

Output Format:

[
  {
    "question":"...",
    "options":[
      "...",
      "...",
      "...",
      "..."
    ],
    "correctOptionIndex":0,
    "explanation":"..."
  }
]

Return ONLY the final verified JSON array.
""";

    // Prompt definitions ------------------------------------------------
    final promptTamil = """
Generate exactly 25 UNIQUE TNPSC General Tamil MCQs.

Requirements:
- SSLC Standard
- Cover different Samacheer Kalvi chapters.
- Cover Grammar, Literature, and Tamil Scholars.
- No repeated chapter.
- No repeated question pattern.
$avoidPrompt

$commonRules
""";

    final promptGS = """
Generate exactly 15 UNIQUE TNPSC General Studies MCQs.

Requirements:
Rotate equally between:
- Science
- History
- Geography
- Polity
- Economy
- Indian National Movement

$avoidPrompt

$commonRules
""";

    final promptAptitude = """
Generate exactly 10 UNIQUE TNPSC Aptitude MCQs.

Topics:
- HCF & LCM
- Ratio & Proportion
- Percentage
- Simple & Compound Interest
- Time & Work
- Area & Volume
- Logical Reasoning

Each question must require calculation.

$avoidPrompt

$commonRules
""";

    // --------------------------------------------------------------------
    List<dynamic> allQuestions = [];

    // 1️⃣ Tamil questions
    print("AI_DEBUG: Generating 25 Tamil Questions...");
    final resTamil = await _generateWithFallback(promptTamil);
    if (resTamil != null) {
      try {
        List<dynamic> tamilQuestions = jsonDecode(resTamil);
        if (tamilQuestions.length > 25)
          tamilQuestions = tamilQuestions.sublist(0, 25);
        if (tamilQuestions.length == 25) {
          allQuestions.addAll(
            tamilQuestions.map((q) => {...q, 'quiz_type': 'general_tamil'}),
          );
        }
      } catch (e) {
        print("AI_DEBUG: Tamil JSON Parse Error: $e");
      }
    }

    // 2️⃣ General Studies
    print("AI_DEBUG: Generating 15 GS Questions...");
    final resGS = await _generateWithFallback(promptGS);
    if (resGS != null) {
      try {
        List<dynamic> gsQuestions = jsonDecode(resGS);
        if (gsQuestions.length > 15) gsQuestions = gsQuestions.sublist(0, 15);
        if (gsQuestions.length == 15) {
          allQuestions.addAll(
            gsQuestions.map((q) => {...q, 'quiz_type': 'general_studies'}),
          );
        }
      } catch (e) {
        print("AI_DEBUG: GS JSON Parse Error: $e");
      }
    }

    // 3️⃣ Aptitude
    print("AI_DEBUG: Generating 10 Aptitude Questions...");
    final resAptitude = await _generateWithFallback(promptAptitude);
    if (resAptitude != null) {
      try {
        List<dynamic> aptitudeQuestions = jsonDecode(resAptitude);
        if (aptitudeQuestions.length > 10)
          aptitudeQuestions = aptitudeQuestions.sublist(0, 10);
        if (aptitudeQuestions.length == 10) {
          allQuestions.addAll(
            aptitudeQuestions.map((q) => {...q, 'quiz_type': 'aptitude'}),
          );
        }
      } catch (e) {
        print("AI_DEBUG: Aptitude JSON Parse Error: $e");
      }
    }

    // --------------------------------------------------------------------
    if (allQuestions.length == 50) {
      // Final check for 50 questions total
      final querySnapshot = await FirebaseFirestore.instance
          .collection('mock_tests')
          .where('date', isEqualTo: dateStr)
          .where('type', isEqualTo: 'daily_quiz')
          .where('quizType', isEqualTo: 'daily_50_quiz')
          .get();

      final quizData = {
        'date': dateStr,
        'title': "Daily Mock Quiz / தினசரி மாதிரி வினாடி வினா",
        'quizType': 'daily_50_quiz',
        'quiz_type': 'tamil_gs_aptitude',
        'questions': allQuestions,
        'type': 'daily_quiz',
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (querySnapshot.docs.isNotEmpty) {
        await querySnapshot.docs.first.reference.set(
          quizData,
          SetOptions(merge: true),
        );
      } else {
        await FirebaseFirestore.instance.collection('mock_tests').add(quizData);
      }
      return true;
    }
    return false;
  }

  // -----------------------------------------------------------------
  // Room specific pre-defined quiz generation
  // -----------------------------------------------------------------
  static Future<bool> generateAndSaveRoomPredefinedQuiz(String subject) async {
    String specializedPrompt = "";

    if (subject == 'general_tamil') {
      specializedPrompt = '''
Generate 20 UNIQUE TNPSC General Tamil (பொதுத்தமிழ்) MCQs (SSLC Standard). 
Cover Part A: Grammar (இலக்கணம்), Part B: Literature (இலக்கியம்), and Part C: Tamil Scholars.
STRICT LANGUAGE REQUIREMENTS:
1. USE ONLY Pure Tamil and Pure English. NO MIXED LANGUAGE.
2. NO OTHER LANGUAGES (No Hindi, etc.).
3. Ensure there are NO spelling mistakes.
Format: Question: "English\\nதமிழ்". Options: "English / தமிழ்". Explanation: "English. தமிழ்."
''';
    } else if (subject == 'general_studies') {
      specializedPrompt = '''
Generate 20 UNIQUE TNPSC General Studies (பொது அறிவு) MCQs (SSLC Standard). 
Rotate between Science, History, Geography, Polity, and Economy.
STRICT LANGUAGE REQUIREMENTS:
1. USE ONLY Pure Tamil and Pure English. NO MIXED LANGUAGE.
2. NO OTHER LANGUAGES (No Hindi, etc.).
3. Ensure there are NO spelling mistakes.
Format: Question: "English\\nதமிழ்". Options: "English / தமிழ்". Explanation: "English. தமிழ்."
''';
    } else if (subject == 'aptitude') {
      specializedPrompt = '''
Generate 20 UNIQUE TNPSC Aptitude and Mental Ability MCQs (SSLC Standard). 
Cover Simplification, Percentage, HCF/LCM, Ratio, Interest, Area, Volume, Time and Work.
CRITICAL INSTRUCTIONS:
1. Double-check the 'correctOptionIndex' (0, 1, 2, or 3).
2. USE ONLY Pure Tamil and Pure English. NO MIXED LANGUAGE. NO OTHER LANGUAGES (Hindi, etc.).
Format: Question: "English\\nதமிழ்". Options: "English / தமிழ்". Explanation: "English. தமிழ்."
''';
    } else if (subject == 'current_affairs') {
      specializedPrompt = '''
Generate 20 UNIQUE TNPSC Current Affairs (நடப்பு நிகழ்வுகள்) MCQs. 
Focus on important national and international events, awards, sports, and Tamil Nadu specific news from the last 6 months.
STRICT LANGUAGE REQUIREMENTS:
1. USE ONLY Pure Tamil and Pure English. NO MIXED LANGUAGE.
2. NO OTHER LANGUAGES (No Hindi, etc.).
3. Ensure there are NO spelling mistakes.
Format: Question: "English\\nதமிழ்". Options: "English / தமிழ்". Explanation: "English. தமிழ்."
''';
    } else {
      specializedPrompt =
          "Create 20 UNIQUE TNPSC MCQs for '$subject' (Bilingual). STRICT LANGUAGE REQUIREMENTS: 1. USE ONLY Pure Tamil and Pure English. NO MIXED LANGUAGE. 2. NO OTHER LANGUAGES (Hindi, etc.). 3. NO spelling mistakes. Format: Question: 'English\\nதமிழ்'. Options: 'English / தமிழ்'. Explanation: 'English. தமிழ்.'";
    }

    final prompt =
        '''
$specializedPrompt
Strictly use this JSON format: 
[{"question": "English\\nதமிழ்", 
"options": ["English Option 1 / தமிழ் விருப்பம் 1", "English Option 2 / தமிழ் விருப்பம் 2", "English Option 3 / தமிழ் விருப்பம் 3", "English Option 4 / தமிழ் விருப்பம் 4"], 
"correctOptionIndex": 0, 
"explanation": "English explanation. தமிழ் விளக்கம்."}]. 
Only return the raw JSON array, no other text or markdown formatting.
''';

    final res = await _generateWithFallback(prompt);
    if (res != null) {
      try {
        int start = res.indexOf('[');
        int end = res.lastIndexOf(']');
        if (start != -1 && end != -1) {
          List<dynamic> questions = jsonDecode(
            res.substring(start, end + 1),
          );

          if (questions.length < 20) return false;

          final collection = FirebaseFirestore.instance.collection('room_predefined_quizzes');

          // 1. Add new quiz
          await collection.add({
            'subject': subject,
            'questions': questions.map((q) => {...q, 'quiz_type': 'room_quiz'}).toList(),
            'createdAt': FieldValue.serverTimestamp(),
          });

          // 2. Rotation Logic: Keep only latest 500 quizzes
          try {
            final snap = await collection.orderBy('createdAt', descending: true).get();
            if (snap.docs.length > 500) {
              final toDelete = snap.docs.sublist(500);
              final batch = FirebaseFirestore.instance.batch();
              for (var doc in toDelete) {
                batch.delete(doc.reference);
              }
              await batch.commit();
              print("AI_DEBUG: Deleted ${toDelete.length} old room quizzes to maintain 500 limit");
            }
          } catch (e) {
            print("AI_DEBUG: Rotation error: $e");
          }

          return true;
        }
      } catch (e) {
        print("AI_DEBUG: Room Predefined Quiz JSON Parse Error: $e");
      }
    }
    return false;
  }

  // -----------------------------------------------------------------
  // Scheduled quiz generation (used by bulk‑7‑day flow)
  // -----------------------------------------------------------------
  static Future<bool> generateScheduledQuiz(
    DateTime date,
    String quizType, {
    int count = 20,
    int? setIndex,
  }) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    String subjectTitle = "";
    String syllabusPrompt = "";

    if (quizType == 'general_tamil') {
      subjectTitle =
          "General Tamil (SSLC Standard)${setIndex != null ? ' - Set $setIndex' : ''}";
      syllabusPrompt =
          "Part A: Grammar (இலக்கணம்), Part B: Literature (இலக்கியம்), and Part C: Tamil Scholars and Service (தமிழ் அறிஞர்களும் தமிழ்த் தொண்டும்).";
    } else if (quizType == 'general_studies') {
      subjectTitle =
          "General Studies (SSLC Standard)${setIndex != null ? ' - Set $setIndex' : ''}";
      syllabusPrompt =
          "General Science, Current Events, Geography, History and Culture of India, Indian Polity, Indian Economy, and Indian National Movement.";
    } else {
      subjectTitle =
          "Aptitude & Mental Ability Test (SSLC Standard)${setIndex != null ? ' - Set $setIndex' : ''}";
      syllabusPrompt =
          "Simplification, Percentage, HCF & LCM, Ratio and Proportion, Simple Interest, Compound Interest, Area, Volume, Time and Work, and Logical Reasoning/Puzzles.";
    }

    final prompt =
        '''
Generate EXACTLY $count TNPSC MCQs for the subject '$subjectTitle' based on the syllabus: $syllabusPrompt.
STRICT LANGUAGE REQUIREMENTS:
1. USE ONLY Pure Tamil and Pure English. NO MIXED LANGUAGE.
2. NO OTHER LANGUAGES: Strictly DO NOT include Hindi, Malayalam, or others.
3. Ensure there are NO spelling mistakes.
4. Each question MUST be bilingual. Format: "English question text\\nதமிழ் வினா". 
5. Each option MUST contain both English and Tamil text separated by a slash ( / ). Format: "English Option / தமிழ் விருப்பம்". 
6. Each explanation MUST be bilingual. Format: "English explanation. தமிழ் விளக்கம்."
Strictly use this JSON format: 
[{"question": "English question text\\nதமிழ் வினா", 
"options": ["English Option 1 / தமிழ் விருப்பம் 1", "English Option 2 / தமிழ் விருப்பம் 2", "English Option 3 / தமிழ் விருப்பம் 3", "English Option 4 / தமிழ் விருப்பம் 4"], 
"correctOptionIndex": 0, 
"explanation": "English explanation. தமிழ் விளக்கம்."}]. 
Return only the raw JSON array of EXACTLY $count items.
''';

    final res = await _generateWithFallback(prompt);
    if (res != null) {
      try {
        int start = res.indexOf('[');
        int end = res.lastIndexOf(']');
        if (start != -1 && end != -1) {
          List<dynamic> allQuestions = jsonDecode(
            res.substring(start, end + 1),
          );

          // STRICT VALIDATION: Ensure exactly 'count' questions
          if (allQuestions.length != count) {
            print(
              "AI_DEBUG: Count mismatch. Got ${allQuestions.length}, expected $count. Retrying logic...",
            );
            // If too many, trim. If too few, this attempt failed.
            if (allQuestions.length > count) {
              allQuestions = allQuestions.sublist(0, count);
            } else {
              return false;
            }
          }

          final querySnapshot = await FirebaseFirestore.instance
              .collection('quizzes')
              .where('date', isEqualTo: dateStr)
              .where('quiz_type', isEqualTo: quizType)
              .where('set_index', isEqualTo: setIndex)
              .get();

          final quizData = {
            'date': dateStr,
            'title': subjectTitle,
            'quiz_type': quizType,
            'quizType': quizType,
            'set_index': setIndex,
            'questions': allQuestions
                .map((q) => {...q, 'quiz_type': quizType})
                .toList(),
            'type': 'daily_quiz',
            'createdAt': FieldValue.serverTimestamp(),
          };

          if (querySnapshot.docs.isNotEmpty) {
            await querySnapshot.docs.first.reference.set(
              quizData,
              SetOptions(merge: true),
            );
          } else {
            await FirebaseFirestore.instance
                .collection('quizzes')
                .add(quizData);
          }
          return true;
        }
      } catch (e) {
        print("AI_DEBUG: JSON Parse Error: $e");
      }
    }
    return false;
  }

  // -----------------------------------------------------------------
  // Additional helper methods (subject questions, study material, chats, etc.)
  // -----------------------------------------------------------------
  static Future<bool> generateSubjectQuestions(
    String subject, {
    String? category,
  }) async {
    String specializedPrompt = "";

    if (subject == 'general_tamil') {
      specializedPrompt = '''
Generate 20 UNIQUE TNPSC General Tamil (பொதுத்தமிழ்) MCQs (SSLC Standard). 
Cover Part A: Grammar (இலக்கணம்), Part B: Literature (இலக்கியம்), and Part C: Tamil Scholars.
STRICT LANGUAGE REQUIREMENTS:
1. USE ONLY Pure Tamil and Pure English. NO MIXED LANGUAGE.
2. NO OTHER LANGUAGES (No Hindi, etc.).
3. Ensure there are NO spelling mistakes.
Format: Question: "English\\nதமிழ்". Options: "English / தமிழ்". Explanation: "English. தமிழ்."
''';
    } else if (subject == 'general_studies') {
      specializedPrompt = '''
Generate 20 UNIQUE TNPSC General Studies (பொது அறிவு) MCQs (SSLC Standard). 
Rotate between Science, History, Geography, Polity, and Economy.
STRICT LANGUAGE REQUIREMENTS:
1. USE ONLY Pure Tamil and Pure English. NO MIXED LANGUAGE.
2. NO OTHER LANGUAGES (No Hindi, etc.).
3. Ensure there are NO spelling mistakes.
Format: Question: "English\\nதமிழ்". Options: "English / தமிழ்". Explanation: "English. தமிழ்."
''';
    } else if (subject == 'aptitude') {
      specializedPrompt = '''
Generate 20 UNIQUE TNPSC Aptitude and Mental Ability MCQs (SSLC Standard). 
Cover Simplification, Percentage, HCF/LCM, Ratio, Interest, Area, Volume, Time and Work.
CRITICAL INSTRUCTIONS:
1. Double-check the 'correctOptionIndex' (0, 1, 2, or 3).
2. USE ONLY Pure Tamil and Pure English. NO MIXED LANGUAGE. NO OTHER LANGUAGES (Hindi, etc.).
Format: Question: "English\\nதமிழ்". Options: "English / தமிழ்". Explanation: "English. தமிழ்."
''';
    } else if (subject == 'current_affairs') {
      specializedPrompt = '''
Generate 20 UNIQUE TNPSC Current Affairs (நடப்பு நிகழ்வுகள்) MCQs. 
Focus on important national and international events, awards, sports, and Tamil Nadu specific news from the last 6 months.
STRICT LANGUAGE REQUIREMENTS:
1. USE ONLY Pure Tamil and Pure English. NO MIXED LANGUAGE.
2. NO OTHER LANGUAGES (No Hindi, etc.).
3. Ensure there are NO spelling mistakes.
Format: Question: "English\\nதமிழ்". Options: "English / தமிழ்". Explanation: "English. தமிழ்."
''';
    } else {
      specializedPrompt =
          "Create 25 UNIQUE TNPSC MCQs for '$subject' (Bilingual). STRICT LANGUAGE REQUIREMENTS: 1. USE ONLY Pure Tamil and Pure English. NO MIXED LANGUAGE. 2. NO OTHER LANGUAGES (Hindi, etc.). 3. NO spelling mistakes. Format: Question: 'English\\nதமிழ்'. Options: 'English / தமிழ்'. Explanation: 'English. தமிழ்.'";
    }

    final prompt =
        '''
$specializedPrompt
Strictly use this JSON format: 
[{"question": "English\\nதமிழ்", 
"options": ["English Option 1 / தமிழ் விருப்பம் 1", "English Option 2 / தமிழ் விருப்பம் 2", "English Option 3 / தமிழ் விருப்பம் 3", "English Option 4 / தமிழ் விருப்பம் 4"], 
"correctOptionIndex": 0, 
"explanation": "English explanation. தமிழ் விளக்கம்."}]. 
Only return the raw JSON array, no other text or markdown formatting.
''';

    final res = await _generateWithFallback(prompt);
    if (res != null) {
      try {
        int start = res.indexOf('[');
        int end = res.lastIndexOf(']');
        if (start != -1 && end != -1) {
          List<dynamic> newQuestions = jsonDecode(
            res.substring(start, end + 1),
          );
          newQuestions = newQuestions
              .map((q) => {...q, 'quiz_type': 'subject_question'})
              .toList();

          String safeId = subject.trim().replaceAll('/', '-');
          final docRef = FirebaseFirestore.instance
              .collection('subject_questions')
              .doc(safeId);
          final doc = await docRef.get();

          List<dynamic> existingQuestions = [];
          if (doc.exists) {
            existingQuestions = doc.get('questions') ?? [];
          }

          Set<String> existingTexts = existingQuestions
              .map((e) => (e['question'] ?? "").toString().trim())
              .toSet();
          List<dynamic> uniqueNew = newQuestions.where((item) {
            String text = (item['question'] ?? "").toString().trim();
            return text.isNotEmpty && !existingTexts.contains(text);
          }).toList();

          if (uniqueNew.isEmpty) return true;

          List<dynamic> finalQuestions = [...existingQuestions, ...uniqueNew];
          await docRef.set({
            'subject': subject,
            'questions': finalQuestions,
            'lastUpdated': FieldValue.serverTimestamp(),
            'category': category,
          }, SetOptions(merge: true));
          return true;
        }
      } catch (e) {
        print("AI_DEBUG: JSON Parse Error for $subject: $e");
      }
    }
    return false;
  }

  static Future<bool> generateStudyMaterial(
    String subject, {
    String? category,
  }) async {
    final prompt =
        "Create 25 structured TNPSC study points for '$subject'. STRICT LANGUAGE REQUIREMENTS: 1. USE ONLY Pure Tamil and Pure English. NO MIXED LANGUAGE. 2. NO OTHER LANGUAGES (Hindi, etc.). 3. NO spelling mistakes. Use this JSON format: [{\"id\": 1, \"tamil\": \"...\", \"english\": \"...\"}]. Only return the JSON array.";
    final res = await _generateWithFallback(prompt);
    if (res != null) {
      try {
        int start = res.indexOf('[');
        int end = res.lastIndexOf(']');
        if (start != -1 && end != -1) {
          List<dynamic> newMaterial = jsonDecode(res.substring(start, end + 1));
          String safeId = subject.trim().replaceAll('/', '-');
          final docRef = FirebaseFirestore.instance
              .collection('subject_study_material')
              .doc(safeId);
          final doc = await docRef.get();

          List<dynamic> existingMaterial = [];
          if (doc.exists) {
            existingMaterial = doc.get('material') ?? [];
          }

          Set<String> existingTexts = existingMaterial
              .map((e) => (e['tamil'] ?? "").toString().trim())
              .toSet();
          List<dynamic> uniqueNew = newMaterial.where((item) {
            String text = (item['tamil'] ?? "").toString().trim();
            return text.isNotEmpty && !existingTexts.contains(text);
          }).toList();

          if (uniqueNew.isEmpty) return true;

          List<dynamic> finalMaterial = [...existingMaterial, ...uniqueNew];
          for (int i = 0; i < finalMaterial.length; i++) {
            finalMaterial[i]['id'] = i + 1;
          }

          await docRef.set({
            'subject': subject,
            'category': category,
            'material': finalMaterial,
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          return true;
        }
      } catch (e) {
        print("AI_DEBUG: Study Material Parse Error: $e");
      }
    }
    return false;
  }

  // Simple chat helpers ------------------------------------------------
  static Future<String?> chatWithAppContext(
    String message,
    String context,
  ) async {
    final prompt =
        "TNPSC Tutor context search: $context. Question: $message. STRICT LANGUAGE REQUIREMENTS: 1. USE ONLY Pure Tamil and Pure English. NO MIXED LANGUAGE. 2. NO OTHER LANGUAGES (Hindi, etc.). 3. NO spelling mistakes. Bilingual output required.";
    return await _generateWithFallback(prompt);
  }

  static Future<String?> chatWithAi(String message) async {
    final prompt = "TNPSC Doubt: $message. STRICT LANGUAGE REQUIREMENTS: 1. USE ONLY Pure Tamil and Pure English. NO MIXED LANGUAGE. 2. NO OTHER LANGUAGES (Hindi, etc.). 3. NO spelling mistakes. Answer in Pure Tamil & Pure English (Bilingual).";
    return await _generateWithFallback(prompt);
  }

  static Future<String> explainQuestion(
    String question,
    List<String> options,
    String correctAnswer,
  ) async {
    final prompt =
        "Explain TNPSC question: $question. Answer: $correctAnswer. STRICT LANGUAGE REQUIREMENTS: 1. USE ONLY Pure Tamil and Pure English. NO MIXED LANGUAGE. 2. NO OTHER LANGUAGES (Hindi, etc.). 3. NO spelling mistakes. Provide bilingual explanation.";
    final res = await _generateWithFallback(prompt);
    return res ?? "Explanation unavailable.";
  }

  static Future<String> generateStructuredStudyMaterial(String topic) async {
    final prompt = "Generate TNPSC study guide for '$topic'. STRICT LANGUAGE REQUIREMENTS: 1. USE ONLY Pure Tamil and Pure English. NO MIXED LANGUAGE. 2. NO OTHER LANGUAGES (Hindi, etc.). 3. NO spelling mistakes. Bilingual.";
    final res = await _generateWithFallback(prompt);
    return res ?? "Guide unavailable.";
  }

  static Future<List<dynamic>> generateCustomQuiz(String topic) async {
    final prompt =
        '''
Generate 20 TNPSC MCQs for '$topic' in both Pure Tamil and Pure English (Bilingual). 
CRITICAL INSTRUCTIONS:
1. Ensure the 'correctOptionIndex' (0-3) EXACTLY points to the correct answer in the 'options' list. 
2. For Math/Aptitude, double-check your calculations.
3. USE ONLY Pure Tamil and Pure English. NO MIXED LANGUAGE. NO OTHER LANGUAGES (Hindi, etc.).
4. Each question MUST be bilingual. Format: "English question\\nதமிழ் வினா". 
5. Each option MUST contain both English and Tamil text separated by a slash ( / ). Format: "English Option / தமிழ் விருப்பம்". 
6. Each explanation MUST be bilingual. Format: "English explanation. தமிழ் விளக்கம்."
Strictly use this JSON format: 
[{"question": "English question\\nதமிழ் வினா", 
"options": ["English Option 1 / தமிழ் விருப்பம் 1", "English Option 2 / தமிழ் விருப்பம் 2", "English Option 3 / தமிழ் விருப்பம் 3", "English Option 4 / தமிழ் விருப்பம் 4"], 
"correctOptionIndex": 0, 
"explanation": "English explanation. தமிழ் விளக்கம்."}].
Only return the raw JSON array, no other text or markdown formatting.
''';
    final res = await _generateWithFallback(prompt);
    if (res != null) {
      try {
        int start = res.indexOf('[');
        int end = res.lastIndexOf(']');
        if (start != -1 && end != -1)
          return jsonDecode(res.substring(start, end + 1));
      } catch (e) {}
    }
    return [];
  }
}
