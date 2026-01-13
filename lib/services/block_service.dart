import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service for handling user blocking functionality
class BlockService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Block a user
  /// This will immediately remove their content from the blocker's feed
  static Future<void> blockUser({
    required String blockerId,
    required String blockedUserId,
    String? reason,
  }) async {
    try {
      final now = DateTime.now();

      // Add to blocked users subcollection
      await _firestore
          .collection('users')
          .doc(blockerId)
          .collection('blockedUsers')
          .doc(blockedUserId)
          .set({
        'blockedUserId': blockedUserId,
        'blockedAt': Timestamp.fromDate(now),
        if (reason != null) 'reason': reason,
      });

      // Also store in top-level collection for easy querying
      await _firestore
          .collection('blockedUsers')
          .doc('${blockerId}_$blockedUserId')
          .set({
        'blockerId': blockerId,
        'blockedUserId': blockedUserId,
        'blockedAt': Timestamp.fromDate(now),
        if (reason != null) 'reason': reason,
      });

      // Trigger Cloud Function to notify developer
      // This will be handled by Firebase Functions
      debugPrint('User blocked: $blockedUserId by $blockerId');

      // Note: Content removal from feeds happens in queries using getBlockedUserIds()
    } catch (e) {
      debugPrint('Failed to block user: $e');
      rethrow;
    }
  }

  /// Unblock a user
  static Future<void> unblockUser({
    required String blockerId,
    required String blockedUserId,
  }) async {
    try {
      // Remove from blocked users subcollection
      await _firestore
          .collection('users')
          .doc(blockerId)
          .collection('blockedUsers')
          .doc(blockedUserId)
          .delete();

      // Remove from top-level collection
      await _firestore
          .collection('blockedUsers')
          .doc('${blockerId}_$blockedUserId')
          .delete();

      debugPrint('User unblocked: $blockedUserId by $blockerId');
    } catch (e) {
      debugPrint('Failed to unblock user: $e');
      rethrow;
    }
  }

  /// Check if a user is blocked
  static Future<bool> isUserBlocked({
    required String blockerId,
    required String blockedUserId,
  }) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(blockerId)
          .collection('blockedUsers')
          .doc(blockedUserId)
          .get();

      return doc.exists;
    } catch (e) {
      debugPrint('Failed to check if user is blocked: $e');
      return false;
    }
  }

  /// Get list of blocked user IDs for a user
  static Future<List<String>> getBlockedUserIds(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('blockedUsers')
          .get();

      return snapshot.docs
          .map((doc) => doc.data()['blockedUserId'] as String)
          .toList();
    } catch (e) {
      debugPrint('Failed to get blocked user IDs: $e');
      return [];
    }
  }

  /// Stream blocked user IDs for real-time updates
  static Stream<List<String>> watchBlockedUserIds(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('blockedUsers')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => doc.data()['blockedUserId'] as String)
            .toList());
  }

  /// Get blocked users list with details
  static Future<List<Map<String, dynamic>>> getBlockedUsers(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('blockedUsers')
          .orderBy('blockedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'blockedUserId': data['blockedUserId'] as String,
          'blockedAt': (data['blockedAt'] as Timestamp).toDate(),
          'reason': data['reason'] as String?,
        };
      }).toList();
    } catch (e) {
      debugPrint('Failed to get blocked users: $e');
      return [];
    }
  }

  /// Check if user A has blocked user B or vice versa (bidirectional check)
  static Future<bool> areUsersBlocked({
    required String userId1,
    required String userId2,
  }) async {
    try {
      final isBlocked1 = await isUserBlocked(
        blockerId: userId1,
        blockedUserId: userId2,
      );
      
      final isBlocked2 = await isUserBlocked(
        blockerId: userId2,
        blockedUserId: userId1,
      );

      return isBlocked1 || isBlocked2;
    } catch (e) {
      debugPrint('Failed to check bidirectional block: $e');
      return false;
    }
  }
}
