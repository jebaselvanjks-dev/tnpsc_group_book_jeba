import 'package:flutter/material.dart';
import 'package:tnpsc_group_book/utils/app_language.dart';

class Subject {
  final String id;
  final String titleTa;
  final String titleEn;
  final String subtitleTa;
  final String subtitleEn;
  final IconData icon;
  final Color color;
  final List<String> topicsTa;
  final List<String> topicsEn;
  final Map<String, List<String>> subTopicsMapTa;
  final Map<String, List<String>> subTopicsMapEn;

  Subject({
    required this.id,
    required this.titleTa,
    required this.titleEn,
    required this.subtitleTa,
    required this.subtitleEn,
    required this.icon,
    required this.color,
    this.topicsTa = const [],
    this.topicsEn = const [],
    this.subTopicsMapTa = const {},
    this.subTopicsMapEn = const {},
  });

  String get title => AppLanguage.languageNotifier.value == 'ta' ? titleTa : titleEn;

  String get subtitle => AppLanguage.languageNotifier.value == 'ta' ? subtitleTa : subtitleEn;

  List<String> get topics => AppLanguage.languageNotifier.value == 'ta' ? topicsTa : topicsEn;

  String getTopicKey(int index) {
    if (index >= 0 && index < topicsTa.length) {
      return topicsTa[index];
    }
    return "";
  }

  String getSubTopicKey(int topicIndex, int subTopicIndex) {
    if (topicIndex >= 0 && topicIndex < topicsTa.length) {
      String tamilTopic = topicsTa[topicIndex];
      List<String> tamilSubTopics = subTopicsMapTa[tamilTopic] ?? [];
      if (subTopicIndex >= 0 && subTopicIndex < tamilSubTopics.length) {
        return tamilSubTopics[subTopicIndex];
      }
    }
    return "";
  }

  List<String> getSubTopics(int index) {
    if (AppLanguage.languageNotifier.value == 'ta') {
      if (index >= 0 && index < topicsTa.length) {
        return subTopicsMapTa[topicsTa[index]] ?? [];
      }
    } else {
      if (index >= 0 && index < topicsEn.length) {
        return subTopicsMapEn[topicsEn[index]] ?? [];
      }
    }
    return [];
  }
}

