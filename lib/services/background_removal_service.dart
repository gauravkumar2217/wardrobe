import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'image_processing_service.dart';

/// Background removal service
/// Option A: Uses remove.bg API (recommended for iOS stability)
/// Option B: Can be extended to use lightweight TFLite model (<5MB) for offline mode
class BackgroundRemovalService {
  static const String _removeBgApiUrl = 'https://api.remove.bg/v1.0/removebg';

  /// Get remove.bg API key from environment variables
  static String? get _removeBgApiKey {
    try {
      if (!dotenv.isInitialized) return null;
      return dotenv.env['REMOVE_BG_API_KEY'];
    } catch (_) {
      return null;
    }
  }

  /// Remove background from image using remove.bg API
  /// Returns processed image file without background
  static Future<File?> removeBackground(File imageFile) async {
    try {
      // Resize image before processing (maxHeight: 512 for performance)
      final resizedImage = await ImageProcessingService.processImageForML(imageFile);
      if (resizedImage == null) {
        debugPrint('Failed to resize image for background removal');
        return null;
      }

      // Check if API key is set
      final apiKey = _removeBgApiKey;
      if (apiKey == null || apiKey.isEmpty) {
        debugPrint('⚠️ Remove.bg API key not set. Please configure REMOVE_BG_API_KEY in .env file');
        // Fallback: return original image
        return imageFile;
      }

      // Read image bytes
      final imageBytes = await resizedImage.readAsBytes();

      // Create multipart request
      final request = http.MultipartRequest('POST', Uri.parse(_removeBgApiUrl));
      request.headers['X-Api-Key'] = apiKey;
      request.files.add(
        http.MultipartFile.fromBytes(
          'image_file',
          imageBytes,
          filename: 'image.jpg',
        ),
      );

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        debugPrint('Remove.bg API error: ${response.statusCode} - ${response.body}');
        return null;
      }

      // Save processed image
      final processedPath = '${imageFile.path}_processed.png';
      final processedFile = File(processedPath);
      await processedFile.writeAsBytes(response.bodyBytes);

      debugPrint('Background removed successfully');
      return processedFile;
    } catch (e) {
      debugPrint('Error removing background: $e');
      return null;
    }
  }

  /// Remove background using offline TFLite model (if implemented)
  /// This would use a lightweight model (<5MB) for fully offline processing
  static Future<File?> removeBackgroundOffline(File imageFile) async {
    // TODO: Implement offline background removal using TFLite
    // For now, return null to indicate offline mode not available
    debugPrint('Offline background removal not yet implemented');
    return null;
  }

  /// Remove background (tries API first, falls back to offline if available)
  static Future<File?> removeBackgroundAuto(File imageFile) async {
    // Try API first
    final apiResult = await removeBackground(imageFile);
    if (apiResult != null) {
      return apiResult;
    }

    // Fallback to offline if available
    return await removeBackgroundOffline(imageFile);
  }
}
