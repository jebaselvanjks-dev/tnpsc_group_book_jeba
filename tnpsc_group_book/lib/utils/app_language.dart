import 'package:flutter/material.dart';
import '../services/hive_service.dart';
import '../services/ai_service.dart';

class AppLanguage {
  static final ValueNotifier<String> languageNotifier = ValueNotifier<String>(HiveService.getLanguage());

  static void changeLanguage(String code) {
    languageNotifier.value = code;
    HiveService.saveLanguage(code);
  }

  static String getString(String key) {
    bool ta = languageNotifier.value == 'ta';
    switch (key) {
      case 'settings':
        return ta ? 'அமைப்புகள்' : 'Settings';
      case 'appearance':
        return ta ? 'தோற்றம்' : 'Appearance';
      case 'dark_theme':
        return ta ? 'இருண்ட கருப்பொருள்' : 'Dark Theme';
      case 'dark_theme_desc':
        return ta ? 'ஒளி, இருண்ட கருப்பொருளை மாற்றவும்' : 'Switch between light and dark themes';
      case 'system_theme':
        return ta ? 'கணினி கருப்பொருள்' : 'System Theme';
      case 'system_theme_desc':
        return ta ? 'சாதனத்தின் இயல்புநிலையைப் பயன்படுத்தவும்' : 'Use device default theme';
      case 'language':
        return ta ? 'மொழி' : 'Language';
      case 'language_desc':
        return ta ? 'தமிழ் மற்றும் ஆங்கில மொழி' : 'Choose Tamil or English';
      case 'about_app':
        return ta ? 'பயன்பாட்டைப் பற்றி' : 'About App';
      case 'app_version':
        return ta ? 'செயலி பதிப்பு' : 'App Version';
      case 'update_available':
        return ta ? 'புதிய பதிப்பு கிடைக்கிறது' : 'Update Available';
      case 'update_desc':
        return ta ? 'செயலியின் புதிய பதிப்பு கிடைக்கிறது. சிறந்த அனுபவத்திற்கு இப்போதே புதுப்பிக்கவும்.' : 'A new version of the app is available. Please update now for a better experience.';
      case 'update_now':
        return ta ? 'இப்போதே புதுப்பி' : 'Update Now';
      case 'update_required_title':
        return ta ? 'புதுப்பித்தல் அவசியம்' : 'Update Required';
      case 'update_required_desc':
        return ta ? 'இந்த அம்சத்தைப் பயன்படுத்த, செயலியை சமீபத்திய பதிப்பிற்குப் புதுப்பிக்கவும்.' : 'Please update the app to the latest version to access this feature.';
      case 'privacy_policy':
        return ta ? 'தனியுரிமைக் கொள்கை' : 'Privacy Policy';
      case 'terms_conditions':
        return ta ? 'விதிமுறைகள் & நிபந்தனைகள்' : 'Terms & Conditions';
      case 'app_title':
        return 'TNPSC Master';
      case 'home':
        return ta ? 'முகப்பு' : 'Home';
      case 'books':
        return ta ? 'புத்தகங்கள்' : 'Books';
      case 'book':
        return ta ? 'புத்தகம்' : 'Book';
      case 'rank':
        return ta ? 'தரவரிசை' : 'Rank';
      case 'profile':
        return ta ? 'சுயவிவரம்' : 'Profile';
      case 'greeting':
        return ta ? 'வணக்கம்' : 'Hello';
      case 'ready_to_crack':
        return ta ? 'இன்று TNPSC தேர்வை வெல்லத் தயாரா?' : 'Ready to crack TNPSC today?';
      case 'today_quiz_ready':
        return ta ? 'இன்றைய வினாடி வினா தயார்! ✅' : "Today's Quiz Ready! ✅";
      case 'daily_quiz':
        return ta ? 'தினசரி வினாடி வினா' : 'Daily Quiz';
      case 'daily_quiz_ready':
        return ta ? 'இன்றைய வினாடி வினா தயார்! ✅' : "Today's Quiz Ready! ✅";
      case 'mock_quiz':
        return ta ? '50 கேள்விகள் – 2 நாட்களுக்கு ஒருமுறை' : '50 Questions – Once Every 2 Days';
      case 'mock_quiz_ready':
        return ta ? 'இன்றைய 50 வினாடி வினா தயார்! ✅' : "Today's 50 Quiz Ready! ✅";
      case 'start_now':
        return ta ? 'இப்போதே தொடங்கு' : 'Start Now';
      case 'questions_10':
        return ta ? '10 கேள்விகள்' : '10 Questions';
      case 'mins_5':
        return ta ? '10 நிமிடங்கள்' : '10 mins';
      case 'start_quiz':
        return ta ? 'வினாடி வினாவைத் தொடங்கு' : 'Start Quiz';
      case 'view_top_10':
        return ta ? 'டாப் 10 பேரைப் பார்க்க' : 'View Top 10';
      case 'mock_tests':
        return ta ? 'மாதிரித் தேர்வுகள்' : 'Mock Tests';
      case 'mock_test_desc':
        return ta ? '50 கேள்விகள்\n30 நிமிடம்' : '50 Qns\n30 min';
      case 'subjects':
        return ta ? 'பாடங்கள்' : 'Subjects';
      case 'select_category':
        return ta ? 'உங்கள் வினாடி வினாவைத் தொடங்க ஒரு வகையைத் தேர்ந்தெடுக்கவும்' : 'Select a category to start your quiz';
      case 'days':
        return ta ? 'நாட்கள்' : 'Days';
      case 'ask_ai_explain':
        return ta ? 'AI-யிடம் விளக்கம் கேட்க' : 'Ask AI for explanation';
      case 'ai_thinking':
        return ta ? 'AI விளக்கம் அளிக்கிறது...' : 'AI is thinking...';
      case 'mistake_bank':
        return ta ? 'தவறு செய்த வினாக்கள்' : 'Mistake Bank';
      case 'reattempt_all':
        return ta ? 'அனைத்தையும் மீண்டும் முயற்சி செய்' : 'Re-attempt All';
      case 'no_mistakes_title':
        return ta ? 'சிறப்பு! தவறுகள் ஏதுமில்லை' : 'Excellent! No Mistakes';
      case 'no_mistakes_desc':
        return ta ? 'நீங்கள் அனைத்து கேள்விகளுக்கும் சரியாக பதிலளித்துள்ளீர்கள். இப்படியே தொடருங்கள்!' : 'You have answered all questions correctly. Keep up the great work!';
      case 'correct_answer':
        return ta ? 'சரியான விடை' : 'Correct Answer';
      case 'bookmarks':
        return ta ? 'சேமித்த வினாக்கள்' : 'Bookmarks';
      case 'no_bookmarks_title':
        return ta ? 'சேமித்த வினாக்கள் எதுவுமில்லை' : 'No Bookmarks Yet';
      case 'no_bookmarks_desc':
        return ta ? 'உங்களுக்குப் பிடித்த அல்லது கடினமான வினாக்களைப் பிற்காலத்தில் படிக்கச் சேமித்து வைக்கலாம்.' : 'Save your favorite or difficult questions to study later.';
      case 'your_strength':
        return ta ? 'உங்கள் பலம்' : 'Your Strength';
      case 'next_quiz':
        return ta ? 'அடுத்த தேர்வு' : 'Next Quiz';
      case 'prev_quiz':
        return ta ? 'முந்தைய தேர்வு' : 'Prev Quiz';
      case 'ai_tutor':
        return ta ? 'AI உதவியாளர்' : 'AI Tutor';
      case 'ai_tutor_welcome_title':
        return ta ? 'வணக்கம்! நான் உங்கள் AI Tutor' : 'Hello! I am your AI Tutor';
      case 'ai_tutor_welcome_desc':
        return ta ? 'உங்களுக்குத் தேவையான சந்தேகங்களை இங்கே கேட்கலாம். நான் உங்களுக்கு தமிழ் மற்றும் ஆங்கிலத்தில் விளக்குகிறேன்.' : 'Ask me any study-related doubts. I will explain to you in Tamil and English.';
      case 'ask_ai_hint':
        return ta ? 'உங்களின் சந்தேகத்தைக் கேட்கவும்...' : 'Type your doubt here...';
      case 'ai_limit_reached':
        return ta ? 'இன்றைய AI வரம்பு முடிந்தது. நாளை மீண்டும் முயற்சிக்கவும்.' : 'Daily AI limit reached. Please try again tomorrow.';
      case 'my_history':
        return ta ? 'எனது வரலாறு' : 'My History';
      case 'no_history_title':
        return ta ? 'வரலாறு ஏதுமில்லை' : 'No History Yet';
      case 'no_history_desc':
        return ta ? 'நீங்கள் விளையாடும் தேர்வுகள் இங்கே சேமிக்கப்படும்.' : 'Quizzes you play will appear here.';
      case 'view_all':
        return ta ? 'அனைத்தையும் பார்' : 'View All';
      case 'completed':
        return ta ? 'முடிக்கப்பட்டது' : 'Completed';
      case 'quizzes':
        return ta ? 'வினாடி வினாக்கள்' : 'Quizzes';
      case 'points':
        return ta ? 'புள்ளிகள்' : 'Points';
      case 'quick_settings':
        return ta ? 'விரைவான அமைப்புகள்' : 'Quick Settings';
      case 'more':
        return ta ? 'மேலும்' : 'More';
      case 'app_settings':
        return ta ? 'பயன்பாட்டு அமைப்புகள்' : 'App Settings';
      case 'admin_panel':
        return ta ? 'நிர்வாக குழு' : 'Admin Panel';
      case 'logout':
        return ta ? 'வெளியேறு' : 'Logout';
      case 'leaderboard':
        return ta ? 'தரவரிசைப் பட்டியல்' : 'Leaderboard';
      case 'time_up':
        return ta ? 'நேரம் முடிந்தது!' : "Time's Up!";
      case 'time_up_desc':
        return ta ? 'இந்தத் தேர்வுக்கான நேரம் முடிந்துவிட்டது. உங்கள் முடிவுகளைப் பார்க்கலாம்.' : 'The time for this quiz has expired. Let\'s see your results.';
      case 'view_result':
        return ta ? 'முடிவுகளைப் பார்' : 'View Results';
      case 'time_left':
        return ta ? 'மீதமுள்ள நேரம்' : 'Time Left';
      case 'sec':
        return ta ? 'நொடி' : 'sec';
      case 'min':
        return ta ? 'நிமிடம்' : 'min';
      case 'no_results_today':
        return ta ? 'இன்று தரவுகள் ஏதுமில்லை' : 'No results for today yet';
      case 'best_performance_today':
        return ta ? 'இன்றைய உங்களின் சிறந்த செயல்பாடு' : 'Your Best Performance Today';
      case 'you_label':
        return ta ? 'நீங்கள்' : 'You';
      case 'score':
        return ta ? 'மதிப்பெண்' : 'Score';
      case 'daily':
        return ta ? 'தினசரி வினா மதிப்பெண்' : 'Daily Quiz Score';
      case 'mock':
        return ta ? 'மாதிரி வினா மதிப்பெண்' : 'Mock Quiz Score';
      case 'rewards_gifts':
        return ta ? 'பரிசுகள் & வெகுமதிகள்' : 'Rewards & Gifts';
      case 'watch_ad_points':
        return ta ? 'விளம்பரத்தைப் பார்த்து புள்ளிகளைப் பெறுங்கள்' : 'Watch Ad & Earn Points';
      case 'support_us_points':
        return ta ? 'எங்களை ஆதரித்து இலவச புள்ளிகளைப் பெறுங்கள்!' : 'Support us and get free points!';
      case 'revision_tools':
        return ta ? 'திருப்புதல் கருவிகள்' : 'Revision Tools';
      case 'saved_questions':
        return ta ? 'சேமிக்கப்பட்ட கேள்விகள்' : 'Saved Questions';
      case 'saved_questions_desc':
        return ta ? 'நீங்கள் குறித்த கேள்விகளைத் திருப்புதல் செய்யுங்கள்' : 'Revise your bookmarked questions';
      case 'support':
        return ta ? 'ஆதரவு' : 'Support';
      case 'feedback_support':
        return ta ? 'கருத்து & ஆதரவு' : 'Feedback & Support';
      case 'report_bugs':
        return ta ? 'பிழைகளைப் புகாரளிக்கவும் அல்லது அம்சங்களைப் பரிந்துரைக்கவும்' : 'Report bugs or suggest features';
      case 'storage_offline':
        return ta ? 'சேமிப்பகம் & ஆஃப்லைன்' : 'Storage & Offline';
      case 'clear_offline_data':
        return ta ? 'ஆஃப்லைன் தரவை நீக்குக' : 'Clear Offline Data';
      case 'clear_cache_desc':
        return ta ? 'இடம் காலியாக்க தற்காலிகச் சேமிப்பை நீக்கவும்' : 'Remove cached quizzes to free up space';
      case 'rewards_success':
        return ta ? "வாழ்த்துக்கள்! உங்களுக்கு 10 புள்ளிகள் கிடைத்துள்ளன! 🎁" : "Congratulations! You got 10 points! 🎁";
      case 'question':
        return ta ? 'கேள்வி' : 'Question';
      case 'next':
        return ta ? 'அடுத்தது' : 'Next';
      case 'submit':
        return ta ? 'சமர்ப்பி' : 'Submit';
      case 'end':
        return ta ? 'முடி' : 'End';
      case 'no_questions':
        return ta ? 'இந்த தலைப்பிற்கான கேள்விகள் எதுவும் கிடைக்கவில்லை.' : 'No questions found for this topic.';
      case 'generate_questions_desc':
        return ta ? 'தயவுசெய்து ஆப் அமைப்புகளில் இருந்து கேள்விகளை உருவாக்கவும்.' : 'Please generate questions from App Settings.';
      case 'go_back':
        return ta ? 'திரும்பிச் செல்ல' : 'Go Back';
      case 'added_to_bookmarks':
        return ta ? 'புத்தகக் குறிகளில் சேர்க்கப்பட்டது' : 'Added to bookmarks';
      case 'removed_from_bookmarks':
        return ta ? 'புத்தகக் குறிகளில் இருந்து அகற்றப்பட்டது' : 'Removed from bookmarks';
      case 'outstanding':
        return ta ? 'சிறப்பானது!' : 'Outstanding!';
      case 'well_done':
        return ta ? 'நன்று!' : 'Well done!';
      case 'good_effort':
        return ta ? 'நல்ல முயற்சி!' : 'Good effort!';
      case 'quiz_completed':
        return ta ? 'நீங்கள் வினாடி வினாவை முடித்துவிட்டீர்கள்.' : 'You have completed the quiz.';
      case 'accuracy':
        return ta ? 'துல்லியம்' : 'Accuracy';
      case 'speed':
        return ta ? 'வேகம்' : 'Speed';
      case 'time':
        return ta ? 'நேரம்' : 'Time';
      case 'missed_quiz':
        return ta ? 'பதிலளிக்காத வினாக்கள்' : 'Missed Quiz';
      case 'smart_weak_analysis':
        return ta ? 'உங்கள் பலம் பலவீனம்' : 'Smart Weak Analysis';
      case 'correct_answers':
        return ta ? 'சரியான பதில்கள்' : 'Correct Answers';
      case 'share_scorecard':
        return ta ? 'மதிப்பெண் அட்டையைப் பகிர்க' : 'Share Scorecard';
      case 'review_answers':
        return ta ? 'பதில்களைச் சரிபார்க்கவும்' : 'Review Answers';
      case 'go_home':
        return ta ? 'முகப்பிற்குச் செல்க' : 'Go Home';
      case 'share_text':
        return ta ? 'நான் TNPSC Master ஆப்பில் {score}/{total} மதிப்பெண்கள் எடுத்துள்ளேன்! 🎯 நீங்களும் முயற்சி செய்யுங்கள்!' : 'I scored {score}/{total} on TNPSC Master App! 🎯 Try it yourself!';
      case 'prepare_anywhere':
        return ta ? 'எங்கிருந்தும், எந்த நேரத்திலும் தயாராகுங்கள்!' : 'Prepare Anywhere, Anytime!';
      case 'download_app':
        return ta ? 'TNPSC Master செயலியைப் பதிவிறக்கவும் 🚀' : 'Download TNPSC Master App 🚀';
      case 'your_answer':
        return ta ? 'உங்கள் பதில்:' : 'Your Answer:';
      case 'correct_answer_label':
        return ta ? 'சரியான பதில்:' : 'Correct Answer:';
      case 'your_answer_correct':
        return ta ? 'உங்கள் பதில் (சரி):' : 'Your Answer (Correct):';
      case 'explanation':
        return ta ? 'விளக்கம்:' : 'Explanation:';
      case 'no_bookmarks':
        return ta ? 'புத்தகக் குறிகள் எதுவும் இல்லை!' : 'No bookmarks yet!';
      case 'exam':
        return ta ? 'தேர்வு' : 'Exam';
      case 'study':
        return ta ? 'படிப்பு' : 'Study';
      case 'ready_for_test':
        return ta ? 'தேர்வுக்கு தயாரா?' : 'Ready for the test?';
      case 'test_knowledge':
        return ta ? 'இந்த தலைப்பில் உங்கள் அறிவை சோதிக்கவும்.' : 'Test your knowledge on this topic.';
      case 'start_test':
        return ta ? 'தேர்வைத் தொடங்கு' : 'Start Test';
      case 'study_material_preparing':
        return ta ? 'பாடக்குறிப்புகள் தயார் செய்யப்படுகின்றன...' : 'Study material is being prepared...';
      case 'mock_tests_title':
        return ta ? 'மாதிரித் தேர்வுகள் 🎯' : 'Mock Tests 🎯';
      case 'no_mock_tests':
        return ta ? 'மாதிரித் தேர்வுகள் இன்னும் கிடைக்கவில்லை.' : 'No Mock Tests Available Yet.';
      case 'available':
        return ta ? 'கிடைக்கிறது' : 'AVAILABLE';
      case 'unlocks_in':
        return ta ? '{days} நாட்களில் திறக்கும்' : 'UNLOCKS IN {days} DAYS';
      case 'previous_test':
        return ta ? 'முந்தையத் தேர்வு' : 'PREVIOUS TEST';
      case 'active_now':
        return ta ? 'தற்போது செயலில் உள்ளது ({days} நாட்களில் முடியும்)' : 'ACTIVE NOW (Ends in {days} Days)';
      case 'questions_count_label':
        return ta ? '{count} கேள்விகள்' : '{count} Questions';
      case 'one_hour':
        return ta ? '1 மணிநேரம்' : '1 Hour';
      case 'locked':
        return ta ? 'பூட்டப்பட்டுள்ளது' : 'Locked';
      case 'review_previous_test':
        return ta ? 'முந்தைய தேர்வைச் சரிபார்க்கவும்' : 'Review Previous Test';
      case 'start_mock_test':
        return ta ? 'மாதிரித் தேர்வைத் தொடங்கு' : 'Start Mock Test';
      case 'welcome_title':
        return ta ? 'TNPSC Master-க்கு வரவேற்கிறோம் 👋' : 'Welcome to TNPSC Master 👋';
      case 'login_desc':
        return ta ? 'உங்கள் தயாரிப்பைத் தொடர உங்கள் மொபைல் எண்ணுடன் உள்நுழையவும்.' : 'Login with your mobile number to continue your preparation.';
      case 'user_name_hint':
        return ta ? 'பயனர் பெயர்' : 'User Name';
      case 'mobile_number_hint':
        return ta ? 'மொபைல் எண்' : 'Mobile Number';
      case 'continue':
        return ta ? 'தொடரவும்' : 'Continue';
      case 'verify_login':
        return ta ? 'சரிபார்த்து உள்நுழையவும்' : 'Verify & Login';
      case 'change_mobile':
        return ta ? 'மொபைல் எண்ணை மாற்றவும்' : 'Change Mobile Number';
      case 'or':
        return ta ? 'அல்லது' : 'OR';
      case 'google_login':
        return ta ? 'Google மூலம் தொடரவும்' : 'Continue with Google';
      case 'invalid_mobile':
        return ta ? 'சரியான 10 இலக்க மொபைல் எண்ணை உள்ளிடவும்' : 'Please enter a valid 10-digit mobile number';
      case 'invalid_otp':
        return ta ? 'சரியான OTP-ஐ உள்ளிடவும்' : 'Please enter a valid OTP';
      case 'verification_failed':
        return ta ? 'சரிபார்ப்பு தோல்வியடைந்தது' : 'Verification Failed';
      case 'invalid_otp_error':
        return ta ? 'தவறான OTP' : 'Invalid OTP';
      case 'feedback_title':
        return ta ? 'கருத்து மற்றும் ஆதரவு ✉️' : 'Feedback & Support ✉️';
      case 'help_improve':
        return ta ? 'நாங்கள் மேம்பட உதவுங்கள்!' : 'Help us improve!';
      case 'feedback_desc':
        return ta ? 'பிழையைக் கண்டீர்களா? ஆலோசனை உள்ளதா? அல்லது கூடுதல் பாடங்கள் வேண்டுமா? அனைத்தையும் எங்களிடம் கூறுங்கள்.' : 'Found a bug? Have a suggestion? Or need more subjects? Tell us everything.';
      case 'feedback_hint':
        return ta ? 'உங்கள் செய்தியை இங்கே தட்டச்சு செய்யவும்...' : 'Type your message here...';
      case 'submit_feedback':
        return ta ? 'கருத்தைச் சமர்ப்பிக்கவும்' : 'Submit Feedback';
      case 'reach_us':
        return ta ? 'அல்லது support@tnpscmaster.com இல் எங்களைத் தொடர்பு கொள்ளவும்' : 'Or reach us at support@tnpscmaster.com';
      case 'thank_you':
        return ta ? 'நன்றி! 🙏' : 'Thank You! 🙏';
      case 'feedback_success':
        return ta ? 'உங்கள் கருத்து வெற்றிகரமாக அனுப்பப்பட்டது. உங்கள் பங்களிப்பிற்கு நன்றி!' : 'Your feedback has been sent successfully. We appreciate your input!';
      case 'enter_message':
        return ta ? 'முதலில் உங்கள் செய்தியை உள்ளிடவும்.' : 'Please enter your message first.';
      case 'feedback_fail':
        return ta ? 'கருத்தை அனுப்ப முடியவில்லை. மீண்டும் முயற்சிக்கவும்.' : 'Failed to send feedback. Please try again.';
      case 'select_topic_desc':
        return ta ? 'பயிற்சியைத் தொடங்க ஒரு தலைப்பைத் தேர்ந்தெடுக்கவும்' : 'Select a topic to start practicing';
      case 'anonymous':
        return ta ? 'பெயரிடப்படாதவர்' : 'Anonymous';
      case 'tagline':
        return ta ? 'தினசரி பயிற்சி. தினசரி வெற்றி.' : 'Daily Practice. Daily Success.';
      case 'school_books':
        return ta ? 'பள்ளிப் பாடப்புத்தகங்கள்' : 'School Books';
      case 'class_label':
        return ta ? '{count}-ஆம் வகுப்பு' : 'Class {count}';
      case 'new_edition':
        return ta ? '2024 புதிய பதிப்பு' : '2024 New Edition';
      case 'no_phone_linked':
        return ta ? 'போன் எண் இணைக்கப்படவில்லை' : 'No Phone Linked';
      case 'admin_controls_desc':
        return ta ? 'நிர்வாகக் கட்டுப்பாடுகள் & விருப்பங்கள்' : 'Admin controls & preferences';
      case 'clear_cache_warning':
        return ta ? 'இது பதிவிறக்கம் செய்யப்பட்ட அனைத்து வினாடி வினாக்களையும் அகற்றும். அவற்றை மீண்டும் அணுக இணையம் தேவைப்படும்.' : 'This will remove all downloaded quizzes. You will need internet to access them again.';
      case 'cancel':
        return ta ? 'ரத்துசெய்' : 'Cancel';
      case 'clear_action':
        return ta ? 'நீக்கு' : 'Clear';
      case 'cache_cleared_success':
        return ta ? 'தற்காலிகச் சேமிப்பு வெற்றிகரமாக நீக்கப்பட்டது!' : 'Offline cache cleared successfully!';
      case 'ok':
        return ta ? 'சரி' : 'OK';
      case 'generate_ai':
        return ta ? 'AI மூலம் உருவாக்குக ✨' : 'Generate with AI ✨';
      case 'user_fallback':
        return ta ? 'ஆர்வலர்' : 'Aspirant';
      case 'na':
        return ta ? 'கிடைக்கவில்லை' : 'N/A';
      case 'sec_per_q':
        return ta ? '{val} வினா / வினா' : '{val} sec / q';
      case 'quizzes_exist':
        return ta ? 'இன்றைய மற்றும் நாளைய தேர்வுகள் ஏற்கனவே உள்ளன!' : 'Today and tomorrow\'s quizzes already exist!';
      case 'sync_success':
        return ta ? 'அனைத்து கேள்விகளும் வெற்றிகரமாக ஒத்திசைக்கப்பட்டன!' : 'All questions synced to Firestore!';
      case 'clear_cloud_data':
        return ta ? 'கிளவுட் தரவை நீக்கு' : 'Clear All Cloud Data';
      case 'clear_confirm_title':
        return ta ? 'அனைத்து தரவையும் நீக்கவா?' : 'Clear All Data?';
      case 'clear_confirm_desc':
        return ta ? 'இது அனைத்து வினாடி வினாக்களையும் நீக்கிவிடும். இதை மாற்ற முடியாது.' : 'This will delete all quizzes from Firestore. This cannot be undone.';
      case 'delete_everything':
        return ta ? 'அனைத்தையும் நீக்கு' : 'Delete Everything';
      case 'data_cleared':
        return ta ? 'கிளவுட் தரவு நீக்கப்பட்டது!' : 'All cloud data cleared!';
      case 'ai_quota_exceeded':
        return ta ? 'இன்றைய AI வரம்பு முடிந்தது 🛑' : 'AI daily limit reached 🛑';
      case 'scanning_duplicates':
        return ta ? 'நகல்களைத் தேடுகிறது...' : 'Scanning for duplicates...';
      case 'upload_success':
        return ta ? 'வெற்றிகரமாக {count} கேள்விகள் பதிவேற்றப்பட்டன! 🎉' : 'Successfully uploaded {count} questions! 🎉';
      case 'admin_dashboard':
        return ta ? 'நிர்வாக முகப்பு ⚙️' : 'Admin Dashboard ⚙️';
      case 'total_users':
        return ta ? 'மொத்த பயனர்கள்' : 'Total Users';
      case 'total_questions':
        return ta ? 'மொத்த கேள்விகள்' : 'Total Questions';
      case 'question_mgmt':
        return ta ? 'கேள்வி மேலாண்மை' : 'Question Management';
      case 'user_stats':
        return ta ? 'பயனர் புள்ளிவிவரங்கள்' : 'User Statistics';
      case 'notif_title':
        return ta ? 'இன்றைய குவிஸ் தயார்! 🧠' : 'Today\'s Quiz is Ready! 🧠';
      case 'notif_body':
        return ta ? 'இன்றைய TNPSC சவாலில் கலந்துகொண்டு உங்கள் அறிவைச் சோதியுங்கள்!' : 'Take today\'s TNPSC challenge and test your knowledge!';
      case 'reminder_title':
        return ta ? 'குழுத் தேர்வு நேரம்! ⚔️' : 'Group Test Time! ⚔️';
      case 'reminder_body':
        return ta ? 'உங்கள் நண்பர்களுடன் இணைந்து குழுத் தேர்வை இப்போதே தொடங்குங்கள்!' : 'Join with your friends and start the group test now!';
      case 'study_challenge':
        return ta ? 'TNPSC Master - இன்றைய சவால்!' : 'TNPSC Master - Today\'s Challenge!';
      case 'start_quiz_now':
        return ta ? 'இன்றைய வினாடி வினாவைத் தொடங்கி வெற்றி பெறுங்கள்!' : 'Start today\'s quiz and win!';
      case 'view_edit_questions':
        return ta ? 'கேள்விகளைக் காண & திருத்த' : 'View & Edit Questions';
      case 'modify_q_desc':
        return ta ? 'கேள்விகள் மற்றும் பதில்களை மாற்றவும்.' : 'Modify questions and answers.';
      case 'find_del_duplicates':
        return ta ? 'நகல்களைக் கண்டறிந்து நீக்குக' : 'Find & Delete Duplicates';
      case 'scan_remove_desc':
        return ta ? 'மீண்டும் மீண்டும் வரும் கேள்விகளைத் தானாகவே நீக்குகிறது.' : 'Automatically scans and removes repeated questions.';
      case 'upload_json':
        return ta ? 'JSON பதிவேற்றவும் (AI வடிவம்)' : 'Upload JSON (AI Format)';
      case 'bulk_upload_desc':
        return ta ? 'AI உருவாக்கிய கேள்விகளை மொத்தமாகப் பதிவேற்றவும்.' : 'Bulk upload AI generated questions.';
      case 'view_users_ranks':
        return ta ? 'பயனர்கள் & தரவரிசைகளைப் பார்க்க' : 'View All Users & Ranks';
      case 'check_perf_desc':
        return ta ? 'தனிநபர் செயல்திறனைச் சரிபார்க்கவும்.' : 'Check individual performance.';
      case 'ai_automation':
        return ta ? 'AI ஆட்டோமேஷன்' : 'AI Automation';
      case 'gen_today_quiz':
        return ta ? 'இன்றைய குவிஸ் உருவாக்கு' : "Generate Today's Quiz";
      case 'use_gemini_desc':
        return ta ? 'இன்றைய குவிஸ் உருவாக்க Gemini AI-ஐப் பயன்படுத்துகிறது.' : "Uses Gemini AI to create today's daily quiz.";
      case 'clear_regen_quiz':
        return ta ? 'மீண்டும் குவிஸ் உருவாக்கு' : 'Clear & Regen Daily Quiz';
      case 'delete_regen_desc':
        return ta ? 'இன்றைய குவிஸை நீக்கிவிட்டு புதிய ஒன்றை உருவாக்குகிறது.' : 'Deletes today\'s quiz and generates a new one.';
      case 'gen_7day_batch':
        return ta ? '7-நாள் தொகுப்பை உருவாக்கு' : 'Generate 7-Days Daily Batch';
      case 'gen_20q_desc':
        return ta ? 'அடுத்த 7 நாட்களுக்குத் தலா 20 கேள்விகளை உருவாக்குகிறது.' : 'Generates 20 questions each for the next 7 days.';
      case 'create_50q_mock':
        return ta ? '50-கேள்வி மாதிரித் தேர்வு' : 'Create 50-Question Mock Test';
      case 'full_length_desc':
        return ta ? 'முழு நீள 50 கேள்விகள் கொண்ட TNPSC தேர்வு.' : 'Full-length 50 questions TNPSC exam.';
      case 'manual_broadcast':
        return ta ? 'கைமுறை அறிவிப்பு' : 'Manual Broadcast';
      case 'send_notif_all':
        return ta ? 'அனைவருக்கும் அறிவிப்பு அனுப்பவும்' : 'Send Notification to All';
      case 'custom_msg_desc':
        return ta ? 'ஒவ்வொரு பயனருக்கும் தனிப்பயன் செய்தியை அனுப்பவும்.' : 'Send a custom message to every user.';
      case 'upload_ai_title':
        return ta ? 'AI கேள்விகளைப் பதிவேற்றவும் (JSON)' : 'Upload AI Questions (JSON)';
      case 'paste_json_hint':
        return ta ? 'JSON வரிசையை இங்கே ஒட்டவும்...' : 'Paste JSON array here...';
      case 'cancel_btn':
        return ta ? 'ரத்து' : 'Cancel';
      case 'upload_btn':
        return ta ? 'பதிவேற்றவும்' : 'Upload';
      case 'success_title':
        return ta ? 'வெற்றி! 🎉' : 'Success! 🎉';
      case 'daily_quiz_gen_success':
        return ta ? 'இன்றைய வினாடி வினா உருவாக்கப்பட்டு கிளவுட்டில் பதிவேற்றப்பட்டது. இப்போதே பார்க்க விரும்புகிறீர்களா?' : 'Daily Quiz generated and uploaded to Firestore. Would you like to view it now?';
      case 'maybe_later':
        return ta ? 'பிறகு பார்க்கலாம்' : 'Maybe Later';
      case 'view_quiz':
        return ta ? 'வினாடி வினாவைப் பார்' : 'View Quiz';
      case 'gen_daily_loading':
        return ta ? 'இன்றைய வினாடி வினாவை உருவாக்குகிறது...' : 'Generating Daily Quiz...';
      case 'regen_daily_loading':
        return ta ? 'மீண்டும் வினாடி வினாவை உருவாக்குகிறது...' : 'Regenerating Daily Quiz...';
      case 'prep_7day_loading':
        return ta ? '7-நாள் தொகுப்பைத் தயார் செய்கிறது...' : 'Preparing 7-Day Batch...';
      case 'gen_mock_loading':
        return ta ? 'மாதிரித் தேர்வை உருவாக்குகிறது...' : 'Generating Mock Test...';
      case 'mock_test_scheduled':
        return ta ? '{date}-க்கு மாதிரித் தேர்வு திட்டமிடப்பட்டது! 📅' : 'Mock Test Scheduled for {date}! 📅';
      case 'broadcast_title':
        return ta ? 'அறிவிப்பு செய்தி 📢' : 'Broadcast Message 📢';
      case 'title_label':
        return ta ? 'தலைப்பு' : 'Title';
      case 'message_body_label':
        return ta ? 'செய்தி உடல்' : 'Message Body';
      case 'send_now':
        return ta ? 'இப்போதே அனுப்பு' : 'Send Now';
      case 'broadcast_success':
        return ta ? 'அறிவிப்பு வெற்றிகரமாக அனுப்பப்பட்டது! 🚀' : 'Broadcast sent successfully! 🚀';
      case 'pdf_label':
        return 'PDF';
      case 'general_category':
        return ta ? 'பொது' : 'General';
      case 'admin_dashboard_label':
        return ta ? 'நிர்வாக முகப்பு' : 'Admin Dashboard';
      case 'manage_q_desc':
        return ta ? 'கேள்விகள், பயனர்கள் மற்றும் AI-ஐ நிர்வகிக்கவும்' : 'Manage questions, users, and AI automation';
      case 'gen_ai_quizzes':
        return ta ? 'AI வினாடி வினாக்களை உருவாக்கு' : 'Generate AI Quizzes';
      case 'create_today_tomorrow':
        return ta ? '7 நாட்களுக்கான வினாடி வினாக்களை உருவாக்கு' : 'Create quizzes for 7 days';
      case 'ai_gen_3days':
        return ta ? 'AI 7 நாட்களுக்கான வினாடி வினாக்களை உருவாக்குகிறது...' : 'AI is generating 7 days of quizzes...';
      case 'gen_success_count':
        return ta ? '{count}/3 நாட்கள் வெற்றிகரமாகச் சரிபார்க்கப்பட்டு உருவாக்கப்பட்டது!' : 'Checked & Generated {count}/3 days successfully!';
      case 'upload_local_q':
        return ta ? 'உள்ளூர் கேள்விகளைப் பதிவேற்றவும்' : 'Upload Local Questions';
      case 'sync_local_firestore':
        return ta ? 'அனைத்து உள்ளூர் கேள்விகளையும் கிளவுட்டுடன் ஒத்திசைக்கவும்' : 'Sync all local questions to Firestore';
      case 'wipe_firestore_desc':
        return ta ? 'கிளவுட்டில் உள்ள அனைத்து கேள்விகளையும் நீக்குக' : 'Wipe all questions from Firestore';
      case 'notif_daily_quiz_ready_title':
        return ta ? 'இன்றைய குவிஸ் தயார்! 🧠' : "Today's Quiz Ready! 🧠";
      case 'notif_daily_quiz_ready_body':
        return ta ? 'இன்றைய TNPSC சவாலில் கலந்துகொண்டு உங்கள் அறிவைச் சோதியுங்கள்!' : "Test your knowledge by joining today's TNPSC challenge!";
      case 'students_access_desc':
        return ta ? 'மாணவர்கள் இந்த நாளிலிருந்து அணுகலாம்' : 'Students can access from this day';
      case 'generation_time_desc':
        return ta ? 'உருவாக்கத்திற்கு 30-40 வினாடிகள் ஆகும்.' : 'Generation takes 30-40 seconds.';
      case 'unlock_date_label':
        return ta ? 'திறக்கும் தேதி' : 'Unlock Date';
      case 'invalid_json_error':
        return ta ? 'பிழை: தவறான JSON வடிவம்.' : 'Error: Invalid JSON format.';
      case 'subject_tamil':
        return ta ? 'தமிழ்' : 'Tamil';
      case 'subject_social':
        return ta ? 'சமூக அறிவியல்' : 'Social Science';
      case 'subject_science':
        return ta ? 'அறிவியல்' : 'Science';
      case 'more_details':
        return ta ? 'மேலும் விவரங்கள்' : 'More Details';
      case 'error_prefix':
        return ta ? 'பிழை' : 'Error';
      case 'upload_failed':
        return ta ? 'பதிவேற்றம் தோல்வியடைந்தது' : 'Upload failed';
      case 'clear_failed':
        return ta ? 'நீக்கம் தோல்வியடைந்தது' : 'Clear failed';
      case 'push_notif_channel':
        return ta ? 'புஷ் அறிவிப்புகள்' : 'Push Notifications';
      case 'study_rem_channel':
        return ta ? 'படிப்பு நினைவூட்டல்கள்' : 'Study Reminders';
      case 'study_rem_desc':
        return ta ? 'TNPSC படிக்க உங்களை நினைவூட்டும் தினசரி அறிவிப்புகள்' : 'Daily notifications to remind you to study for TNPSC';
      case 'app_update_title':
        return ta ? 'TNPSC புதுப்பிப்பு' : 'TNPSC Update';
      case 'daily_rem_channel':
        return ta ? 'தினசரி நினைவூட்டல்கள்' : 'Daily Reminders';
      case 'daily_rem_desc':
        return ta ? 'படிப்புக்கான திட்டமிடப்பட்ட நினைவூட்டல்கள்' : 'Scheduled reminders for study';
      case 'ai_smart_prep':
        return ta ? 'ஸ்மார்ட் சாட்' : 'Smart Chat';
      case 'ai_smart_prep_desc':
        return ta ? 'உங்கள் பாடக்குறிப்புகள் மற்றும் வினாக்கள் குறித்து AI உடன் உரையாடுங்கள்' : 'Chat with AI about your study materials and questions';
      case 'ai_gen_quiz':
        return ta ? 'AI தேர்வு உருவாக்கு' : 'AI Generate Quiz';
      case 'ai_gen_study':
        return ta ? 'AI பாடக்குறிப்பு உருவாக்கு' : 'AI Generate Material';
      case 'enter_topic_hint':
        return ta ? 'எந்த தலைப்பு? (எ.கா: சிந்து சமவெளி நாகரிகம்)' : 'Which topic? (e.g., Indus Valley Civilization)';
      case 'gen_study_loading':
        return ta ? 'AI பாடக்குறிப்புகளைத் தயார் செய்கிறது...' : 'Preparing AI Study Notes...';
      case 'gen_quiz_loading':
        return ta ? 'AI பிரத்யேகத் தேர்வை உருவாக்குகிறது...' : 'Generating Custom AI Quiz...';
      case 'gen_full_subject':
        return ta ? 'முழு பாட உள்ளடக்கம் உருவாக்கு' : 'Generate Full Subject Content';
      case 'gen_full_desc':
        return ta ? '20 கேள்விகள் + 15 பாடக்குறிப்புகளை வரிசையாக உருவாக்குகிறது' : 'Generate 20 Questions + 15 Study Points sequentially';
      case 'gen_full_loading':
        return ta ? 'பாட உள்ளடக்கம் (கேள்வி & படிப்பு) உருவாக்குகிறது...' : 'Generating Subject Content (Q&A + Study)...';
      case 'gen_full_success':
        return ta ? 'பாட உள்ளடக்கம் வெற்றிகரமாக உருவாக்கப்பட்டது!' : 'Subject Content Generated Successfully!';
      case 'subject_name_label':
        return ta ? 'பாடத்தின் பெயர்' : 'Subject Name';
      case 'category_label':
        return ta ? 'வகை' : 'Category';
      case 'gen_full_subject_title':
        return ta ? 'முழு பாட உள்ளடக்கம்' : 'Full Subject Generation';
      case 'gen_all_subjects':
        return ta ? 'அனைத்து பாடங்களையும் உருவாக்கு' : 'Bulk Generate All Subjects';
      case 'gen_all_desc':
        return ta ? 'அனைத்து பாடங்களின் கீழ் உள்ள அனைத்து தலைப்புகளையும் வரிசையாக உருவாக்குகிறது' : 'Sequentially generates content for ALL sub-topics across all subjects';
      case 'bulk_gen_progress':
        return ta ? 'மொத்த முன்னேற்றம்: {current}/{total}\nதற்போது: {topic}' : 'Total Progress: {current}/{total}\nNow: {topic}';
      case 'bulk_gen_success':
        return ta ? 'அனைத்து பாட உள்ளடக்கங்களும் வெற்றிகரமாக உருவாக்கப்பட்டன!' : 'All subject contents generated successfully!';
      case 'bulk_gen_title':
        return ta ? 'அனைத்து பாடங்கள் மொத்த உருவாக்கம்' : 'Full Subject Bulk Generation';
      case 'old_test_papers':
        return ta ? 'முந்தைய ஆண்டு வினாத்தாள்கள்' : 'Old Test Papers';
      case 'tnpsc':
        return ta ? 'TNPSC' : 'TNPSC';
      case 'trb':
        return ta ? 'TRB' : 'TRB';
      case 'tet':
        return ta ? 'TET' : 'TET';
      case 'net':
        return ta ? 'NET' : 'NET';
      case 'set':
        return ta ? 'SET' : 'SET';
      case 'vao':
        return ta ? 'VAO' : 'VAO';
      case 'no_mastery_data':
        return ta ? 'வினாடி வினாக்களை முடித்து உங்கள் முன்னேற்றத்தைக் காணுங்கள்!' : 'Complete quizzes to see your mastery progress!';
      case 'ai_error':
        return ta ? 'AI பதில் அளிப்பதில் சிக்கல் ஏற்பட்டுள்ளது. மீண்டும் முயலவும்.' : 'AI is having trouble responding. Please try again.';
      case 'ai_data_retrieval_error':
        return ta ? 'தகவல்களைத் திரட்டுவதில் சிக்கல். மீண்டும் முயலவும்.' : 'I\'m having trouble retrieving study data. Please try again.';
      case 'saved_quizzes':
        return ta ? 'சேமிக்கப்பட்ட வினாக்கள்' : 'Saved Quizzes';
      case 'copied_to_clipboard':
        return ta ? 'கிளிப்போர்டுக்கு நகலெடுக்கப்பட்டது!' : 'Copied to clipboard!';
      case 'exit_app_title':
        return ta ? 'வெளியேறவா?' : 'Exit App?';
      case 'exit_app_desc':
        return ta ? 'நிச்சயமாக நீங்கள் வெளியேற விரும்புகிறீர்களா?' : 'Are you sure you want to exit?';
      case 'yes':
        return ta ? 'ஆம்' : 'Yes';
      case 'no':
        return ta ? 'இல்லை' : 'No';
      case 'show_more':
        return ta ? 'மேலும் காண்க' : 'Show More';
      case 'listen':
        return ta ? 'கேட்க' : 'Listen';
      case 'audio_guide':
        return ta ? 'ஆடியோ வழிகாட்டி' : 'Audio Guide';
      case 'listen_all':
        return ta ? 'அனைத்தையும் கேள்' : 'Listen All';
      case 'stop_audio':
        return ta ? 'நிறுத்து' : 'Stop Audio';
      case 'resume_audio':
        return ta ? 'தொடர்க' : 'Resume';
      case 'play_from_start':
        return ta ? 'முதலில் இருந்து' : 'From start';
      case 'bg_audio_title':
        return ta ? 'பின்னணி ஆடியோ' : 'Background Audio';
      case 'bg_audio_desc':
        return ta ? 'செயலியை மூடினாலும் அல்லது வேறு செயலிகளைப் பயன்படுத்தினாலும் ஆடியோ தொடர்ந்து ஒலிக்க வேண்டுமா?' : 'Do you want the audio to continue playing even if you use other apps?';
      case 'listening_now':
        return ta ? 'இப்போது கேட்கிறீர்கள்' : 'Listening Now';
      case 'email_label':
        return ta ? 'மின்னஞ்சல் முகவரி' : 'Email Address';
      case 'email_hint':
        return ta ? 'மின்னஞ்சலை உள்ளிடவும்' : 'Enter your email';
      case 'password_label':
        return ta ? 'கடவுச்சொல்' : 'Password';
      case 'password_hint':
        return ta ? 'கடவுச்சொல்லை உள்ளிடவும்' : 'Enter your password';
      case 'forgot_password':
        return ta ? 'கடவுச்சொல்லை மறந்துவிட்டீர்களா?' : 'Forgot Password?';
      case 'sign_up_prompt':
        return ta ? 'புதிய கணக்கை உருவாக்க வேண்டுமா?' : "Don't have an account? Sign Up";
      case 'sign_in_prompt':
        return ta ? 'ஏற்கனவே கணக்கு உள்ளதா? உள்நுழைக' : 'Already have an account? Sign In';
      case 'reset_password_sent':
        return ta ? 'கடவுச்சொல் மீட்பு மின்னஞ்சல் அனுப்பப்பட்டது!' : 'Password reset email sent!';
      case 'enter_valid_email':
        return ta ? 'சரியான மின்னஞ்சலை உள்ளிடவும்' : 'Please enter a valid email address';
      case 'enter_valid_password':
        return ta ? 'கடவுச்சொல் குறைந்தது 6 எழுத்துக்கள் இருக்க வேண்டும்' : 'Password must be at least 6 characters';
      case 'reset_password_title':
        return ta ? 'கடவுச்சொல்லை மீட்டமை' : 'Reset Password';
      case 'reset_password_desc':
        return ta
            ? 'உங்கள் மின்னஞ்சலை உள்ளிடவும். API-யில் பதிவு செய்யப்பட்டிருந்தால் கடவுச்சொல் மின்னஞ்சலில் அனுப்பப்படும்.'
            : 'Enter your email. If registered in our system, your password will be sent to this email.';
      case 'send_reset_link':
        return ta ? 'கடவுச்சொல் அனுப்பு' : 'Send Password';
      case 'change_password_title':
        return ta ? 'கடவுச்சொல் மாற்று' : 'Change Password';
      case 'change_password_desc':
        return ta
            ? 'தற்போதைய கடவுச்சொல் மற்றும் புதிய கடவுச்சொல் API-யில் புதுப்பிக்கப்படும்.'
            : 'Your current and new password will be updated in the app API.';
      case 'change_password_button':
        return ta ? 'கடவுச்சொல் மாற்று' : 'Update Password';
      case 'current_password':
        return ta ? 'தற்போதைய கடவுச்சொல்' : 'Current Password';
      case 'new_password':
        return ta ? 'புதிய கடவுச்சொல்' : 'New Password';
      case 'confirm_password':
        return ta ? 'கடவுச்சொலை உறுதிசெய்' : 'Confirm Password';
      case 'create_account_prompt':
        return ta ? 'புதிய கணக்கு உருவாக்கு' : 'Create New Account';
      case 'password_email_sent':
        return ta
            ? 'கடவுச்சொல் மின்னஞ்சலில் அனுப்பப்பட்டது. அந்த கடவுச்சொல்லுடன் login செய்து, புதிய கடவுச்சொல் மாற்றவும்.'
            : 'Password sent to your email. Sign in with that password, then set a new password.';
      case 'must_change_password_banner':
        return ta
            ? 'மின்னஞ்சலில் வந்த கடவுச்சொல்லை மாற்றிய பிறகே app-ஐ பயன்படுத்தலாம்.'
            : 'You must change the password from your email before using the app.';
      case 'must_change_password_desc':
        return ta
            ? 'தற்போதைய கடவுச்சொல் (மின்னஞ்சலில் வந்தது) மற்றும் புதிய கடவுச்சொல் வித்தியாசமாக இருக்க வேண்டும்.'
            : 'Current password (from email) and new password must be different.';
      case 'sign_in_button':
        return ta ? 'உள்நுழைக' : 'Sign In';
      case 'sign_up_button':
        return ta ? 'கணக்கை உருவாக்கு' : 'Sign Up';
      case 'general_tamil':
        return ta ? 'பொது தமிழ்' : 'General Tamil';
      case 'general_studies':
        return ta ? 'பொது அறிவு' : 'General Studies ';
      case 'aptitude':
        return ta ? 'கணிதத் திறன் & மனத்திறன்' : 'Aptitude & Mental Ability';
      case 'current_affairs':
        return ta ? 'நடப்பு நிகழ்வுகள்' : 'Current Affairs';
      case 'audio_settings':
        return ta ? 'ஆடியோ அமைப்புகள்' : 'Audio Settings';
      case 'voice_speed':
        return ta ? 'ஆடியோ வேகம்' : 'Voice Speed';
      case 'repeat_count':
        return ta ? 'மறுமுறை ஒலித்தல்' : 'Repeat Count';
      case 'no_repeat':
        return ta ? 'மறுமுறை இல்லை' : 'No Repeat';
      case 'repeat_x_times':
        return ta ? '{count} முறை' : '{count} times';
      case 'normal_speed':
        return ta ? 'சாதாரண' : 'Normal';
      case 'font_size':
        return ta ? 'எழுத்து அளவு' : 'Font Size';
      case 'font_size_desc':
        return ta ? 'எழுத்துக்களின் அளவை மாற்றவும்' : 'Adjust text size';
      case 'welcome_group_quiz':
        return ta ? 'குழு வினாடி வினாவிற்கு வரவேற்கிறோம்!' : 'Welcome to the Group Quiz!';
      case 'group_test_lobby':
        return ta ? 'குழு தேர்வு கூடம்' : 'Group Test Lobby';
      case 'group_test_needs_players':
        return ta ? 'தொடங்குவதற்கு குறைந்தபட்சம் 2 வீரர்கள் தேவை.' : 'Need at least 2 players to start.';
      case 'could_not_start_group_test':
        return ta ? 'குழு தேர்வை தொடங்க முடியவில்லை. தயவுசெய்து மீண்டும் முயற்சிக்கவும்.' : 'Could not start the group test. Please try again.';
      case 'room_setup_note':
        return ta ? 'தேர்வைத் தொடங்க உங்கள் நண்பர்களுடன் குழு குறியீட்டைப் பகிரவும்.' : 'Share the room code with your friends to start the quiz.';
      case 'room_code':
        return ta ? 'குழு குறியீடு' : 'Room Code';
      case 'players_joined':
        return ta ? 'இணைந்த வீரர்கள்' : 'Players Joined';
      case 'lobby_max_players':
        return ta ? 'அதிகபட்ச வீரர்கள்: {max}' : 'Max Players: {max}';
      case 'start_group_test':
        return ta ? 'குழு தேர்வைத் தொடங்கு' : 'Start Group Test';
      case 'waiting_for_host':
        return ta ? 'ஹோஸ்ட் தேர்வைத் தொடங்க காத்திருக்கிறது...' : 'Waiting for host to start the test...';
      case 'room_screen_title':
        return ta ? 'குழு வினாடி வினா' : 'Room Quiz';
      case 'battle_title':
        return ta ? 'குழுத் தேர்வு' : 'Group Match';
      case 'insufficient_points_create':
        return ta ? 'புள்ளிகள் மிகவும் குறைவு: {points}' : 'Insufficient points: {points}';
      case 'daily_quiz_first_error':
        return ta ? 'குழு தேர்வை உருவாக்குவதற்கு முன் இன்றைய தினசரி வினாடி வினாவை முடிக்கவும்!' : 'Please complete today\'s Daily Quiz first before creating a room!';
      case 'room_exists_error':
        return ta ? 'இந்த குழு ஏற்கனவே உள்ளது' : 'Room already exists';
      case 'room_created_success':
        return ta ? 'குழு வெற்றிகரமாக உருவாக்கப்பட்டது! {points} புள்ளிகள் கழிக்கப்பட்டது.' : 'Room created successfully! {points} points deducted.';
      case 'room_already_started':
        return ta ? 'குழு ஏற்கனவே தொடங்கப்பட்டது' : 'Room has already started';
      case 'room_full':
        return ta ? 'குழு நிரம்பியுள்ளது' : 'Room is full';
      case 'room_not_found':
        return ta ? 'குழு கிடைக்கவில்லை' : 'Room not found';
      case 'room_limit_title':
        return ta ? 'குழு வரம்பு எட்டியது' : 'Room limit reached';
      case 'room_limit_desc':
        return ta ? 'நீங்கள் குழு வரம்பை எட்டியுள்ளீர்கள். மேலும் குழு உருவாக்க விளம்பரத்தைப் பார்க்கவும்.' : 'You have reached the room limit. Watch an ad to unlock more.';
      case 'ads_watched':
        return ta ? 'விளம்பரங்கள் பார்க்கப்பட்டன: {watched}' : 'Ads watched: {watched}';
      case 'close_btn':
        return ta ? 'மூடு' : 'Close';
      case 'watch_ad_btn':
        return ta ? 'விளம்பரத்தைப் பார்க்க' : 'Watch Ad';
      case 'active_room_available':
        return ta ? 'செயலில் இருக்கும் குழு கிடைக்கிறது' : 'Active Room Available';
      case 'active_room_desc':
        return ta ? 'வரவேற்பு! நீங்கள் தற்போது உள்ள குழுவில் சேரலாம்.' : 'Welcome! You can join the currently active room.';
      case 'enter_waiting_room':
        return ta ? 'காத்திருக்கும் குழுக்குள் செல்லவும்' : 'Enter Waiting Room';
      case 'create_room_section':
        return ta ? 'குழு உருவாக்கம்' : 'Create Room';
      case 'create_room_desc':
        return ta ? 'நீங்கள் புதிய குழுவை உருவாக்கலாம்.' : 'You can create a new room.';
      case 'select_subject':
        return ta ? 'பாடத்தை தேர்ந்தெடுக்கவும்' : 'Select Subject';
      case 'max_players_label':
        return ta ? 'அதிகபட்ச வீரர்கள்' : 'Max Players';
      case 'extra_player_cost':
        return ta ? 'கூடுதல் வீரர் செலவு: {points} புள்ளிகள்' : 'Extra player cost: {points} points';
      case 'base_room_cost':
        return ta ? 'அடிப்படை குழு செலவு: {points} புள்ளிகள்' : 'Base room cost: {points} points';
      case 'create_room_btn':
        return ta ? 'குழுவை உருவாக்கு' : 'Create Room';
      case 'join_room_section':
        return ta ? 'குழுவில் சேர' : 'Join Room';
      case 'join_room_desc':
        return ta ? 'குறியீட்டைப் பதிந்து குழுவில் சேரவும்.' : 'Enter a code to join a room.';
      case 'room_code_hint':
        return ta ? 'குழு குறியீடு : A3ET55' : 'Room Code : A3ET55';
      case 'loading_quiz':
        return ta ? 'குழுவிற்கான வினாக்கள் தயாராகின்றன...' : 'Questions for the group are being prepared...';
      case 'join_room_btn':
        return ta ? 'சேர்ந்து கொள்ளவும்' : 'Join Room';
      case 'room_history':
        return ta ? 'குழு தேர்வு வரலாறு' : 'Room History';
      case 'last_room_history':
        return ta ? 'கடைசி குழு' : 'Final Group';
      case 'correct_feedback':
        return ta ? 'சரி!' : 'Correct!';
      case 'wrong_feedback':
        return ta ? 'தவறு!' : 'Wrong!';
      case 'correct_answer_feedback':
        return ta ? 'சரியான விடை:' : 'Correct answer:';
      case 'mock_quiz_title':
        return ta ? 'மாதிரி வினாடி வினா' : 'Mock Quiz';
      case 'focus_recommendation':
        return ta ? 'உங்களுக்கு {category} பாடத்தில் அதிக கவனம் தேவை' : 'You need to focus more on: {category}';
      case 'excellent_work':
        return ta ? 'அனைத்து பாடங்களிலும் சிறப்பான செயல்பாடு!' : 'Excellent performance in all areas!';
      case 'room_info_title':
        return ta ? 'குழுத் தேர்வு - வழிமுறைகள்' : 'Room Match Instructions';
      case 'room_info_create_title':
        return ta ? '1. குழுவை உருவாக்குதல் (Create)' : '1. Create Room';
      case 'room_info_create_desc':
        return ta 
            ? '• ஒரு பாடத்தைத் தேர்ந்தெடுத்து வீரர்களின் எண்ணிக்கையை முடிவு செய்யுங்கள்.\n• ஒரு விளம்பரத்தைப் பார்த்த பிறகு உங்கள் குழு தயாராகிவிடும்.'
            : '• Select a subject and choose the number of players.\n• Your room will be ready after watching a short ad.';
      case 'room_info_join_title':
        return ta ? '2. குழுவில் இணைதல் (Join)' : '2. Join Room';
      case 'room_info_join_desc':
        return ta 
            ? '• உங்கள் நண்பர் கொடுத்த 6 இலக்க கோடை உள்ளிட்டு இணையுங்கள்.\n• குழு முழுமையடைவதற்குள் இணைய வேண்டும்.'
            : '• Enter the 6-digit code provided by your friend.\n• Join before the room becomes full.';
      case 'room_info_play_title':
        return ta ? '3. விளையாடுதல் (Play)' : '3. Play';
      case 'room_info_play_desc':
        return ta 
            ? '• அனைவரும் இணைந்தவுடன் ஹோஸ்ட் தேர்வைத் தொடங்குவார்.\n• அனைவரும் ஒரே கேள்விகளுக்குப் பதிலளிப்பீர்கள்.'
            : '• The host will start the test once everyone joins.\n• All players will answer the same set of questions.';
      case 'room_info_earn_title':
        return ta ? '4. புள்ளிகளைப் பெறுவது எப்படி? (Earn Points)' : '4. How to Earn Points?';
      case 'room_info_earn_desc':
        return ta 
            ? '• தினசரி வினாடி வினா விளையாடுவதன் மூலம் உங்கள் மதிப்பெண்ணுக்கு இணையான புள்ளிகள் கிடைக்கும்.\n• "Gifts" பகுதியில் விளம்பரங்களைப் பார்த்து புள்ளிகள் பெறலாம் (1st Ad: 15pts, 2nd: 10pts, 3rd: 5pts).\n• குழுத் தேர்வை (Room Match) முடிக்கும் அனைவருக்கும் 25 வெகுமதி புள்ளிகள் கிடைக்கும்.\n• அன்றைய முதல் குழுவை (Room) வெற்றிகரமாக உருவாக்கினால் 10 போனஸ் புள்ளிகள் கிடைக்கும்.'
            : '• Earn points equal to your score in Daily Quizzes.\n• Watch ads in the "Gifts" section for points (1st Ad: 15pts, 2nd: 10pts, 3rd: 5pts).\n• All players who complete a Room Match get 25 reward points.\n• Get 10 bonus points for successfully creating your first room of the day.';
      case 'room_info_points_spend_title':
        return ta ? '5. புள்ளிகள் எப்போது கழிக்கப்படும்? (Spending)' : '5. Point Deductions';
      case 'room_info_points_spend_desc':
        return ta 
            ? '• ஒரு நாளைக்கு முதல் குழு உருவாக்கம் இலவசம் (அடிப்படை வீரர்கள்).\n• அதே நாளில் கூடுதல் குழுக்களை உருவாக்க 200 புள்ளிகள் கழிக்கப்படும்.\n• 10 வீரர்களுக்கு மேல் (Max Players) தேர்வு செய்தால் கூடுதல் வீரர்களுக்கு தலா 100 புள்ளிகள் கழிக்கப்படும்.'
            : '• First room creation of the day is free (for base players).\n• Creating additional rooms on the same day costs 200 points.\n• Selecting more than 10 players costs 100 points extra per player.';
      case 'current_points_label':
        return ta ? 'உங்களிடம் உள்ள புள்ளிகள்' : 'Your Current Points';
      case 'total_deduction_label':
        return ta ? 'மொத்தமாக கழிக்கப்படும் புள்ளிகள்' : 'Total Deduction';
      case 'remaining_points_label':
        return ta ? 'மீதமுள்ள புள்ளிகள்' : 'Remaining Points';
      case 'base_cost_label':
        return ta ? 'அடிப்படை செலவு' : 'Base Cost';
      case 'extra_cost_label':
        return ta ? 'கூடுதல் வீரர் செலவு' : 'Extra Player Cost';
      case 'free':
        return ta ? 'இலவசம்' : 'Free';
      default:
        return key;
    }
  }