final List<Subject> tnpscSubjects = [
  Subject(
    id: '1',
    titleTa: 'பொதுத் தமிழ்',
    titleEn: 'General Tamil',
    subtitleTa: 'இலக்கணம், இலக்கியம் & தமிழ் அறிஞர்கள்',
    subtitleEn: 'Grammar, Literature & Tamil Scholars',
    icon: Icons.menu_book_rounded,
    color: Colors.orange,
    topicsTa: ['இலக்கணம்', 'இலக்கியம்', 'தமிழ் அறிஞர்களும் தமிழ்த் தொண்டும்'],
    topicsEn: ['இலக்கணம்', 'இலக்கியம்', 'தமிழ் அறிஞர்களும் தமிழ்த் தொண்டும்'],
    subTopicsMapTa: {
      'இலக்கணம்': [
        'எழுத்தியல்',
        'சொற்களின் வகைகள்',
        'பெயர்ச்சொல்',
        'வினைச்சொல்',
        'வினையுரிச்சொல்',
        'இடைச்சொல்',
        'உருபுகள்',
        'வேற்றுமை உருபுகள்',
        'காலங்கள்',
        'எண்',
        'பால்',
        'இடம்',
        'வாக்கிய அமைப்பு',
        'இணைப்புச் சொற்கள்',
        'எதிர்ச்சொற்கள்',
        'இணைச்சொற்கள்',
        'பொருள் விளக்கம்',
        'எழுத்துப் பிழை திருத்தம்',
      ],
      'இலக்கியம்': [
        'திருக்குறள்',
        'அறநூல்கள்',
        'கம்பராமாயணம்',
        'எட்டுத்தொகை',
        'பத்துப்பாட்டு',
        'ஐம்பெருங் காப்பியங்கள்',
        'ஐஞ்சிறு காப்பியங்கள்',
        'சிற்றிலக்கியங்கள்',
        'பக்தி இலக்கியம்',
      ],
      'தமிழ் அறிஞர்களும் தமிழ்த் தொண்டும்': ['பாரதியார், பாரதிதாசன்', 'மரபுக் கவிதை', 'புதுக்கவிதை', 'தமிழின் தொன்மை', 'உரைநடை', 'நாடகக் கலை'],
    },
    subTopicsMapEn: {
      'இலக்கணம்': [
        'எழுத்தியல்',
        'சொற்களின் வகைகள்',
        'பெயர்ச்சொல்',
        'வினைச்சொல்',
        'வினையுரிச்சொல்',
        'இடைச்சொல்',
        'உருபுகள்',
        'வேற்றுமை உருபுகள்',
        'காலங்கள்',
        'எண்',
        'பால்',
        'இடம்',
        'வாக்கிய அமைப்பு',
        'இணைப்புச் சொற்கள்',
        'எதிர்ச்சொற்கள்',
        'இணைச்சொற்கள்',
        'பொருள் விளக்கம்',
        'எழுத்துப் பிழை திருத்தம்',
      ],
      'இலக்கியம்': [
        'திருக்குறள்',
        'அறநூல்கள்',
        'கம்பராமாயணம்',
        'எட்டுத்தொகை',
        'பத்துப்பாட்டு',
        'ஐம்பெருங் காப்பியங்கள்',
        'ஐஞ்சிறு காப்பியங்கள்',
        'சிற்றிலக்கியங்கள்',
        'பக்தி இலக்கியம்',
      ],
      'தமிழ் அறிஞர்களும் தமிழ்த் தொண்டும்': ['பாரதியார், பாரதிதாசன்', 'மரபுக் கவிதை', 'புதுக்கவிதை', 'தமிழின் தொன்மை', 'உரைநடை', 'நாடகக் கலை'],
    },
  ),
  // Subject(
  //   id: '2',
  //   titleTa: 'General English',
  //   titleEn: 'General English',
  //   subtitleTa: 'Grammar & Literature',
  //   subtitleEn: 'Grammar & Literature',
  //   icon: Icons.translate_rounded,
  //   color: Colors.blueGrey,
  //   topicsTa: ['English Grammar', 'Literature'],
  //   topicsEn: ['English Grammar', 'Literature'],
  //   subTopicsMapTa: {
  //     'English Grammar': ['Parts of Speech', 'Tenses', 'Active & Passive Voice', 'Synonyms & Antonyms', 'Error Spotting'],
  //     'Literature': ['Figures of Speech', 'Appreciation Questions', 'Important Poems', 'Authors & Literary Works'],
  //   },
  //   subTopicsMapEn: {
  //     'English Grammar': ['Parts of Speech', 'Tenses', 'Active & Passive Voice', 'Synonyms & Antonyms', 'Error Spotting'],
  //     'Literature': ['Figures of Speech', 'Appreciation Questions', 'Important Poems', 'Authors & Literary Works'],
  //   },
  // ),
  Subject(
    id: '2',
    titleTa: 'பொது அறிவியல்',
    titleEn: 'General Science',
    subtitleTa: 'அறிவியல் கோட்பாடுகள்',
    subtitleEn: 'Scientific Concepts',
    icon: Icons.science_rounded,
    color: Colors.cyan,
    topicsTa: ['இயற்பியல் & வேதியியல்', 'உயிரியல் & சுற்றுச்சூழல்'],
    topicsEn: ['Physics & Chemistry', 'Biology & Environment'],
    subTopicsMapTa: {
      'இயற்பியல் & வேதியியல்': [
        'பேரண்டத்தின் இயல்பு',
        'இயக்கவியல் & ஆற்றல்',
        'காந்தவியல் & மின்சாரவியல்',
        'தனிமங்கள் மற்றும் சேர்மங்கள்',
        'அமிலங்கள், காரங்கள் & உப்புகள்',
      ],
      'உயிரியல் & சுற்றுச்சூழல்': [
        'உயிரினங்களின் வகைப்பாடு',
        'ஊட்டச்சத்து & மனித நோய்கள்',
        'மரபியல் & பரிணாமம்',
        'சுற்றுச்சூழல் மற்றும் சூழலியல்',
      ],
    },
    subTopicsMapEn: {
      'Physics & Chemistry': [
        'Nature of Universe',
        'Mechanics & Energy',
        'Magnetism & Electricity',
        'Elements and Compounds',
        'Acids, Bases & Salts',
      ],
      'Biology & Environment': [
        'Classification of Living Organisms',
        'Nutrition & Human Diseases',
        'Genetics & Evolution',
        'Environment and Ecology',
      ],
    },
  ),
  Subject(
    id: '3',
    titleTa: 'வரலாறு மற்றும் பண்பாடு',
    titleEn: 'History and Culture',
    subtitleTa: 'இந்திய வரலாறு & பண்பாடு',
    subtitleEn: 'History & Culture of India',
    icon: Icons.account_balance_rounded,
    color: Colors.blue,
    topicsTa: ['இந்திய வரலாறு'],
    topicsEn: ['Indian History'],
    subTopicsMapTa: {
      'இந்திய வரலாறு': ['சிந்து சமவெளி நாகரிகம்', 'குப்தர்கள்', 'டெல்லி சுல்தான்கள்', 'முகலாயர்கள்', 'மராத்தியர்கள்', 'தென்னிந்திய வரலாறு'],
    },
    subTopicsMapEn: {
      'Indian History': ['Indus Valley Civilization', 'Guptas', 'Delhi Sultans', 'Mughals', 'Marathas', 'South Indian History'],
    },
  ),
  Subject(
    id: '4',
    titleTa: 'இந்திய தேசிய இயக்கம்',
    titleEn: 'Indian National Movement',
    subtitleTa: 'விடுதலைப் போராட்டம்',
    subtitleEn: 'Freedom Struggle',
    icon: Icons.history_edu_rounded,
    color: Colors.amber,
    topicsTa: ['தேசிய மறுமலர்ச்சி'],
    topicsEn: ['National Renaissance'],
    subTopicsMapTa: {
      'தேசிய மறுமலர்ச்சி': [
        'இந்திய தேசிய காங்கிரஸ் (INC)',
        'தலைவர்கள் எழுச்சி (காந்தி, நேரு, படேல், போஸ்)',
        'தமிழ்நாட்டின் பங்கு (வ.உ.சி, பெரியார், பாரதி, காமராசர்)',
      ],
    },
    subTopicsMapEn: {
      'National Renaissance': [
        'Indian National Congress (INC)',
        'Emergence of Leaders (Gandhi, Nehru, Patel, Bose)',
        'Role of Tamil Nadu (VOC, Periyar, Bharathi, Kamarajar)',
      ],
    },
  ),
  Subject(
    id: '5',
    titleTa: 'அரசியலமைப்பு',
    titleEn: 'Indian Polity',
    subtitleTa: 'இந்திய அரசியல் அமைப்பு',
    subtitleEn: 'Constitution of India',
    icon: Icons.gavel_rounded,
    color: Colors.indigo,
    topicsTa: ['அரசியலமைப்பு', 'நிர்வாகம்'],
    topicsEn: ['Constitution', 'Governance'],
    subTopicsMapTa: {
      'அரசியலமைப்பு': ['முகப்புரை', 'அடிப்படை உரிமைகள் & கடமைகள்', 'மத்திய அரசு', 'மாநில அரசு', 'தேர்தல் முறை'],
      'நிர்வாகம்': ['பஞ்சாயத்து ராஜ்', 'ஊழல் எதிர்ப்பு நடவடிக்கைகள்', 'லோக் அதாலத், லோக்பால் & ஓம்புட்ஸ்மேன்', 'தகவல் அறியும் உரிமை (RTI)'],
    },
    subTopicsMapEn: {
      'Constitution': ['Preamble', 'Fundamental Rights & Duties', 'Union Government', 'State Government', 'Election System'],
      'Governance': ['Panchayati Raj', 'Anti-Corruption Measures', 'Lok Adalat, Lokpal & Ombudsman', 'Right to Information (RTI)'],
    },
  ),
  Subject(
    id: '6',
    titleTa: 'புவியியல்',
    titleEn: 'Geography',
    subtitleTa: 'இந்தியப் புவியியல்',
    subtitleEn: 'Geography of India',
    icon: Icons.public_rounded,
    color: Colors.green,
    topicsTa: ['புவியியல் கூறுகள்'],
    topicsEn: ['Geographical Features'],
    subTopicsMapTa: {
      'புவியியல் கூறுகள்': [
        'இயற்கை அமைவு',
        'மழைப்பொழிவு & காலநிலை',
        'ஆறுகள் & நீர்நிலைகள்',
        'மண், காடுகள் & வனவிலங்குகள்',
        'போக்குவரத்து & தகவல் தொடர்பு',
        'பேரழிவு மேலாண்மை',
      ],
    },
    subTopicsMapEn: {
      'Geographical Features': [
        'Physical Features',
        'Monsoon & Climate',
        'Rivers & Water Resources',
        'Soil, Forests & Wildlife',
        'Transport & Communication',
        'Disaster Management',
      ],
    },
  ),
  Subject(
    id: '7',
    titleTa: 'இந்தியப் பொருளாதாரம்',
    titleEn: 'Indian Economy',
    subtitleTa: 'பொருளாதாரக் கொள்கைகள்',
    subtitleEn: 'Economic Policies',
    icon: Icons.monetization_on_rounded,
    color: Colors.brown,
    topicsTa: ['பொருளாதாரம்'],
    topicsEn: ['Economy'],
    subTopicsMapTa: {
      'பொருளாதாரம்': [
        'இந்திய பொருளாதாரத்தின் இயல்புகள்',
        'ஐந்தாண்டு திட்டங்கள் & நிதி ஆயோக்',
        'நிதி ஆணையம் & GST',
        'வங்கி முறை & RBI',
        'கிராமப்புற மேம்பாடு & சமூகத் திட்டங்கள்',
      ],
    },
    subTopicsMapEn: {
      'Economy': [
        'Nature of Indian Economy',
        'Five Year Plans & NITI Aayog',
        'Finance Commission & GST',
        'Banking System & RBI',
        'Rural Development & Social Programmes',
      ],
    },
  ),
  Subject(
    id: '8',
    titleTa: 'தமிழ்நாடு (Unit 8 & 9)',
    titleEn: 'Tamil Nadu History & Development',
    subtitleTa: 'வரலாறு, பண்பாடு & நிர்வாகம்',
    subtitleEn: 'History, Culture & Administration',
    icon: Icons.location_city_rounded,
    color: Colors.purple,
    topicsTa: ['தமிழ்நாடு வரலாறு', 'தமிழக நிர்வாகம்'],
    topicsEn: ['TN History', 'TN Administration'],
    subTopicsMapTa: {
      'தமிழ்நாடு வரலாறு': [
        'தமிழ் சமுதாய வரலாறு & தொல்லியல் கண்டுபிடிப்புகள்',
        'நீதிக்கட்சி & சுயமரியாதை இயக்கம்',
        'திராவிட இயக்கம் & சமூக சீர்திருத்தங்கள்',
      ],
      'தமிழக நிர்வாகம்': [
        'மனிதவள மேம்பாட்டுக் குறியீடு (HDI)',
        'சமூக நீதி & சமூக ஒற்றுமை',
        'தமிழக கல்வி, சுகாதாரம் & பொருளாதார வளர்ச்சி',
        'தமிழக மின் ஆளுமை (e-Governance)',
      ],
    },
    subTopicsMapEn: {
      'TN History': [
        'History of Tamil Society & Archaeological Discoveries',
        'Justice Party & Self Respect Movement',
        'Dravidian Movement & Social Reforms',
      ],
      'TN Administration': [
        'Human Development Indicators (HDI)',
        'Social Justice & Social Harmony',
        'Education, Health & Economy in TN',
        'e-Governance in Tamil Nadu',
      ],
    },
  ),
  Subject(
    id: '9',
    titleTa: 'கிராம நிர்வாகம் (VAO)',
    titleEn: 'Village Administration',
    subtitleTa: 'கிராம நிர்வாக நடைமுறைகள்',
    subtitleEn: 'Village Administrative Procedures',
    icon: Icons.foundation_rounded,
    color: Colors.deepOrange,
    topicsTa: ['நில அளவை & பதிவேடுகள்', 'அரசு நிறுவனங்கள் & பணிகள்'],
    topicsEn: ['Land Records & Survey', 'Govt Institutions & Duties'],
    subTopicsMapTa: {
      'நில அளவை & பதிவேடுகள்': ['கிராம கணக்குகள் (அடங்கல், பட்டா)', 'நில அளவை முறைகள்', 'வட்டாட்சியர் & கிராம நிர்வாக அலுவலர் பணிகள்'],
      'அரசு நிறுவனங்கள் & பணிகள்': ['வருவாய்த்துறை அமைப்புகள்', 'கிராம பஞ்சாயத்து பணிகள்', 'அரசு நலத்திட்டங்கள் & சான்றிதழ்கள்'],
    },
    subTopicsMapEn: {
      'Land Records & Survey': ['Village Accounts (Adangal, Patta)', 'Land Survey Methods', 'Duties of Tahsildar & VAO'],
      'Govt Institutions & Duties': ['Revenue Department Structure', 'Village Panchayat Functions', 'Govt Schemes & Certificates'],
    },
  ),
  Subject(
    id: '10',
    titleTa: 'திறனறிவும் மனக்கணக்கு நுண்ணறிவும்',
    titleEn: 'Aptitude & Mental Ability',
    subtitleTa: 'கணிதம், தர்க்க அறிவு & உளவியல்',
    subtitleEn: 'Maths, Reasoning & Psychology',
    icon: Icons.calculate_rounded,
    color: Colors.pink,
    topicsTa: ['கணிதம் (Aptitude)', 'உளவியல் & தர்க்க அறிவு (Psychology)'],
    topicsEn: ['Aptitude', 'Psychology & Reasoning'],
    subTopicsMapTa: {
      'கணிதம் (Aptitude)': [
        'சுருக்குதல் (Simplification)',
        'விழுக்காடு (Percentage)',
        'மீப்பெரு பொது காரணி (HCF) & மீச்சிறு பொது மடங்கு (LCM)',
        'விகிதம் மற்றும் விகிதாச்சாரம் (Ratio & Proportion)',
        'தனிவட்டி (Simple Interest)',
        'கூட்டுவட்டி (Compound Interest)',
        'பரப்பளவு (Area) & கொள்ளளவு (Volume)',
        'நேரம் மற்றும் வேலை (Time & Work)',
        'சராசரி (Average)',
        'வயது கணக்குகள் (Problems on Ages)',
        'லாபம் மற்றும் நஷ்டம் (Profit & Loss)',
        'பகடை & நிகழ்த்தகவு (Dice & Probability)',
        'எண்கள் (Number System)',
      ],
      'உளவியல் & தர்க்க அறிவு (Psychology)': [
        'எண் மற்றும் எழுத்துத் தொடர்கள் (Number & Alphabet Series)',
        'புதிர்கள் (Puzzles)',
        'தொடர்புகள் மற்றும் திசைகள் (Blood Relations & Directions)',
        'வரைபடங்கள் மற்றும் விளக்கங்கள் (Visual Reasoning)',
        'தகவல் கையாளுதல் திறன் (Data Interpretation)',
        'குறியீடுதல் மற்றும் குறியீடழித்தல் (Coding & Decoding)',
        'மனத்திறன் மற்றும் முடிவெடுத்தல் (Mental Ability & Decision Making)',
      ],
    },
    subTopicsMapEn: {
      'Aptitude': [
        'Simplification',
        'Percentage',
        'HCF & LCM',
        'Ratio and Proportion',
        'Simple Interest',
        'Compound Interest',
        'Area & Volume',
        'Time & Work',
        'Average',
        'Problems on Ages',
        'Profit & Loss',
        'Dice & Probability',
        'Number System',
      ],
      'Psychology & Reasoning': [
        'Number & Alphabet Series',
        'Puzzles',
        'Blood Relations & Directions',
        'Visual Reasoning',
        'Data Interpretation',
        'Coding & Decoding',
        'Mental Ability & Decision Making',
      ],
    },
  ),
  Subject(
    id: '12',
    titleTa: 'நடப்பு நிகழ்வுகள்',
    titleEn: 'Current Affairs',
    subtitleTa: 'தினசரி செய்திகள்',
    subtitleEn: 'Daily Updates',
    icon: Icons.newspaper_rounded,
    color: Colors.teal,
    topicsTa: ['பொதுச் செய்திகள்', 'முக்கிய நிகழ்வுகள்'],
    topicsEn: ['General News', 'Important Events'],
    subTopicsMapTa: {
      'பொதுச் செய்திகள்': ['தமிழ்நாடு நிகழ்வுகள்', 'தேசிய நிகழ்வுகள்', 'சர்வதேச நிகழ்வுகள்'],
      'முக்கிய நிகழ்வுகள்': ['அரசு திட்டங்கள் & கொள்கைகள்', 'அறிவியல் & தொழில்நுட்பம்', 'விளையாட்டு, நூல்கள் & விருதுகள்', 'முக்கிய தினங்கள்'],
    },
    subTopicsMapEn: {
      'General News': ['Tamil Nadu Events', 'National Events', 'International Events'],
      'Important Events': ['Government Schemes & Policies', 'Science & Tech', 'Sports, Books & Awards', 'Important Days'],
    },
  ),
];
