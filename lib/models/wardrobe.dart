import 'package:cloud_firestore/cloud_firestore.dart';

class Wardrobe {
  final String id;
  final String title;
  final String location;
  final String season;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int clothCount; // Denormalized count for quick access

  Wardrobe({
    required this.id,
    required this.title,
    required this.location,
    required this.season,
    required this.createdAt,
    required this.updatedAt,
    this.clothCount = 0,
  });

  // Convert to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'location': location,
      'season': season,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'clothCount': clothCount,
    };
  }

  // Create from Firestore document
  factory Wardrobe.fromJson(Map<String, dynamic> json, String id) {
    return Wardrobe(
      id: id,
      title: json['title'] as String,
      location: json['location'] as String,
      season: json['season'] as String,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
      clothCount: json['clothCount'] as int? ?? 0,
    );
  }

  // Create a copy with updated fields
  Wardrobe copyWith({
    String? id,
    String? title,
    String? location,
    String? season,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? clothCount,
  }) {
    return Wardrobe(
      id: id ?? this.id,
      title: title ?? this.title,
      location: location ?? this.location,
      season: season ?? this.season,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      clothCount: clothCount ?? this.clothCount,
    );
  }

  // Season options enum
  static const List<String> seasons = [
    'Summer',
    'Winter',
    'Spring',
    'Fall',
    'All-season',
    'Custom',
  ];
}

