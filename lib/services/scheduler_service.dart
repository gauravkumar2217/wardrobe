import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../models/schedule.dart';

/// Local notification schedules (device storage). No Firestore — Laravel push
/// schedules use a separate server model when synced in the future.
class SchedulerService {
  static const String _schedulesKey = 'user_schedules';

  static Future<void> _cacheToPrefs(String userId, List<Schedule> schedules) async {
    final prefs = await SharedPreferences.getInstance();
    final schedulesJson = schedules.map((s) => s.toJson()).toList();
    await prefs.setString('$_schedulesKey$userId', jsonEncode(schedulesJson));
    if (kDebugMode) {
      debugPrint('Cached ${schedules.length} schedules locally for user: $userId');
    }
  }

  static Future<List<Schedule>> _loadFromPrefsOnly(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('$_schedulesKey$userId');
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }
      final List<dynamic> schedulesJson = jsonDecode(jsonString);
      return schedulesJson
          .map((json) => Schedule.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to load schedules from prefs: $e');
      }
      return [];
    }
  }

  static Future<List<Schedule>> loadSchedules(String userId) async {
    return _loadFromPrefsOnly(userId);
  }

  static Future<void> saveSchedules(String userId, List<Schedule> schedules) async {
    await _cacheToPrefs(userId, schedules);
  }

  static Future<void> addSchedule(String userId, Schedule schedule) async {
    final local = await _loadFromPrefsOnly(userId);
    final merged = [...local.where((s) => s.id != schedule.id), schedule];
    await _cacheToPrefs(userId, merged);
  }

  static Future<void> updateSchedule(String userId, Schedule schedule) async {
    final local = await _loadFromPrefsOnly(userId);
    final i = local.indexWhere((s) => s.id == schedule.id);
    if (i >= 0) {
      local[i] = schedule;
    } else {
      local.add(schedule);
    }
    await _cacheToPrefs(userId, local);
  }

  static Future<void> deleteSchedule(String userId, String scheduleId) async {
    final local = await _loadFromPrefsOnly(userId);
    local.removeWhere((s) => s.id == scheduleId);
    await _cacheToPrefs(userId, local);
  }

  static Future<Schedule?> getSchedule(String userId, String scheduleId) async {
    final schedules = await _loadFromPrefsOnly(userId);
    try {
      return schedules.firstWhere((s) => s.id == scheduleId);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearSchedules(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_schedulesKey$userId');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to clear schedule prefs: $e');
      }
    }
  }
}
