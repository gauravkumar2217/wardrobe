import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../utils/image_compression.dart';

/// Image processing service with iOS optimization
class ImageProcessingService {
  /// Convert HEIC to JPEG (critical for iOS ML processing)
  static Future<File?> convertHeicToJpeg(File heicFile) async {
    try {
      if (!heicFile.path.toLowerCase().endsWith('.heic')) {
        return heicFile; // Already not HEIC
      }

      // Read HEIC file
      final bytes = await heicFile.readAsBytes();
      
      // Decode image
      final image = img.decodeImage(bytes);
      if (image == null) {
        debugPrint('Failed to decode HEIC image');
        return null;
      }

      // Encode as JPEG
      final jpegBytes = img.encodeJpg(image, quality: 90);
      
      // Create new file with .jpg extension
      final jpegPath = heicFile.path.replaceAll('.heic', '.jpg').replaceAll('.HEIC', '.jpg');
      final jpegFile = File(jpegPath);
      await jpegFile.writeAsBytes(jpegBytes);

      // Delete original HEIC file
      try {
        await heicFile.delete();
      } catch (e) {
        debugPrint('Could not delete HEIC file: $e');
      }

      return jpegFile;
    } catch (e) {
      debugPrint('Error converting HEIC to JPEG: $e');
      return null;
    }
  }

  /// Resize image to maxHeight (important for iOS performance)
  static Future<File?> resizeImage(File imageFile, {int maxHeight = 512}) async {
    try {
      // Read image
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        debugPrint('Failed to decode image for resizing');
        return null;
      }

      // Calculate new dimensions maintaining aspect ratio
      if (image.height <= maxHeight) {
        return imageFile; // No resize needed
      }

      final aspectRatio = image.width / image.height;
      final newHeight = maxHeight;
      final newWidth = (newHeight * aspectRatio).round();

      // Resize image
      final resizedImage = img.copyResize(
        image,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.linear,
      );

      // Encode as JPEG
      final resizedBytes = img.encodeJpg(resizedImage, quality: 85);

      // Create new file
      final resizedPath = '${imageFile.path}_resized.jpg';
      final resizedFile = File(resizedPath);
      await resizedFile.writeAsBytes(resizedBytes);

      return resizedFile;
    } catch (e) {
      debugPrint('Error resizing image: $e');
      return null;
    }
  }

  /// Process image for body scan (iOS optimized)
  /// - Converts HEIC to JPEG
  /// - Resizes to maxWidth: 720
  /// - Compresses to <1MB
  static Future<File?> processImageForBodyScan(File imageFile) async {
    try {
      File? processedFile = imageFile;

      // Step 1: Convert HEIC to JPEG if needed
      if (imageFile.path.toLowerCase().endsWith('.heic')) {
        processedFile = await convertHeicToJpeg(imageFile);
        if (processedFile == null) {
          debugPrint('Failed to convert HEIC to JPEG');
          return null;
        }
      }

      // Step 2: Resize to maxWidth: 720 (maintain aspect ratio)
      final resizedFile = await _resizeToMaxWidth(processedFile, maxWidth: 720);
      if (resizedFile == null) {
        debugPrint('Failed to resize image');
        return null;
      }

      // Step 3: Compress to <1MB
      final compressedFile = await ImageCompression.compressImage(
        resizedFile,
        maxSizeKB: 1000,
        quality: 75,
      );

      return compressedFile;
    } catch (e) {
      debugPrint('Error processing image for body scan: $e');
      return null;
    }
  }

  /// Resize image to maxWidth maintaining aspect ratio
  static Future<File?> _resizeToMaxWidth(File imageFile, {int maxWidth = 720}) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        debugPrint('Failed to decode image');
        return null;
      }

      // Check if resize is needed
      if (image.width <= maxWidth) {
        return imageFile;
      }

      // Calculate new dimensions
      final aspectRatio = image.height / image.width;
      final newWidth = maxWidth;
      final newHeight = (newWidth * aspectRatio).round();

      // Resize
      final resizedImage = img.copyResize(
        image,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.linear,
      );

      // Encode as JPEG
      final resizedBytes = img.encodeJpg(resizedImage, quality: 85);

      // Create new file
      final resizedPath = '${imageFile.path}_maxwidth.jpg';
      final resizedFile = File(resizedPath);
      await resizedFile.writeAsBytes(resizedBytes);

      return resizedFile;
    } catch (e) {
      debugPrint('Error resizing to max width: $e');
      return null;
    }
  }

  /// Process image for ML (resize to maxHeight: 512)
  static Future<File?> processImageForML(File imageFile) async {
    return resizeImage(imageFile, maxHeight: 512);
  }
}
