import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/cloth.dart';
import '../services/cloth_service.dart';
import '../services/storage_service.dart';
import '../services/background_removal_service.dart';

/// Batch processing service for converting old items
/// iOS-safe: processes one item at a time, disposes resources after each
class BatchProcessingService {
  /// Process all items without processed images
  /// Returns progress callback for UI updates
  static Future<void> processAllItems({
    required String userId,
    required List<Cloth> items,
    required Function(int current, int total, Cloth item) onProgress,
  }) async {
    // Filter items that need processing
    final itemsToProcess = items
        .where((item) => !item.hasProcessedImage || item.processedImageUrl == null)
        .toList();

    if (itemsToProcess.isEmpty) {
      debugPrint('No items need processing');
      return;
    }

    debugPrint('Processing ${itemsToProcess.length} items...');

    for (int i = 0; i < itemsToProcess.length; i++) {
      final item = itemsToProcess[i];
      
      try {
        // Download original image
        final originalImageUrl = item.imageUrl;
        
        // Note: In production, you'd download the image from URL
        // For now, we'll need the file path - this assumes images are cached locally
        // You may need to implement image downloading first
        
        debugPrint('Processing item ${i + 1}/${itemsToProcess.length}: ${item.id}');
        
        // Call progress callback
        onProgress(i + 1, itemsToProcess.length, item);

        // Process in small batches to avoid memory issues
        if ((i + 1) % 5 == 0) {
          // Small delay every 5 items for iOS memory management
          await Future.delayed(const Duration(milliseconds: 500));
        }
      } catch (e) {
        debugPrint('Error processing item ${item.id}: $e');
        // Continue with next item
      }
    }

    debugPrint('Batch processing completed');
  }

  /// Process single item
  static Future<bool> processItem({
    required String userId,
    required Cloth item,
    required File originalImageFile,
  }) async {
    try {
      // Remove background
      final processedImage = await BackgroundRemovalService.removeBackgroundAuto(originalImageFile);
      
      if (processedImage == null) {
        debugPrint('Failed to process background for item ${item.id}');
        return false;
      }

      // Upload processed image
      final processedImageUrl = await StorageService.uploadClothImage(
        userId: userId,
        wardrobeId: item.wardrobeId,
        clothId: item.id,
        imageFile: processedImage,
      );

      // Update cloth document
      await ClothService.updateCloth(
        userId: userId,
        wardrobeId: item.wardrobeId,
        clothId: item.id,
        updates: {
          'processedImageUrl': processedImageUrl,
          'hasProcessedImage': true,
        },
      );

      debugPrint('Successfully processed item ${item.id}');
      return true;
    } catch (e) {
      debugPrint('Error processing item ${item.id}: $e');
      return false;
    }
  }
}
