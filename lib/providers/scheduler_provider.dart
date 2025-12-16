import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/schedule.dart';
import '../services/scheduler_service.dart';
import '../services/local_notification_service.dart';
import '../services/schedule_notification_worker.dart';

/// Provider for managing schedules
class SchedulerProvider with ChangeNotifier {
  List<Schedule> _schedules = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _scheduledNotificationsEnabled = true;

  List<Schedule> get schedules => _schedules;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get scheduledNotificationsEnabled => _scheduledNotificationsEnabled;

  /// Load schedules for a user
  Future<void> loadSchedules(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _schedules = await SchedulerService.loadSchedules(userId);
      
      // Load scheduled notifications enabled state
      final prefs = await SharedPreferences.getInstance();
      _scheduledNotificationsEnabled = prefs.getBool('scheduled_notifications_enabled_$userId') ?? true;
      
      // Store userId for background worker
      await prefs.setString('current_user_id', userId);
      
      // Reschedule all notifications if enabled
      if (_scheduledNotificationsEnabled) {
        await LocalNotificationService.rescheduleAll(_schedules);
        // Register background worker for periodic checks
        await ScheduleNotificationWorker.registerPeriodicTask();
      } else {
        await LocalNotificationService.cancelAllNotifications();
        // Cancel background worker
        await ScheduleNotificationWorker.cancelPeriodicTask();
      }
      
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load schedules: ${e.toString()}';
      debugPrint('Error loading schedules: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add a new schedule
  Future<bool> addSchedule(String userId, Schedule schedule) async {
    try {
      await SchedulerService.addSchedule(userId, schedule);
      _schedules.add(schedule);
      
      // Schedule notification if enabled
      if (_scheduledNotificationsEnabled && schedule.isEnabled) {
        await LocalNotificationService.scheduleNotification(schedule);
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to add schedule: ${e.toString()}';
      debugPrint('Error adding schedule: $e');
      notifyListeners();
      return false;
    }
  }

  /// Update an existing schedule
  Future<bool> updateSchedule(String userId, Schedule schedule) async {
    try {
      await SchedulerService.updateSchedule(userId, schedule);
      final index = _schedules.indexWhere((s) => s.id == schedule.id);
      
      if (index != -1) {
        _schedules[index] = schedule;
      }
      
      // Reschedule notification
      if (_scheduledNotificationsEnabled) {
        if (schedule.isEnabled) {
          await LocalNotificationService.scheduleNotification(schedule);
        } else {
          await LocalNotificationService.cancelNotification(schedule.id);
        }
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update schedule: ${e.toString()}';
      debugPrint('Error updating schedule: $e');
      notifyListeners();
      return false;
    }
  }

  /// Delete a schedule
  Future<bool> deleteSchedule(String userId, String scheduleId) async {
    try {
      await SchedulerService.deleteSchedule(userId, scheduleId);
      _schedules.removeWhere((s) => s.id == scheduleId);
      
      // Cancel notification
      await LocalNotificationService.cancelNotification(scheduleId);
      
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete schedule: ${e.toString()}';
      debugPrint('Error deleting schedule: $e');
      notifyListeners();
      return false;
    }
  }

  /// Toggle scheduled notifications on/off
  Future<void> setScheduledNotificationsEnabled(String userId, bool enabled) async {
    _scheduledNotificationsEnabled = enabled;
    
    // Save to preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('scheduled_notifications_enabled_$userId', enabled);
    
    // Reschedule or cancel all notifications
    if (enabled) {
      await LocalNotificationService.rescheduleAll(_schedules);
      // Register background worker
      await ScheduleNotificationWorker.registerPeriodicTask();
    } else {
      await LocalNotificationService.cancelAllNotifications();
      // Cancel background worker
      await ScheduleNotificationWorker.cancelPeriodicTask();
    }
    
    notifyListeners();
  }

  /// Get schedule by ID
  Schedule? getScheduleById(String scheduleId) {
    try {
      return _schedules.firstWhere((s) => s.id == scheduleId);
    } catch (e) {
      return null;
    }
  }

  /// Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

