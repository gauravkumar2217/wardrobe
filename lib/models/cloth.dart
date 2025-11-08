import 'package:cloud_firestore/cloud_firestore.dart';

class Cloth {
  final String id;
  final String imageUrl;
  final String type;
  final String color;
  final List<String> occasions; // Changed to support multiple occasions
  final String season;
  final DateTime createdAt;
  final DateTime? lastWorn;

  Cloth({
    required this.id,
    required this.imageUrl,
    required this.type,
    required this.color,
    required this.occasions,
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
      'occasions': occasions, // Store as array
      'occasion': occasions.isNotEmpty ? occasions.first : 'Other', // Keep for backward compatibility
      'season': season,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastWorn': lastWorn != null ? Timestamp.fromDate(lastWorn!) : null,
    };
  }

  // Create from Firestore document
  // Handles both old format (single occasion string) and new format (occasions array)
  factory Cloth.fromJson(Map<String, dynamic> json, String id) {
    List<String> occasionsList;
    
    // Check if 'occasions' array exists (new format)
    if (json['occasions'] != null && json['occasions'] is List) {
      occasionsList = List<String>.from(json['occasions']);
    } 
    // Fallback to single 'occasion' string (old format) for backward compatibility
    else if (json['occasion'] != null) {
      occasionsList = [json['occasion'] as String];
    } 
    // Default if neither exists
    else {
      occasionsList = ['Other'];
    }
    
    return Cloth(
      id: id,
      imageUrl: json['imageUrl'] as String,
      type: json['type'] as String,
      color: json['color'] as String,
      occasions: occasionsList,
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
  static const List<String> occasionOptions = [
    'Casual',
    'Formal',
    'Party',
    'Work',
    'Sports',
    'Evening',
    'Other',
  ];
}

