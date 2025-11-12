import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_schedule.dart';
import 'notification_service.dart';

/// Service to manage user notification schedules
class NotificationScheduleService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get Firestore path for notification schedules
  static String _schedulesPath(String userId) {
    return 'users/$userId/notificationSchedules';
  }

  /// Save a notification schedule
  static Future<void> saveSchedule(NotificationSchedule schedule) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      final now = DateTime.now();
      final scheduleData = schedule.toJson();
      scheduleData['updatedAt'] = Timestamp.fromDate(now);

      if (schedule.id.isEmpty) {
        // New schedule
        scheduleData['createdAt'] = Timestamp.fromDate(now);
        await _firestore
            .collection(_schedulesPath(user.uid))
            .add(scheduleData);
      } else {
        // Update existing schedule
        await _firestore
            .collection(_schedulesPath(user.uid))
            .doc(schedule.id)
            .update(scheduleData);
      }

      // Schedule the notification
      await _scheduleNotification(schedule);

      if (kDebugMode) {
        debugPrint('Notification schedule saved: ${schedule.id}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to save notification schedule: $e');
      }
      throw Exception('Failed to save notification schedule: $e');
    }
  }

  /// Get all notification schedules for current user
  static Future<List<NotificationSchedule>> getSchedules() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return [];
    }

    try {
      final snapshot = await _firestore
          .collection(_schedulesPath(user.uid))
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => NotificationSchedule.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to get notification schedules: $e');
      }
      return [];
    }
  }

  /// Get active notification schedules
  static Future<List<NotificationSchedule>> getActiveSchedules() async {
    final schedules = await getSchedules();
    return schedules.where((s) => s.isActive).toList();
  }

  /// Delete a notification schedule
  static Future<void> deleteSchedule(String scheduleId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      await _firestore
          .collection(_schedulesPath(user.uid))
          .doc(scheduleId)
          .delete();

      // Cancel the scheduled notification
      await NotificationService.cancelScheduledNotification(scheduleId.hashCode);

      if (kDebugMode) {
        debugPrint('Notification schedule deleted: $scheduleId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to delete notification schedule: $e');
      }
      throw Exception('Failed to delete notification schedule: $e');
    }
  }

  /// Toggle schedule active status
  static Future<void> toggleSchedule(String scheduleId, bool isActive) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      await _firestore
          .collection(_schedulesPath(user.uid))
          .doc(scheduleId)
          .update({
        'isActive': isActive,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // If activating, reschedule the notification
      if (isActive) {
        final schedules = await getSchedules();
        final schedule = schedules.firstWhere((s) => s.id == scheduleId);
        await _scheduleNotification(schedule);
      } else {
        // If deactivating, cancel the notification
        await NotificationService.cancelScheduledNotification(scheduleId.hashCode);
      }

      if (kDebugMode) {
        debugPrint('Notification schedule toggled: $scheduleId -> $isActive');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to toggle notification schedule: $e');
      }
      throw Exception('Failed to toggle notification schedule: $e');
    }
  }

  /// Schedule notification based on schedule
  static Future<void> _scheduleNotification(
      NotificationSchedule schedule) async {
    if (!schedule.isActive) return;

    try {
      if (schedule.isRepeat) {
        // Schedule for each selected weekday
        for (final weekday in schedule.weekdays) {
          await NotificationService.scheduleWeeklyNotification(
            id: '${schedule.id}_$weekday'.hashCode,
            title: 'Wardrobe - ${schedule.occasion}',
            body: 'Your ${schedule.occasion.toLowerCase()} outfit suggestion is ready!',
            weekday: weekday,
            hour: schedule.time.hour,
            minute: schedule.time.minute,
            occasion: schedule.occasion,
          );
        }
      } else {
        // Schedule one-time notification
        await NotificationService.scheduleOneTimeNotification(
          id: schedule.id.hashCode,
          title: 'Wardrobe - ${schedule.occasion}',
          body: 'Your ${schedule.occasion.toLowerCase()} outfit suggestion is ready!',
          scheduledDate: _getNextScheduledDate(schedule),
          occasion: schedule.occasion,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to schedule notification: $e');
      }
    }
  }

  /// Get next scheduled date for one-time notification
  static DateTime _getNextScheduledDate(NotificationSchedule schedule) {
    final now = DateTime.now();
    var scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      schedule.time.hour,
      schedule.time.minute,
    );

    // If time has passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  /// Reschedule all active notifications (call on app start)
  static Future<void> rescheduleAllNotifications() async {
    try {
      final activeSchedules = await getActiveSchedules();
      for (final schedule in activeSchedules) {
        await _scheduleNotification(schedule);
      }
      if (kDebugMode) {
        debugPrint('Rescheduled ${activeSchedules.length} notification schedules');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to reschedule notifications: $e');
      }
    }
  }
}

