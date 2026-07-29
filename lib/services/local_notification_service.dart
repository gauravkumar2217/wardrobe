import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/schedule.dart';
import '../screens/profile/create_avatar_screen.dart';
import '../screens/suggestions/daily_suggestion_screen.dart';
import '../screens/suggestions/outfit_suggestion_screen.dart';
import '../utils/navigator_key.dart' show navigatorKey;

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
      // Use launcher_icon which exists in mipmap folders
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

    // Handle navigation based on payload
    if (response.payload != null && response.payload!.isNotEmpty) {
      try {
        final payloadData = jsonDecode(response.payload!);
        if (payloadData is Map<String, dynamic>) {
          final type = payloadData['type'] as String?;

          if (type == 'outfit_suggestion') {
            // Navigate to outfit suggestion screen using global navigator key
            if (kDebugMode) {
              debugPrint(
                  'Outfit suggestion notification tapped - navigating to suggestion screen');
            }

            // Use the global navigator key from main.dart
            navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (_) => const OutfitSuggestionScreen(),
              ),
            );
          } else if (type == 'daily_suggestion') {
            if (kDebugMode) {
              debugPrint(
                  'Daily suggestion notification tapped - navigating to daily suggestion screen');
            }
            navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (_) => const DailySuggestionScreen(),
              ),
            );
          } else if (type == 'avatar_ready' || type == 'avatar_failed') {
            if (kDebugMode) {
              debugPrint(
                  'Avatar notification tapped - navigating to create avatar screen');
            }
            navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (_) => const CreateAvatarScreen(),
              ),
            );
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error parsing notification payload: $e');
        }
      }
    }
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

      // Create notification details with modern styling
      final androidDetails = AndroidNotificationDetails(
        'scheduled_notifications',
        'Scheduled Notifications',
        channelDescription: 'Notifications for scheduled wardrobe reminders',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        color: const Color(0xFF043915), // Purple theme color
        colorized: true, // Use color for notification background
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
        icon: '@mipmap/launcher_icon',
        showWhen: true,
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
      final notificationId =
          schedule.id.hashCode.abs() % 2147483647; // Max int32

      // Schedule the notification
      final purpose = schedule.filterSettings['purpose'] as String?;
      final payloadData = {
        'type': purpose == 'daily_suggestion' ? 'daily_suggestion' : 'outfit_suggestion',
        'scheduleId': schedule.id,
      };
      final payload = jsonEncode(payloadData);

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
        payload: payload,
      );

      if (kDebugMode) {
        debugPrint(
            '✅ Scheduled notification for ${schedule.title} at ${scheduledTime.toString()}');
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
      final notificationId =
          scheduleId.hashCode.abs() % 2147483647; // Max int32
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

  /// Check if notification permissions are granted
  static Future<bool> checkPermissions() async {
    print('');
    print('═══════════════════════════════════════════════════════');
    print('🔍 CHECKING NOTIFICATION PERMISSIONS');
    print('═══════════════════════════════════════════════════════');
    print('⏰ Time: ${DateTime.now().toIso8601String()}');
    print('📱 Platform: ${defaultTargetPlatform}');
    print('');

    try {
      if (kDebugMode) {
        debugPrint('🔍 Checking notification permissions...');
        debugPrint('   Platform: ${defaultTargetPlatform}');
      }
      print('🔍 Checking notification permissions...');
      print('   Platform: ${defaultTargetPlatform}');

      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidImplementation =
            _notifications.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        if (androidImplementation == null) {
          print('❌ Android implementation not available');
          if (kDebugMode) {
            debugPrint('❌ Android implementation not available');
          }
          return false;
        }

        print('📱 Requesting Android notification permission...');
        if (kDebugMode) {
          debugPrint('📱 Requesting Android notification permission...');
        }

        final granted =
            await androidImplementation.requestNotificationsPermission();
        print('📱 Permission request completed. Result: $granted');

        if (kDebugMode) {
          debugPrint('📱 Android notification permission result: $granted');
          print('📱 Android notification permission result: $granted');
          if (granted == null) {
            debugPrint(
                '⚠️ Permission request returned null - may need manual permission');
            print(
                '⚠️ Permission request returned null - may need manual permission');
          } else if (granted == false) {
            debugPrint(
                '❌ Permission DENIED - User needs to enable in device settings');
            print(
                '❌ Permission DENIED - User needs to enable in device settings');
          } else {
            debugPrint('✅ Permission GRANTED');
            print('✅ Permission GRANTED');
          }
        }

        return granted ?? false;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosImplementation =
            _notifications.resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();

        if (iosImplementation == null) {
          print('❌ iOS implementation not available');
          if (kDebugMode) {
            debugPrint('❌ iOS implementation not available');
          }
          return false;
        }

        print('📱 Requesting iOS notification permission...');
        if (kDebugMode) {
          debugPrint('📱 Requesting iOS notification permission...');
        }

        final granted = await iosImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        print('📱 Permission request completed. Result: $granted');

        if (kDebugMode) {
          debugPrint('📱 iOS notification permission result: $granted');
          print('📱 iOS notification permission result: $granted');
          if (granted == null) {
            debugPrint('⚠️ Permission request returned null');
            print('⚠️ Permission request returned null');
          } else if (granted == false) {
            debugPrint(
                '❌ Permission DENIED - User needs to enable in device settings');
            print(
                '❌ Permission DENIED - User needs to enable in device settings');
          } else {
            debugPrint('✅ Permission GRANTED');
            print('✅ Permission GRANTED');
          }
        }

        return granted ?? false;
      }

      if (kDebugMode) {
        debugPrint('⚠️ Unknown platform: ${defaultTargetPlatform}');
      }
      return false;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ Error checking permissions: $e');
        debugPrint('Stack trace: $stackTrace');
      }
      return false;
    }
  }

  /// Download image from URL and convert to Uint8List for notification
  static Future<Uint8List?> _downloadImage(String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to download image: $e');
      }
      return null;
    }
  }

  /// Send an immediate notification (not scheduled)
  /// Used by background workers to send notifications right away
  /// [imageUrl] - Optional cloth image URL to display in notification
  static Future<bool> sendImmediateNotification({
    required String title,
    required String body,
    String? payload,
    String? imageUrl,
  }) async {
    print('');
    print('═══════════════════════════════════════════════════════');
    print('🔔 SENDING IMMEDIATE NOTIFICATION');
    print('═══════════════════════════════════════════════════════');
    if (kDebugMode) {
      debugPrint('');
      debugPrint('═══════════════════════════════════════════════════════');
      debugPrint('🔔 SENDING IMMEDIATE NOTIFICATION');
      debugPrint('═══════════════════════════════════════════════════════');
    }

    if (!_isInitialized) {
      if (kDebugMode) {
        debugPrint('⚠️ Service not initialized, initializing now...');
      }
      await initialize();
    } else {
      if (kDebugMode) {
        debugPrint('✅ Service already initialized');
      }
    }

    try {
      // Check and request permissions
      print('🔍 Step 1: Checking permissions...');
      if (kDebugMode) {
        debugPrint('🔍 Step 1: Checking permissions...');
      }
      final hasPermission = await checkPermissions();
      print('📊 Permission check result: $hasPermission');

      if (!hasPermission) {
        print('❌ Step 1 FAILED: Notification permission not granted');
        print('   → User needs to enable notifications in device settings');
        print('   → Android: Settings → Apps → Wardrobe → Notifications');
        print('   → iOS: Settings → Wardrobe → Notifications');
        if (kDebugMode) {
          debugPrint('❌ Step 1 FAILED: Notification permission not granted');
          debugPrint(
              '   → User needs to enable notifications in device settings');
          debugPrint(
              '   → Android: Settings → Apps → Wardrobe → Notifications');
          debugPrint('   → iOS: Settings → Wardrobe → Notifications');
        }
        return false;
      }

      print('✅ Step 1 PASSED: Permissions granted');
      if (kDebugMode) {
        debugPrint('✅ Step 1 PASSED: Permissions granted');
      }

      // Ensure notification channel exists (Android)
      if (defaultTargetPlatform == TargetPlatform.android) {
        print('🔍 Step 2: Creating/verifying Android notification channel...');
        if (kDebugMode) {
          debugPrint(
              '🔍 Step 2: Creating/verifying Android notification channel...');
        }

        const androidChannel = AndroidNotificationChannel(
          'scheduled_notifications',
          'Scheduled Notifications',
          description: 'Notifications for scheduled wardrobe reminders',
          importance: Importance.high,
          playSound: true,
        );

        final androidImplementation =
            _notifications.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        if (androidImplementation != null) {
          await androidImplementation.createNotificationChannel(androidChannel);
          print('✅ Step 2 PASSED: Notification channel created/verified');
          if (kDebugMode) {
            debugPrint(
                '✅ Step 2 PASSED: Notification channel created/verified');
          }
        } else {
          print('⚠️ Step 2 WARNING: Android implementation not available');
          if (kDebugMode) {
            debugPrint(
                '⚠️ Step 2 WARNING: Android implementation not available');
          }
        }
      } else {
        print('⏭️ Step 2 SKIPPED: Not Android platform');
        if (kDebugMode) {
          debugPrint('⏭️ Step 2 SKIPPED: Not Android platform');
        }
      }

      // Download image if provided
      Uint8List? imageData;
      if (imageUrl != null && imageUrl.isNotEmpty) {
        print('🔍 Step 3a: Downloading cloth image...');
        if (kDebugMode) {
          debugPrint('🔍 Step 3a: Downloading cloth image from: $imageUrl');
        }
        imageData = await _downloadImage(imageUrl);
        if (imageData != null) {
          print('✅ Step 3a PASSED: Image downloaded successfully');
          if (kDebugMode) {
            debugPrint('✅ Step 3a PASSED: Image downloaded successfully');
          }
        } else {
          print('⚠️ Step 3a WARNING: Failed to download image, using default');
          if (kDebugMode) {
            debugPrint(
                '⚠️ Step 3a WARNING: Failed to download image, using default');
          }
        }
      }

      // Create notification details
      print('🔍 Step 3: Creating notification details...');
      if (kDebugMode) {
        debugPrint('🔍 Step 3: Creating notification details...');
      }

      // Create BigPictureStyle for modern look with cloth image
      BigPictureStyleInformation? bigPictureStyle;
      AndroidBitmap<Object>? largeIconBitmap;

      if (imageData != null) {
        final imageBitmap = ByteArrayAndroidBitmap(imageData);
        bigPictureStyle = BigPictureStyleInformation(
          imageBitmap,
          largeIcon: imageBitmap,
          contentTitle: title,
          summaryText: body,
          htmlFormatContentTitle: false,
          htmlFormatSummaryText: false,
        );
        largeIconBitmap = imageBitmap;
      } else {
        // Use app icon as large icon with white background
        largeIconBitmap =
            const DrawableResourceAndroidBitmap('@mipmap/launcher_icon');
      }

      final androidDetails = AndroidNotificationDetails(
        'scheduled_notifications',
        'Scheduled Notifications',
        channelDescription: 'Notifications for scheduled wardrobe reminders',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        showWhen: true,
        when: DateTime.now().millisecondsSinceEpoch,
        styleInformation: bigPictureStyle,
        color: const Color(0xFF043915), // Purple theme color
        colorized: true, // Use color for notification background
        largeIcon: largeIconBitmap,
        // Small icon with white background
        icon: '@mipmap/launcher_icon',
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

      print('✅ Step 3 PASSED: Notification details created');
      if (kDebugMode) {
        debugPrint('✅ Step 3 PASSED: Notification details created');
      }

      // Generate a unique notification ID
      final notificationId = DateTime.now().millisecondsSinceEpoch % 2147483647;

      print('🔍 Step 4: Preparing notification...');
      print('   📋 Notification ID: $notificationId');
      print('   📋 Title: "$title"');
      print('   📋 Body: "$body"');
      print('   📋 Payload: ${payload ?? "none"}');
      print('   📋 Platform: ${defaultTargetPlatform}');
      if (kDebugMode) {
        debugPrint('🔍 Step 4: Preparing notification...');
        debugPrint('   📋 Notification ID: $notificationId');
        debugPrint('   📋 Title: "$title"');
        debugPrint('   📋 Body: "$body"');
        debugPrint('   📋 Payload: ${payload ?? "none"}');
        debugPrint('   📋 Platform: ${defaultTargetPlatform}');
      }

      // Show notification immediately
      print('🔍 Step 5: Calling _notifications.show()...');
      if (kDebugMode) {
        debugPrint('🔍 Step 5: Calling _notifications.show()...');
      }

      await _notifications.show(
        notificationId,
        title,
        body,
        details,
        payload: payload,
      );

      print('✅ Step 5 PASSED: show() completed without errors');
      print('✅ SUCCESS: Notification should appear on device');
      print('═══════════════════════════════════════════════════════');
      print('');
      if (kDebugMode) {
        debugPrint('✅ Step 5 PASSED: show() completed without errors');
        debugPrint('✅ SUCCESS: Notification should appear on device');
        debugPrint('═══════════════════════════════════════════════════════');
        debugPrint('');
      }

      return true;
    } catch (e, stackTrace) {
      print('❌ ERROR: Failed to send immediate notification');
      print('   Error: $e');
      print('   Stack trace:');
      print('   $stackTrace');
      print('═══════════════════════════════════════════════════════');
      print('');
      if (kDebugMode) {
        debugPrint('❌ ERROR: Failed to send immediate notification');
        debugPrint('   Error: $e');
        debugPrint('   Stack trace:');
        debugPrint('   $stackTrace');
        debugPrint('═══════════════════════════════════════════════════════');
        debugPrint('');
      }
      return false;
    }
  }

  /// Send a test notification to verify permissions and setup
  static Future<bool> sendTestNotification() async {
    print('');
    print('═══════════════════════════════════════════════════════');
    print('🧪 SEND TEST NOTIFICATION CALLED');
    print('═══════════════════════════════════════════════════════');
    print('⏰ Time: ${DateTime.now().toIso8601String()}');
    print('');

    final result = await sendImmediateNotification(
      title: 'Test Notification',
      body: 'If you see this, notifications are working!',
      payload: 'test',
    );

    print('');
    print('═══════════════════════════════════════════════════════');
    print('🧪 TEST NOTIFICATION COMPLETE');
    print('   Result: $result');
    print('═══════════════════════════════════════════════════════');
    print('');

    return result;
  }
}
