import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../utils/image_compression.dart';

/// Storage service for Firebase Storage operations
class StorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload profile photo
  /// Path: users/{userId}/profile/{imageName}
  static Future<String> uploadProfilePhoto({
    required String userId,
    required File imageFile,
  }) async {
    try {
      // Compress image
      final compressedFile = await ImageCompression.compressImage(imageFile);

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'profile_$timestamp.jpg';

      // Upload to Storage
      final ref = _storage.ref().child('users/$userId/profile/$fileName');
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'max-age=31536000',
      );

      await ref.putFile(compressedFile, metadata);
      final downloadURL = await ref.getDownloadURL();

      if (kDebugMode) {
        debugPrint('Profile photo uploaded: $downloadURL');
      }

      return downloadURL;
    } catch (e) {
      debugPrint('Error uploading profile photo: $e');
      rethrow;
    }
  }

  /// Upload cloth image
  /// Path: users/{userId}/wardrobes/{wardrobeId}/clothes/{clothId}/{imageName}
  static Future<String> uploadClothImage({
    required String userId,
    required String wardrobeId,
    required String clothId,
    required File imageFile,
  }) async {
    try {
      // Compress image
      final compressedFile = await ImageCompression.compressImage(imageFile);

      // Generate filename
      final fileName = 'cloth_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Upload to Storage
      final ref = _storage
          .ref()
          .child('users/$userId/wardrobes/$wardrobeId/clothes/$clothId/$fileName');
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'max-age=31536000',
      );

      await ref.putFile(compressedFile, metadata);
      final downloadURL = await ref.getDownloadURL();

      if (kDebugMode) {
        debugPrint('Cloth image uploaded: $downloadURL');
      }

      return downloadURL;
    } catch (e) {
      debugPrint('Error uploading cloth image: $e');
      rethrow;
    }
  }

  /// Upload chat image
  /// Path: users/{userId}/chats/{chatId}/messages/{messageId}/images/{imageName}
  static Future<String> uploadChatImage({
    required String userId,
    required String chatId,
    required String messageId,
    required File imageFile,
  }) async {
    try {
      // Compress image
      final compressedFile = await ImageCompression.compressImage(imageFile);

      // Generate filename
      final fileName = 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Upload to Storage
      final ref = _storage.ref().child(
          'users/$userId/chats/$chatId/messages/$messageId/images/$fileName');
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'max-age=31536000',
      );

      await ref.putFile(compressedFile, metadata);
      final downloadURL = await ref.getDownloadURL();

      if (kDebugMode) {
        debugPrint('Chat image uploaded: $downloadURL');
      }

      return downloadURL;
    } catch (e) {
      debugPrint('Error uploading chat image: $e');
      rethrow;
    }
  }

  /// Delete profile photo
  static Future<void> deleteProfilePhoto({
    required String userId,
    required String imageUrl,
  }) async {
    try {
      // Extract path from URL
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();

      if (kDebugMode) {
        debugPrint('Profile photo deleted');
      }
    } catch (e) {
      debugPrint('Error deleting profile photo: $e');
      rethrow;
    }
  }

  /// Delete cloth image
  static Future<void> deleteClothImage({
    required String userId,
    required String wardrobeId,
    required String clothId,
    required String imageUrl,
  }) async {
    try {
      // Extract path from URL
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();

      if (kDebugMode) {
        debugPrint('Cloth image deleted');
      }
    } catch (e) {
      debugPrint('Error deleting cloth image: $e');
      rethrow;
    }
  }

  /// Delete chat image
  static Future<void> deleteChatImage(String imageUrl) async {
    try {
      // Extract path from URL
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();

      if (kDebugMode) {
        debugPrint('Chat image deleted');
      }
    } catch (e) {
      debugPrint('Error deleting chat image: $e');
      rethrow;
    }
  }

  /// Get download URL from Storage path
  static Future<String> getDownloadURL(String path) async {
    try {
      final ref = _storage.ref().child(path);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error getting download URL: $e');
      rethrow;
    }
  }
}

