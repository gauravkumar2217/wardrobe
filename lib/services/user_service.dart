import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';

/// User service for managing user profiles
class UserService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get user profile
  static Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();

      if (!doc.exists || doc.data() == null) {
        return null;
      }

      return UserProfile.fromJson(doc.data()!);
    } catch (e) {
      debugPrint('Failed to fetch user profile: $e');
      return null;
    }
  }

  /// Create or update user profile
  static Future<void> createOrUpdateProfile({
    required String userId,
    required UserProfile profile,
  }) async {
    try {
      final profileData = profile.toJson();
      profileData['updatedAt'] = FieldValue.serverTimestamp();
      
      if (!profileData.containsKey('createdAt')) {
        profileData['createdAt'] = FieldValue.serverTimestamp();
      }

      await _firestore
          .collection('users')
          .doc(userId)
          .set(profileData, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to create/update user profile: $e');
      rethrow;
    }
  }

  /// Update user profile (partial update)
  static Future<void> updateProfile({
    required String userId,
    Map<String, dynamic>? updates,
    UserProfile? profile,
  }) async {
    try {
      if (profile != null) {
        final profileData = profile.toJson();
        profileData['updatedAt'] = FieldValue.serverTimestamp();
        await _firestore
            .collection('users')
            .doc(userId)
            .update(profileData);
      } else if (updates != null) {
        updates['updatedAt'] = FieldValue.serverTimestamp();
        await _firestore
            .collection('users')
            .doc(userId)
            .update(updates);
      }
    } catch (e) {
      debugPrint('Failed to update user profile: $e');
      rethrow;
    }
  }

  /// Update notification settings
  static Future<void> updateNotificationSettings({
    required String userId,
    required NotificationSettings settings,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .update({
        'settings.notifications': settings.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Failed to update notification settings: $e');
      rethrow;
    }
  }

  /// Update privacy settings
  static Future<void> updatePrivacySettings({
    required String userId,
    required PrivacySettings privacy,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .update({
        'settings.privacy': privacy.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Failed to update privacy settings: $e');
      rethrow;
    }
  }

  /// Search users by name, email, or phone
  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      // Note: Firestore doesn't support full-text search natively
      // This is a basic implementation - consider using Algolia or similar for production
      final usersRef = _firestore.collection('users');
      
      // Search by displayName (prefix match)
      final nameQuery = await usersRef
          .where('displayName', isGreaterThanOrEqualTo: query)
          .where('displayName', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(20)
          .get();

      final results = <Map<String, dynamic>>[];
      
      for (var doc in nameQuery.docs) {
        final data = doc.data();
        results.add({
          'userId': doc.id,
          'displayName': data['displayName'] as String?,
          'photoUrl': data['photoUrl'] as String?,
          'email': data['email'] as String?,
        });
      }

      return results;
    } catch (e) {
      debugPrint('Failed to search users: $e');
      return [];
    }
  }

  /// Get user by ID (public info only)
  static Future<Map<String, dynamic>?> getUserPublicInfo(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      
      if (!doc.exists) return null;

      final data = doc.data()!;
      return {
        'userId': doc.id,
        'displayName': data['displayName'] as String?,
        'photoUrl': data['photoUrl'] as String?,
      };
    } catch (e) {
      debugPrint('Failed to get user public info: $e');
      return null;
    }
  }

  /// Delete user account
  static Future<void> deleteAccount(String userId) async {
    try {
      // Note: This should be handled by Cloud Function for complete cleanup
      // This only deletes the user profile document
      await _firestore.collection('users').doc(userId).delete();
    } catch (e) {
      debugPrint('Failed to delete account: $e');
      rethrow;
    }
  }

  /// Stream user profile for real-time updates
  static Stream<UserProfile?> watchUserProfile(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return UserProfile.fromJson(snapshot.data()!);
    });
  }
}
