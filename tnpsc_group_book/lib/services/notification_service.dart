import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'dart:convert';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:tnpsc_group_book/utils/app_language.dart';

// This must be a top-level function for background messaging
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("AI_DEBUG: Handling a background message: ${message.messageId}");
}

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();
    
    // 1. Request Permission (for iOS and Android 13+)
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('AI_DEBUG: User granted notification permission');
    }

    // 2. Local Notifications Setup
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap logic here
      },
    );

    // 3. Handle FCM Messages
    // Foreground messaging
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("AI_DEBUG: Got a message in foreground!");
      if (message.notification != null) {
        _showLocalNotificationFromFCM(message);
      }
    });

    // Background messaging handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 4. Subscribe to a general topic
    await _messaging.subscribeToTopic('all_users');
    
    // 5. Get and save Token
    await saveFCMToken();

    // 6. Schedule Automatic Daily Reminder at 8:00 PM
    await scheduleDailyReminder(hour: 20, minute: 0);
  }

  static Future<void> _showLocalNotificationFromFCM(RemoteMessage message) async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'fcm_channel',
      AppLanguage.getString('push_notif_channel'),
      importance: Importance.max,
      priority: Priority.high,
    );

    final NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails, iOS: const DarwinNotificationDetails());

    await _notificationsPlugin.show(
      id: message.hashCode,
      title: message.notification?.title ?? AppLanguage.getString('app_update_title'),
      body: message.notification?.body ?? "",
      notificationDetails: platformDetails,
    );
  }

  static Future<void> saveFCMToken() async {
    try {
      String? token = await _messaging.getToken();
      String? uid = FirebaseAuth.instance.currentUser?.uid;

      if (token != null && uid != null) {
        debugPrint("AI_DEBUG: FCM Token: $token");
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint("AI_DEBUG: Error saving FCM token: $e");
    }
  }

  static Future<void> showDailyStudyReminder() async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'study_reminder_channel',
      AppLanguage.getString('study_rem_channel'),
      channelDescription: AppLanguage.getString('study_rem_desc'),
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );

    final NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails, iOS: const DarwinNotificationDetails());

    await _notificationsPlugin.show(
      id: 0,
      title: AppLanguage.getString('study_challenge'),
      body: AppLanguage.getString('start_quiz_now'),
      notificationDetails: platformDetails,
    );
  }

  static Future<void> scheduleDailyReminder({required int hour, required int minute}) async {
    await _notificationsPlugin.zonedSchedule(
      id: 1,
      title: AppLanguage.getString('reminder_title'),
      body: AppLanguage.getString('reminder_body'),
      scheduledDate: _nextInstanceOfTime(hour, minute),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder_channel',
          'daily_rem_channel',
          channelDescription: 'daily_rem_desc',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // --- NEW: Send notification to all users via FCM Topic (v1 API) ---
  static Future<bool> sendNotificationToAll({required String title, required String body}) async {
    // IMPORTANT: Replace these with details from your Service Account JSON file
    const String projectId = "tnpsc-prepare-app-koilra-c9998";
    const String clientEmail = "firebase-adminsdk-fbsvc@tnpsc-prepare-app-koilra-c9998.iam.gserviceaccount.com";
    const String privateKey = "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCZ4MSkoDTeAETy\n3OMukAm+6mCKOOCFwBo55xk0XvFCaUz/ZLRJHL92JEyup5GN9FHEkxTTWohr23Tm\nUBatcJW7JmISRgPrv45mb/SUwr4n1bvN93hxB8ku8TVdpAkcoVd+j/hHgcRITTwe\nkNIUlwxJEqkAWd50e2ziiQMCTHMVpMVieGt7ZjthMblScs9jF5hfU1erxGJ2gdwr\nPor3Wevdy+f4SwDhLBcwqPVnLRs7Lg02OvXE+9y1fc/3g8x9l+VRRlxU1I1cgMxP\njefwzh3gFbCXE8NrQsrvPCzmg5MF/lbHga4ujXrG6qD7xlTzobe6VttdRvtEMex9\nA3TQXOPxAgMBAAECggEAHGfTpRg16i1ejP6dqYDJa8bUX2+0crxNmxbAHlzQaJQL\ntLGgXkbCSUrWJP+l7PCHD6SfGY0C1fZDFCkApq+71Dp3rCvkmWZZISvVmIiCldPs\nwU7HmwX264V3dnvLes+F2UU2bezUkQxA5tuRDF/90pdxPzFX0WTfasokFg6KyBnD\nUmXwq3DDBfLrNl3P5UPHRAXmhD7tWAJ4JSaIvVwVrHxxBoMMtl/YIaGppcXFFUuY\nLDBqahuJfDhJgGC43op33/h7BYY1zCcAvMIuhRd+ebcr05TrzKOhtHMwUlFBeiHX\n+eYR++HXtRBDcNcskY+UrOi+8VBrnSb7Ms+YIJDB4QKBgQDK+X+Mf3ytGrE9g1tu\n8CEUnJw6pkWSr32XJjN+4Sqzu078GyxVD9OO9/HivZfdbBtO6tzXBfHPTS67+SfI\nyKahlcL03SAGycEokluyCrVYDIqSObsCbvCCs8H6j+ZaUOzu6X/5NT9F3y37NQCS\nxvN7vp5s/joVRfQSnGZVr5zspQKBgQDCE8umSXTd6Je8UkPO7TFqE3BtAVE9lKiZ\nVM3PnLSiurbegy+dsdjhkoZVlX4oioqF7WcJfXFTB90ytGCkti8LZNUQExT9XFlf\nhcdH0OTE9E6xoD2N9KxgWoWmOUtrVhJVod4TOUxwF9tG/wvln7+UuFuKIfPISvUC\nVzkOBt98XQKBgQC/XEhnUo5duUuenegnCFd30krsdHQlXjQ+u3JTTb/voUlPH+NE\n8t3W7WXsCilSRSjd10mLo3wdoDvOVpGul5WZw9MA/jTCkZX9RTcT/UqJD5HZWHo6\nShOQdh8MtnxLa/5lJFlVv2C+5DG6o3a96roFUWqVgX2LLt90aGWGpUGCTQKBgHwD\nFC1UYNXvaw3N70BJNjsW4s70eYoE9NrNYpmYA6C7+GAkqYd1fiVdcHM9jBixtiQv\n95gLzR8GNmTQ97QoKdV4/+A+oTnoCb/NBvKv246yoZpEzzBnOMJ09VOq5rNWk26e\neP4Frf8ub1JlZJ+8vTl1uCCC43iH1RlCzNVWtPWNAoGAFVFM0v4flTvAb6B/qk83\nzKQmh0UhvQiEXM+ohXvBNpca8N9/nqVmsc2J7IeAwTUgsuDS3ScO+diVTKfUOz9q\nYg1dJ00LssqkCrW1/jWP5OlAR2IgzkKbCVjFT8OM8bqJlD/vhArmBNsu9IeuuENo\nZiweN9C3ej86tEjGMdC2lu8=\n-----END PRIVATE KEY-----\n"; // Ensure it starts with -----BEGIN PRIVATE KEY-----

    if (projectId == "tnpsc-prepare-app-koilra-c9998") {
      debugPrint("AI_DEBUG: FCM v1 credentials not set. Notification not sent.");
      return false;
    }

    try {
      // 1. Obtain OAuth2 Access Token
      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
      final credentials = auth.ServiceAccountCredentials.fromJson({
        "project_id": projectId,
        "private_key": privateKey,
        "client_email": clientEmail,
        "type": "service_account",
      });

      final client = await auth.clientViaServiceAccount(credentials, scopes);
      final accessToken = client.credentials.accessToken.data;

      // 2. Send Message to Topic via v1 API
      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/v1/projects/$projectId/messages:send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'message': {
            'topic': 'all_users',
            'notification': {
              'title': title,
              'body': body,
            },
            'android': {
              'notification': {
                'click_action': 'FLUTTER_NOTIFICATION_CLICK',
                'sound': 'default',
              },
            },
            'data': {
              'type': 'new_quiz',
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            },
          },
        }),
      );

      client.close();

      if (response.statusCode == 200) {
        debugPrint("AI_DEBUG: FCM v1 topic message sent successfully!");
        return true;
      } else {
        debugPrint("AI_DEBUG: FCM v1 error: ${response.body}");
        return false;
      }
    } catch (e) {
      debugPrint("AI_DEBUG: Error sending FCM v1: $e");
      return false;
    }
  }

  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
