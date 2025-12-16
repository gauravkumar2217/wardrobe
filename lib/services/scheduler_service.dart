import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../models/schedule.dart';

/// Service for managing schedules in local storage
class SchedulerService {
  static const String _schedulesKey = 'user_schedules';

  /// Save schedules to local storage
  static Future<void> saveSchedules(String userId, List<Schedule> schedules) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final schedulesJson = schedules.map((s) => s.toJson()).toList();
      final jsonString = jsonEncode(schedulesJson);
      await prefs.setString('$_schedulesKey$userId', jsonString);
      
      if (kDebugMode) {
        debugPrint('✅ Saved ${schedules.length} schedules for user: $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to save schedules: $e');
      }
      rethrow;
    }
  }

  /// Load schedules from local storage
  static Future<List<Schedule>> loadSchedules(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('$_schedulesKey$userId');
      
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final List<dynamic> schedulesJson = jsonDecode(jsonString);
      final schedules = schedulesJson
          .map((json) => Schedule.fromJson(json as Map<String, dynamic>))
          .toList();

      if (kDebugMode) {
        debugPrint('✅ Loaded ${schedules.length} schedules for user: $userId');
      }

      return schedules;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to load schedules: $e');
      }
      return [];
    }
  }

  /// Add a new schedule
  static Future<void> addSchedule(String userId, Schedule schedule) async {
    final schedules = await loadSchedules(userId);
    schedules.add(schedule);
    await saveSchedules(userId, schedules);
  }

  /// Update an existing schedule
  static Future<void> updateSchedule(String userId, Schedule schedule) async {
    final schedules = await loadSchedules(userId);
    final index = schedules.indexWhere((s) => s.id == schedule.id);
    
    if (index != -1) {
      schedules[index] = schedule;
      await saveSchedules(userId, schedules);
    } else {
      throw Exception('Schedule not found: ${schedule.id}');
    }
  }

  /// Delete a schedule
  static Future<void> deleteSchedule(String userId, String scheduleId) async {
    final schedules = await loadSchedules(userId);
    schedules.removeWhere((s) => s.id == scheduleId);
    await saveSchedules(userId, schedules);
  }

  /// Get a schedule by ID
  static Future<Schedule?> getSchedule(String userId, String scheduleId) async {
    final schedules = await loadSchedules(userId);
    try {
      return schedules.firstWhere((s) => s.id == scheduleId);
    } catch (e) {
      return null;
    }
  }

  /// Clear all schedules for a user
  static Future<void> clearSchedules(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_schedulesKey$userId');
      
      if (kDebugMode) {
        debugPrint('✅ Cleared all schedules for user: $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to clear schedules: $e');
      }
    }
  }
}