  /// Splits bilingual text and returns both English and Tamil on separate lines
  static String formatBilingual(String raw) {
    if (raw.isEmpty) return "";

    // Normalize escaped newlines
    raw = raw.replaceAll('\\n', '\n');

    String en = "";
    String ta = "";

    // 1. Check for explicit separators
    if (raw.contains('\n') || raw.contains(' / ') || raw.contains(' | ')) {
      List<String> parts;
      if (raw.contains('\n')) {
        parts = raw.split('\n');
      } else if (raw.contains(' / ')) {
        parts = raw.split(' / ');
      } else {
        parts = raw.split(' | ');
      }

      en = parts[0].trim();
      ta = parts.length > 1 ? parts.sublist(1).join(' / ').trim() : en;
    } else {
      // 2. Smart detection: Split at the first Tamil character if no separator is found
      int tamilIndex = -1;
      for (int i = 0; i < raw.length; i++) {
        int code = raw.codeUnitAt(i);
        if (code >= 0x0B80 && code <= 0x0BFF) {
          if (i == 0 || raw[i-1] == ' ' || raw[i-1] == '"' || raw[i-1] == "'" || raw[i-1] == '(') {
            tamilIndex = i;
            break;
          }
        }
      }

      if (tamilIndex > 0) {
        int splitIndex = tamilIndex;
        if (splitIndex > 0 && (raw[splitIndex-1] == '"' || raw[splitIndex-1] == "'" || raw[splitIndex-1] == '(')) {
          splitIndex--;
        }

        en = raw.substring(0, splitIndex).trim();
        while (en.endsWith('/') || en.endsWith('|') || en.endsWith(':') || en.endsWith('-')) {
          en = en.substring(0, en.length - 1).trim();
        }
        ta = raw.substring(splitIndex).trim();
      } else if (tamilIndex == 0) {
        ta = raw.trim();
        en = ta;
      } else {
        en = raw.trim();
        ta = en;
      }
    }

    // Return both joined by a newline if they are different
    if (en == ta || ta.isEmpty) {
      // If we only have one language, try to translate it on-the-fly
      // This is a placeholder for UI to trigger translation if needed
      return en; 
    }
    return "$en\n$ta";
  }

