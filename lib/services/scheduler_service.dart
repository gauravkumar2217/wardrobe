import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../models/schedule.dart';

/// Persists schedules to **Cloud Firestore** (`users/{userId}/schedules/{scheduleId}`)
/// and mirrors to SharedPreferences for offline / background worker use.
class SchedulerService {
  static const String _schedulesKey = 'user_schedules';
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _schedulesRef(String userId) {
    return _firestore.collection('users').doc(userId).collection('schedules');
  }

  static Future<void> _cacheToPrefs(String userId, List<Schedule> schedules) async {
    final prefs = await SharedPreferences.getInstance();
    final schedulesJson = schedules.map((s) => s.toJson()).toList();
    await prefs.setString('$_schedulesKey$userId', jsonEncode(schedulesJson));
    if (kDebugMode) {
      debugPrint('✅ Cached ${schedules.length} schedules locally for user: $userId');
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
        debugPrint('❌ Failed to load schedules from prefs: $e');
      }
      return [];
    }
  }

  static List<Schedule> _schedulesFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) {
    return snap.docs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data());
      data['id'] = doc.id;
      return Schedule.fromJson(data);
    }).toList();
  }

  static Future<List<Schedule>> _fetchFromFirestore(String userId) async {
    final snap = await _schedulesRef(userId).get();
    return _schedulesFromSnapshot(snap);
  }

  /// Replace remote schedules with [schedules]: upsert each doc, delete extras (no full wipe).
  static Future<void> saveSchedules(String userId, List<Schedule> schedules) async {
    try {
      await _cacheToPrefs(userId, schedules);
      final col = _schedulesRef(userId);
      final snap = await col.get();
      final wanted = schedules.map((s) => s.id).toSet();
      var batch = _firestore.batch();
      var ops = 0;
      Future<void> commitIfNeeded() async {
        if (ops >= 400) {
          await batch.commit();
          batch = _firestore.batch();
          ops = 0;
        }
      }
      for (final d in snap.docs) {
        if (!wanted.contains(d.id)) {
          batch.delete(d.reference);
          ops++;
          await commitIfNeeded();
        }
      }
      for (final s in schedules) {
        batch.set(col.doc(s.id), s.toJson());
        ops++;
        await commitIfNeeded();
      }
      if (ops > 0) {
        await batch.commit();
      }
      if (kDebugMode) {
        debugPrint('✅ Synced ${schedules.length} schedules to Firestore for user: $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to save schedules to Firestore: $e');
      }
      rethrow;
    }
  }

  /// Load from Firestore when online; fall back to prefs.
  static Future<List<Schedule>> loadSchedules(String userId) async {
    try {
      final schedules = await _fetchFromFirestore(userId);
      await _cacheToPrefs(userId, schedules);
      if (kDebugMode) {
        debugPrint('✅ Loaded ${schedules.length} schedules from Firestore for user: $userId');
      }
      return schedules;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Firestore load failed, using local cache: $e');
      }
      return _loadFromPrefsOnly(userId);
    }
  }

  static Future<void> addSchedule(String userId, Schedule schedule) async {
    await _schedulesRef(userId).doc(schedule.id).set(schedule.toJson());
    try {
      final all = await _fetchFromFirestore(userId);
      await _cacheToPrefs(userId, all);
    } catch (e) {
      final local = await _loadFromPrefsOnly(userId);
      final merged = [...local.where((s) => s.id != schedule.id), schedule];
      await _cacheToPrefs(userId, merged);
      if (kDebugMode) {
        debugPrint('⚠️ Post-add Firestore refresh failed; merged prefs: $e');
      }
    }
    if (kDebugMode) {
      debugPrint('✅ Added schedule ${schedule.id} to Firestore');
    }
  }

  static Future<void> updateSchedule(String userId, Schedule schedule) async {
    await _schedulesRef(userId).doc(schedule.id).set(
          schedule.toJson(),
          SetOptions(merge: true),
        );
    try {
      final all = await _fetchFromFirestore(userId);
      await _cacheToPrefs(userId, all);
    } catch (e) {
      final local = await _loadFromPrefsOnly(userId);
      final i = local.indexWhere((s) => s.id == schedule.id);
      if (i >= 0) {
        local[i] = schedule;
      } else {
        local.add(schedule);
      }
      await _cacheToPrefs(userId, local);
      if (kDebugMode) {
        debugPrint('⚠️ Post-update Firestore refresh failed; merged prefs: $e');
      }
    }
    if (kDebugMode) {
      debugPrint('✅ Updated schedule ${schedule.id} in Firestore');
    }
  }

  static Future<void> deleteSchedule(String userId, String scheduleId) async {
    await _schedulesRef(userId).doc(scheduleId).delete();
    try {
      final all = await _fetchFromFirestore(userId);
      await _cacheToPrefs(userId, all);
    } catch (e) {
      final local = await _loadFromPrefsOnly(userId);
      local.removeWhere((s) => s.id == scheduleId);
      await _cacheToPrefs(userId, local);
      if (kDebugMode) {
        debugPrint('⚠️ Post-delete Firestore refresh failed; merged prefs: $e');
      }
    }
    if (kDebugMode) {
      debugPrint('✅ Deleted schedule $scheduleId from Firestore');
    }
  }

  static Future<Schedule?> getSchedule(String userId, String scheduleId) async {
    try {
      final doc = await _schedulesRef(userId).doc(scheduleId).get();
      if (!doc.exists || doc.data() == null) return null;
      final data = Map<String, dynamic>.from(doc.data()!);
      data['id'] = doc.id;
      return Schedule.fromJson(data);
    } catch (e) {
      final schedules = await _loadFromPrefsOnly(userId);
      try {
        return schedules.firstWhere((s) => s.id == scheduleId);
      } catch (_) {
        return null;
      }
    }
  }

  static Future<void> clearSchedules(String userId) async {
    try {
      final snap = await _schedulesRef(userId).get();
      final batch = _firestore.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Firestore clear schedules: $e');
      }
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_schedulesKey$userId');
      if (kDebugMode) {
        debugPrint('✅ Cleared all schedules for user: $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Failed to clear schedule prefs: $e');
      }
    }
  }
}
