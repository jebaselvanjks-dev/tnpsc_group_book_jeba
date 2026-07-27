import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_log.dart';
import 'package:tnpsc_group_book/utils/app_language.dart';
import 'dart:ui';
import '../main.dart';

class DeepLinkService with WidgetsBindingObserver {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final ValueNotifier<String?> pendingRoomCode = ValueNotifier<String?>(null);

  void init() {
    WidgetsBinding.instance.addObserver(this);
    
    // AI_DEBUG: Check for initial link on startup
    _checkInitialLink();

    // AI_DEBUG: Check clipboard as a fallback for new users
    checkClipboard();
  }

  Future<void> checkClipboard() async {
    try {
      ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null) {
        AppLog.d("DeepLinkService: Checking clipboard for room code...");
        _handleLink(data!.text!);
      }
    } catch (e) {
      AppLog.e("DeepLinkService: Error checking clipboard: $e");
    }
  }

  void _checkInitialLink() {
    // In Flutter, the initial deep link is often passed as the default route name
    String? initialRoute = PlatformDispatcher.instance.defaultRouteName;
    AppLog.d("DeepLinkService: Checking initial route: $initialRoute");
    
    if (initialRoute != "/" && initialRoute != "index.html") {
      _handleLink(initialRoute);
    }
  }

  @override
  Future<bool> didPushRoute(String route) async {
    AppLog.d("DeepLinkService: Observer received route: $route");
    _handleLink(route);
    return false; // Return false to allow standard navigation to proceed if needed
  }

  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) async {
    final String location = routeInformation.uri.toString();
    AppLog.d("DeepLinkService: Observer received location: $location");
    _handleLink(location);
    return false;
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  void _handleLink(String link) {
    AppLog.d("DeepLinkService: Received raw input: '$link'");
    if (link.isEmpty || link == "/" || link == "index.html") return;

    // AI_DEBUG: Support various formats (Full text messages, deep links, or just the code)
    try {
      String input = link.trim();
      
      // 1. Try to find 6-digit uppercase code using Regex (Matches OKAXBI, ABCDEF etc)
      // This is powerful because it works even if they copy the WHOLE message
      final RegExp codeRegex = RegExp(r'\b[A-Z0-9]{6}\b');
      final Iterable<RegExpMatch> matches = codeRegex.allMatches(input);
      
      String? foundCode;
      
      // If there's a specific 'code=' parameter, prioritize it
      if (input.contains('code=')) {
        Uri? uri = Uri.tryParse(input.replaceAll(' ', ''));
        if (uri != null) {
          foundCode = uri.queryParameters['code'] ?? 
                      uri.queryParameters['roomCode'] ?? 
                      uri.queryParameters['room'];
        }
      }
      
      // If no code parameter, use the first 6-digit match that isn't part of a URL
      if (foundCode == null && matches.isNotEmpty) {
        for (var match in matches) {
           String potential = match.group(0)!;
           // Avoid matching parts of the URL or app ID
           if (!input.contains('details?id=') || !input.substring(input.indexOf('id=')).contains(potential)) {
             foundCode = potential;
             break;
           }
        }
      }

      if (foundCode != null) {
        String code = foundCode.toUpperCase();
        if (code.length >= 5 && code.length <= 8) {
          pendingRoomCode.value = code;
          AppLog.d("DeepLinkService: SUCCESS! Extracted Code: ${pendingRoomCode.value}");
          
          // scaffoldMessengerKey.currentState?.showSnackBar(
          //   SnackBar(
          //     content: Text(AppLanguage.languageNotifier.value == 'ta'
          //       ? "கோட் கண்டறியப்பட்டது! கோட்: $code"
          //       : "Code Detected! Code: $code"),
          //     backgroundColor: Colors.green,
          //     duration: const Duration(seconds: 3),
          //   ),
          // );
          return; // Stop here if code is found
        }
      }
      
      AppLog.d("DeepLinkService: No valid room code found in input.");
    } catch (e) {
      AppLog.e("DeepLinkService: Error processing input '$link': $e");
    }
  }

  void clearPendingCode() {
    pendingRoomCode.value = null;
  }
}
