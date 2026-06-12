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
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: Duration.zero,
      ));
      await remoteConfig.fetchAndActivate();
      _cachedApiKey = remoteConfig.getString('gemini_api_key');
      if (_cachedApiKey != null && _cachedApiKey!.length > 10) {
        print("AI_DEBUG: Key picked: "+_cachedApiKey!.substring(0,5)+"..."+_cachedApiKey!.substring(_cachedApiKey!.length-5));
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
      final listUrl = Uri.parse('https://generativelanguage.googleapis.com/v1/models?key=$apiKey');
      final listRes = await http.get(listUrl).timeout(const Duration(seconds: 10));
      if (listRes.statusCode == 200) {
        final listData = jsonDecode(listRes.body);
        for (var m in listData['models']) {
          String mName = m['name'].toString().replaceFirst('models/', '');
          if (m['supportedGenerationMethods'].contains('generateContent')) {
            discoveredModels.add(mName);
          }
        }
        print("AI_DEBUG: Discovered ${discoveredModels.length} models: $discoveredModels");
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
              'https://generativelanguage.googleapis.com/$version/models/$modelName:generateContent?key=$apiKey');

          final response = await http.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {'parts': [{'text': prompt}]}
              ],
              'safetySettings': [
                {'category': 'HARM_CATEGORY_HARASSMENT', 'threshold': 'BLOCK_NONE'},
                {'category': 'HARM_CATEGORY_HATE_SPEECH', 'threshold': 'BLOCK_NONE'},
                {'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT', 'threshold': 'BLOCK_NONE'},
                {'category': 'HARM_CATEGORY_DANGEROUS_CONTENT', 'threshold': 'BLOCK_NONE'}
              ],
              'generationConfig': {'responseMimeType': 'application/json'}
            }),
          ).timeout(const Duration(seconds: 30));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final text = data['candidates'][0]['content']['parts'][0]['text'];
            if (text != null) {
              print("AI_DEBUG: REST SUCCESS with $modelName on $version");
              return text;
            }
          } else {
            print("AI_DEBUG: REST FAIL ($version/$modelName) - Status: "+response.statusCode.toString()+", Body: "+response.body);
          }
        } catch (e) {
          print("AI_DEBUG: REST Error ($version/$modelName): $e");
        }
      }
    }
    return null;
  }

  // -----------------------------------------------------------------
  // Daily quiz (10 Tamil, 6 GS, 4 Aptitude) generation
  // -----------------------------------------------------------------
  static Future<bool> generateAndSaveDailyQuiz(DateTime date) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);

    // Prompt definitions ------------------------------------------------
    final promptTamil = '''
Generate 10 TNPSC General Tamil (பொதுத்தமிழ்) MCQs (SSLC Standard) covering Part A: Grammar (இலக்கணம்), Part B: Literature (இலக்கியம்), and Part C: Tamil Scholars and Service (தமிழ் அறிஞர்களும் தமிழ்த் தொண்டும்). 
Each question MUST be bilingual: contain both English and Tamil text. Format: "English question text\\nTamil question text". 
Each option and explanation MUST contain both English and Tamil text separated by a slash ( / ). Format: "English Option / தமிழ் விருப்பம்". 
Strictly use this JSON format: 
[{"question": "English question text\\nTamil question text", 
"options": ["English Option 1 / தமிழ் விருப்பம் 1", "English Option 2 / தமிழ் விருப்பம் 2", "English Option 3 / தமிழ் விருப்பம் 3", "English Option 4 / தமிழ் விருப்பம் 4"], 
"correctOptionIndex": 0, 
"explanation": "English explanation / தமிழ் விளக்கம்"}]. 
Only return the raw JSON array, no other text or markdown formatting.
''';

    final promptGS = '''
Generate 6 TNPSC General Studies (பொது அறிவு) MCQs (SSLC Standard) covering General Science, Current Events, Geography, History and Culture of India, Indian Polity, Indian Economy, and Indian National Movement. 
Each question MUST be bilingual: contain both English and Tamil text. Format: "English question text\\nTamil question text". 
Each option and explanation MUST contain both English and Tamil text separated by a slash ( / ). Format: "English Option / தமிழ் விருப்பம்". 
Strictly use this JSON format: 
[{"question": "English question text\\nTamil question text", 
"options": ["English Option 1 / தமிழ் விருப்பம் 1", "English Option 2 / தமிழ் விருப்பம் 2", "English Option 3 / தமிழ் விருப்பம் 3", "English Option 4 / தமிழ் விருப்பம் 4"], 
"correctOptionIndex": 0, 
"explanation": "English explanation / தமிழ் விளக்கம்"}]. 
Only return the raw JSON array, no other text or markdown formatting.
''';

    final promptAptitude = '''
Generate 4 TNPSC Aptitude and Mental Ability (திறனறிவும் மனக்கணக்கு நுண்ணறிவும்) MCQs (SSLC Standard) covering Simplification, Percentage, HCF & LCM, Ratio and Proportion, Simple Interest, Compound Interest, Area, Volume, Time and Work, and Logical Reasoning. 
Each question MUST be bilingual: contain both English and Tamil text. Format: "English question text\\nTamil question text". 
Each option and explanation MUST contain both English and Tamil text separated by a slash ( / ). Format: "English Option / தமிழ் விருப்பம்". 
Strictly use this JSON format: 
[{"question": "English question text\\nTamil question text", 
"options": ["English Option 1 / தமிழ் விருப்பம் 1", "English Option 2 / தமிழ் விருப்பம் 2", "English Option 3 / தமிழ் விருப்பம் 3", "English Option 4 / தமிழ் விருப்பம் 4"], 
"correctOptionIndex": 0, 
"explanation": "English explanation / தமிழ் விளக்கம்"}]. 
Only return the raw JSON array, no other text or markdown formatting.
''';

    // --------------------------------------------------------------------
    // Daily quiz generation with quiz_type tagging
    List<dynamic> allQuestions = [];

    // Helper to fetch questions and tag them with a quiz_type
    Future<void> fetchAndTag(String prompt, String quizType) async {
      final res = await _generateWithFallback(prompt);
      if (res != null) {
        int start = res.indexOf('[');
        int end = res.lastIndexOf(']');
        if (start != -1 && end != -1) {
          List q = jsonDecode(res.substring(start, end + 1));
          // Add quiz_type to each question map
          allQuestions.addAll(q.map((item) => {...item, 'quiz_type': quizType}));
        }
      }
    }

    // Fetch each category and tag appropriately
    await fetchAndTag(promptTamil, 'general_tamil');
    await fetchAndTag(promptGS, 'general_studies');
    await fetchAndTag(promptAptitude, 'aptitude');

    if (allQuestions.isEmpty) return false;

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
      await querySnapshot.docs.first.reference.set(quizData, SetOptions(merge: true));
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

    // Prompt definitions ------------------------------------------------
    final promptTamil = '''
Generate 25 TNPSC General Tamil (பொத்துத்தமிழ்) MCQs (SSLC Standard) covering Part A: Grammar (இலக்கணம்), Part B: Literature (இலக்கியம்), and Part C: Tamil Scholars and Service (தமிழ் அறிஞர்களும் தமிழ்த் தொண்டும்). 
Each question MUST be bilingual: contain both English and Tamil text. Format: "English question text\\nTamil question text". 
Each option and explanation MUST contain both English and Tamil text separated by a slash ( / ). Format: "English Option / தமிழ் விருப்பம்". 
Strictly use this JSON format: 
[{"question": "English question text\\nTamil question text", 
"options": ["English Option 1 / தமிழ் விருப்பம் 1", "English Option 2 / தமிழ் விருப்பம் 2", "English Option 3 / தமிழ் விருப்பம் 3", "English Option 4 / தமிழ் விருப்பம் 4"], 
"correctOptionIndex": 0, 
"explanation": "English explanation / தமிழ் விளக்கம்"}]. 
Only return the raw JSON array, no other text or markdown formatting.
''';

    final promptGS = '''
Generate 15 TNPSC General Studies (பொது அறிவு) MCQs (SSLC Standard) covering General Science, Current Events, Geography, History and Culture of India, Indian Polity, Indian Economy, and Indian National Movement. 
Each question MUST be bilingual: contain both English and Tamil text. Format: "English question text\\nTamil question text". 
Each option and explanation MUST contain both English and Tamil text separated by a slash ( / ). Format: "English Option / தமிழ் விருப்பம்". 
Strictly use this JSON format: 
[{"question": "English question text\\nTamil question text", 
"options": ["English Option 1 / தமிழ் விருப்பம் 1", "English Option 2 / தமிழ் விருப்பம் 2", "English Option 3 / தமிழ் விருப்பம் 3", "English Option 4 / தமிழ் விருப்பம் 4"], 
"correctOptionIndex": 0, 
"explanation": "English explanation / தமிழ் விளக்கம்"}]. 
Only return the raw JSON array, no other text or markdown formatting.
''';

    final promptAptitude = '''
Generate 10 TNPSC Aptitude and Mental Ability (திறனறிவும் மனக்கணக்கு நுண்ணறிவும்) MCQs (SSLC Standard) covering Simplification, Percentage, HCF & LCM, Ratio and Proportion, Simple Interest, Compound Interest, Area, Volume, Time and Work, and Logical Reasoning. 
Each question MUST be bilingual: contain both English and Tamil text. Format: "English question text\\nTamil question text". 
Each option and explanation MUST contain both English and Tamil text separated by a slash ( / ). Format: "English Option / தமிழ் விருப்பம்". 
Strictly use this JSON format: 
[{"question": "English question text\\nTamil question text", 
"options": ["English Option 1 / தமிழ் விருப்பம் 1", "English Option 2 / தமிழ் விருப்பம் 2", "English Option 3 / தமிழ் விருப்பம் 3", "English Option 4 / தமிழ் விருப்பம் 4"], 
"correctOptionIndex": 0, 
"explanation": "English explanation / தமிழ் விளக்கம்"}]. 
Only return the raw JSON array, no other text or markdown formatting.
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
          final List<dynamic> tamilQuestions = jsonDecode(resTamil.substring(start, end + 1));
          allQuestions.addAll(tamilQuestions.map((q) => {...q, 'quiz_type': 'general_tamil'}));
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
          final List<dynamic> gsQuestions = jsonDecode(resGS.substring(start, end + 1));
          allQuestions.addAll(gsQuestions.map((q) => {...q, 'quiz_type': 'general_studies'}));
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
          final List<dynamic> aptitudeQuestions = jsonDecode(resAptitude.substring(start, end + 1));
          allQuestions.addAll(aptitudeQuestions.map((q) => {...q, 'quiz_type': 'aptitude'}));
        }
      } catch (e) {
        print("AI_DEBUG: Aptitude JSON Parse Error: $e");
      }
    }

    // --------------------------------------------------------------------
    if (allQuestions.isNotEmpty) {
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
        await querySnapshot.docs.first.reference.set(quizData, SetOptions(merge: true));
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
  static Future<bool> generateScheduledQuiz(DateTime date, String quizType) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    int totalQuestions = 25;
    String subjectTitle = "";
    String syllabusPrompt = "";

    if (quizType == 'tamil_eligibility') {
      totalQuestions = 100;
      subjectTitle = "Tamil Eligibility-cum-Scoring Test (SSLC Standard)";
      syllabusPrompt = "General Tamil (பொதுத்தமிழ்) - Part A: Grammar (இலக்கணம்), Part B: Literature (இலக்கியம்), and Part C: Tamil Scholars and Service (தமிழ் அறிஞர்களும் தமிழ்த் தொண்டும்).";
    } else if (quizType == 'general_studies') {
      totalQuestions = 75;
      subjectTitle = "General Studies (SSLC Standard)";
      syllabusPrompt = "General Studies (பொது அறிவு) - General Science, Current Events, Geography, History and Culture of India, Indian Polity, Indian Economy, and Indian National Movement.";
    } else {
      totalQuestions = 25;
      subjectTitle = "Aptitude & Mental Ability Test (SSLC Standard)";
      syllabusPrompt = "Aptitude and Mental Ability (திறனறிவும் மனக்கணக்கு நுண்ணறிவும்) - Simplification, Percentage, HCF & LCM, Ratio and Proportion, Simple Interest, Compound Interest, Area, Volume, Time and Work, and Logical Reasoning/Puzzles.";
    }

    // Break into 25‑question chunks to avoid payload limits
    int chunkSize = 25;
    int chunks = (totalQuestions / chunkSize).ceil();
    List<dynamic> allQuestions = [];

    for (int i = 0; i < chunks; i++) {
      int startIdx = i * chunkSize + 1;
      int endIdx = (i + 1) * chunkSize;
      if (endIdx > totalQuestions) endIdx = totalQuestions;
      int count = endIdx - startIdx + 1;

      final prompt = '''
