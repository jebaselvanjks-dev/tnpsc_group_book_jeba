import 'package:flutter/material.dart';

class DeepLinkService with WidgetsBindingObserver {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final ValueNotifier<String?> pendingRoomCode = ValueNotifier<String?>(null);

  void init() {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  Future<bool> didPushRoute(String route) async {
    debugPrint("DeepLinkService: Observer received route: $route");
    _handleLink(route);
    return false; // Return false to allow standard navigation to proceed if needed
  }

  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) async {
    final String location = routeInformation.uri.toString();
    debugPrint("DeepLinkService: Observer received location: $location");
    _handleLink(location);
    return false;
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  void _handleLink(String link) {
    debugPrint("DeepLinkService: Received link: $link");
    // Format: tnpscmaster://join?code=ABCDEF or /join?code=ABCDEF or https://.../join?code=ABCDEF
    try {
      Uri uri = Uri.parse(link);
      
      // AI_DEBUG: Support various host/path patterns for robustness
      bool isJoinLink = uri.host == 'join' || 
                        uri.path.contains('join') || 
                        uri.queryParameters.containsKey('code');
      
      if (isJoinLink) {
        String? code = uri.queryParameters['code'];
        if (code != null && (code.length == 6 || code.length == 5)) {
          pendingRoomCode.value = code.toUpperCase();
          debugPrint("DeepLinkService: SUCCESS! Extracted Code: ${pendingRoomCode.value}");
        } else {
          debugPrint("DeepLinkService: Link received but code was invalid length: $code");
        }
      } else {
        debugPrint("DeepLinkService: Link received but didn't match 'join' pattern.");
      }
    } catch (e) {
      debugPrint("DeepLinkService: Error parsing link: $e");
    }
  }

  void clearPendingCode() {
    pendingRoomCode.value = null;
  }
}
