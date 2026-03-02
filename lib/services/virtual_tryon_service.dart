import 'package:flutter/foundation.dart';
import '../models/cloth.dart';
import '../models/body_profile.dart';

/// Virtual try-on service for segmented overlay
/// Uses Flutter GPU acceleration (Stack, Positioned, Transform)
/// iOS: Uses Metal backend automatically
class VirtualTryOnService {
  /// Calculate position and scale for clothing item on body
  /// Returns positioning data for overlay
  static Map<String, double> calculateItemPosition({
    required Cloth cloth,
    required BodyProfile bodyProfile,
    required String itemType, // 'shirt', 'pants', 'shoes', 'accessory'
  }) {
    // Get body measurements
    final measurements = bodyProfile.measurements;
    if (measurements == null) {
      return {'x': 0, 'y': 0, 'scale': 1.0, 'rotation': 0};
    }

    // Calculate position based on item type and body measurements
    double x = 0;
    double y = 0;
    double scale = 1.0;
    double rotation = 0;

    switch (itemType.toLowerCase()) {
      case 'shirt':
      case 'top':
      case 't-shirt':
      case 'blouse':
        // Position at shoulder level
        y = 0.15; // 15% from top
        scale = (measurements.shoulderWidthCm ?? 40) / 40; // Scale based on shoulder width
        break;

      case 'pants':
      case 'trousers':
      case 'jeans':
        // Position at hip level
        y = 0.45; // 45% from top
        scale = (measurements.hipWidthCm ?? 40) / 40; // Scale based on hip width
        break;

      case 'shoes':
      case 'footwear':
        // Position at bottom
        y = 0.90; // 90% from top
        scale = 0.8; // Smaller scale for shoes
        break;

      case 'accessory':
      case 'accessories':
        // Position varies by accessory type
        y = 0.20; // 20% from top (neck area)
        scale = 0.6; // Smaller scale for accessories
        break;

      default:
        // Default positioning
        y = 0.30;
        scale = 1.0;
    }

    return {
      'x': x,
      'y': y,
      'scale': scale.clamp(0.5, 2.0), // Clamp scale between 0.5 and 2.0
      'rotation': rotation,
    };
  }

  /// Get similar items for suggestion
  static List<Cloth> getSimilarItems({
    required Cloth currentItem,
    required List<Cloth> allItems,
    int limit = 5,
  }) {
    final similarItems = <Cloth>[];

    // Filter by same category and type
    for (var item in allItems) {
      if (item.id == currentItem.id) continue; // Skip current item

      // Check if same category and type
      if (item.category == currentItem.category &&
          item.clothType == currentItem.clothType) {
        similarItems.add(item);
        if (similarItems.length >= limit) break;
      }
    }

    // If not enough, add items with same category
    if (similarItems.length < limit) {
      for (var item in allItems) {
        if (item.id == currentItem.id) continue;
        if (similarItems.any((i) => i.id == item.id)) continue;

        if (item.category == currentItem.category) {
          similarItems.add(item);
          if (similarItems.length >= limit) break;
        }
      }
    }

    return similarItems;
  }
}
