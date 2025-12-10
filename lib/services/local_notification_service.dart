import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter/foundation.dart';
import 'dart:math';
import '../models/schedule.dart';

/// Local notification service for scheduling notifications
/// Uses approximate scheduling to avoid exact timer issues with app stores
class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  /// Initialize the local notification service
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize timezone
      tz.initializeTimeZones();
      
      // Android initialization settings
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      
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

      // Request permissions (iOS)
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _notifications
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
      }

      // Request permissions (Android 13+)
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _notifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();

        // Create notification channel for Android
        const androidChannel = AndroidNotificationChannel(
          'scheduled_notifications',
          'Scheduled Notifications',
          description: 'Notifications for scheduled wardrobe reminders',
          importance: Importance.high,
          playSound: true,
        );

        await _notifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(androidChannel);
      }

      _isInitialized = true;
      if (kDebugMode) {
        debugPrint('✅ Local Notification Service initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Local Notification Service initialization failed: $e');
      }
    }
  }

  /// Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    if (kDebugMode) {
      debugPrint('Notification tapped: ${response.payload}');
    }
    // Handle navigation if needed
  }

  /// Schedule a notification based on schedule configuration
  /// Uses approximate scheduling with randomization to avoid exact timer issues
  static Future<bool> scheduleNotification(Schedule schedule) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (!schedule.isEnabled) {
      // Cancel existing notification if disabled
      await cancelNotification(schedule.id);
      return true;
    }

    try {
      // Calculate next occurrence time with some randomization
      final nextTime = _calculateNextNotificationTime(schedule);
      
      if (nextTime == null) {
        if (kDebugMode) {
          debugPrint('No valid time found for schedule: ${schedule.id}');
        }
        return false;
      }

      // Add small randomization (±2 minutes) to avoid exact timing
      final random = Random();
      final variance = random.nextInt(5) - 2; // -2 to +2 minutes
      final scheduledTime = nextTime.add(Duration(minutes: variance));

      // Create notification details
      final androidDetails = AndroidNotificationDetails(
        'scheduled_notifications',
        'Scheduled Notifications',
        channelDescription: 'Notifications for scheduled wardrobe reminders',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Generate a unique notification ID from schedule ID
      // Use hash code to ensure uniqueness while keeping it as int
      final notificationId = schedule.id.hashCode.abs() % 2147483647; // Max int32
      
      // Schedule the notification
      await _notifications.zonedSchedule(
        notificationId,
        schedule.title,
        schedule.description ?? 'Time to check your wardrobe!',
        tz.TZDateTime.from(scheduledTime, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: _getDateTimeComponents(schedule),
        payload: schedule.id,
      );

      if (kDebugMode) {
        debugPrint('✅ Scheduled notification for ${schedule.title} at ${scheduledTime.toString()}');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to schedule notification: $e');
      }
      return false;
    }
  }

  /// Calculate the next notification time based on schedule
  static DateTime? _calculateNextNotificationTime(Schedule schedule) {
    final now = DateTime.now();
    final scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      schedule.hour,
      schedule.minute,
    );

    // Check if today is a valid day
    final todayWeekday = now.weekday % 7; // Convert to 0-6 (Sunday = 0)
    
    if (schedule.daysOfWeek.contains(todayWeekday)) {
      // If scheduled time hasn't passed today, use today
      if (scheduledTime.isAfter(now)) {
        return scheduledTime;
      }
    }

    // Find next valid day
    for (int i = 1; i <= 7; i++) {
      final nextDay = now.add(Duration(days: i));
      final nextWeekday = nextDay.weekday % 7;
      
      if (schedule.daysOfWeek.contains(nextWeekday)) {
        return DateTime(
          nextDay.year,
          nextDay.month,
          nextDay.day,
          schedule.hour,
          schedule.minute,
        );
      }
    }

    return null;
  }

  /// Get DateTimeComponents for recurring notifications
  static DateTimeComponents? _getDateTimeComponents(Schedule schedule) {
    if (schedule.daysOfWeek.length == 7) {
      // Daily
      return DateTimeComponents.time;
    } else if (schedule.daysOfWeek.length == 1) {
      // Weekly on specific day
      return DateTimeComponents.dayOfWeekAndTime;
    } else {
      // Multiple days - use time only, we'll handle day matching manually
      return DateTimeComponents.time;
    }
  }

  /// Cancel a scheduled notification
  static Future<void> cancelNotification(String scheduleId) async {
    try {
      final notificationId = scheduleId.hashCode.abs() % 2147483647; // Max int32
      await _notifications.cancel(notificationId);
      if (kDebugMode) {
        debugPrint('✅ Cancelled notification for schedule: $scheduleId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to cancel notification: $e');
      }
    }
  }

  /// Cancel all scheduled notifications
  static Future<void> cancelAllNotifications() async {
    try {
      await _notifications.cancelAll();
      if (kDebugMode) {
        debugPrint('✅ Cancelled all notifications');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to cancel all notifications: $e');
      }
    }
  }

  /// Reschedule all notifications for a list of schedules
  static Future<void> rescheduleAll(List<Schedule> schedules) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Cancel all existing notifications first
    await cancelAllNotifications();

    // Schedule all enabled schedules
    for (final schedule in schedules) {
      if (schedule.isEnabled) {
        await scheduleNotification(schedule);
      }
    }
  }
}

