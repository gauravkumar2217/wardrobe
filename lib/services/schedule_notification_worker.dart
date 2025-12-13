import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/schedule.dart';
import '../services/scheduler_service.dart';
import '../services/local_notification_service.dart';
import '../services/cloth_service.dart';
import '../models/cloth.dart';

/// Background worker for scheduled notifications
/// This worker runs periodically to check schedules and send notifications
class ScheduleNotificationWorker {
  static const String taskName = 'scheduleNotificationTask';
  static const String periodicTaskName = 'periodicScheduleCheck';

  /// Initialize the background worker
  static Future<void> initialize() async {
    try {
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: kDebugMode,
      );

      if (kDebugMode) {
        debugPrint('✅ Schedule Notification Worker initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to initialize worker: $e');
      }
    }
  }

  /// Register periodic task to check schedules
  /// Runs every 15 minutes to check if any schedules need to trigger
  static Future<void> registerPeriodicTask() async {
    try {
      await Workmanager().registerPeriodicTask(
        periodicTaskName,
        periodicTaskName,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(
          networkType: NetworkType.not_required,
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: false,
        ),
      );

      if (kDebugMode) {
        debugPrint('✅ Registered periodic schedule check task');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to register periodic task: $e');
      }
    }
  }

  /// Cancel periodic task
  static Future<void> cancelPeriodicTask() async {
    try {
      await Workmanager().cancelByUniqueName(periodicTaskName);
      if (kDebugMode) {
        debugPrint('✅ Cancelled periodic schedule check task');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to cancel periodic task: $e');
      }
    }
  }

  /// Process schedules and send notifications
  /// This is called by the background worker
  static Future<void> processSchedules() async {
    try {
      if (kDebugMode) {
        debugPrint('🔄 Background worker: Checking schedules...');
      }

      // Get userId from shared preferences
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('current_user_id');
      
      if (userId != null) {
        await processSchedulesForUser(userId);
      } else {
        if (kDebugMode) {
          debugPrint('⚠️ No userId found in shared preferences');
        }
      }
      
      if (kDebugMode) {
        debugPrint('✅ Background worker: Schedule check completed');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Background worker error: $e');
      }
    }
  }

  /// Process schedules for a specific user
  static Future<void> processSchedulesForUser(String userId) async {
    try {
      final schedules = await SchedulerService.loadSchedules(userId);
      final now = DateTime.now();
      final currentHour = now.hour;
      final currentMinute = now.minute;
      final currentWeekday = now.weekday % 7; // 0-6 (Sunday = 0)

      for (final schedule in schedules) {
        if (!schedule.isEnabled) continue;

        // Check if this schedule should trigger now
        final shouldTrigger = schedule.daysOfWeek.contains(currentWeekday) &&
            schedule.hour == currentHour &&
            schedule.minute == currentMinute;

        if (shouldTrigger) {
          await _sendScheduleNotification(schedule, userId);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error processing schedules for user $userId: $e');
      }
    }
  }

  /// Send notification for a schedule with filtered clothes
  static Future<void> _sendScheduleNotification(
    Schedule schedule,
    String userId,
  ) async {
    try {
      // Load user's clothes
      List<Cloth> clothes = [];
      
      // Apply wardrobe filter if specified
      final wardrobeId = schedule.filterSettings['wardrobeId'] as String?;
      if (wardrobeId != null) {
        clothes = await ClothService.getClothes(
          userId: userId,
          wardrobeId: wardrobeId,
        );
      } else {
        clothes = await ClothService.getAllUserClothes(userId);
      }

      // Apply filters from schedule
      final filterTypes = (schedule.filterSettings['types'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      final filterOccasions =
          (schedule.filterSettings['occasions'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
      final filterSeasons =
          (schedule.filterSettings['seasons'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
      final filterColors =
          (schedule.filterSettings['colors'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];

      // Filter clothes
      var filteredClothes = clothes;

      if (filterTypes.isNotEmpty) {
        filteredClothes = filteredClothes
            .where((c) => filterTypes.contains(c.clothType))
            .toList();
      }

      if (filterOccasions.isNotEmpty) {
        filteredClothes = filteredClothes
            .where((c) => c.occasions.any((occ) => filterOccasions.contains(occ)))
            .toList();
      }

      if (filterSeasons.isNotEmpty) {
        filteredClothes = filteredClothes
            .where((c) => filterSeasons.contains(c.season))
            .toList();
      }

      if (filterColors.isNotEmpty) {
        filteredClothes = filteredClothes
            .where((c) =>
                c.colorTags.colors.any((color) => filterColors.contains(color)))
            .toList();
      }

      // Create notification message based on filtered clothes
      String notificationBody;
      if (filteredClothes.isEmpty) {
        notificationBody = schedule.description ??
            'No clothes match your filter criteria.';
      } else {
        final count = filteredClothes.length;
        notificationBody = schedule.description ??
            'You have $count item${count > 1 ? 's' : ''} matching your criteria!';
      }

      // Send immediate notification (not scheduled, but triggered now)
      await LocalNotificationService.sendImmediateNotification(
        title: schedule.title,
        body: notificationBody,
        payload: schedule.id,
      );

      if (kDebugMode) {
        debugPrint(
            '✅ Sent schedule notification: ${schedule.title} - $notificationBody');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to send schedule notification: $e');
      }
    }
  }
}

/// Top-level function for background worker callback
/// This must be a top-level function, not a class method
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      if (kDebugMode) {
        debugPrint('🔄 Background task started: $task');
      }

      switch (task) {
        case ScheduleNotificationWorker.periodicTaskName:
          // Process schedules (will get userId from shared preferences)
          await ScheduleNotificationWorker.processSchedules();
          break;
        default:
          if (kDebugMode) {
            debugPrint('⚠️ Unknown task: $task');
          }
      }

      return Future.value(true);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Background task error: $e');
      }
      return Future.value(false);
    }
  });
}

