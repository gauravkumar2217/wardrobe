import 'package:cloud_firestore/cloud_firestore.dart';

/// Wardrobe model with complete structure from app-plan.md
class Wardrobe {
  final String id;
  final String ownerId;
  final String name;
  final String location;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int totalItems; // Maintained by Cloud Function

  Wardrobe({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.location,
    required this.createdAt,
    required this.updatedAt,
    this.totalItems = 0,
  });

  factory Wardrobe.fromJson(Map<String, dynamic> json, String id) {
    return Wardrobe(
      id: id,
      ownerId: json['ownerId'] as String,
      name: json['name'] as String,
      location: json['location'] as String,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
      totalItems: json['totalItems'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ownerId': ownerId,
      'name': name,
      'location': location,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      // Note: totalItems is managed by Cloud Functions
    };
  }

  Wardrobe copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? location,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? totalItems,
  }) {
    return Wardrobe(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      totalItems: totalItems ?? this.totalItems,
    );
  }
}
