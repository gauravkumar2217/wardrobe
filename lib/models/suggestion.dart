import 'package:cloud_firestore/cloud_firestore.dart';

class Suggestion {
  final String id; // Format: YYYY-MM-DD
  final String wardrobeId;
  final List<String> clothIds;
  final String? reason;
  final DateTime createdAt;
  final bool viewed;

  Suggestion({
    required this.id,
    required this.wardrobeId,
    required this.clothIds,
    this.reason,
    required this.createdAt,
    this.viewed = false,
  });

  // Convert to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'wardrobeId': wardrobeId,
      'clothIds': clothIds,
      'reason': reason,
      'createdAt': Timestamp.fromDate(createdAt),
      'viewed': viewed,
    };
  }

  // Create from Firestore document
  factory Suggestion.fromJson(Map<String, dynamic> json, String id) {
    return Suggestion(
      id: id,
      wardrobeId: json['wardrobeId'] as String,
      clothIds: List<String>.from(json['clothIds'] as List),
      reason: json['reason'] as String?,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      viewed: json['viewed'] as bool? ?? false,
    );
  }

  // Create a copy with updated fields
  Suggestion copyWith({
    String? id,
    String? wardrobeId,
    List<String>? clothIds,
    String? reason,
    DateTime? createdAt,
    bool? viewed,
  }) {
    return Suggestion(
      id: id ?? this.id,
      wardrobeId: wardrobeId ?? this.wardrobeId,
      clothIds: clothIds ?? this.clothIds,
      reason: reason ?? this.reason,
      createdAt: createdAt ?? this.createdAt,
      viewed: viewed ?? this.viewed,
    );
  }

  // Generate date string in YYYY-MM-DD format
  static String getTodayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

