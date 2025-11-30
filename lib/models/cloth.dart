import 'package:cloud_firestore/cloud_firestore.dart';

/// Cloth model with complete structure from app-plan.md
class Cloth {
  final String id;
  final String ownerId;
  final String wardrobeId;
  final String imageUrl;
  final String season;
  final String placement;
  final ColorTags colorTags;
  final String clothType;
  final String category;
  final List<String> occasions;
  final AiDetected? aiDetected;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? wornAt; // When the cloth was last worn
  final String visibility; // "private", "friends", "public"
  final List<String>? sharedWith;
  final int likesCount;
  final int commentsCount;

  Cloth({
    required this.id,
    required this.ownerId,
    required this.wardrobeId,
    required this.imageUrl,
    required this.season,
    required this.placement,
    required this.colorTags,
    required this.clothType,
    required this.category,
    required this.occasions,
    this.aiDetected,
    required this.createdAt,
    required this.updatedAt,
    this.wornAt,
    this.visibility = 'private',
    this.sharedWith,
    this.likesCount = 0,
    this.commentsCount = 0,
  });

  factory Cloth.fromJson(Map<String, dynamic> json, String id) {
    return Cloth(
      id: id,
      ownerId: json['ownerId'] as String,
      wardrobeId: json['wardrobeId'] as String,
      imageUrl: json['imageUrl'] as String,
      season: json['season'] as String,
      placement: json['placement'] as String,
      colorTags: json['colorTags'] != null
          ? ColorTags.fromJson(json['colorTags'] as Map<String, dynamic>)
          : ColorTags(primary: json['color'] as String? ?? 'Unknown'),
      clothType:
          json['clothType'] as String? ?? json['type'] as String? ?? 'Other',
      category: json['category'] as String? ?? 'Casual',
      occasions: json['occasions'] != null
          ? List<String>.from(json['occasions'])
          : (json['occasion'] != null
              ? [json['occasion'] as String]
              : ['Other']),
      aiDetected: json['aiDetected'] != null
          ? AiDetected.fromJson(json['aiDetected'] as Map<String, dynamic>)
          : null,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
      wornAt: json['wornAt'] != null
          ? (json['wornAt'] as Timestamp).toDate()
          : (json['lastWornAt'] != null
              ? (json['lastWornAt'] as Timestamp).toDate()
              : null), // Support legacy lastWornAt field
      visibility: json['visibility'] as String? ?? 'private',
      sharedWith: json['sharedWith'] != null
          ? List<String>.from(json['sharedWith'])
          : null,
      likesCount: json['likesCount'] as int? ?? 0,
      commentsCount: json['commentsCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ownerId': ownerId,
      'wardrobeId': wardrobeId,
      'imageUrl': imageUrl,
      'season': season,
      'placement': placement,
      'colorTags': colorTags.toJson(),
      'clothType': clothType,
      'category': category,
      'occasions': occasions,
      if (aiDetected != null) 'aiDetected': aiDetected!.toJson(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (wornAt != null) 'wornAt': Timestamp.fromDate(wornAt!),
      'visibility': visibility,
      if (sharedWith != null) 'sharedWith': sharedWith,
      // Note: likesCount and commentsCount are managed by Cloud Functions
    };
  }

  Cloth copyWith({
    String? id,
    String? ownerId,
    String? wardrobeId,
    String? imageUrl,
    String? season,
    String? placement,
    ColorTags? colorTags,
    String? clothType,
    String? category,
    List<String>? occasions,
    AiDetected? aiDetected,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? wornAt,
    String? visibility,
    List<String>? sharedWith,
    int? likesCount,
    int? commentsCount,
  }) {
    return Cloth(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      wardrobeId: wardrobeId ?? this.wardrobeId,
      imageUrl: imageUrl ?? this.imageUrl,
      season: season ?? this.season,
      placement: placement ?? this.placement,
      colorTags: colorTags ?? this.colorTags,
      clothType: clothType ?? this.clothType,
      category: category ?? this.category,
      occasions: occasions ?? this.occasions,
      aiDetected: aiDetected ?? this.aiDetected,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      wornAt: wornAt ?? this.wornAt,
      visibility: visibility ?? this.visibility,
      sharedWith: sharedWith ?? this.sharedWith,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
    );
  }
}

/// Color tags structure
class ColorTags {
  final String primary;
  final String? secondary;
  final List<String> colors;
  final bool isMultiColor;

  ColorTags({
    required this.primary,
    this.secondary,
    List<String>? colors,
    this.isMultiColor = false,
  }) : colors = colors ?? [primary];

  factory ColorTags.fromJson(Map<String, dynamic> json) {
    return ColorTags(
      primary: json['primary'] as String,
      secondary: json['secondary'] as String?,
      colors: json['colors'] != null ? List<String>.from(json['colors']) : null,
      isMultiColor: json['isMultiColor'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'primary': primary,
      if (secondary != null) 'secondary': secondary,
      'colors': colors,
      'isMultiColor': isMultiColor,
    };
  }
}

/// AI detection results
class AiDetected {
  final String? clothType;
  final List<String> colors;
  final double confidence;
  final DateTime detectedAt;

  AiDetected({
    this.clothType,
    required this.colors,
    required this.confidence,
    required this.detectedAt,
  });

  factory AiDetected.fromJson(Map<String, dynamic> json) {
    return AiDetected(
      clothType: json['clothType'] as String?,
      colors: List<String>.from(json['colors'] ?? []),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      detectedAt: (json['detectedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (clothType != null) 'clothType': clothType,
      'colors': colors,
      'confidence': confidence,
      'detectedAt': Timestamp.fromDate(detectedAt),
    };
  }
}

/// Wear history entry
class WearHistoryEntry {
  final String id;
  final String userId;
  final DateTime wornAt;
  final String source; // "manual", "scheduledSuggestion"

  WearHistoryEntry({
    required this.id,
    required this.userId,
    required this.wornAt,
    required this.source,
  });

  factory WearHistoryEntry.fromJson(Map<String, dynamic> json, String id) {
    return WearHistoryEntry(
      id: id,
      userId: json['userId'] as String,
      wornAt: (json['wornAt'] as Timestamp).toDate(),
      source: json['source'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'wornAt': Timestamp.fromDate(wornAt),
      'source': source,
    };
  }
}

/// Like entry
class Like {
  final String id; // userId
  final String userId;
  final DateTime createdAt;

  Like({
    required this.id,
    required this.userId,
    required this.createdAt,
  });

  factory Like.fromJson(Map<String, dynamic> json, String id) {
    return Like(
      id: id,
      userId: json['userId'] as String,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

/// Comment entry
class Comment {
  final String id;
  final String userId;
  final String text;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Comment({
    required this.id,
    required this.userId,
    required this.text,
    required this.createdAt,
    this.updatedAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json, String id) {
    return Comment(
      id: id,
      userId: json['userId'] as String,
      text: json['text'] as String,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }
}
