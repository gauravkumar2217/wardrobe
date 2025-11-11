import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static GlobalKey<NavigatorState>? navigatorKey;

  /// Set navigator key for navigation from notifications
  static void setNavigatorKey(GlobalKey<NavigatorState> key) {
    navigatorKey = key;
  }

  /// Initialize notification service
  static Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone
    tz.initializeTimeZones();

    // Android initialization settings
    const androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    // iOS initialization settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channels for Android
    await _createNotificationChannels();

    _initialized = true;
  }

  /// Create notification channels for Android
  static Future<void> _createNotificationChannels() async {
    // Channel for daily suggestions
    const dailyChannel = AndroidNotificationChannel(
      'daily_suggestions',
      'Daily Outfit Suggestions',
      description: 'Get daily outfit suggestions at 7 AM',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    // Channel for FCM push notifications
    const fcmChannel = AndroidNotificationChannel(
      'wardrobe_notifications',
      'Wardrobe Notifications',
      description: 'Push notifications from Wardrobe',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (android != null) {
      await android.createNotificationChannel(dailyChannel);
      await android.createNotificationChannel(fcmChannel);
    }
  }

  /// Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    if (kDebugMode) {
      debugPrint('Notification tapped: ${response.id}');
    }

    // Navigate to suggestion screen when notification is tapped
    if (navigatorKey?.currentState != null) {
      navigatorKey!.currentState!.pushNamed('/suggestions');
    }
  }

  /// Schedule daily notification at 7 AM
  static Future<void> scheduleDailySuggestionNotification() async {
    await initialize();

    // Cancel any existing daily notification
    await cancelDailyNotification();

    // Schedule for 7 AM every day
    final now = DateTime.now();
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      7, // 7 AM
    );

    // If 7 AM has already passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    if (kDebugMode) {
      debugPrint('Scheduling daily notification for: $scheduledDate');
    }

    const androidDetails = AndroidNotificationDetails(
      'daily_suggestions',
      'Daily Outfit Suggestions',
      channelDescription: 'Get daily outfit suggestions at 7 AM',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      color: Color(0xFF7C3AED), // Wardrobe brand color (purple)
      colorized: true,
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      // Try exact alarm first (requires permission on Android 12+)
      await _notifications.zonedSchedule(
        0, // Notification ID
        'Wardrobe',
        'Outfit Suggestion Ready! Check out today\'s outfit suggestion',
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
      );
      if (kDebugMode) {
        debugPrint('Daily notification scheduled successfully (exact mode)');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to schedule exact notification: $e');
      }
      // If exact alarms aren't permitted, fall back to inexact scheduling
      // This doesn't require special permission but may be less precise
      try {
        await _notifications.zonedSchedule(
          0, // Notification ID
          'Wardrobe',
          'Outfit Suggestion Ready! Check out today\'s outfit suggestion',
          scheduledDate,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
        );
        if (kDebugMode) {
          debugPrint(
              'Daily notification scheduled successfully (inexact mode)');
        }
      } catch (fallbackError) {
        // If scheduling still fails, log the error but don't crash
        if (kDebugMode) {
          debugPrint('Failed to schedule notification: $fallbackError');
        }
      }
    }
  }

  /// Cancel daily notification
  static Future<void> cancelDailyNotification() async {
    await _notifications.cancel(0);
  }

  /// Show immediate notification (for testing)
  static Future<void> showNotification({
    required String title,
    required String body,
    int id = 1,
  }) async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      'immediate_notifications',
      'Immediate Notifications',
      channelDescription: 'Immediate notifications',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      color: Color(0xFF7C3AED), // Wardrobe brand color (purple)
      colorized: true,
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(id, title, body, notificationDetails);
  }

  /// Request notification permissions
  static Future<bool> requestPermissions() async {
    await initialize();

    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (android != null) {
      // Request notification permission (Android 13+)
      await android.requestNotificationsPermission();
    }

    final ios = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();

    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    return true;
  }

  /// Check if exact alarm permission is granted (Android 12+)
  /// Returns true if permission is granted or not needed (Android < 12)
  static Future<bool> canScheduleExactAlarms() async {
    try {
      const platform = MethodChannel('com.wardrobe_chat.app/notifications');
      final bool? result = await platform.invokeMethod('canScheduleExactAlarms');
      return result ?? false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error checking exact alarm permission: $e');
      }
      // If method doesn't exist or fails, assume permission is available
      // (for older Android versions or if native code isn't set up)
      return true;
    }
  }

  /// Request exact alarm permission (Android 12+)
  /// Opens system settings for the user to grant permission
  static Future<bool> requestExactAlarmPermission() async {
    try {
      const platform = MethodChannel('com.wardrobe_chat.app/notifications');
      final bool? result = await platform.invokeMethod('requestExactAlarmPermission');
      return result ?? false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error requesting exact alarm permission: $e');
      }
      return false;
    }
  }

  /// Show notification from FCM message
  static Future<void> showFCMNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
    int id = 999,
  }) async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      'wardrobe_notifications',
      'Wardrobe Notifications',
      channelDescription: 'Push notifications from Wardrobe',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      color: Color(0xFF7C3AED), // Wardrobe brand color (purple)
      colorized: true,
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(id, title, body, notificationDetails);
  }
}
