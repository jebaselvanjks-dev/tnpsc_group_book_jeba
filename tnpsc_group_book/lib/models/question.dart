import 'package:tnpsc_group_book/utils/app_language.dart';

class Question {
  final String? id; // Unique ID for bookmarks
  final String question; // Legacy combined format
  final List<String> options; // Legacy combined format
  final int correctOptionIndex;
  final String explanation; // Legacy combined format
  final String? subject; // To categorize bookmarks
  final String? quizType; // To categorize bookmarks

  // New Bilingual Fields
  final String? questionEn;
  final String? questionTa;
  final List<String>? optionsEn;
  final List<String>? optionsTa;
  final String? explanationEn;
  final String? explanationTa;

  Question({
    this.id,
    required this.question,
    required this.options,
    required this.correctOptionIndex,
    required this.explanation,
    this.subject,
    this.quizType,
    this.questionEn,
    this.questionTa,
    this.optionsEn,
    this.optionsTa,
    this.explanationEn,
    this.explanationTa,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'question': question,
      'options': options,
      'correctOptionIndex': correctOptionIndex,
      'explanation': explanation,
      'subject': subject,
      'quiz_type': quizType,
      'question_en': questionEn,
      'question_ta': questionTa,
      'options_en': optionsEn,
      'options_ta': optionsTa,
      'explanation_en': explanationEn,
      'explanation_ta': explanationTa,
    };
  }

  factory Question.fromMap(Map<String, dynamic> map) {
    // 1. Detect if it's the new structured format
    String? qEn = map['question_en']?.toString();
    String? qTa = map['question_ta']?.toString();
    String? eEn = map['explanation_en']?.toString();
    String? eTa = map['explanation_ta']?.toString();

    List<String>? optsEn;
    List<String>? optsTa;

    // Handle new options format: List of objects [{"en": "...", "ta": "..."}]
    if (map['options'] is List &&
        map['options'].isNotEmpty &&
        map['options'][0] is Map) {
      final optsList = List<Map<String, dynamic>>.from(map['options']);
      optsEn = optsList.map((o) => (o['en'] ?? "").toString()).toList();
      optsTa = optsList.map((o) => (o['ta'] ?? "").toString()).toList();
    }

    // 2. Compute structured fields if they are missing (Parsing Legacy Strings)
    String rawQ = map['question']?.toString() ?? "";
    if (qEn == null && qTa == null && rawQ.isNotEmpty) {
      var parsed = AppLanguage.parseBilingual(rawQ);
      qEn = parsed['en'];
      qTa = parsed['ta'];
    }

    String rawE = map['explanation']?.toString() ?? "";
    if (eEn == null && eTa == null && rawE.isNotEmpty) {
      var parsed = AppLanguage.parseBilingual(rawE);
      eEn = parsed['en'];
      eTa = parsed['ta'];
    }

    if (optsEn == null && optsTa == null && map['options'] is List) {
      optsEn = [];
      optsTa = [];
      for (var opt in map['options']) {
        if (opt is String) {
          var parsed = AppLanguage.parseBilingual(opt);
          optsEn.add(parsed['en']!);
          optsTa.add(parsed['ta']!);
        }
      }
    }

    // 3. Compute legacy fields for backward compatibility
    String finalQ = rawQ.isNotEmpty ? rawQ : "$qEn\n$qTa";
    
    List<String> finalOpts = [];
    if (map['options'] is List && map['options'].isNotEmpty && map['options'][0] is String) {
      finalOpts = List<String>.from(map['options']);
    } else if (optsEn != null && optsTa != null) {
      for (int i = 0; i < optsEn.length; i++) {
        finalOpts.add("${optsEn[i]} / ${optsTa[i]}");
      }
    }

    String finalEx = rawE.isNotEmpty ? rawE : "$eEn $eTa";

    return Question(
      id: map['id'],
      question: finalQ,
      options: finalOpts,
      correctOptionIndex: map['correctOptionIndex'] ?? 0,
      explanation: finalEx,
      subject: map['subject'],
      quizType: map['quiz_type'],
      questionEn: qEn,
      questionTa: qTa,
      optionsEn: optsEn,
      optionsTa: optsTa,
      explanationEn: eEn,
      explanationTa: eTa,
    );
  }

