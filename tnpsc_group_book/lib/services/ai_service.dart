import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:http/http.dart' as http;

class AiService {
  static String? _cachedApiKey;

  // -----------------------------------------------------------------
  // API key handling (Remote Config)
  // -----------------------------------------------------------------
  static Future<String> _getApiKey() async {
    if (_cachedApiKey != null && _cachedApiKey!.isNotEmpty) {
      return _cachedApiKey!;
    }
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(minutes: 1),
          minimumFetchInterval: Duration.zero,
        ),
      );
      await remoteConfig.fetchAndActivate();
      _cachedApiKey = remoteConfig.getString('gemini_api_key');
      if (_cachedApiKey != null && _cachedApiKey!.length > 10) {
        print(
          "AI_DEBUG: Key picked: " +
              _cachedApiKey!.substring(0, 5) +
              "..." +
              _cachedApiKey!.substring(_cachedApiKey!.length - 5),
        );
      }
      return _cachedApiKey!;
    } catch (e) {
      print("AI_DEBUG: Remote Config Error: $e");
      return "";
    }
  }

  // -----------------------------------------------------------------
  // Core request helper – discovers models, falls back, and returns raw text
  // -----------------------------------------------------------------
  static Future<String?> _generateWithFallback(String prompt) async {
    final apiKey = await _getApiKey();
    if (apiKey.isEmpty) return null;

    // 1. Discover available models
    List<String> discoveredModels = [];
    try {
      print("AI_DEBUG: Discovering available models...");
      final listUrl = Uri.parse(
        'https://generativelanguage.googleapis.com/v1/models?key=$apiKey',
      );
      final listRes = await http
          .get(listUrl)
          .timeout(const Duration(seconds: 10));
      if (listRes.statusCode == 200) {
        final listData = jsonDecode(listRes.body);
        for (var m in listData['models']) {
          String mName = m['name'].toString().replaceFirst('models/', '');
          if (m['supportedGenerationMethods'].contains('generateContent')) {
            discoveredModels.add(mName);
          }
        }
        print(
          "AI_DEBUG: Discovered ${discoveredModels.length} models: $discoveredModels",
        );
      }
    } catch (e) {
      print("AI_DEBUG: Discovery failed: $e");
    }

    // 2. Fallback defaults if discovery failed
    if (discoveredModels.isEmpty) {
      discoveredModels = ['gemini-1.5-flash', 'gemini-pro'];
    }

    // 3. Try each model (v1 then v1beta)
    for (String version in ['v1', 'v1beta']) {
      for (String modelName in discoveredModels) {
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
                    'temperature': 0.7,
                  },
                }),
              )
              .timeout(const Duration(seconds: 45));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final text = data['candidates'][0]['content']['parts'][0]['text'];
            if (text != null) {
              print("AI_DEBUG: REST SUCCESS with $modelName on $version");
              return text;
            }
          } else {
            print(
              "AI_DEBUG: REST FAIL ($version/$modelName) - Status: " +
                  response.statusCode.toString() +
                  ", Body: " +
                  response.body,
            );
          }
        } catch (e) {
          print("AI_DEBUG: REST Error ($version/$modelName): $e");
        }
      }
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
        ? "\nSTRICTLY DO NOT REPEAT these recent questions or specific topics from the last 30 days: $recentContext"
        : "";

    // Prompt definitions ------------------------------------------------
    final promptTamil =
        '''
Generate 10 UNIQUE TNPSC General Tamil MCQs (SSLC Standard). 
Focus on different chapters of Samacheer Kalvi books. $avoidPrompt
STRICT BILINGUAL & QUALITY REQUIREMENTS:
1. EVERY FIELD (question, each option, and explanation) MUST contain BOTH Pure Tamil and Pure English.
2. NO MIXED LANGUAGE: English sentences must be 100% English. Tamil sentences must be 100% Tamil.
3. NO OTHER LANGUAGES: Strictly DO NOT include Hindi, etc.
4. Each question MUST follow format: "English question text\\nதமிழ் வினா". 
5. Each option MUST follow format: "English Option / தமிழ் விருப்பம்". 
6. Each explanation MUST follow format: "English explanation. தமிழ் விளக்கம்."
7. Ensure exactly 10 questions are returned.
Strictly use JSON format: [{"question": "...", "options": ["...", "...", "...", "..."], "correctOptionIndex": 0, "explanation": "..."}].
''';

    final promptGS =
        '''
Generate 6 UNIQUE TNPSC General Studies MCQs (SSLC Standard). 
Rotate between Science, History, Polity, and Economy. $avoidPrompt
STRICT BILINGUAL & QUALITY REQUIREMENTS:
1. EVERY FIELD (question, each option, and explanation) MUST contain BOTH Pure Tamil and Pure English.
2. NO MIXED LANGUAGE: English sentences must be 100% English. Tamil sentences must be 100% Tamil.
3. NO OTHER LANGUAGES: Strictly DO NOT include Hindi, etc.
4. Format: Question: "English question\\nதமிழ் வினா". Options: "English Option / தமிழ் விருப்பம்". Explanation: "English explanation. தமிழ் விளக்கம்."
5. Ensure exactly 6 questions are returned.
Strictly use JSON format: [{"question": "...", "options": ["...", "...", "...", "..."], "correctOptionIndex": 0, "explanation": "..."}].
''';

    final promptAptitude =
        '''
Generate 4 UNIQUE TNPSC Aptitude MCQs (SSLC Standard). 
Topics: HCF/LCM, Ratio, Time & Work, Interest, or Mensuration. $avoidPrompt
STRICT BILINGUAL & QUALITY REQUIREMENTS:
1. EVERY FIELD (question, each option, and explanation) MUST contain BOTH Pure Tamil and Pure English.
2. Ensure the 'correctOptionIndex' (0-3) EXACTLY points to the correct answer. 
3. USE ONLY Pure Tamil and Pure English. NO MIXED LANGUAGE. NO OTHER LANGUAGES.
4. Each question MUST follow format: "English question\\nதமிழ் வினா". Options: "English Option / தமிழ் விருப்பம்". Explanation: "English explanation. தமிழ் விளக்கம்."
5. Ensure exactly 4 questions are returned.
Strictly use JSON format: [{"question": "...", "options": ["...", "...", "...", "..."], "correctOptionIndex": 0, "explanation": "..."}].
''';

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
        int start = res.indexOf('[');
        int end = res.lastIndexOf(']');
        if (start != -1 && end != -1) {
          List q = jsonDecode(res.substring(start, end + 1));

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
        ? "\nSTRICTLY DO NOT REPEAT these recent questions or specific topics from the last 30 days: $recentContext"
        : "";

    // Prompt definitions ------------------------------------------------
    final promptTamil =
        '''
Generate 25 UNIQUE TNPSC General Tamil MCQs (SSLC Standard). 
Cover Grammar, Literature, and Tamil Scholars. $avoidPrompt
STRICT BILINGUAL REQUIREMENTS:
1. EVERY field (question, options, explanation) MUST contain BOTH Pure Tamil and Pure English.
2. NO MIXED LANGUAGE. NO OTHER LANGUAGES (Hindi, etc.).
3. Format: Question: "English question\\nதமிழ் வினா". Options: "English Option / தமிழ் விருப்பம்". Explanation: "English explanation. தமிழ் விளக்கம்."
Strictly use JSON format: [{"question": "...", "options": ["...", "...", "...", "..."], "correctOptionIndex": 0, "explanation": "..."}].
''';

    final promptGS =
        '''
Generate 15 UNIQUE TNPSC General Studies MCQs (SSLC Standard). 
Cover Science, History, Geography, Polity, and Economy. $avoidPrompt
STRICT BILINGUAL REQUIREMENTS:
1. EVERY field (question, options, explanation) MUST contain BOTH Pure Tamil and Pure English.
2. NO MIXED LANGUAGE. NO OTHER LANGUAGES (Hindi, etc.).
3. Format: Question: "English question\\nதமிழ் வினா". Options: "English Option / தமிழ் விருப்பம்". Explanation: "English explanation. தமிழ் விளக்கம்."
Strictly use JSON format: [{"question": "...", "options": ["...", "...", "...", "..."], "correctOptionIndex": 0, "explanation": "..."}].
''';

    final promptAptitude =
        '''
Generate 10 UNIQUE TNPSC Aptitude MCQs (SSLC Standard). 
Cover HCF/LCM, Ratio, Time & Work, Interest, Mensuration, and Reasoning. $avoidPrompt
STRICT BILINGUAL REQUIREMENTS:
1. EVERY field (question, options, explanation) MUST contain BOTH Pure Tamil and Pure English.
2. Ensure the 'correctOptionIndex' (0-3) is correct.
3. USE ONLY Pure Tamil and Pure English. NO MIXED LANGUAGE. NO OTHER LANGUAGES.
4. Format: Question: "English question\\nதமிழ் வினா". Options: "English Option / தமிழ் விருப்பம்". Explanation: "English explanation. தமிழ் விளக்கம்."
Strictly use JSON format: [{"question": "...", "options": ["...", "...", "...", "..."], "correctOptionIndex": 0, "explanation": "..."}].
''';

    // --------------------------------------------------------------------
    List<dynamic> allQuestions = [];

    // 1️⃣ Tamil questions
    print("AI_DEBUG: Generating 25 Tamil Questions...");
    final resTamil = await _generateWithFallback(promptTamil);
    if (resTamil != null) {
      try {
        int start = resTamil.indexOf('[');
        int end = resTamil.lastIndexOf(']');
        if (start != -1 && end != -1) {
          List<dynamic> tamilQuestions = jsonDecode(
            resTamil.substring(start, end + 1),
          );
          if (tamilQuestions.length > 25)
            tamilQuestions = tamilQuestions.sublist(0, 25);
          if (tamilQuestions.length == 25) {
            allQuestions.addAll(
              tamilQuestions.map((q) => {...q, 'quiz_type': 'general_tamil'}),
            );
          }
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
        int start = resGS.indexOf('[');
        int end = resGS.lastIndexOf(']');
        if (start != -1 && end != -1) {
          List<dynamic> gsQuestions = jsonDecode(
            resGS.substring(start, end + 1),
          );
          if (gsQuestions.length > 15) gsQuestions = gsQuestions.sublist(0, 15);
          if (gsQuestions.length == 15) {
            allQuestions.addAll(
              gsQuestions.map((q) => {...q, 'quiz_type': 'general_studies'}),
            );
          }
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
        int start = resAptitude.indexOf('[');
        int end = resAptitude.lastIndexOf(']');
        if (start != -1 && end != -1) {
          List<dynamic> aptitudeQuestions = jsonDecode(
            resAptitude.substring(start, end + 1),
          );
          if (aptitudeQuestions.length > 10)
            aptitudeQuestions = aptitudeQuestions.sublist(0, 10);
          if (aptitudeQuestions.length == 10) {
            allQuestions.addAll(
              aptitudeQuestions.map((q) => {...q, 'quiz_type': 'aptitude'}),
            );
          }
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