Generate $count TNPSC MCQs (Questions $startIdx to $endIdx out of $totalQuestions) for the subject '$subjectTitle' based on the Combined Civil Services Examination‑IV (Group‑IV and VAO) syllabus: $syllabusPrompt. 
Each question MUST be bilingual: contain both English and Tamil text. Format: "English question text\\nTamil question text". 
Each option and explanation MUST contain both English and Tamil text separated by a slash ( / ). Format: "English Option / தமிழ் விருப்பம்". 
Strictly use this JSON format: 
[{"question": "English question text\\nTamil question text", 
"options": ["English Option 1 / தமிழ் விருப்பம் 1", "English Option 2 / தமிழ் விருப்பம் 2", "English Option 3 / தமிழ் விருப்பம் 3", "English Option 4 / தமிழ் விருப்பம் 4"], 
"correctOptionIndex": 0, 
"explanation": "English explanation / தமிழ் விளக்கம்"}]. 
Only return the raw JSON array, no other text or markdown formatting.
''';

      final res = await _generateWithFallback(prompt);
      if (res != null) {
        try {
          int start = res.indexOf('[');
          int end = res.lastIndexOf(']');
          if (start != -1 && end != -1) {
            List chunkQuestions = jsonDecode(res.substring(start, end + 1));
            allQuestions.addAll(chunkQuestions.map((q) => {...q, 'quiz_type': quizType}));
          } else {
            print("AI_DEBUG: Bracket mismatch in chunk response: $res");
            return false;
          }
        } catch (e) {
          print("AI_DEBUG: Chunk $i JSON Parse Error: $e");
          return false;
        }
      } else {
        print("AI_DEBUG: Chunk $i API response is null");
        return false;
      }
    }

    if (allQuestions.isNotEmpty) {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('quizzes')
          .where('date', isEqualTo: dateStr)
          .get();

      final quizData = {
        'date': dateStr,
        'title': subjectTitle,
        'quiz_type': quizType,
        'quizType': quizType,
        'questions': allQuestions,
        'type': 'daily_quiz',
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (querySnapshot.docs.isNotEmpty) {
        await querySnapshot.docs.first.reference.set(quizData, SetOptions(merge: true));
      } else {
        await FirebaseFirestore.instance.collection('quizzes').add(quizData);
      }
      return true;
    }
    return false;
  }

  // -----------------------------------------------------------------
  // Additional helper methods (subject questions, study material, chats, etc.)
  // -----------------------------------------------------------------
  static Future<bool> generateSubjectQuestions(String subject, {String? category}) async {
    String specializedPrompt = "";

    if (subject == 'general_tamil') {
      specializedPrompt = '''