  String get uniqueId => id ?? question.hashCode.toString();

  // Getters to simplify UI usage with language selection
  String get displayQuestion {
    final lang = AppLanguage.languageNotifier.value;
    if (lang == 'ta') {
      return questionTa ?? question;
    } else if (lang == 'en') {
      return questionEn ?? question;
    }
    return question; // Default to combined
  }

  List<String> get displayOptions {
    final lang = AppLanguage.languageNotifier.value;
    if (lang == 'ta') {
      return optionsTa ?? options;
    } else if (lang == 'en') {
      return optionsEn ?? options;
    }
    return options; // Default to combined
  }

  String get displayExplanation {
    final lang = AppLanguage.languageNotifier.value;
    if (lang == 'ta') {
      return explanationTa ?? explanation;
    } else if (lang == 'en') {
      return explanationEn ?? explanation;
    }
    return explanation; // Default to combined
  }

  // Legacy format for places that still need both (like Review)
  String get bilingualQuestion => (questionEn != null && questionTa != null) 
      ? "$questionEn\n$questionTa" 
      : question;

  List<String> get bilingualOptions {
    if (optionsEn != null && optionsTa != null) {
      return List.generate(optionsEn!.length, (i) => "${optionsEn![i]} / ${optionsTa![i]}");
    }
    return options;
  }

  String get bilingualExplanation => (explanationEn != null && explanationTa != null)
      ? "$explanationEn $explanationTa"
      : explanation;

  // TTS Helper
  String get ttsText {
    final lang = AppLanguage.languageNotifier.value;
    String q = displayQuestion;
    String opts = "";
    for (int i = 0; i < displayOptions.length; i++) {
      opts += ". ${lang == 'ta' ? 'விருப்பம்' : 'Option'} ${i + 1}: ${displayOptions[i]}";
    }
    return "$q $opts";
  }
}

// Empty fallback - everything will now be fetched from Firestore (AI Generated)
final Map<String, List<Question>> subjectQuestions = {};
final List<Question> historyQuestions = [];
final List<Question> tamilQuestions = [];

