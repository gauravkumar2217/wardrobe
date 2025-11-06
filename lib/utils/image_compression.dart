import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Image compression utility
class ImageCompression {
  /// Compress image to max 5MB
  static Future<File> compressImage(
    File imageFile, {
    int maxSizeKB = 5000, // 5MB
    int quality = 85,
  }) async {
    try {
      // Get file size
      final fileSize = await imageFile.length();
      final fileSizeKB = fileSize ~/ 1024;

      // If already under limit, return original
      if (fileSizeKB <= maxSizeKB) {
        return imageFile;
      }

      // Compress image
      final targetPath = '${imageFile.path}_compressed.jpg';
      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        imageFile.absolute.path,
        targetPath,
        quality: quality,
        minWidth: 1920,
        minHeight: 1920,
      );

      if (compressedFile == null) {
        throw Exception('Failed to compress image');
      }

      // Check if compressed size is acceptable
      final compressedSize = await compressedFile.length();
      final compressedSizeKB = compressedSize ~/ 1024;

      if (compressedSizeKB > maxSizeKB) {
        // Try more aggressive compression
        final moreCompressed = await FlutterImageCompress.compressAndGetFile(
          imageFile.absolute.path,
          '${imageFile.path}_compressed2.jpg',
          quality: quality ~/ 2,
          minWidth: 1280,
          minHeight: 1280,
        );

        if (moreCompressed != null) {
          return File(moreCompressed.path);
        }
      }

      return File(compressedFile.path);
    } catch (e) {
      // Return original file if compression fails
      return imageFile;
    }
  }
}

