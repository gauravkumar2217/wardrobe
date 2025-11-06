import 'package:cloud_firestore/cloud_firestore.dart';

class Outfit {
  final String id;
  final String wardrobeId;
  final List<String> clothIds; // top, bottom, accessory, etc.
  final String? occasion;
  final String? weather;
  final double confidence;
  final DateTime createdAt;
  final int? userRating; // 1-5 stars

  Outfit({
    required this.id,
    required this.wardrobeId,
    required this.clothIds,
    this.occasion,
    this.weather,
    this.confidence = 0.0,
    required this.createdAt,
    this.userRating,
  });

  Map<String, dynamic> toJson() {
    return {
      'wardrobeId': wardrobeId,
      'clothIds': clothIds,
      'occasion': occasion,
      'weather': weather,
      'confidence': confidence,
      'createdAt': Timestamp.fromDate(createdAt),
      'userRating': userRating,
    };
  }

  factory Outfit.fromJson(Map<String, dynamic> json, String id) {
    return Outfit(
      id: id,
      wardrobeId: json['wardrobeId'] as String,
      clothIds: List<String>.from(json['clothIds'] as List),
      occasion: json['occasion'] as String?,
      weather: json['weather'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      userRating: json['userRating'] as int?,
    );
  }
}

