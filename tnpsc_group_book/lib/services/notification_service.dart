import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'hive_service.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:tnpsc_group_book/utils/app_date.dart';
import 'dart:convert';
import '../utils/app_log.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:tnpsc_group_book/utils/app_language.dart';

// This must be a top-level function for background messaging
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  AppLog.d("AI_DEBUG: Handling a background message: ${message.messageId}");
}

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  static Future<void> init() async {
    if (_isInitialized) {
      AppLog.d("AI_DEBUG: NotificationService already initialized. Skipping.");
      return;
    }
    try {
      AppLog.d("AI_DEBUG: Initializing NotificationService...");
      _isInitialized = true;
      tz.initializeTimeZones();
      
      // 1. Request Permission (for iOS and Android 13+)
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      AppLog.d('AI_DEBUG: Notification permission status: ${settings.authorizationStatus}');

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
        onDidReceiveNotificationResponse: (NotificationResponse details) {
          AppLog.d("AI_DEBUG: Notification tapped: ${details.payload}");
        },
      );

      // Create channels
      const AndroidNotificationChannel fcmChannel = AndroidNotificationChannel(
        'fcm_channel',
        'Push Notifications',
        description: 'This channel is used for important notifications.',
        importance: Importance.max,
      );

      const AndroidNotificationChannel dailyChannel = AndroidNotificationChannel(
        'daily_reminder_channel',
        'Daily Reminders',
        description: 'Scheduled study reminders',
        importance: Importance.max,
      );

      const AndroidNotificationChannel studyChannel = AndroidNotificationChannel(
        'study_reminder_channel',
        'Study Reminders',
        description: 'TNPSC study reminders',
        importance: Importance.max,
      );

      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      await androidPlugin?.createNotificationChannel(fcmChannel);
      await androidPlugin?.createNotificationChannel(dailyChannel);
      await androidPlugin?.createNotificationChannel(studyChannel);

      // 3. Handle FCM Messages
      // Foreground messaging
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        AppLog.d("AI_DEBUG: Got a message in foreground: ${message.notification?.title}");
        if (message.notification != null) {
          _showLocalNotificationFromFCM(message);
        }
      });

      // Background messaging handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 4. Subscribe to topics and save token
      // Use a small delay to ensure FCM is ready
      Future.delayed(const Duration(seconds: 2), () async {
        try {
          await _messaging.subscribeToTopic('all_users');
          AppLog.d("AI_DEBUG: Subscribed to all_users topic");
          await saveFCMToken();
        } catch (e) {
          AppLog.d("AI_DEBUG: Delayed init error: $e");
        }
      });

      // 5. Schedule Automatic Reminders
      await reschedulePersonalizedReminders();
    } catch (e) {
      AppLog.d("AI_DEBUG: Error initializing NotificationService: $e");
    }
  }

  /// Reschedules daily reminders based on user performance and status
  static Future<void> reschedulePersonalizedReminders() async {
    try {
      final box = Hive.box(HiveService.userBoxName);
      final bool isTa = AppLanguage.languageNotifier.value == 'ta';

      // --- 1. Morning Reminder (8:00 AM) - Score Based ---
      // AI_DYNAMIC: Calculate score based on when the notification will actually show
      final tz.TZDateTime scheduledMorning = _nextInstanceOfTime(8, 0);
      // If showing tomorrow morning, "yesterday" from its perspective is "today"
      final DateTime scoreDate = scheduledMorning.subtract(const Duration(days: 1));
      String scoreDateStr = AppDate.format(scoreDate);
      int lastScore = box.get('best_score_daily_$scoreDateStr', defaultValue: 0) as int;

      String morningTitle = AppLanguage.getString('notif_daily_quiz_ready_title');
      String morningBody;

      if (lastScore > 0) {
        morningBody = AppLanguage.getString('notif_yesterday_score').replaceAll('{score}', lastScore.toString());
      } else {
        morningBody = AppLanguage.getString('notif_daily_quiz_ready_body');
      }

      await _notificationsPlugin.cancel(id: 100);
      await _notificationsPlugin.zonedSchedule(
        id: 100,
        title: morningTitle,
        body: morningBody,
        scheduledDate: scheduledMorning,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_reminder_channel',
            'Daily Reminders',
            channelDescription: 'Scheduled study reminders',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      // --- 2. Evening Reminder (8:00 PM) - Streak Warning ---
      final tz.TZDateTime scheduledEvening = _nextInstanceOfTime(20, 0);
      final String scheduledDateStr = AppDate.format(scheduledEvening);
      final String todayStr = AppDate.getTodayString();
      
      bool isDoneOnTargetDay = false;
      if (scheduledDateStr == todayStr) {
        isDoneOnTargetDay = HiveService.isDailyQuizDone();
      }

      int streak = box.get('streak', defaultValue: 0) as int;

      // Only show streak warning if quiz is not done on the target day AND user has an active streak
      if (!isDoneOnTargetDay && streak > 0) {
        await _notificationsPlugin.cancel(id: 200);
        await _notificationsPlugin.zonedSchedule(
          id: 200,
          title: AppLanguage.getString('reminder_title'),
          body: AppLanguage.getString('notif_streak_warning'),
          scheduledDate: scheduledEvening,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'daily_reminder_channel',
              'Daily Reminders',
              channelDescription: 'Scheduled study reminders',
              importance: Importance.max,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } else {
        await _notificationsPlugin.cancel(id: 200);
      }

      AppLog.d("AI_DEBUG: Personalized reminders rescheduled.");
    } catch (e) {
      AppLog.e("AI_DEBUG: Error rescheduling reminders: $e");
    }
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
        AppLog.d("AI_DEBUG: FCM Token: $token");
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      AppLog.d("AI_DEBUG: Error saving FCM token: $e");
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

  static Future<void> scheduleDailyReminder({
    required int id,
    required int hour,
    required int minute,
    required String titleKey,
    required String bodyKey,
  }) async {
    await _notificationsPlugin.zonedSchedule(
      id: id,
      title: AppLanguage.getString(titleKey),
      body: AppLanguage.getString(bodyKey),
      scheduledDate: _nextInstanceOfTime(hour, minute),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder_channel',
          'Daily Reminders',
          channelDescription: 'Scheduled study reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    AppLog.d("AI_DEBUG: Scheduled notification $id at $hour:$minute");
  }

  // --- NEW: Send notification to all users via FCM Topic (v1 API) ---
  static Future<bool> sendNotificationToAll({required String title, required String body}) async {
    // IMPORTANT: Replace these with details from your Service Account JSON file
    const String projectId = "tnpsc-prepare-app-koilra-c9998";
    const String clientEmail = "firebase-adminsdk-fbsvc@tnpsc-prepare-app-koilra-c9998.iam.gserviceaccount.com";
    const String privateKey = "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCZ4MSkoDTeAETy\n3OMukAm+6mCKOOCFwBo55xk0XvFCaUz/ZLRJHL92JEyup5GN9FHEkxTTWohr23Tm\nUBatcJW7JmISRgPrv45mb/SUwr4n1bvN93hxB8ku8TVdpAkcoVd+j/hHgcRITTwe\nkNIUlwxJEqkAWd50e2ziiQMCTHMVpMVieGt7ZjthMblScs9jF5hfU1erxGJ2gdwr\nPor3Wevdy+f4SwDhLBcwqPVnLRs7Lg02OvXE+9y1fc/3g8x9l+VRRlxU1I1cgMxP\njefwzh3gFbCXE8NrQsrvPCzmg5MF/lbHga4ujXrG6qD7xlTzobe6VttdRvtEMex9\nA3TQXOPxAgMBAAECggEAHGfTpRg16i1ejP6dqYDJa8bUX2+0crxNmxbAHlzQaJQL\ntLGgXkbCSUrWJP+l7PCHD6SfGY0C1fZDFCkApq+71Dp3rCvkmWZZISvVmIiCldPs\nwU7HmwX264V3dnvLes+F2UU2bezUkQxA5tuRDF/90pdxPzFX0WTfasokFg6KyBnD\nUmXwq3DDBfLrNl3P5UPHRAXmhD7tWAJ4JSaIvVwVrHxxBoMMtl/YIaGppcXFFUuY\nLDBqahuJfDhJgGC43op33/h7BYY1zCcAvMIuhRd+ebcr05TrzKOhtHMwUlFBeiHX\n+eYR++HXtRBDcNcskY+UrOi+8VBrnSb7Ms+YIJDB4QKBgQDK+X+Mf3ytGrE9g1tu\n8CEUnJw6pkWSr32XJjN+4Sqzu078GyxVD9OO9/HivZfdbBtO6tzXBfHPTS67+SfI\nyKahlcL03SAGycEokluyCrVYDIqSObsCbvCCs8H6j+ZaUOzu6X/5NT9F3y37NQCS\nxvN7vp5s/joVRfQSnGZVr5zspQKBgQDCE8umSXTd6Je8UkPO7TFqE3BtAVE9lKiZ\nVM3PnLSiurbegy+dsdjhkoZVlX4oioqF7WcJfXFTB90ytGCkti8LZNUQExT9XFlf\nhcdH0OTE9E6xoD2N9KxgWoWmOUtrVhJVod4TOUxwF9tG/wvln7+UuFuKIfPISvUC\nVzkOBt98XQKBgQC/XEhnUo5duUuenegnCFd30krsdHQlXjQ+u3JTTb/voUlPH+NE\n8t3W7WXsCilSRSjd10mLo3wdoDvOVpGul5WZw9MA/jTCkZX9RTcT/UqJD5HZWHo6\nShOQdh8MtnxLa/5lJFlVv2C+5DG6o3a96roFUWqVgX2LLt90aGWGpUGCTQKBgHwD\nFC1UYNXvaw3N70BJNjsW4s70eYoE9NrNYpmYA6C7+GAkqYd1fiVdcHM9jBixtiQv\n95gLzR8GNmTQ97QoKdV4/+A+oTnoCb/NBvKv246yoZpEzzBnOMJ09VOq5rNWk26e\neP4Frf8ub1JlZJ+8vTl1uCCC43iH1RlCzNVWtPWNAoGAFVFM0v4flTvAb6B/qk83\nzKQmh0UhvQiEXM+ohXvBNpca8N9/nqVmsc2J7IeAwTUgsuDS3ScO+diVTKfUOz9q\nYg1dJ00LssqkCrW1/jWP5OlAR2IgzkKbCVjFT8OM8bqJlD/vhArmBNsu9IeuuENo\nZiweN9C3ej86tEjGMdC2lu8=\n-----END PRIVATE KEY-----\n"; // Ensure it starts with -----BEGIN PRIVATE KEY-----

    if (projectId == "tnpsc-prepare-app-koilra-c9998") {
      AppLog.d("AI_DEBUG: FCM v1 credentials not set. Notification not sent.");
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
        AppLog.d("AI_DEBUG: FCM v1 topic message sent successfully!");
        return true;
      } else {
        AppLog.d("AI_DEBUG: FCM v1 error: ${response.body}");
        return false;
      }
    } catch (e) {
      AppLog.d("AI_DEBUG: Error sending FCM v1: $e");
      return false;
    }
  }

  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    try {
      // Ensure timezones are initialized even if called out of order
      if (!_isInitialized) {
        tz.initializeTimeZones();
      }

      final tz.Location india = tz.getLocation('Asia/Kolkata');
      final tz.TZDateTime now = tz.TZDateTime.now(india);
      tz.TZDateTime scheduledDate =
          tz.TZDateTime(india, now.year, now.month, now.day, hour, minute);
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }
      return scheduledDate;
    } catch (e) {
      AppLog.d("AI_DEBUG: Timezone error, falling back to local: $e");
      final now = AppDate.getISTNow();
      DateTime scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }
      
      try {
        return tz.TZDateTime.from(scheduledDate, tz.local);
      } catch (_) {
        // Absolute fallback if tz.local is also not ready
        return tz.TZDateTime.now(tz.UTC).add(const Duration(hours: 5, minutes: 30));
      }
    }
  }
}
