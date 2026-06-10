import 'package:cloud_firestore/cloud_firestore.dart';

/// Cloth model with complete structure from app-plan.md
class Cloth {
  final String id;
  final String ownerId;
  final String wardrobeId;
  final String imageUrl;
  final String? processedImageUrl; // Clean front picture without background
  final bool hasProcessedImage; // Boolean flag
  final String season;
  final String placement;
  final PlacementDetails? placementDetails; // Details for Laundry, DryCleaning, Repairing
  final ColorTags colorTags;
  final String clothType;
  final String category;
  /// Top category: 'cloth' | 'makeup' | 'footwear' | 'accessories'
  final String itemKind;
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
    this.processedImageUrl,
    this.hasProcessedImage = false,
    required this.season,
    required this.placement,
    this.placementDetails,
    required this.colorTags,
    required this.clothType,
    required this.category,
    this.itemKind = 'cloth',
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

  /// Parse itemKind from Firestore; map legacy 'shoes' to 'footwear'.
  static String _parseItemKind(String? value) {
    if (value == null || value.isEmpty) return 'cloth';
    if (value == 'shoes') return 'footwear';
    if (value == 'cloth' || value == 'makeup' || value == 'footwear' || value == 'accessories') {
      return value;
    }
    return 'cloth';
  }

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String && value.isNotEmpty) return DateTime.parse(value);
    return DateTime.now();
  }

  static DateTime? _parseOptionalDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String && value.isNotEmpty) return DateTime.parse(value);
    return null;
  }

  factory Cloth.fromJson(Map<String, dynamic> json, String id) {
    final placementDetailsJson =
        json['placement_details'] ?? json['placementDetails'];
    final colorTagsJson = json['color_tags'] ?? json['colorTags'];
    final aiDetectedJson = json['ai_detected'] ?? json['aiDetected'];

    return Cloth(
      id: id,
      ownerId: json['owner_id'] as String? ?? json['ownerId'] as String? ?? '',
      wardrobeId:
          json['wardrobe_id'] as String? ?? json['wardrobeId'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? json['imageUrl'] as String? ?? '',
      processedImageUrl: json['processed_image_url'] as String? ??
          json['processedImageUrl'] as String?,
      hasProcessedImage: json['has_processed_image'] as bool? ??
          json['hasProcessedImage'] as bool? ??
          false,
      season: json['season'] as String? ?? 'all',
      placement: json['placement'] as String? ?? 'Wardrobe',
      placementDetails: placementDetailsJson is Map<String, dynamic>
          ? PlacementDetails.fromJson(placementDetailsJson)
          : null,
      colorTags: colorTagsJson is Map<String, dynamic>
          ? ColorTags.fromJson(colorTagsJson)
          : ColorTags(primary: json['color'] as String? ?? 'Unknown'),
      clothType: json['cloth_type'] as String? ??
          json['clothType'] as String? ??
          json['type'] as String? ??
          'Other',
      category: json['category'] as String? ?? 'Casual',
      itemKind: _parseItemKind(
        json['item_kind'] as String? ?? json['itemKind'] as String?,
      ),
      occasions: json['occasions'] != null
          ? List<String>.from(json['occasions'])
          : (json['occasion'] != null
              ? [json['occasion'] as String]
              : ['Other']),
      aiDetected: aiDetectedJson is Map<String, dynamic>
          ? AiDetected.fromJson(aiDetectedJson)
          : null,
      createdAt: _parseDate(json['created_at'] ?? json['createdAt']),
      updatedAt: _parseDate(json['updated_at'] ?? json['updatedAt']),
      wornAt: _parseOptionalDate(json['worn_at'] ?? json['wornAt']) ??
          _parseOptionalDate(json['lastWornAt']),
      visibility: json['visibility'] as String? ?? 'private',
      sharedWith: json['shared_with'] != null
          ? List<String>.from(json['shared_with'])
          : json['sharedWith'] != null
              ? List<String>.from(json['sharedWith'])
              : null,
      likesCount:
          json['likes_count'] as int? ?? json['likesCount'] as int? ?? 0,
      commentsCount: json['comments_count'] as int? ??
          json['commentsCount'] as int? ??
          0,
    );
  }

  factory Cloth.fromApiJson(Map<String, dynamic> json) {
    return Cloth.fromJson(json, json['id']?.toString() ?? '');
  }

  Map<String, dynamic> toJson() {
    return {
      'ownerId': ownerId,
      'wardrobeId': wardrobeId,
      'imageUrl': imageUrl,
      if (processedImageUrl != null) 'processedImageUrl': processedImageUrl,
      'hasProcessedImage': hasProcessedImage,
      'season': season,
      'placement': placement,
      if (placementDetails != null) 'placementDetails': placementDetails!.toJson(),
      'colorTags': colorTags.toJson(),
      'clothType': clothType,
      'category': category,
      'itemKind': itemKind,
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
    String? processedImageUrl,
    bool? hasProcessedImage,
    String? season,
    String? placement,
    PlacementDetails? placementDetails,
    ColorTags? colorTags,
    String? clothType,
    String? category,
    String? itemKind,
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
      processedImageUrl: processedImageUrl ?? this.processedImageUrl,
      hasProcessedImage: hasProcessedImage ?? this.hasProcessedImage,
      season: season ?? this.season,
      placement: placement ?? this.placement,
      placementDetails: placementDetails ?? this.placementDetails,
      colorTags: colorTags ?? this.colorTags,
      clothType: clothType ?? this.clothType,
      category: category ?? this.category,
      itemKind: itemKind ?? this.itemKind,
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

/// Placement details for Laundry, DryCleaning, Repairing
class PlacementDetails {
  final String shopName;
  final DateTime givenDate;
  final DateTime returnDate;

  PlacementDetails({
    required this.shopName,
    required this.givenDate,
    required this.returnDate,
  });

  factory PlacementDetails.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String && value.isNotEmpty) return DateTime.parse(value);
      return DateTime.now();
    }

    return PlacementDetails(
      shopName: json['shop_name'] as String? ?? json['shopName'] as String? ?? '',
      givenDate: parseDate(json['given_date'] ?? json['givenDate']),
      returnDate: parseDate(json['return_date'] ?? json['returnDate']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shopName': shopName,
      'givenDate': Timestamp.fromDate(givenDate),
      'returnDate': Timestamp.fromDate(returnDate),
    };
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
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String && value.isNotEmpty) return DateTime.parse(value);
      return DateTime.now();
    }

    return AiDetected(
      clothType: json['cloth_type'] as String? ?? json['clothType'] as String?,
      colors: List<String>.from(json['colors'] ?? []),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      detectedAt: parseDate(json['detected_at'] ?? json['detectedAt']),
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
