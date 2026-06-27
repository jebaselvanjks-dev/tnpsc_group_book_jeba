import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:tnpsc_group_book/utils/app_language.dart';
import 'package:tnpsc_group_book/services/hive_service.dart';

class TtsService {
  static final FlutterTts _flutterTts = FlutterTts();
  static bool _isPlaying = false;
  static String? _currentText;
  static final ValueNotifier<String?> currentTextNotifier = ValueNotifier<String?>(null);
  static Function? onComplete;

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

  // Fallback methods for background mode (now no-op)
  static Future<void> startBackgroundMode() async {}
  static Future<void> stopBackgroundMode() async {}
}
