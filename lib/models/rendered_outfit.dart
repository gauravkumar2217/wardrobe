import 'package:cloud_firestore/cloud_firestore.dart';

/// Rendered outfit model for try-on results
class RenderedOutfit {
  final String outfitId;
  final String userId;
  final List<String> clothingItems; // Array of cloth IDs
  final String viewAngle; // 'front', 'left', 'right'
  final String renderedImageUrl; // Final rendered image URL
  final DateTime createdAt;
  final DateTime? expiresAt; // Cache expiration (24 hours)

  RenderedOutfit({
    required this.outfitId,
    required this.userId,
    required this.clothingItems,
    required this.viewAngle,
    required this.renderedImageUrl,
    required this.createdAt,
    this.expiresAt,
  });

  factory RenderedOutfit.fromJson(Map<String, dynamic> json, String outfitId) {
    return RenderedOutfit(
      outfitId: outfitId,
      userId: json['userId'] as String,
      clothingItems: List<String>.from(json['clothingItems'] as List),
      viewAngle: json['viewAngle'] as String,
      renderedImageUrl: json['renderedImageUrl'] as String,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      expiresAt: json['expiresAt'] != null
          ? (json['expiresAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'clothingItems': clothingItems,
      'viewAngle': viewAngle,
      'renderedImageUrl': renderedImageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
    };
  }

  /// Check if cached render is still valid (not expired)
  bool get isValid {
    if (expiresAt == null) return true;
    return DateTime.now().isBefore(expiresAt!);
  }

  /// Generate cache key for lookup
  static String generateCacheKey({
    required String userId,
    required List<String> clothingItems,
    required String viewAngle,
  }) {
    final sortedItems = List<String>.from(clothingItems)..sort();
    return '${userId}_${sortedItems.join('_')}_$viewAngle';
  }
}
