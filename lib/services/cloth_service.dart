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

      final data = doc.data();
      if (data == null) return null;

      return Cloth.fromJson(data, clothId);
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
          .map((doc) => Cloth.fromJson(doc.data(), doc.id))
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
          .map((doc) => Cloth.fromJson(doc.data(), doc.id))
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

      // Update cloth's wornAt (when worn) and updatedAt (last update time)
      await _firestore
          .collection(_clothesPath(userId, wardrobeId))
          .doc(clothId)
          .update({
        'wornAt': Timestamp.fromDate(now),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Also update top-level collection
      await _firestore.collection('clothes').doc(clothId).update({
        'wornAt': Timestamp.fromDate(now),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Failed to mark as worn: $e');
      rethrow;
    }
  }

  /// Remove today's worn entry (undo mark as worn)
  static Future<DateTime?> unmarkWornToday({
    required String userId,
    required String wardrobeId,
    required String clothId,
  }) async {
    try {
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      final historyRef = _firestore
          .collection(_clothesPath(userId, wardrobeId))
          .doc(clothId)
          .collection('wearHistory');

      // Find today's wear entry
      final todayEntry = await historyRef
          .where('wornAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday))
          .orderBy('wornAt', descending: true)
          .limit(1)
          .get();

      if (todayEntry.docs.isEmpty) {
        // Nothing to remove, simply return the current latest wornAt
        final latestSnapshot =
            await historyRef.orderBy('wornAt', descending: true).limit(1).get();
        if (latestSnapshot.docs.isEmpty) {
          // No history at all
          await _updateWornAtFields(
            userId: userId,
            wardrobeId: wardrobeId,
            clothId: clothId,
            wornAt: null,
          );
          return null;
        }
        final latest =
            (latestSnapshot.docs.first.data()['wornAt'] as Timestamp).toDate();
        await _updateWornAtFields(
          userId: userId,
          wardrobeId: wardrobeId,
          clothId: clothId,
          wornAt: latest,
        );
        return latest;
      }

      // Remove today's entry
      await todayEntry.docs.first.reference.delete();

      // Determine the new latest wornAt (if any)
      final latestSnapshot =
          await historyRef.orderBy('wornAt', descending: true).limit(1).get();

      DateTime? latestWornAt;
      if (latestSnapshot.docs.isNotEmpty) {
        latestWornAt =
            (latestSnapshot.docs.first.data()['wornAt'] as Timestamp).toDate();
      }

      await _updateWornAtFields(
        userId: userId,
        wardrobeId: wardrobeId,
        clothId: clothId,
        wornAt: latestWornAt,
      );

      return latestWornAt;
    } catch (e) {
      debugPrint('Failed to unmark worn status: $e');
      rethrow;
    }
  }

  static Future<void> _updateWornAtFields({
    required String userId,
    required String wardrobeId,
    required String clothId,
    required DateTime? wornAt,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (wornAt != null) {
      updates['wornAt'] = Timestamp.fromDate(wornAt);
    } else {
      updates['wornAt'] = FieldValue.delete();
    }

    await _firestore
        .collection(_clothesPath(userId, wardrobeId))
        .doc(clothId)
        .update(updates);

    await _firestore.collection('clothes').doc(clothId).update(updates);
  }

  /// Like cloth
  static Future<void> likeCloth({
    required String userId,
    required String ownerId,
    required String wardrobeId,
    required String clothId,
  }) async {
    try {
      final likeRef = _firestore
          .collection(_clothesPath(ownerId, wardrobeId))
          .doc(clothId)
          .collection('likes')
          .doc(userId);

      // Check if like already exists
      final likeDoc = await likeRef.get();
      if (likeDoc.exists) {
        // Like already exists, no need to do anything
        return;
      }

      final now = DateTime.now();

      // Create like document
      await likeRef.set({
        'userId': userId,
        'createdAt': Timestamp.fromDate(now),
      });

      // Update likesCount on subcollection cloth document
      final clothRef =
          _firestore.collection(_clothesPath(ownerId, wardrobeId)).doc(clothId);

      // Check if cloth exists before updating
      final clothDoc = await clothRef.get();
      if (!clothDoc.exists) {
        // Cloth doesn't exist, delete the like we just created
        await likeRef.delete();
        throw Exception('Cloth not found');
      }

      await clothRef.update({
        'likesCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update likesCount on top-level cloth document
      await _firestore.collection('clothes').doc(clothId).update({
        'likesCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
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
      final likeRef = _firestore
          .collection(_clothesPath(ownerId, wardrobeId))
          .doc(clothId)
          .collection('likes')
          .doc(userId);

      // Check if like exists before deleting
      final likeDoc = await likeRef.get();
      if (!likeDoc.exists) {
        // Like doesn't exist, no need to do anything
        return;
      }

      // Delete like document
      await likeRef.delete();

      // Update likesCount on subcollection cloth document
      final clothRef =
          _firestore.collection(_clothesPath(ownerId, wardrobeId)).doc(clothId);

      // Check if cloth exists before updating
      final clothDoc = await clothRef.get();
      if (clothDoc.exists) {
        await clothRef.update({
          'likesCount': FieldValue.increment(-1),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Update likesCount on top-level cloth document
        await _firestore.collection('clothes').doc(clothId).update({
          'likesCount': FieldValue.increment(-1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      // If cloth doesn't exist, that's okay - the like is already deleted
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

  /// Get actual like count from Firestore (counts like documents)
  static Future<int> getLikeCount({
    required String ownerId,
    required String wardrobeId,
    required String clothId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_clothesPath(ownerId, wardrobeId))
          .doc(clothId)
          .collection('likes')
          .get();

      return snapshot.docs.length;
    } catch (e) {
      debugPrint('Failed to get like count: $e');
      return 0;
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

      // Create comment document
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

      // Update commentsCount on subcollection cloth document
      final clothRef = _firestore
          .collection(_clothesPath(ownerId, wardrobeId))
          .doc(clothId);
      
      // Check if cloth exists before updating
      final clothDoc = await clothRef.get();
      if (!clothDoc.exists) {
        // Cloth doesn't exist, delete the comment we just created
        await _firestore
            .collection(_clothesPath(ownerId, wardrobeId))
            .doc(clothId)
            .collection('comments')
            .doc(commentId)
            .delete();
        throw Exception('Cloth not found');
      }

      await clothRef.update({
        'commentsCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update commentsCount on top-level cloth document
      await _firestore.collection('clothes').doc(clothId).update({
        'commentsCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
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

      final data = commentDoc.data();
      if (data == null) return;

      final comment = Comment.fromJson(data, commentId);

      // Only comment author can delete
      if (comment.userId != userId) {
        throw Exception('Only comment author can delete');
      }

      // Delete comment document
      await _firestore
          .collection(_clothesPath(ownerId, wardrobeId))
          .doc(clothId)
          .collection('comments')
          .doc(commentId)
          .delete();

      // Update commentsCount on subcollection cloth document
      final clothRef = _firestore
          .collection(_clothesPath(ownerId, wardrobeId))
          .doc(clothId);
      
      // Check if cloth exists before updating
      final clothDoc = await clothRef.get();
      if (clothDoc.exists) {
        await clothRef.update({
          'commentsCount': FieldValue.increment(-1),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Update commentsCount on top-level cloth document
        await _firestore.collection('clothes').doc(clothId).update({
          'commentsCount': FieldValue.increment(-1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      // If cloth doesn't exist, that's okay - the comment is already deleted
    } catch (e) {
      debugPrint('Failed to delete comment: $e');
      rethrow;
    }
  }

  /// Get actual comment count from Firestore (counts comment documents)
  static Future<int> getCommentCount({
    required String ownerId,
    required String wardrobeId,
    required String clothId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_clothesPath(ownerId, wardrobeId))
          .doc(clothId)
          .collection('comments')
          .get();

      return snapshot.docs.length;
    } catch (e) {
      debugPrint('Failed to get comment count: $e');
      return 0;
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
            .map((doc) => Cloth.fromJson(doc.data(), doc.id))
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
            .map((doc) => Cloth.fromJson(doc.data(), doc.id))
            .toList());
  }

  /// Get wear history for cloth
  static Future<List<WearHistoryEntry>> getWearHistory({
    required String userId,
    required String wardrobeId,
    required String clothId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_clothesPath(userId, wardrobeId))
          .doc(clothId)
          .collection('wearHistory')
          .orderBy('wornAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => WearHistoryEntry.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Failed to get wear history: $e');
      return [];
    }
  }
}
