import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Model for user notification schedules
class NotificationSchedule {
  final String id;
  final String occasion;
  final TimeOfDay time;
  final bool isRepeat;
  final List<int> weekdays; // 1 = Monday, 7 = Sunday
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  NotificationSchedule({
    required this.id,
    required this.occasion,
    required this.time,
    required this.isRepeat,
    required this.weekdays,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Convert to Firestore document
  Map<String, dynamic> toJson() {
    return {
      'occasion': occasion,
      'hour': time.hour,
      'minute': time.minute,
      'isRepeat': isRepeat,
      'weekdays': weekdays,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Create from Firestore document
  factory NotificationSchedule.fromJson(Map<String, dynamic> json, String id) {
    return NotificationSchedule(
      id: id,
      occasion: json['occasion'] as String,
      time: TimeOfDay(
        hour: json['hour'] as int,
        minute: json['minute'] as int,
      ),
      isRepeat: json['isRepeat'] as bool? ?? false,
      weekdays: (json['weekdays'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
      isActive: json['isActive'] as bool? ?? true,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
    );
  }

  /// Get weekday names
  static List<String> getWeekdayNames() {
    return ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  }

  /// Get weekday name from index (1-7)
  static String getWeekdayName(int weekday) {
    return getWeekdayNames()[weekday - 1];
  }

  /// Get occasion options
  static List<String> getOccasionOptions() {
    return [
      'Office',
      'Casual',
      'Party',
      'Formal',
      'Wedding',
      'Date',
      'Gym',
      'Travel',
      'Other',
    ];
  }
}

