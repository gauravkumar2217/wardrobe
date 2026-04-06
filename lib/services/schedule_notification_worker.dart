import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/schedule.dart';
import '../services/scheduler_service.dart';
import '../services/local_notification_service.dart';
import '../services/cloth_service.dart';
import '../models/cloth.dart';
import '../models/outfit_suggestion.dart';
import '../services/outfit_suggestion_service.dart';

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
      // Cancel any existing task first to avoid duplicates
      await Workmanager().cancelByUniqueName(periodicTaskName);

      // Wait a bit before registering new task
      await Future.delayed(const Duration(milliseconds: 100));

      await Workmanager().registerPeriodicTask(
        periodicTaskName,
        periodicTaskName,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(
          networkType: NetworkType.notRequired,
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: false,
        ),
      );

      // Store registration timestamp
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'periodic_task_last_registered', DateTime.now().toIso8601String());

      if (kDebugMode) {
        debugPrint(
            '✅ Registered periodic schedule check task (runs every 15 minutes)');
        debugPrint('⏰ Registration time: ${DateTime.now().toIso8601String()}');
      }
      print(
          '✅ Registered periodic schedule check task (runs every 15 minutes)');
      print('⏰ Registration time: ${DateTime.now().toIso8601String()}');
      print(
          '💡 Task will run automatically every 15 minutes in the background');
      print('💡 Check terminal logs to see when the worker executes');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to register periodic task: $e');
      }
      print('❌ Failed to register periodic task: $e');
    }
  }

  /// Cancel periodic task
  static Future<void> cancelPeriodicTask() async {
    try {
      await Workmanager().cancelByUniqueName(periodicTaskName);
      if (kDebugMode) {
        debugPrint('✅ Cancelled periodic schedule check task');
      }
      print('✅ Cancelled periodic schedule check task');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to cancel periodic task: $e');
      }
      print('❌ Failed to cancel periodic task: $e');
    }
  }

  /// Check if periodic task is registered (for debugging)
  /// Note: Workmanager doesn't provide a direct way to check task status,
  /// but we can verify by attempting to register and checking for errors
  static Future<Map<String, dynamic>> getTaskStatus() async {
    try {
      // Note: Workmanager doesn't expose task status directly
      // We'll return information about when it was last registered
      final prefs = await SharedPreferences.getInstance();
      final lastRegistered = prefs.getString('periodic_task_last_registered');

      return {
        'isRegistered': lastRegistered != null,
        'lastRegistered': lastRegistered,
        'taskName': periodicTaskName,
        'frequency': '15 minutes',
        'note':
            'Workmanager runs tasks in background. Check device logs to verify execution.',
      };
    } catch (e) {
      return {
        'error': e.toString(),
      };
    }
  }

  /// Process schedules and send notifications
  /// This is called by the background worker
  static Future<void> processSchedules() async {
    print('');
    print('═══════════════════════════════════════════════════════');
    print('🔄 BACKGROUND WORKER: processSchedules() called');
    print('═══════════════════════════════════════════════════════');
    print('⏰ Time: ${DateTime.now().toIso8601String()}');

    try {
      if (kDebugMode) {
        debugPrint('🔄 Background worker: Checking schedules...');
      }
      print('🔄 Background worker: Checking schedules...');

      // Get userId from shared preferences
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('current_user_id');

      if (userId != null) {
        print('✅ Found userId: $userId');
        await processSchedulesForUser(userId);
      } else {
        if (kDebugMode) {
          debugPrint('⚠️ No userId found in shared preferences');
        }
        print('⚠️ No userId found in shared preferences');
        print('💡 Make sure user is logged in and schedules are loaded');
      }

      if (kDebugMode) {
        debugPrint('✅ Background worker: Schedule check completed');
      }
      print('✅ Background worker: Schedule check completed');
      print('═══════════════════════════════════════════════════════');
      print('');
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ Background worker error: $e');
        debugPrint('Stack trace: $stackTrace');
      }
      print('❌ Background worker error: $e');
      print('Stack trace: $stackTrace');
      print('═══════════════════════════════════════════════════════');
      print('');
    }
  }

  /// Process schedules for a specific user
  /// Checks schedules that should have triggered in the last 15 minutes
  /// This accounts for the fact that the worker runs every 15 minutes
  static Future<void> processSchedulesForUser(String userId) async {
    print('');
    print('═══════════════════════════════════════════════════════');
    print('🔄 BACKGROUND WORKER: Processing schedules');
    print('═══════════════════════════════════════════════════════');
    print('👤 User ID: $userId');

    try {
      final schedules = await SchedulerService.loadSchedules(userId);
      final now = DateTime.now();
      final fifteenMinutesAgo = now.subtract(const Duration(minutes: 15));

      if (kDebugMode) {
        debugPrint(
            '🕐 Current time: ${now.hour}:${now.minute.toString().padLeft(2, '0')}');
        debugPrint(
            '🕐 Checking time range: ${fifteenMinutesAgo.hour}:${fifteenMinutesAgo.minute.toString().padLeft(2, '0')} to ${now.hour}:${now.minute.toString().padLeft(2, '0')}');
        debugPrint('📋 Checking ${schedules.length} schedule(s)...');
      }
      print(
          '🕐 Current time: ${now.hour}:${now.minute.toString().padLeft(2, '0')}');
      print(
          '🕐 Checking time range: ${fifteenMinutesAgo.hour}:${fifteenMinutesAgo.minute.toString().padLeft(2, '0')} to ${now.hour}:${now.minute.toString().padLeft(2, '0')}');
      print('📋 Total schedules to check: ${schedules.length}');

      int schedulesFound = 0;
      int notificationsSent = 0;
      final processedScheduleIds = <String>{};

      // Check each minute in the last 15 minutes
      // This ensures we catch schedules even if the worker runs slightly late
      for (int minutesBack = 0; minutesBack <= 15; minutesBack++) {
        final checkTime = now.subtract(Duration(minutes: minutesBack));
        final checkHour = checkTime.hour;
        final checkMinute = checkTime.minute;
        final checkWeekday = checkTime.weekday % 7; // 0-6 (Sunday = 0)

        for (final schedule in schedules) {
          if (!schedule.isEnabled) {
            continue;
          }

          // Skip if we already processed this schedule in this check cycle
          if (processedScheduleIds.contains(schedule.id)) {
            continue;
          }

          // Check if this schedule should have triggered at this time
          final shouldHaveTriggered =
              schedule.daysOfWeek.contains(checkWeekday) &&
                  schedule.hour == checkHour &&
                  schedule.minute == checkMinute;

          if (shouldHaveTriggered) {
            schedulesFound++;
            processedScheduleIds.add(schedule.id);

            if (kDebugMode) {
              debugPrint(
                  '✅ Found schedule that should have triggered: ${schedule.title} at $checkHour:${checkMinute.toString().padLeft(2, '0')}');
            }
            print(
                '✅ Found schedule that should have triggered: ${schedule.title} at $checkHour:${checkMinute.toString().padLeft(2, '0')}');

            // Send notification for this schedule
            try {
              final sent = await _sendScheduleNotification(schedule, userId);
              if (sent) {
                notificationsSent++;
                if (kDebugMode) {
                  debugPrint('📤 Sent notification for: ${schedule.title}');
                }
                print('📤 ✅ Sent notification for: ${schedule.title}');
              } else {
                if (kDebugMode) {
                  debugPrint(
                      '⚠️ Notification not sent for ${schedule.title} (permission issue?)');
                }
                print(
                    '⚠️ ❌ Notification NOT sent for ${schedule.title} (permission issue?)');
              }
            } catch (e) {
              if (kDebugMode) {
                debugPrint(
                    '❌ Failed to send notification for ${schedule.title}: $e');
              }
              print('❌ Error sending notification for ${schedule.title}: $e');
            }
          }
        }
      }

      if (kDebugMode) {
        debugPrint(
            '✅ Background worker: Found $schedulesFound schedule(s), sent $notificationsSent notification(s)');
      }
      print(
          '✅ Background worker: Found $schedulesFound schedule(s), sent $notificationsSent notification(s)');
      print('═══════════════════════════════════════════════════════');
      print('');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error processing schedules for user $userId: $e');
      }
      print('❌ Error processing schedules for user $userId: $e');
      print('');
    }
  }

  /// Manually check schedules from the last 15 minutes
  /// Returns a map with results for UI display
  static Future<Map<String, dynamic>> manualCheckLast15Minutes(
      String userId) async {
    print('');
    print('═══════════════════════════════════════════════════════');
    print('🔄 MANUAL CHECK: Starting check for last 15 minutes');
    print('═══════════════════════════════════════════════════════');
    print('👤 User ID: $userId');

    try {
      if (kDebugMode) {
        debugPrint(
            '🔄 Manual check: Checking schedules from last 15 minutes...');
      }
      print('🔄 Manual check: Checking schedules from last 15 minutes...');

      final schedules = await SchedulerService.loadSchedules(userId);
      final now = DateTime.now();
      final fifteenMinutesAgo = now.subtract(const Duration(minutes: 15));

      if (kDebugMode) {
        debugPrint(
            '🕐 Checking time range: ${fifteenMinutesAgo.hour}:${fifteenMinutesAgo.minute.toString().padLeft(2, '0')} to ${now.hour}:${now.minute.toString().padLeft(2, '0')}');
        debugPrint('📋 Total schedules to check: ${schedules.length}');
      }
      print(
          '🕐 Checking time range: ${fifteenMinutesAgo.hour}:${fifteenMinutesAgo.minute.toString().padLeft(2, '0')} to ${now.hour}:${now.minute.toString().padLeft(2, '0')}');
      print('📋 Total schedules to check: ${schedules.length}');

      int schedulesFound = 0;
      int notificationsSent = 0;
      final foundSchedules = <Schedule>[];

      // Check each minute in the last 15 minutes
      for (int minutesBack = 0; minutesBack <= 15; minutesBack++) {
        final checkTime = now.subtract(Duration(minutes: minutesBack));
        final checkHour = checkTime.hour;
        final checkMinute = checkTime.minute;
        final checkWeekday = checkTime.weekday % 7; // 0-6 (Sunday = 0)

        for (final schedule in schedules) {
          if (!schedule.isEnabled) continue;

          // Check if this schedule should have triggered at this time
          final shouldHaveTriggered =
              schedule.daysOfWeek.contains(checkWeekday) &&
                  schedule.hour == checkHour &&
                  schedule.minute == checkMinute;

          if (shouldHaveTriggered) {
            // Check if we already found this schedule
            if (!foundSchedules.any((s) => s.id == schedule.id)) {
              schedulesFound++;
              foundSchedules.add(schedule);

              if (kDebugMode) {
                debugPrint(
                    '✅ Found schedule that should have triggered: ${schedule.title} at $checkHour:${checkMinute.toString().padLeft(2, '0')}');
              }
              print(
                  '✅ Found schedule that should have triggered: ${schedule.title} at $checkHour:${checkMinute.toString().padLeft(2, '0')}');

              // Send notification for this schedule
              try {
                final sent = await _sendScheduleNotification(schedule, userId);
                if (sent) {
                  notificationsSent++;
                  if (kDebugMode) {
                    debugPrint('📤 Sent notification for: ${schedule.title}');
                  }
                  print('📤 ✅ Sent notification for: ${schedule.title}');
                } else {
                  if (kDebugMode) {
                    debugPrint(
                        '⚠️ Notification not sent for ${schedule.title} (permission issue?)');
                  }
                  print(
                      '⚠️ ❌ Notification NOT sent for ${schedule.title} (permission issue?)');
                }
              } catch (e) {
                if (kDebugMode) {
                  debugPrint(
                      '❌ Failed to send notification for ${schedule.title}: $e');
                }
              }
            }
          }
        }
      }

      final message = schedulesFound > 0
          ? 'Found $schedulesFound schedule(s) and sent $notificationsSent notification(s)'
          : 'No schedules found in the last 15 minutes';

      if (kDebugMode) {
        debugPrint('✅ Manual check completed: $message');
      }

      print('');
      print('═══════════════════════════════════════════════════════');
      print('📊 MANUAL CHECK RESULTS:');
      print('   Schedules Found: $schedulesFound');
      print('   Notifications Sent: $notificationsSent');
      print('   Message: $message');
      print('═══════════════════════════════════════════════════════');
      print('');

      return {
        'schedulesFound': schedulesFound,
        'notificationsSent': notificationsSent,
        'message': message,
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error in manual check: $e');
      }
      return {
        'schedulesFound': 0,
        'notificationsSent': 0,
        'message': 'Error checking schedules: $e',
      };
    }
  }

  /// Test method to send notification for a schedule directly (for debugging)
  /// This bypasses the background worker and shows logs in terminal
  static Future<Map<String, dynamic>> testSendScheduleNotification(
    Schedule schedule,
    String userId,
  ) async {
    print('');
    print('═══════════════════════════════════════════════════════');
    print('🧪 TEST: Sending notification for schedule directly');
    print('═══════════════════════════════════════════════════════');
    print('📋 Schedule: ${schedule.title}');
    print('👤 User ID: $userId');
    print('');

    try {
      final sent = await _sendScheduleNotification(schedule, userId);

      print('');
      print('═══════════════════════════════════════════════════════');
      print('📊 TEST RESULT:');
      print('   Notification Sent: $sent');
      print('═══════════════════════════════════════════════════════');
      print('');

      return {
        'success': sent,
        'message': sent
            ? 'Notification sent successfully!'
            : 'Failed to send notification. Check logs above.',
      };
    } catch (e, stackTrace) {
      print('');
      print('❌ TEST ERROR:');
      print('   Error: $e');
      print('   Stack trace: $stackTrace');
      print('═══════════════════════════════════════════════════════');
      print('');

      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  /// Send notification for a schedule with filtered clothes
  /// Returns true if notification was sent successfully, false otherwise
  static Future<bool> _sendScheduleNotification(
    Schedule schedule,
    String userId,
  ) async {
    if (kDebugMode) {
      debugPrint('');
      debugPrint('═══════════════════════════════════════════════════════');
      debugPrint('📅 PROCESSING SCHEDULE: ${schedule.title}');
      debugPrint('═══════════════════════════════════════════════════════');
      debugPrint('   Schedule ID: ${schedule.id}');
      debugPrint(
          '   Time: ${schedule.hour}:${schedule.minute.toString().padLeft(2, '0')}');
      debugPrint('   Days: ${schedule.daysOfWeek}');
      debugPrint('   Enabled: ${schedule.isEnabled}');
    }

    try {
      // Load user's clothes
      if (kDebugMode) {
        debugPrint('🔍 Step 1: Loading clothes...');
      }

      List<Cloth> clothes = [];

      // Apply wardrobe filter if specified
      final wardrobeId = schedule.filterSettings['wardrobeId'] as String?;
      if (wardrobeId != null) {
        if (kDebugMode) {
          debugPrint('   Filtering by wardrobe: $wardrobeId');
        }
        clothes = await ClothService.getClothes(
          userId: userId,
          wardrobeId: wardrobeId,
        );
      } else {
        if (kDebugMode) {
          debugPrint('   Loading all user clothes');
        }
        clothes = await ClothService.getAllUserClothes(userId);
      }

      if (kDebugMode) {
        debugPrint('✅ Step 1 PASSED: Loaded ${clothes.length} clothes');
      }

      // Apply filters from schedule
      if (kDebugMode) {
        debugPrint('🔍 Step 2: Applying filters...');
      }

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
      final filterColors = (schedule.filterSettings['colors'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];

      if (kDebugMode) {
        debugPrint(
            '   Filter Types: ${filterTypes.isEmpty ? "none" : filterTypes}');
        debugPrint(
            '   Filter Occasions: ${filterOccasions.isEmpty ? "none" : filterOccasions}');
        debugPrint(
            '   Filter Seasons: ${filterSeasons.isEmpty ? "none" : filterSeasons}');
        debugPrint(
            '   Filter Colors: ${filterColors.isEmpty ? "none" : filterColors}');
      }

      // Filter clothes
      var filteredClothes = clothes;

      if (filterTypes.isNotEmpty) {
        final beforeCount = filteredClothes.length;
        filteredClothes = filteredClothes
            .where((c) => filterTypes.contains(c.clothType))
            .toList();
        if (kDebugMode) {
          debugPrint(
              '   After type filter: $beforeCount → ${filteredClothes.length}');
        }
      }

      if (filterOccasions.isNotEmpty) {
        final beforeCount = filteredClothes.length;
        filteredClothes = filteredClothes
            .where(
                (c) => c.occasions.any((occ) => filterOccasions.contains(occ)))
            .toList();
        if (kDebugMode) {
          debugPrint(
              '   After occasion filter: $beforeCount → ${filteredClothes.length}');
        }
      }

      if (filterSeasons.isNotEmpty) {
        final beforeCount = filteredClothes.length;
        filteredClothes = filteredClothes
            .where((c) => filterSeasons.contains(c.season))
            .toList();
        if (kDebugMode) {
          debugPrint(
              '   After season filter: $beforeCount → ${filteredClothes.length}');
        }
      }

      if (filterColors.isNotEmpty) {
        final beforeCount = filteredClothes.length;
        filteredClothes = filteredClothes
            .where((c) =>
                c.colorTags.colors.any((color) => filterColors.contains(color)))
            .toList();
        if (kDebugMode) {
          debugPrint(
              '   After color filter: $beforeCount → ${filteredClothes.length}');
        }
      }

      if (kDebugMode) {
        debugPrint(
            '✅ Step 2 PASSED: Filtered to ${filteredClothes.length} clothes');
      }

      // Generate outfit suggestions from filtered clothes
      if (kDebugMode) {
        debugPrint('🔍 Step 3: Generating outfit suggestions...');
      }

      List<OutfitSuggestion> suggestions = [];
      String notificationBody;
      final purpose = schedule.filterSettings['purpose'] as String?;

      if (filteredClothes.isEmpty) {
        notificationBody =
            schedule.description ?? 'No clothes match your filter criteria.';
        if (kDebugMode) {
          debugPrint(
              '   Message: No clothes found (using default or description)');
        }
      } else {
        if (purpose == 'daily_suggestion') {
          final daily = await OutfitSuggestionService.getOrCreateDailySuggestion(
            userId: userId,
            availableClothes: filteredClothes,
          );
          if (daily != null) {
            suggestions = [daily];
          }
          notificationBody = schedule.description ??
              'Your daily outfit suggestion is ready. Tap to view.';
        } else {
          // Generate outfit suggestions (focus on unworn clothes)
          suggestions = await OutfitSuggestionService.generateSuggestions(
            userId: userId,
            availableClothes: filteredClothes,
            maxSuggestions: 3,
          );

          // Save suggestions for later retrieval
          for (final suggestion in suggestions) {
            await OutfitSuggestionService.saveSuggestion(userId, suggestion);
          }

          if (kDebugMode) {
            debugPrint(
                '   Generated ${suggestions.length} outfit suggestion(s)');
          }

          // Create notification message with suggestion info
          if (suggestions.isNotEmpty) {
            final unwornCount = filteredClothes
                .where((c) =>
                    c.wornAt == null ||
                    DateTime.now().difference(c.wornAt!).inDays >= 7)
                .length;

            notificationBody = schedule.description ??
                'New outfit suggestion! You have $unwornCount unworn item${unwornCount > 1 ? 's' : ''} ready to try. Tap to see suggestions!';

            if (kDebugMode) {
              debugPrint(
                  '   Message: Outfit suggestion with $unwornCount unworn items');
            }
          } else {
            final count = filteredClothes.length;
            notificationBody = schedule.description ??
                'You have $count item${count > 1 ? 's' : ''} matching your criteria!';
            if (kDebugMode) {
              debugPrint(
                  '   Message: Found $count item(s) (no suggestions generated)');
            }
          }
        }
      }

      if (kDebugMode) {
        debugPrint(
            '✅ Step 3 PASSED: Notification message and suggestions created');
        debugPrint('   Final message: "$notificationBody"');
        debugPrint('   Suggestions generated: ${suggestions.length}');
      }

      // Prepare notification payload with suggestion data
      final payloadData = {
        'type': purpose == 'daily_suggestion' ? 'daily_suggestion' : 'outfit_suggestion',
        'scheduleId': schedule.id,
        'suggestionIds': suggestions.map((s) => s.id).toList(),
        'clothIds': suggestions.isNotEmpty
            ? suggestions.first.clothIds
            : filteredClothes.take(5).map((c) => c.id).toList(),
      };
      final payload = jsonEncode(payloadData);

      // Send immediate notification (not scheduled, but triggered now)
      if (kDebugMode) {
        debugPrint('🔍 Step 4: Sending notification...');
        debugPrint('   Payload: $payload');
      }

      // Get first cloth image for notification thumbnail
      String? clothImageUrl;
      if (filteredClothes.isNotEmpty) {
        // Use the first unworn cloth, or first cloth if all are worn
        final unwornCloth = filteredClothes.firstWhere(
          (c) =>
              c.wornAt == null ||
              DateTime.now().difference(c.wornAt!).inDays >= 7,
          orElse: () => filteredClothes.first,
        );
        clothImageUrl = unwornCloth.imageUrl;
      }

      final notificationSent =
          await LocalNotificationService.sendImmediateNotification(
        title: schedule.title,
        body: notificationBody,
        payload: payload,
        imageUrl: clothImageUrl, // Add cloth thumbnail
      );

      if (kDebugMode) {
        if (notificationSent) {
          debugPrint('✅ Step 4 PASSED: Notification sent successfully');
          debugPrint('✅ COMPLETE: Schedule notification processed');
        } else {
          debugPrint('❌ Step 4 FAILED: Notification not sent');
          debugPrint('   Possible reasons:');
          debugPrint('   1. Notification permissions not granted');
          debugPrint('   2. App notifications blocked in device settings');
          debugPrint('   3. Do Not Disturb mode is enabled');
          debugPrint('   4. Notification channel disabled (Android)');
        }
        debugPrint('═══════════════════════════════════════════════════════');
        debugPrint('');
      }

      return notificationSent;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to send schedule notification: $e');
      }
      return false;
    }
  }
}

/// Top-level function for background worker callback
/// This must be a top-level function, not a class method
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print('');
    print('═══════════════════════════════════════════════════════');
    print('🔄 BACKGROUND WORKER CALLBACK DISPATCHER');
    print('═══════════════════════════════════════════════════════');
    print('📅 Task: $task');
    print('⏰ Time: ${DateTime.now().toIso8601String()}');
    print('📦 Input Data: $inputData');

    try {
      if (kDebugMode) {
        debugPrint('🔄 Background task started: $task');
        debugPrint('⏰ Time: ${DateTime.now().toIso8601String()}');
      }

      switch (task) {
        case ScheduleNotificationWorker.periodicTaskName:
          print('✅ Processing periodic schedule check...');
          // Process schedules (will get userId from shared preferences)
          await ScheduleNotificationWorker.processSchedules();
          print('✅ Periodic schedule check completed');
          break;
        default:
          if (kDebugMode) {
            debugPrint('⚠️ Unknown task: $task');
          }
          print('⚠️ Unknown task: $task');
      }

      print('✅ Background task completed successfully');
      print('═══════════════════════════════════════════════════════');
      print('');

      return Future.value(true);
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ Background task error: $e');
        debugPrint('Stack trace: $stackTrace');
      }
      print('❌ Background task error: $e');
      print('Stack trace: $stackTrace');
      print('═══════════════════════════════════════════════════════');
      print('');

      return Future.value(false);
    }
  });
}
