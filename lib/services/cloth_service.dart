import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/cloth.dart';
import '../utils/image_compression.dart';

class ClothService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Get Firestore path for clothes in a wardrobe
  static String _clothesPath(String userId, String wardrobeId) {
    return 'users/$userId/wardrobes/$wardrobeId/clothes';
  }

  /// Get Storage path for cloth image
  static String _storagePath(String userId, String wardrobeId, String clothId) {
    return 'user_uploads/$userId/wardrobe_$wardrobeId/$clothId.jpg';
  }

  /// Upload image to Firebase Storage
  static Future<String> uploadImage(
    File imageFile,
    String userId,
    String wardrobeId,
    String clothId,
  ) async {
    try {
      // Compress image before upload
      final compressedFile = await ImageCompression.compressImage(imageFile);
      
      final storageRef = _storage.ref().child(_storagePath(userId, wardrobeId, clothId));
      final uploadTask = storageRef.putFile(compressedFile);
      
      await uploadTask;
      final imageUrl = await storageRef.getDownloadURL();
      return imageUrl;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  /// Add cloth to wardrobe
  static Future<String> addCloth(
    String userId,
    String wardrobeId,
    File? imageFile,
    String type,
    String color,
    String occasion,
    String season,
  ) async {
    try {
      final clothId = _firestore
          .collection(_clothesPath(userId, wardrobeId))
          .doc()
          .id;

      String imageUrl = '';
      
      // Upload image if provided
      if (imageFile != null) {
        imageUrl = await uploadImage(imageFile, userId, wardrobeId, clothId);
      }

      // Create cloth document
      final clothData = {
        'imageUrl': imageUrl,
        'type': type,
        'color': color,
        'occasion': occasion,
        'season': season,
        'createdAt': FieldValue.serverTimestamp(),
        'lastWorn': null,
      };

      await _firestore
          .collection(_clothesPath(userId, wardrobeId))
          .doc(clothId)
          .set(clothData);

      // Update wardrobe's updatedAt and increment clothCount
      await _firestore
          .collection('users/$userId/wardrobes')
          .doc(wardrobeId)
          .update({
        'updatedAt': FieldValue.serverTimestamp(),
        'clothCount': FieldValue.increment(1),
      });

      return clothId;
    } catch (e) {
      throw Exception('Failed to add cloth: $e');
    }
  }

  /// Get all clothes for a wardrobe
  static Future<List<Cloth>> getClothes(
    String userId,
    String wardrobeId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection(_clothesPath(userId, wardrobeId))
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return Cloth.fromJson(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch clothes: $e');
    }
  }

  /// Update cloth
  static Future<void> updateCloth(
    String userId,
    String wardrobeId,
    String clothId,
    Map<String, dynamic> updates,
  ) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      
      await _firestore
          .collection(_clothesPath(userId, wardrobeId))
          .doc(clothId)
          .update(updates);
    } catch (e) {
      throw Exception('Failed to update cloth: $e');
    }
  }

  /// Delete cloth and its image
  static Future<void> deleteCloth(
    String userId,
    String wardrobeId,
    String clothId,
  ) async {
    try {
      // Get cloth to delete its image
      final clothDoc = await _firestore
          .collection(_clothesPath(userId, wardrobeId))
          .doc(clothId)
          .get();

      if (clothDoc.exists) {
        final cloth = Cloth.fromJson(clothDoc.data()!, clothId);
        
        // Delete image from Storage
        if (cloth.imageUrl.isNotEmpty) {
          try {
            final storageRef = _storage.ref().child(
              _storagePath(userId, wardrobeId, clothId),
            );
            await storageRef.delete();
          } catch (e) {
            // Log error but continue with doc deletion
            if (kDebugMode) {
              debugPrint('Failed to delete image: $e');
            }
          }
        }

        // Delete cloth document
        await _firestore
            .collection(_clothesPath(userId, wardrobeId))
            .doc(clothId)
            .delete();

        // Update wardrobe's clothCount
        await _firestore
            .collection('users/$userId/wardrobes')
            .doc(wardrobeId)
            .update({
          'updatedAt': FieldValue.serverTimestamp(),
          'clothCount': FieldValue.increment(-1),
        });
      }
    } catch (e) {
      throw Exception('Failed to delete cloth: $e');
    }
  }

  /// Mark cloth as worn
  static Future<void> markAsWorn(
    String userId,
    String wardrobeId,
    String clothId,
  ) async {
    try {
      await _firestore
          .collection(_clothesPath(userId, wardrobeId))
          .doc(clothId)
          .update({
        'lastWorn': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to mark as worn: $e');
    }
  }

  /// Stream clothes for real-time updates
  static Stream<List<Cloth>> watchClothes(
    String userId,
    String wardrobeId,
  ) {
    return _firestore
        .collection(_clothesPath(userId, wardrobeId))
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Cloth.fromJson(doc.data(), doc.id))
          .toList();
    });
  }
}