Generate 20 TNPSC General Tamil (பொதுத்தமிழ்) MCQs (SSLC Standard) covering Part A: Grammar (இலக்கணம்), Part B: Literature (இலக்கியம்), and Part C: Tamil Scholars and Service (தமிழ் அறிஞர்களும் தமிழ்த் தொண்டும்). 
Each question MUST be bilingual: contain both English and Tamil text. Format: "English question text\\nTamil question text". 
Each option and explanation MUST contain both English and Tamil text separated by a slash ( / ). Format: "English Option / தமிழ் விருப்பம்". 
''';
    } else if (subject == 'general_studies') {
      specializedPrompt = '''
Generate 20 TNPSC General Studies (பொது அறிவு) MCQs (SSLC Standard) covering General Science, Current Events, Geography, History and Culture of India, Indian Polity, Indian Economy, and Indian National Movement. 
Each question MUST be bilingual: contain both English and Tamil text. Format: "English question text\\nTamil question text". 
Each option and explanation MUST contain both English and Tamil text separated by a slash ( / ). Format: "English Option / தமிழ் விருப்பம்". 
''';
    } else if (subject == 'aptitude') {
      specializedPrompt = '''
Generate 20 TNPSC Aptitude and Mental Ability (திறனறிவும் மனக்கணக்கு நுண்ணறிவும்) MCQs (SSLC Standard) covering Simplification, Percentage, HCF & LCM, Ratio and Proportion, Simple Interest, Compound Interest, Area, Volume, Time and Work, and Logical Reasoning. 
Each question MUST be bilingual: contain both English and Tamil text. Format: "English question text\\nTamil question text". 
Each option and explanation MUST contain both English and Tamil text separated by a slash ( / ). Format: "English Option / தமிழ் விருப்பம்". 
''';
    } else {
      specializedPrompt = "Create 25 TNPSC MCQs for '$subject' in both Tamil and English (Bilingual). Each question MUST contain both English and Tamil text separated by a newline (\\n). Each option and explanation MUST contain both English and Tamil text separated by a slash ( / ).";
    }

    final prompt = '''
