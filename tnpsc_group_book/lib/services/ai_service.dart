import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:http/http.dart' as http;

class AiService {
  static List<String>? _cachedApiKeys;
  static List<String>? _cachedPreferredModels;

  static bool _isFetchingConfig = false;

  // -----------------------------------------------------------------
  // Remote Config fetcher for API key and Model Priority
  // -----------------------------------------------------------------
  static Future<void> _fetchRemoteConfig() async {
    if (_isFetchingConfig) return;
    _isFetchingConfig = true;
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
    } finally {
      _isFetchingConfig = false;
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
    
    // AI_DEBUG: Whitelist of stable models that are known to work
    const whitelist = [
      'gemini-2.5-flash',
      'gemini-2.5-flash-lite',
      'gemini-2.0-flash',
      'gemini-1.5-flash',
      'gemini-1.5-pro',
      'gemini-pro',
    ];

    if (_cachedPreferredModels != null && _cachedPreferredModels!.isNotEmpty) {
      // Filter Remote Config models against our whitelist
      List<String> filtered = _cachedPreferredModels!
          .where((m) => whitelist.contains(m.toLowerCase().trim()))
          .toList();
      
      if (filtered.isNotEmpty) return filtered;
    }

    // Default stable list if Remote Config is empty or invalid
    return [
      'gemini-2.5-flash',
      'gemini-2.5-flash-lite',
      'gemini-2.0-flash',
      'gemini-1.5-flash',
      'gemini-1.5-pro',
      'gemini-pro',
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

      // AI_DEBUG: ONLY try models that are BOTH discovered AND in our preferred/whitelist
      // This prevents trying experimental/invalid models that cause 400 errors
      for (var p in preferredModels) {
        if (discoveredModels.contains(p)) {
          finalModelsToTry.add(p);
        }
      }

      // Final fallback if none of our preferred models were discovered on this key
      if (finalModelsToTry.isEmpty) {
        if (discoveredModels.contains('gemini-1.5-flash')) finalModelsToTry.add('gemini-1.5-flash');
        else if (discoveredModels.contains('gemini-pro')) finalModelsToTry.add('gemini-pro');
      }

      if (finalModelsToTry.isEmpty) {
        finalModelsToTry = ['gemini-1.5-flash', 'gemini-pro'];
      }

      print("AI_DEBUG: Trying restricted stable models: $finalModelsToTry");

      // 3. Try each model (v1beta then v1)
      bool keyFailed = false;
      for (String version in ['v1beta', 'v1']) { // Try v1beta first for newer models
        if (keyFailed) break;
        for (String modelName in finalModelsToTry) {
          int retries = 0;
          const int maxRetries = 2;

          while (retries <= maxRetries) {
            try {
              print("AI_DEBUG: REST Call - Trying $modelName on $version (Attempt ${retries + 1})...");
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
                if (candidate['finishReason'] != 'STOP') {
                   print("AI_DEBUG: Model finished with reason: ${candidate['finishReason']}");
                   break; // Try next model
                }

                String? text = candidate['content']['parts'][0]['text'];
                if (text != null) {
                  text = text.trim();
                  // Improved JSON extraction using regex to handle potential markdown or extra text
                  final jsonRegex = RegExp(r'\[.*\]|\{.*\}', dotAll: true);
                  final match = jsonRegex.stringMatch(text);
                  if (match != null) {
                    text = match.trim();
                  }

                  try {
                    jsonDecode(text);
                    return text;
                  } catch (e) {
                    print("AI_DEBUG: JSON Decode failed for: ${text.substring(0, text.length > 50 ? 50 : text.length)}...");
                    break; // Try next model
                  }
                }
              } else if (response.statusCode == 429) {
                print("AI_DEBUG: Rate limit reached (429). Retrying after backoff...");
                await Future.delayed(Duration(seconds: 2 * (retries + 1)));
                retries++;
                continue; 
              } else if (response.statusCode == 403) {
                print("AI_DEBUG: Key invalid or permission denied (403). Switching key...");
                keyFailed = true;
                break;
              } else if (response.statusCode == 503 || response.statusCode == 500) {
                print("AI_DEBUG: Server error (${response.statusCode}). Retrying...");
                await Future.delayed(Duration(seconds: 1 * (retries + 1)));
                retries++;
                continue;
              } else {
                print("AI_DEBUG: REST FAIL - Status: ${response.statusCode}");
                break; // Try next model
              }
            } catch (e) {
              print("AI_DEBUG: REST Error: $e");
              break; // Try next model
            }
          }
          if (keyFailed) break;
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
8. EVERY field MUST BE BILINGUAL (Separate English and Tamil keys).
9. English must be natural and error-free.
10. Tamil must use proper literary Tamil without spelling mistakes.
11. Do NOT mix Tamil and English in the same sentence.
12. Do NOT use Hindi or any other language.
13. Every question must have exactly four options.
14. Only ONE option must be correct.
15. Verify the correct answer before assigning correctOptionIndex.
16. correctOptionIndex MUST exactly match the correct option (0-3).
17. Explanation must clearly justify why the answer is correct.
18. MANDATORY BILINGUAL FORMAT (STRICT):
    - "question_en": "English question text"
    - "question_ta": "தமிழ் வினா உரை"
    - "options": [{"en": "English Option", "ta": "தமிழ் விருப்பம்"}, ...] (List of 4 objects)
    - "explanation_en": "English explanation text"
    - "explanation_ta": "தமிழ் விளக்க உரை"
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
- BILINGUAL REQUIREMENT: Does every field have both English and Tamil?
- Grammar accuracy (Tamil & English)
- No duplicate questions or patterns
- No duplicate options
- Correctness of correctOptionIndex
- Step-by-step math accuracy (for Aptitude)
- Explanation clarity and accuracy

Output Format:

[
  {
    "question_en":"...",
    "question_ta":"...",
    "options":[
      {"en": "...", "ta": "..."},
      {"en": "...", "ta": "..."},
      {"en": "...", "ta": "..."},
      {"en": "...", "ta": "..."}
    ],
    "correctOptionIndex":0,
    "explanation_en":"...",
    "explanation_ta":"..."
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
8. EVERY field MUST BE BILINGUAL (Separate English and Tamil keys).
9. English must be natural and error-free.
10. Tamil must use proper literary Tamil without spelling mistakes.
11. Do NOT mix Tamil and English in the same sentence.
12. Do NOT use Hindi or any other language.
13. Every question must have exactly four options.
14. Only ONE option must be correct.
15. Verify the correct answer before assigning correctOptionIndex.
16. correctOptionIndex MUST exactly match the correct option (0-3).
17. Explanation must clearly justify why the answer is correct.
18. MANDATORY BILINGUAL FORMAT (STRICT):
    - "question_en": "English question text"
    - "question_ta": "தமிழ் வினா உரை"
    - "options": [{"en": "English Option", "ta": "தமிழ் விருப்பம்"}, ...] (List of 4 objects)
    - "explanation_en": "English explanation text"
    - "explanation_ta": "தமிழ் விளக்க உரை"
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
- BILINGUAL REQUIREMENT: Does every field have both English and Tamil?
- Grammar accuracy (Tamil & English)
- No duplicate questions or patterns
- No duplicate options
- Correctness of correctOptionIndex
- Step-by-step math accuracy (for Aptitude)
- Explanation clarity and accuracy

Output Format:

[
  {
    "question_en":"...",
    "question_ta":"...",
    "options":[
      {"en": "...", "ta": "..."},
      {"en": "...", "ta": "..."},
      {"en": "...", "ta": "..."},
      {"en": "...", "ta": "..."}
    ],
    "correctOptionIndex":0,
    "explanation_en":"...",
    "explanation_ta":"..."
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

    // Get topics from last 90 days to avoid repeats in room quizzes
    String recentContext = await _getRecentQuizContext('room_predefined_quizzes', 90);

    final avoidPrompt = recentContext.isNotEmpty
        ? """
STRICTLY DO NOT create questions that are identical, very similar, or based on these recent questions/topics:
$recentContext

Rules:
- Do NOT repeat the same question.
- Do NOT repeat the same concepts or historical facts.
"""
        : "";

    if (subject == 'general_tamil') {
      specializedPrompt = '''
Generate 20 UNIQUE TNPSC General Tamil (பொதுத்தமிழ்) MCQs (SSLC Standard). 
Cover Part A: Grammar (இலக்கணம்), Part B: Literature (இலக்கியம்), and Part C: Tamil Scholars.
STRICT LANGUAGE REQUIREMENTS:
1. USE ONLY Pure Tamil and Pure English. NO MIXED LANGUAGE.
2. NO OTHER LANGUAGES (No Hindi, etc.).
3. Ensure there are NO spelling mistakes.
''';
    } else if (subject == 'general_studies') {
      specializedPrompt = '''
Generate 20 UNIQUE TNPSC General Studies (பொது அறிவு) MCQs (SSLC Standard). 
Rotate between Science, History, Geography, Polity, and Economy.
STRICT LANGUAGE REQUIREMENTS:
1. USE ONLY Pure Tamil and Pure English. NO MIXED LANGUAGE.
2. NO OTHER LANGUAGES (No Hindi, etc.).
3. Ensure there are NO spelling mistakes.
''';
    } else if (subject == 'aptitude') {
      specializedPrompt = '''
Generate 20 UNIQUE TNPSC Aptitude and Mental Ability MCQs (SSLC Standard). 
Cover Simplification, Percentage, HCF/LCM, Ratio, Interest, Area, Volume, Time and Work.
CRITICAL INSTRUCTIONS:
1. Double-check the 'correctOptionIndex' (0, 1, 2, or 3).
2. USE ONLY Pure Tamil and Pure English. NO MIXED LANGUAGE. NO OTHER LANGUAGES (Hindi, etc.).
''';
    } else if (subject == 'current_affairs') {
      specializedPrompt = '''
Generate 20 UNIQUE TNPSC Current Affairs (நடப்பு நிகழ்வுகள்) MCQs. 
Focus on important national and international events, awards, sports, and Tamil Nadu specific news from the last 6 months.
STRICT LANGUAGE REQUIREMENTS:
1. USE ONLY Pure Tamil and Pure English. NO MIXED LANGUAGE.
2. NO OTHER LANGUAGES (No Hindi, etc.).
3. Ensure there are NO spelling mistakes.
''';
    } else {
      specializedPrompt =
          "Create 20 UNIQUE TNPSC MCQs for '$subject' (Bilingual). STRICT LANGUAGE REQUIREMENTS: 1. USE ONLY Pure Tamil and Pure English. NO MIXED LANGUAGE. 2. NO OTHER LANGUAGES (Hindi, etc.). 3. NO spelling mistakes.";
    }

    final prompt =
        '''
$specializedPrompt
$avoidPrompt
Strictly use this BILINGUAL JSON format: 
[{"question_en": "English question text", 
"question_ta": "தமிழ் வினா உரை",
"options": [{"en": "English Option", "ta": "தமிழ் விருப்பம்"}, ...], 
"correctOptionIndex": 0, 
"explanation_en": "English explanation text",
"explanation_ta": "தமிழ் விளக்க உரை"}]. 
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

          final docRef = FirebaseFirestore.instance.collection('room_predefined_quizzes').doc(subject);

          // AI_DEBUG: Sliding Window Logic (Max 1500 questions)
          // 1. Fetch existing pool to maintain size
          final snap = await docRef.get();
          List<dynamic> existingQs = [];
          if (snap.exists) {
            existingQs = List.from(snap.get('questions') ?? []);
          }

          // 2. Prepare new questions
          List<dynamic> sanitizedNewQs = questions.map((q) => {
            ...q, 
            'quiz_type': subject,
            'subject': subject,
            'createdAt': DateTime.now().toIso8601String(), // Changed from serverTimestamp to fix Array error
          }).toList();
          
          // 3. Maintenance: Combine (Prepend new) and trim to latest 500
          // AI_DEBUG: Reduced pool size to 500 to stay under 1MB Firestore limit
          const int maxPoolSize = 500;
          List<dynamic> combinedQs = [...sanitizedNewQs, ...existingQs];
          
          if (combinedQs.length > maxPoolSize) {
            combinedQs = combinedQs.sublist(0, maxPoolSize);
            print("AI_DEBUG: Pool Size Management for $subject. Kept latest 500 questions.");
          }

          // 4. Save back to Firestore
          await docRef.set({
            'subject': subject,
            'questions': combinedQs,
            'lastUpdated': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(), // Added for avoidance context fetch
          }, SetOptions(merge: true));

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
4. Each question MUST be bilingual using separate keys for English and Tamil.
Strictly use this BILINGUAL JSON format: 
[{"question_en": "English question text", 
"question_ta": "தமிழ் வினா உரை",
"options": [{"en": "English Option", "ta": "தமிழ் விருப்பம்"}, ...], 
"correctOptionIndex": 0, 
"explanation_en": "English explanation text",
"explanation_ta": "தமிழ் விளக்க உரை"}]. 
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

    // Get topics from last 90 days to avoid repeats
    String recentContext = await _getRecentQuizContext('subject_questions', 90);

    final avoidPrompt = recentContext.isNotEmpty
        ? """
STRICTLY DO NOT create questions that are identical, very similar, or based on these recent questions/topics:
$recentContext

Rules:
- Do NOT repeat the same question.
- Do NOT repeat the same concepts or historical facts.
"""
        : "";

    if (subject == 'general_tamil') {
      specializedPrompt = '''
Generate 20 UNIQUE TNPSC General Tamil (பொதுத்தமிழ்) MCQs (SSLC Standard). 
Cover Part A: Grammar (இலக்கணம்), Part B: Literature (இலக்கியம்), and Part C: Tamil Scholars.
STRICT LANGUAGE REQUIREMENTS:
1. USE ONLY Pure Tamil and Pure English. NO MIXED LANGUAGE.
2. NO OTHER LANGUAGES (No Hindi, etc.).
3. Ensure there are NO spelling mistakes.
''';
    } else if (subject == 'general_studies') {
      specializedPrompt = '''
Generate 20 UNIQUE TNPSC General Studies (பொது அறிவு) MCQs (SSLC Standard). 
Rotate between Science, History, Geography, Polity, and Economy.
STRICT LANGUAGE REQUIREMENTS:
1. USE ONLY Pure Tamil and Pure English. NO MIXED LANGUAGE.
2. NO OTHER LANGUAGES (No Hindi, etc.).
3. Ensure there are NO spelling mistakes.
''';
    } else if (subject == 'aptitude') {
      specializedPrompt = '''
Generate 20 UNIQUE TNPSC Aptitude and Mental Ability MCQs (SSLC Standard). 
Cover Simplification, Percentage, HCF/LCM, Ratio, Interest, Area, Volume, Time and Work.
CRITICAL INSTRUCTIONS:
1. Double-check the 'correctOptionIndex' (0, 1, 2, or 3).
2. USE ONLY Pure Tamil and Pure English. NO MIXED LANGUAGE. NO OTHER LANGUAGES (Hindi, etc.).
''';
    } else if (subject == 'current_affairs') {
      specializedPrompt = '''
Generate 20 UNIQUE TNPSC Current Affairs (நடப்பு நிகழ்வுகள்) MCQs. 
Focus on important national and international events, awards, sports, and Tamil Nadu specific news from the last 6 months.
STRICT LANGUAGE REQUIREMENTS:
1. USE ONLY Pure Tamil and Pure English. NO MIXED LANGUAGE.
2. NO OTHER LANGUAGES (No Hindi, etc.).
3. Ensure there are NO spelling mistakes.
''';
    } else {
      specializedPrompt =
          "Create 25 UNIQUE TNPSC MCQs for '$subject' (Bilingual). STRICT LANGUAGE REQUIREMENTS: 1. USE ONLY Pure Tamil and Pure English. NO MIXED LANGUAGE. 2. NO OTHER LANGUAGES (Hindi, etc.). 3. NO spelling mistakes.";
    }

    final prompt =
        '''
$specializedPrompt
$avoidPrompt
Strictly use this BILINGUAL JSON format: 
[{"question_en": "English question text", 
"question_ta": "தமிழ் வினா உரை",
"options": [{"en": "English Option", "ta": "தமிழ் விருப்பம்"}, ...], 
"correctOptionIndex": 0, 
"explanation_en": "English explanation text",
"explanation_ta": "தமிழ் விளக்க உரை"}].
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
              .map((e) => (e['question_ta'] ?? "").toString().trim())
              .toSet();
          List<dynamic> uniqueNew = newQuestions.where((item) {
            String text = (item['question_ta'] ?? "").toString().trim();
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
        "Create 25 structured TNPSC study points for '$subject'. STRICT LANGUAGE REQUIREMENTS: 1. USE ONLY Pure Tamil and Pure English. NO MIXED LANGUAGE. 2. NO OTHER LANGUAGES (Hindi, etc.). 3. NO spelling mistakes. Use this BILINGUAL JSON format: [{\"id\": 1, \"ta\": \"...\", \"en\": \"...\"}]. Only return the JSON array.";
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
              .map((e) => (e['ta'] ?? "").toString().trim())
              .toSet();
          List<dynamic> uniqueNew = newMaterial.where((item) {
            String text = (item['ta'] ?? "").toString().trim();
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
4. Each question MUST be bilingual using separate keys for English and Tamil.
Strictly use this BILINGUAL JSON format: 
[{"question_en": "English question text", 
"question_ta": "தமிழ் வினா உரை",
"options": [{"en": "English Option", "ta": "தமிழ் விருப்பம்"}, ...], 
"correctOptionIndex": 0, 
"explanation_en": "English explanation text",
"explanation_ta": "தமிழ் விளக்க உரை"}].
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
