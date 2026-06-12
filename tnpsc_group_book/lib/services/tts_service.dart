import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:tnpsc_group_book/utils/app_language.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:tnpsc_group_book/services/hive_service.dart';

class TtsService {
  static final FlutterTts _flutterTts = FlutterTts();
  static bool _isPlaying = false;
  static String? _currentText;
  static final ValueNotifier<String?> currentTextNotifier = ValueNotifier<String?>(null);
  static Function? onComplete;
  static bool _backgroundInitialized = false;

  static Future<void> initBackgroundService() async {
    if (_backgroundInitialized) return;
    try {
      const androidConfig = FlutterBackgroundAndroidConfig(
        notificationTitle: "TNPSC Study Hub",
        notificationText: "ஆடியோ பின்னணியில் இயங்குகிறது | Audio guide is playing",
        notificationImportance: AndroidNotificationImportance.normal,
        notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
      );
      _backgroundInitialized = await FlutterBackground.initialize(androidConfig: androidConfig);
    } catch (e) {
      debugPrint("Error initializing flutter_background: $e");
    }
  }

  static Future<void> startBackgroundMode() async {
    await initBackgroundService();
    if (_backgroundInitialized && !FlutterBackground.isBackgroundExecutionEnabled) {
      try {
        await FlutterBackground.enableBackgroundExecution();
      } catch (e) {
        debugPrint("Error enabling background execution: $e");
      }
    }
  }

  static Future<void> stopBackgroundMode() async {
    if (_backgroundInitialized && FlutterBackground.isBackgroundExecutionEnabled) {
      try {
        await FlutterBackground.disableBackgroundExecution();
      } catch (e) {
        debugPrint("Error disabling background execution: $e");
      }
    }
  }

  static Future<void> init() async {
    await _flutterTts.setVolume(1.0);
    double speed = HiveService.getTtsSpeed();
    await _flutterTts.setSpeechRate(speed);
    await _flutterTts.setPitch(1.0);
    
    _flutterTts.setCompletionHandler(() {
      _isPlaying = false;
      _currentText = null;
      currentTextNotifier.value = null;
      if (onComplete != null) onComplete!();
    });
  }

  static Future<void> setSpeed(double speed) async {
    await _flutterTts.setSpeechRate(speed);
  }

  static Future<void> speak(String text) async {
    if (_isPlaying && _currentText == text) {
      await stop();
      return;
    }

    await stop();
    
    String langCode = AppLanguage.languageNotifier.value == 'ta' ? 'ta-IN' : 'en-US';
    await _flutterTts.setLanguage(langCode);
    
    double speed = HiveService.getTtsSpeed();
    await _flutterTts.setSpeechRate(speed);
    
    _currentText = text;
    currentTextNotifier.value = text;
    _isPlaying = true;
    await _flutterTts.speak(text);
  }

  static Future<void> stop() async {
    await _flutterTts.stop();
    _isPlaying = false;
    _currentText = null;
    currentTextNotifier.value = null;
  }

  static bool isSpeaking(String text) {
    return _isPlaying && _currentText == text;
  }
}