$specializedPrompt
Strictly use this JSON format: 
[{"question": "English question text\\nTamil question text", 
"options": ["English Option 1 / தமிழ் விருப்பம் 1", "English Option 2 / தமிழ் விருப்பம் 2", "English Option 3 / தமிழ் விருப்பம் 3", "English Option 4 / தமிழ் விருப்பம் 4"], 
"correctOptionIndex": 0, 
"explanation": "English explanation / தமிழ் விளக்கம்"}]. 
Only return the raw JSON array, no other text or markdown formatting.
''';

    final res = await _generateWithFallback(prompt);
    if (res != null) {
      try {
        int start = res.indexOf('[');
        int end = res.lastIndexOf(']');
        if (start != -1 && end != -1) {
          List<dynamic> newQuestions = jsonDecode(res.substring(start, end + 1));
          newQuestions = newQuestions.map((q) => {...q, 'quiz_type': 'subject_question'}).toList();

          String safeId = subject.trim().replaceAll('/', '-');
          final docRef = FirebaseFirestore.instance.collection('subject_questions').doc(safeId);
          final doc = await docRef.get();

          List<dynamic> existingQuestions = [];
          if (doc.exists) {
            existingQuestions = doc.get('questions') ?? [];
          }

          Set<String> existingTexts = existingQuestions.map((e) => (e['question'] ?? "").toString().trim()).toSet();
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

  static Future<bool> generateStudyMaterial(String subject, {String? category}) async {
    final prompt = "Create 25 structured TNPSC study points for '$subject'. Use this JSON format: [{\"id\": 1, \"tamil\": \"...\", \"english\": \"...\"}]. Only return the JSON array.";
    final res = await _generateWithFallback(prompt);
    if (res != null) {
      try {
        int start = res.indexOf('[');
        int end = res.lastIndexOf(']');
        if (start != -1 && end != -1) {
          List<dynamic> newMaterial = jsonDecode(res.substring(start, end + 1));
          String safeId = subject.trim().replaceAll('/', '-');
          final docRef = FirebaseFirestore.instance.collection('subject_study_material').doc(safeId);
          final doc = await docRef.get();

          List<dynamic> existingMaterial = [];
          if (doc.exists) {
            existingMaterial = doc.get('material') ?? [];
          }

          Set<String> existingTexts = existingMaterial.map((e) => (e['tamil'] ?? "").toString().trim()).toSet();
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
  static Future<String?> chatWithAppContext(String message, String context) async {
    final prompt = "TNPSC Tutor context search: $context. Question: $message. Bilingual.";
    return await _generateWithFallback(prompt);
  }

  static Future<String?> chatWithAi(String message) async {
    final prompt = "TNPSC Doubt: $message. Answer in Tamil & English.";
    return await _generateWithFallback(prompt);
  }

  static Future<String> explainQuestion(String question, List<String> options, String correctAnswer) async {
    final prompt = "Explain TNPSC question: $question. Answer: $correctAnswer. Bilingual.";
    final res = await _generateWithFallback(prompt);
    return res ?? "Explanation unavailable.";
  }

  static Future<String> generateStructuredStudyMaterial(String topic) async {
    final prompt = "Generate TNPSC study guide for '$topic'. Bilingual.";
    final res = await _generateWithFallback(prompt);
    return res ?? "Guide unavailable.";
  }

  static Future<List<dynamic>> generateCustomQuiz(String topic) async {
    final prompt = '''
Generate 20 TNPSC MCQs for '$topic' in both Tamil and English (Bilingual). 
Each question MUST contain both English and Tamil text separated by a newline (\n). 
Each option and explanation MUST contain both English and Tamil text separated by a slash ( / ). 
Strictly use this JSON format: 
[{"question": "English question text\\nTamil question text", 
"options": ["English Option 1 / தமிழ் விருப்பம் 1", "English Option 2 / தமிழ் விருப்பம் 2", "English Option 3 / தமிழ் விருப்பம் 3", "English Option 4 / தமிழ் விருப்பம் 4"], 
"correctOptionIndex": 0, 
"explanation": "English explanation / தமிழ் விளக்கம்"}]. 
Only return the raw JSON array, no other text or markdown formatting.
''';
    final res = await _generateWithFallback(prompt);
    if (res != null) {
      try {
        int start = res.indexOf('[');
        int end = res.lastIndexOf(']');
        if (start != -1 && end != -1) return jsonDecode(res.substring(start, end + 1));
      } catch (e) {}
    }
    return [];
  }
}
