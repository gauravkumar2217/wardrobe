import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'wardrobe_service.dart';
import 'cloth_service.dart';

/// Service for managing user account deletion
class AccountDeletionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Delete all user data and account
  static Future<void> deleteAccount(String userId) async {
    try {
      // 1. Delete all wardrobes and their clothes
      final wardrobes = await WardrobeService.getUserWardrobes(userId);
      
      for (final wardrobe in wardrobes) {
        // Get all clothes for this wardrobe
        final clothes = await ClothService.getClothes(userId, wardrobe.id);
        
        // Delete all cloth images from storage
        for (final cloth in clothes) {
          if (cloth.imageUrl.isNotEmpty) {
            try {
              // Extract path from URL or construct it
              final storagePath = 'user_uploads/$userId/wardrobe_${wardrobe.id}/${cloth.id}.jpg';
              final storageRef = _storage.ref().child(storagePath);
              await storageRef.delete();
            } catch (e) {
              // Continue even if image deletion fails
              if (kDebugMode) {
                debugPrint('Failed to delete image for cloth ${cloth.id}: $e');
              }
            }
          }
        }
        
        // Delete wardrobe (this will cascade delete clothes if using subcollections)
        await WardrobeService.deleteWardrobe(userId, wardrobe.id);
      }

      // 2. Delete all suggestions
      try {
        final suggestionsSnapshot = await _firestore
            .collection('users/$userId/suggestions')
            .get();
        
        final batch = _firestore.batch();
        for (var doc in suggestionsSnapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Failed to delete suggestions: $e');
        }
      }

      // 3. Delete all chat conversations
      try {
        final chatsSnapshot = await _firestore
            .collection('users/$userId/chats')
            .get();
        
        for (var chatDoc in chatsSnapshot.docs) {
          // Delete all messages in this chat
          final messagesSnapshot = await chatDoc.reference
              .collection('messages')
              .get();
          
          final batch = _firestore.batch();
          for (var msgDoc in messagesSnapshot.docs) {
            batch.delete(msgDoc.reference);
          }
          batch.delete(chatDoc.reference);
          await batch.commit();
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Failed to delete chats: $e');
        }
      }

      // 4. Delete user profile
      try {
        await _firestore.doc('users/$userId').delete();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Failed to delete user profile: $e');
        }
      }

      // 5. Delete Firebase Auth account
      final user = _auth.currentUser;
      if (user != null && user.uid == userId) {
        await user.delete();
      }
    } catch (e) {
      throw Exception('Failed to delete account: $e');
    }
  }
}