  /// Check if text is single language and translate if so
  static Future<String> translateIfSingleLanguage(String raw) async {
    if (raw.isEmpty) return "";
    
    // Normalize
    raw = raw.replaceAll('\\n', '\n');

    // Quick check if it already has both
    bool hasTamil = false;
    for (int i = 0; i < raw.length; i++) {
      int code = raw.codeUnitAt(i);
      if (code >= 0x0B80 && code <= 0x0BFF) {
        hasTamil = true;
        break;
      }
    }

    bool hasEnglish = false;
    for (int i = 0; i < raw.length; i++) {
      int code = raw.codeUnitAt(i);
      if ((code >= 65 && code <= 90) || (code >= 97 && code <= 122)) {
        hasEnglish = true;
        break;
      }
    }

    // If it has both, return formatted
    if (hasTamil && hasEnglish) {
      return formatBilingual(raw);
    }

    // Otherwise, use AI to translate
    try {
      String? translated = await AiService.chatWithAi(
        "Translate this TNPSC content into both English and Tamil. Format: 'English\\nTamil'. Content: $raw"
      );
      if (translated != null && translated.isNotEmpty) {
        return translated.replaceAll('\\n', '\n').trim();
      }
    } catch (e) {
      debugPrint("Translation error: $e");
    }

    return raw;
  }
}
