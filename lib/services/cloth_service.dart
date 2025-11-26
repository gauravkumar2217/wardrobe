import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/cloth.dart';
import 'storage_service.dart';

/// Cloth service for managing clothes
class ClothService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get Firestore path for clothes
  static String _clothesPath(String userId, String wardrobeId) {
    return 'users/$userId/wardrobes/$wardrobeId/clothes';
  }

  /// Add cloth to wardrobe
  static Future<String> addCloth({
    required String userId,
    required String wardrobeId,
    required File imageFile,
    required String season,
    required String placement,
    required ColorTags colorTags,
    required String clothType,
    required String category,
    required List<String> occasions,
    String visibility = 'private',
    AiDetected? aiDetected,
  }) async {
    try {
      // Validate occasions
      if (occasions.isEmpty) {
        throw Exception('At least one occasion must be selected');
      }

      final clothId = _firestore.collection('clothes').doc().id;
      final now = DateTime.now();

      // Upload image
      final imageUrl = await StorageService.uploadClothImage(
        userId: userId,
        wardrobeId: wardrobeId,
        clothId: clothId,
        imageFile: imageFile,
      );

      // Create cloth document
      final clothData = {
        'ownerId': userId,
        'wardrobeId': wardrobeId,
        'imageUrl': imageUrl,
        'season': season,
        'placement': placement,
        'colorTags': colorTags.toJson(),
        'clothType': clothType,
        'category': category,
        'occasions': occasions,
        'visibility': visibility,
        'likesCount': 0,
        'commentsCount': 0,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        if (aiDetected != null) 'aiDetected': aiDetected.toJson(),
      };

      // Save to subcollection path
      await _firestore
          .collection(_clothesPath(userId, wardrobeId))
          .doc(clothId)
          .set(clothData);

      // Also save to top-level collection for queries
      await _firestore.collection('clothes').doc(clothId).set(clothData);

      if (kDebugMode) {
        debugPrint('Cloth added successfully: $clothId');
      }

      return clothId;
    } catch (e) {
      debugPrint('Failed to add cloth: $e');
      rethrow;
    }
  }

  /// Get cloth by ID
  static Future<Cloth?> getCloth({
    required String userId,
    required String wardrobeId,
    required String clothId,
  }) async {
    try {
      final doc = await _firestore
          .collection(_clothesPath(userId, wardrobeId))
          .doc(clothId)
          .get();

      if (!doc.exists) return null;

      return Cloth.fromJson(doc.data()!, clothId);
    } catch (e) {
      debugPrint('Failed to get cloth: $e');
      return null;
    }
  }

  /// Get all clothes for a wardrobe
  static Future<List<Cloth>> getClothes({
    required String userId,
    required String wardrobeId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_clothesPath(userId, wardrobeId))
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Cloth.fromJson(doc.data()!, doc.id))
          .toList();
    } catch (e) {
      debugPrint('Failed to get clothes: $e');
      return [];
    }
  }

  /// Get all clothes for a user (across all wardrobes)
  static Future<List<Cloth>> getAllUserClothes(String userId) async {
    try {
      // Query top-level clothes collection filtered by ownerId
      final snapshot = await _firestore
          .collection('clothes')
          .where('ownerId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Cloth.fromJson(doc.data()!, doc.id))
          .toList();
    } catch (e) {
      debugPrint('Failed to get all user clothes: $e');
      return [];
    }
  }

  /// Update cloth
  static Future<void> updateCloth({
    required String userId,
    required String wardrobeId,
    required String clothId,
    Map<String, dynamic>? updates,
    Cloth? cloth,
    File? newImageFile,
  }) async {
    try {
      if (newImageFile != null) {
        // Upload new image
        final imageUrl = await StorageService.uploadClothImage(
          userId: userId,
          wardrobeId: wardrobeId,
          clothId: clothId,
          imageFile: newImageFile,
        );
        updates ??= {};
        updates['imageUrl'] = imageUrl;
      }

      if (cloth != null) {
        final clothData = cloth.toJson();
        clothData['updatedAt'] = FieldValue.serverTimestamp();
        // Don't update likesCount and commentsCount (managed by Cloud Functions)
        clothData.remove('likesCount');
        clothData.remove('commentsCount');

        await _firestore
            .collection(_clothesPath(userId, wardrobeId))
            .doc(clothId)
            .update(clothData);

        // Also update top-level collection
        await _firestore.collection('clothes').doc(clothId).update(clothData);
      } else if (updates != null) {
        updates['updatedAt'] = FieldValue.serverTimestamp();
        // Don't allow updating likesCount and commentsCount
        updates.remove('likesCount');
        updates.remove('commentsCount');

        await _firestore
            .collection(_clothesPath(userId, wardrobeId))
            .doc(clothId)
            .update(updates);

        // Also update top-level collection
        await _firestore.collection('clothes').doc(clothId).update(updates);
      }
    } catch (e) {
      debugPrint('Failed to update cloth: $e');
      rethrow;
    }
  }

  /// Delete cloth
  static Future<void> deleteCloth({
    required String userId,
    required String wardrobeId,
    required String clothId,
  }) async {
    try {
      // Get cloth to delete image
      final cloth = await getCloth(
        userId: userId,
        wardrobeId: wardrobeId,
        clothId: clothId,
      );

      if (cloth != null) {
        // Delete image from Storage
        if (cloth.imageUrl.isNotEmpty) {
          try {
            await StorageService.deleteClothImage(
              userId: userId,
              wardrobeId: wardrobeId,
              clothId: clothId,
              imageUrl: cloth.imageUrl,
            );
          } catch (e) {
            debugPrint('Failed to delete cloth image: $e');
          }
        }

        // Delete from subcollection
        await _firestore
            .collection(_clothesPath(userId, wardrobeId))
            .doc(clothId)
            .delete();

        // Delete from top-level collection
        await _firestore.collection('clothes').doc(clothId).delete();
      }
    } catch (e) {
      debugPrint('Failed to delete cloth: $e');
      rethrow;
    }
  }

  /// Mark cloth as worn today
  static Future<void> markAsWornToday({
    required String userId,
    required String wardrobeId,
    required String clothId,
  }) async {
    try {
      final now = DateTime.now();

      // Create wear history entry
      await _firestore
          .collection(_clothesPath(userId, wardrobeId))
          .doc(clothId)
          .collection('wearHistory')
          .add({
        'userId': userId,
        'wornAt': Timestamp.fromDate(now),
        'source': 'manual',
      });

      // Update cloth's lastWornAt
      await _firestore
          .collection(_clothesPath(userId, wardrobeId))
          .doc(clothId)
          .update({
        'lastWornAt': Timestamp.fromDate(now),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Also update top-level collection
      await _firestore.collection('clothes').doc(clothId).update({
        'lastWornAt': Timestamp.fromDate(now),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Failed to mark as worn: $e');
      rethrow;
    }
  }

  /// Like cloth
  static Future<void> likeCloth({
    required String userId,
    required String ownerId,
    required String wardrobeId,
    required String clothId,
  }) async {
    try {
      final now = DateTime.now();

      await _firestore
          .collection(_clothesPath(ownerId, wardrobeId))
          .doc(clothId)
          .collection('likes')
          .doc(userId)
          .set({
        'userId': userId,
        'createdAt': Timestamp.fromDate(now),
      });
    } catch (e) {
      debugPrint('Failed to like cloth: $e');
      rethrow;
    }
  }

  /// Unlike cloth
  static Future<void> unlikeCloth({
    required String userId,
    required String ownerId,
    required String wardrobeId,
    required String clothId,
  }) async {
    try {
      await _firestore
          .collection(_clothesPath(ownerId, wardrobeId))
          .doc(clothId)
          .collection('likes')
          .doc(userId)
          .delete();
    } catch (e) {
      debugPrint('Failed to unlike cloth: $e');
      rethrow;
    }
  }

  /// Check if user has liked cloth
  static Future<bool> hasLiked({
    required String userId,
    required String ownerId,
    required String wardrobeId,
    required String clothId,
  }) async {
    try {
      final doc = await _firestore
          .collection(_clothesPath(ownerId, wardrobeId))
          .doc(clothId)
          .collection('likes')
          .doc(userId)
          .get();

      return doc.exists;
    } catch (e) {
      debugPrint('Failed to check like status: $e');
      return false;
    }
  }

  /// Add comment to cloth
  static Future<String> addComment({
    required String userId,
    required String ownerId,
    required String wardrobeId,
    required String clothId,
    required String text,
  }) async {
    try {
      final commentId = _firestore.collection('comments').doc().id;
      final now = DateTime.now();

      await _firestore
          .collection(_clothesPath(ownerId, wardrobeId))
          .doc(clothId)
          .collection('comments')
          .doc(commentId)
          .set({
        'userId': userId,
        'text': text,
        'createdAt': Timestamp.fromDate(now),
      });

      return commentId;
    } catch (e) {
      debugPrint('Failed to add comment: $e');
      rethrow;
    }
  }

  /// Get comments for cloth
  static Future<List<Comment>> getComments({
    required String ownerId,
    required String wardrobeId,
    required String clothId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_clothesPath(ownerId, wardrobeId))
          .doc(clothId)
          .collection('comments')
          .orderBy('createdAt', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => Comment.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Failed to get comments: $e');
      return [];
    }
  }

  /// Delete comment
  static Future<void> deleteComment({
    required String userId,
    required String ownerId,
    required String wardrobeId,
    required String clothId,
    required String commentId,
  }) async {
    try {
      final commentDoc = await _firestore
          .collection(_clothesPath(ownerId, wardrobeId))
          .doc(clothId)
          .collection('comments')
          .doc(commentId)
          .get();

      if (!commentDoc.exists) return;

      final comment = Comment.fromJson(commentDoc.data()!, commentId);

      // Only comment author can delete
      if (comment.userId != userId) {
        throw Exception('Only comment author can delete');
      }

      await _firestore
          .collection(_clothesPath(ownerId, wardrobeId))
          .doc(clothId)
          .collection('comments')
          .doc(commentId)
          .delete();
    } catch (e) {
      debugPrint('Failed to delete comment: $e');
      rethrow;
    }
  }

  /// Stream clothes for real-time updates
  static Stream<List<Cloth>> watchClothes({
    required String userId,
    required String wardrobeId,
  }) {
    return _firestore
        .collection(_clothesPath(userId, wardrobeId))
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Cloth.fromJson(doc.data()!, doc.id))
            .toList());
  }

  /// Stream all user clothes for real-time updates
  static Stream<List<Cloth>> watchAllUserClothes(String userId) {
    return _firestore
        .collection('clothes')
        .where('ownerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Cloth.fromJson(doc.data()!, doc.id))
            .toList());
  }
}
