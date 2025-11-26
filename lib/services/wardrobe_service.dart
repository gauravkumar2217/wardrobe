import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/wardrobe.dart';

/// Wardrobe service for managing wardrobes
class WardrobeService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get Firestore path for wardrobes
  static String _wardrobesPath(String userId) {
    return 'users/$userId/wardrobes';
  }

  /// Create wardrobe
  static Future<String> createWardrobe({
    required String userId,
    required String name,
    required String location,
  }) async {
    try {
      final wardrobeId = _firestore.collection('wardrobes').doc().id;
      final now = DateTime.now();

      final wardrobeData = {
        'ownerId': userId,
        'name': name,
        'location': location,
        'totalItems': 0,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      };

      // Create in subcollection
      await _firestore
          .collection(_wardrobesPath(userId))
          .doc(wardrobeId)
          .set(wardrobeData);

      // Also create in top-level collection for queries
      await _firestore.collection('wardrobes').doc(wardrobeId).set(wardrobeData);

      if (kDebugMode) {
        debugPrint('Wardrobe created: $wardrobeId');
      }

      return wardrobeId;
    } catch (e) {
      debugPrint('Failed to create wardrobe: $e');
      rethrow;
    }
  }

  /// Get wardrobe by ID
  static Future<Wardrobe?> getWardrobe({
    required String userId,
    required String wardrobeId,
  }) async {
    try {
      final doc = await _firestore
          .collection(_wardrobesPath(userId))
          .doc(wardrobeId)
          .get();

      if (!doc.exists) return null;

      return Wardrobe.fromJson(doc.data()!, wardrobeId);
    } catch (e) {
      debugPrint('Failed to get wardrobe: $e');
      return null;
    }
  }

  /// Get all wardrobes for a user
  static Future<List<Wardrobe>> getUserWardrobes(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_wardrobesPath(userId))
          .orderBy('updatedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Wardrobe.fromJson(doc.data()!, doc.id))
          .toList();
    } catch (e) {
      debugPrint('Failed to get user wardrobes: $e');
      return [];
    }
  }

  /// Update wardrobe
  static Future<void> updateWardrobe({
    required String userId,
    required String wardrobeId,
    Map<String, dynamic>? updates,
    Wardrobe? wardrobe,
  }) async {
    try {
      if (wardrobe != null) {
        final wardrobeData = wardrobe.toJson();
        wardrobeData['updatedAt'] = FieldValue.serverTimestamp();
        // Don't update totalItems (managed by Cloud Functions)
        wardrobeData.remove('totalItems');

        await _firestore
            .collection(_wardrobesPath(userId))
            .doc(wardrobeId)
            .update(wardrobeData);

        // Also update top-level collection
        await _firestore.collection('wardrobes').doc(wardrobeId).update(wardrobeData);
      } else if (updates != null) {
        updates['updatedAt'] = FieldValue.serverTimestamp();
        // Don't allow updating totalItems
        updates.remove('totalItems');

        await _firestore
            .collection(_wardrobesPath(userId))
            .doc(wardrobeId)
            .update(updates);

        // Also update top-level collection
        await _firestore.collection('wardrobes').doc(wardrobeId).update(updates);
      }
    } catch (e) {
      debugPrint('Failed to update wardrobe: $e');
      rethrow;
    }
  }

  /// Delete wardrobe
  static Future<void> deleteWardrobe({
    required String userId,
    required String wardrobeId,
  }) async {
    try {
      // Get all clothes in wardrobe
      final clothesSnapshot = await _firestore
          .collection(_wardrobesPath(userId))
          .doc(wardrobeId)
          .collection('clothes')
          .get();

      // Delete all clothes (this will trigger Cloud Function to update totalItems)
      final batch = _firestore.batch();
      for (var doc in clothesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Delete wardrobe from subcollection
      await _firestore
          .collection(_wardrobesPath(userId))
          .doc(wardrobeId)
          .delete();

      // Delete from top-level collection
      await _firestore.collection('wardrobes').doc(wardrobeId).delete();
    } catch (e) {
      debugPrint('Failed to delete wardrobe: $e');
      rethrow;
    }
  }

  /// Stream wardrobes for real-time updates
  static Stream<List<Wardrobe>> watchUserWardrobes(String userId) {
    return _firestore
        .collection(_wardrobesPath(userId))
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Wardrobe.fromJson(doc.data()!, doc.id))
            .toList());
  }
}
