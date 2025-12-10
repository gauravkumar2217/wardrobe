/// Schedule model for notification scheduling
class Schedule {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final int hour; // 0-23
  final int minute; // 0-59
  final List<int> daysOfWeek; // 0-6 (Sunday = 0, Monday = 1, etc.)
  final bool isEnabled;
  final Map<String, dynamic> filterSettings; // Filter criteria (types, occasions, seasons, colors, wardrobeId)
  final DateTime createdAt;
  final DateTime updatedAt;

  Schedule({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.hour,
    required this.minute,
    required this.daysOfWeek,
    this.isEnabled = true,
    required this.filterSettings,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
      id: json['id'] as String,
      userId: json['userId'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      hour: json['hour'] as int,
      minute: json['minute'] as int,
      daysOfWeek: List<int>.from(json['daysOfWeek'] as List),
      isEnabled: json['isEnabled'] as bool? ?? true,
      filterSettings: Map<String, dynamic>.from(json['filterSettings'] as Map? ?? {}),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'description': description,
      'hour': hour,
      'minute': minute,
      'daysOfWeek': daysOfWeek,
      'isEnabled': isEnabled,
      'filterSettings': filterSettings,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Schedule copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    int? hour,
    int? minute,
    List<int>? daysOfWeek,
    bool? isEnabled,
    Map<String, dynamic>? filterSettings,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Schedule(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      isEnabled: isEnabled ?? this.isEnabled,
      filterSettings: filterSettings ?? this.filterSettings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get a human-readable description of the schedule
  String get scheduleDescription {
    final timeStr = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    final daysSet = daysOfWeek.toSet();
    if (daysOfWeek.length == 7) {
      return 'Daily at $timeStr';
    } else if (daysOfWeek.length == 5 && 
               daysSet.containsAll([1, 2, 3, 4, 5])) {
      return 'Weekdays at $timeStr';
    } else if (daysOfWeek.length == 2 && 
               daysSet.containsAll([0, 6])) {
      return 'Weekends at $timeStr';
    } else {
      final dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      final selectedDays = daysOfWeek.map((d) => dayNames[d]).join(', ');
      return '$selectedDays at $timeStr';
    }
  }
}

