import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final ValueNotifier<String?> pendingRoomCode = ValueNotifier<String?>(null);

  void init() {
    // Standard Flutter way to handle incoming links without 3rd party packages
    SystemChannels.navigation.setMethodCallHandler((call) async {
      if (call.method == 'pushRoute') {
        final String? route = call.arguments as String?;
        if (route != null) {
          _handleLink(route);
        }
      }
      return null;
    });
  }

  void _handleLink(String link) {
    debugPrint("DeepLinkService: Received link: $link");
    // Format: tnpscmaster://join?code=ABCDEF or /join?code=ABCDEF
    try {
      Uri uri = Uri.parse(link);
      if (uri.host == 'join' || uri.path.contains('join')) {
        String? code = uri.queryParameters['code'];
        if (code != null && code.length == 6) {
          pendingRoomCode.value = code.toUpperCase();
          debugPrint("DeepLinkService: Extracted Code: $code");
        }
      }
    } catch (e) {
      debugPrint("DeepLinkService: Error parsing link: $e");
    }
  }

  void clearPendingCode() {
    pendingRoomCode.value = null;
  }
}
