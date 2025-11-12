import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter/material.dart';

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

    _initialized = true;
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

  /// Cancel a scheduled notification by ID
  static Future<void> cancelScheduledNotification(int id) async {
    await _notifications.cancel(id);
  }

  /// Schedule a weekly notification (repeats on specific weekday)
  static Future<void> scheduleWeeklyNotification({
    required int id,
    required String title,
    required String body,
    required int weekday, // 1 = Monday, 7 = Sunday
    required int hour,
    required int minute,
    String? occasion,
  }) async {
    await initialize();

    // Get next occurrence of the weekday
    final now = DateTime.now();
    var scheduledDate = _getNextWeekday(now, weekday, hour, minute);

    if (kDebugMode) {
      debugPrint('Scheduling weekly notification for weekday $weekday at $hour:$minute');
      debugPrint('Next scheduled date: $scheduledDate');
    }

    const androidDetails = AndroidNotificationDetails(
      'scheduled_suggestions',
      'Scheduled Outfit Suggestions',
      channelDescription: 'Notifications for scheduled outfit suggestions',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      color: Color(0xFF7C3AED),
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
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
      if (kDebugMode) {
        debugPrint('Weekly notification scheduled successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to schedule weekly notification: $e');
      }
    }
  }

  /// Schedule a one-time notification
  static Future<void> scheduleOneTimeNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? occasion,
  }) async {
    await initialize();

    final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);

    if (kDebugMode) {
      debugPrint('Scheduling one-time notification for: $tzScheduledDate');
    }

    const androidDetails = AndroidNotificationDetails(
      'scheduled_suggestions',
      'Scheduled Outfit Suggestions',
      channelDescription: 'Notifications for scheduled outfit suggestions',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      color: Color(0xFF7C3AED),
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
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        tzScheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      if (kDebugMode) {
        debugPrint('One-time notification scheduled successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to schedule one-time notification: $e');
      }
    }
  }

  /// Get next occurrence of a weekday at specified time
  static tz.TZDateTime _getNextWeekday(
    DateTime now,
    int weekday,
    int hour,
    int minute,
  ) {
    final currentWeekday = now.weekday; // 1 = Monday, 7 = Sunday
    var daysUntil = weekday - currentWeekday;

    // If weekday has passed this week, schedule for next week
    if (daysUntil < 0) {
      daysUntil += 7;
    }

    // If it's the same day but time has passed, schedule for next week
    if (daysUntil == 0) {
      final scheduledTime = DateTime(now.year, now.month, now.day, hour, minute);
      if (scheduledTime.isBefore(now)) {
        daysUntil = 7;
      }
    }

    final scheduledDate = now.add(Duration(days: daysUntil));
    return tz.TZDateTime(
      tz.local,
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
      hour,
      minute,
    );
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

  /// Request notification permissions (iOS)
  static Future<bool> requestPermissions() async {
    await initialize();

    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (android != null) {
      android.requestNotificationsPermission();
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
}
