import 'package:cloud_firestore/cloud_firestore.dart';

class Cloth {
  final String id;
  final String imageUrl;
  final String type;
  final String color;
  final String occasion;
  final String season;
  final DateTime createdAt;
  final DateTime? lastWorn;

  Cloth({
    required this.id,
    required this.imageUrl,
    required this.type,
    required this.color,
    required this.occasion,
    required this.season,
    required this.createdAt,
    this.lastWorn,
  });

  // Convert to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'imageUrl': imageUrl,
      'type': type,
      'color': color,
      'occasion': occasion,
      'season': season,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastWorn': lastWorn != null ? Timestamp.fromDate(lastWorn!) : null,
    };
  }

  // Create from Firestore document
  factory Cloth.fromJson(Map<String, dynamic> json, String id) {
    return Cloth(
      id: id,
      imageUrl: json['imageUrl'] as String,
      type: json['type'] as String,
      color: json['color'] as String,
      occasion: json['occasion'] as String,
      season: json['season'] as String,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      lastWorn: json['lastWorn'] != null
          ? (json['lastWorn'] as Timestamp).toDate()
          : null,
    );
  }

  // Type options
  static const List<String> types = [
    'Shirt',
    'Pants',
    'Dress',
    'Jacket',
    'Skirt',
    'Shorts',
    'Sweater',
    'T-Shirt',
    'Jeans',
    'Blouse',
    'Other',
  ];

  // Occasion options
  static const List<String> occasions = [
    'Casual',
    'Formal',
    'Party',
    'Work',
    'Sports',
    'Evening',
    'Other',
  ];
}