final List<Question> defaultRoomQuestions = [
  Question(
    question: "Who was the first woman doctor in India?\nஇந்தியாவின் முதல் பெண் மருத்துவர் யார்?",
    options: [
      "Dr. Muthulakshmi Reddy / டாக்டர் முத்துலட்சுமி ரெட்டி",
      "Dr. Annie Besant / டாக்டர் அன்னி பெசண்ட்",
      "Sarojini Naidu / சரோஜினி நாயுடு",
      "Moovalur Ramamirtham / மூவலூர் ராமாமிர்தம்"
    ],
    correctOptionIndex: 0,
    explanation: "Dr. Muthulakshmi Reddy was the first woman doctor in India and the first female legislator. / டாக்டர் முத்துலட்சுமி ரெட்டி இந்தியாவின் முதல் பெண் மருத்துவர் மற்றும் முதல் பெண் சட்டமன்ற உறுப்பினர் ஆவார்.",
    subject: "General Studies",
    quizType: "general_studies",
  ),
  Question(
    question: "Which is the state bird of Tamil Nadu?\nதமிழ்நாட்டின் மாநிலப் பறவை எது?",
    options: [
      "Emerald Dove / மரகதப் புறா",
      "Peacock / மயில்",
      "Koel / குயில்",
      "Parrot / கிளி"
    ],
    correctOptionIndex: 0,
    explanation: "The Emerald Dove is the state bird of Tamil Nadu. / மரகதப் புறா தமிழ்நாட்டின் மாநிலப் பறவை ஆகும்.",
    subject: "General Studies",
    quizType: "general_studies",
  ),
  Question(
    question: "Who is known as the 'Father of the Indian Constitution'?\n'இந்திய அரசியலமைப்பின் தந்தை' என்று அழைக்கப்படுபவர் யார்?",
    options: [
      "Dr. B.R. Ambedkar / டாக்டர் பி.ஆர்.அம்பேத்கர்",
      "Mahatma Gandhi / மகாத்மா காந்தி",
      "Jawaharlal Nehru / ஜவஹர்லால் நேரு",
      "Dr. Rajendra Prasad / டாக்டர் ராஜேந்திர பிரசாத்"
    ],
    correctOptionIndex: 0,
    explanation: "Dr. B.R. Ambedkar was the chief architect and is recognized as the Father of the Indian Constitution. / டாக்டர் பி.ஆர்.அம்பேத்கர் இந்திய அரசியலமைப்பின் முதன்மை வடிவமைப்பாளர் மற்றும் தந்தை என அங்கீகரிக்கப்பட்டுள்ளார்.",
    subject: "General Studies",
    quizType: "general_studies",
  ),
  Question(
    question: "In which year was the state of Madras renamed as Tamil Nadu?\nமெட்ராஸ் மாநிலம் எந்த ஆண்டு தமிழ்நாடு என பெயர் மாற்றம் செய்யப்பட்டது?",
    options: [
      "1967",
      "1969",
      "1972",
      "1956"
    ],
    correctOptionIndex: 1,
    explanation: "In 1969, under Chief Minister C.N. Annadurai, Madras State was officially renamed Tamil Nadu. / 1969 இல், முதலமைச்சர் சி.என். அண்ணாதுரையின் கீழ், மெட்ராஸ் மாநிலம் அதிகாரப்பூர்வமாக தமிழ்நாடு என பெயர் மாற்றம் செய்யப்பட்டது.",
    subject: "General Studies",
    quizType: "general_studies",
  ),
  Question(
    question: "Who built the famous Brihadeeswarar Temple in Thanjavur?\nதஞ்சாவூர் பிரகதீஸ்வரர் கோயிலைக் கட்டியவர் யார்?",
    options: [
      "Rajaraja Chola I / முதலாம் ராஜராஜ சோழன்",
      "Rajendra Chola I / முதலாம் ராஜேந்திர சோழன்",
      "Karikala Chola / கரிகால சோழன்",
      "Aditya Chola / ஆதித்ய சோழன்"
    ],
    correctOptionIndex: 0,
    explanation: "The Brihadeeswarar Temple in Thanjavur was built by Rajaraja Chola I in 1010 AD. / தஞ்சாவூர் பிரகதீஸ்வரர் கோயில் கி.பி. 1010 இல் முதலாம் ராஜராஜ சோழனால் கட்டப்பட்டது.",
    subject: "General Studies",
    quizType: "general_studies",
  ),
  Question(
    question: "Which is the highest peak in Tamil Nadu?\nதமிழ்நாட்டின் மிக உயர்ந்த சிகரம் எது?",
    options: [
      "Doddabetta / தொட்டபெட்டா",
      "Anamudi / ஆனைமுடி",
      "Mahendragiri / மகேந்திரகிரி",
      "Kodaikanal / கொடைக்கானல்"
    ],
    correctOptionIndex: 0,
    explanation: "Doddabetta is the highest peak in the Nilgiri Hills of Tamil Nadu, standing at 2,637 meters. / தொட்டபெட்டா தமிழ்நாட்டின் நீலகிரி மலையில் அமைந்துள்ள மிக உயர்ந்த சிகரமாகும் (2,637 மீட்டர்).",
    subject: "General Studies",
    quizType: "general_studies",
  ),
  Question(
    question: "Who authored the national anthem of India?\nஇந்தியாவின் தேசிய கீதத்தை இயற்றியவர் யார்?",
    options: [
      "Rabindranath Tagore / ரவீந்திரநாத் தாகூர்",
      "Bankim Chandra Chattopadhyay / பங்கிம் சந்திர சாட்டர்ஜி",
      "Subramania Bharati / சுப்பிரமணிய பாரதி",
      "Mahatma Gandhi / மகாத்மா காந்தி"
    ],
    correctOptionIndex: 0,
    explanation: "Jana Gana Mana, the national anthem of India, was composed by Nobel laureate Rabindranath Tagore. / இந்தியாவின் தேசிய கீதமான ஜன கண மன, நோபல் பரிசு பெற்ற ரவீந்திரநாத் தாகூரால் இயற்றப்பட்டது.",
    subject: "General Studies",
    quizType: "general_studies",
  ),
  Question(
    question: "Which article of the Indian Constitution provides for the Right to Equality?\nஇந்திய அரசியலமைப்பின் எந்த விதி சமத்துவ உரிமையை வழங்குகிறது?",
    options: [
      "Articles 14 to 18 / விதிகள் 14 முதல் 18",
      "Articles 19 to 22 / விதிகள் 19 முதல் 22",
      "Articles 23 to 24 / விதிகள் 23 முதல் 24",
      "Articles 25 to 28 / விதிகள் 25 முதல் 28"
    ],
    correctOptionIndex: 0,
    explanation: "Articles 14 to 18 of the Indian Constitution deal with the Right to Equality. / இந்திய அரசியலமைப்பின் 14 முதல் 18 வரையிலான விதிகள் சமத்துவ உரிமையைப் பற்றி பேசுகின்றன.",
    subject: "General Studies",
    quizType: "general_studies",
  ),
  Question(
    question: "Who was the author of the Tamil epic 'Silappatikaram'?\nதமிழின் காப்பியமான 'சிலப்பதிகாரம்' இயற்றியவர் யார்?",
    options: [
      "Ilango Adigal / இளங்கோவடிகள்",
      "Seethalai Sathanar / சீத்தலைச் சாத்தனார்",
      "Thiruvalluvar / திருவள்ளுவர்",
      "Kambar / கம்பர்"
    ],
    correctOptionIndex: 0,
    explanation: "Silappatikaram was written by Ilango Adigal, who was a Chera prince. / சிலப்பதிகாரம் சேர மன்னர் மரபைச் சேர்ந்த இளங்கோவடிகளால் எழுதப்பட்டது.",
    subject: "General Tamil",
    quizType: "general_tamil",
  ),
  Question(
    question: "Which national leader is known as 'Periyar'?\n'பெரியார்' என்று அழைக்கப்படும் தேசியத் தலைவர் யார்?",
    options: [
      "E.V. Ramasamy / ஈ.வெ. ராமசாமி",
      "C. Rajagopalachari / சி. ராஜகோபாலாச்சாரி",
      "K. Kamaraj / கி. காமராஜ்",
      "C.N. Annadurai / சி.என். அண்ணாதுரை"
    ],
    correctOptionIndex: 0,
    explanation: "E.V. Ramasamy is affectionately called 'Periyar' (The Elder) and is known as the Father of the Dravidian Movement. / ஈ.வெ. ராமசாமி அன்புடன் 'பெரியார்' என்று அழைக்கப்படுகிறார் மற்றும் திராவிட இயக்கத்தின் தந்தை என்று அறியப்படுகிறார்.",
    subject: "General Studies",
    quizType: "general_studies",
  ),
  Question(
    question: "How many letters are there in total in Tamil language according to Nannul?\\nநன்னூலின் படி தமிழ் மொழியில் உள்ள மொத்த எழுத்துக்களின் எண்ணிக்கை யாது?",
    options: ["247 / 247", "255 / 255", "260 / 260", "275 / 275"],
    correctOptionIndex: 0,
    explanation: "According to Nannul, Tamil language has 247 letters (including vowels, consonants, and compound letters). / நன்னூலின்படி தமிழ் மொழியில் மொத்தம் 247 எழுத்துக்கள் உள்ளன.",
    subject: "General Tamil",
    quizType: "general_tamil",
  ),
];

