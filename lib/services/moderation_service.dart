import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Moderation service for admin actions
class ModerationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Remove content (comment or message)
  static Future<void> removeContent({
    required String moderatorId,
    required String targetUserId,
    required String targetContentId,
    required String contentType, // 'comment' or 'message'
    required String reason,
  }) async {
    try {
      // Delete the content
      if (contentType == 'comment') {
        // Find and delete comment
        // Comments are stored in: users/{ownerId}/wardrobes/{wardrobeId}/clothes/{clothId}/comments/{commentId}
        // We need to search for it - this is a simplified version
        // In production, you'd want to store content paths in reports
        
        // For now, log the action
        debugPrint('Removing comment: $targetContentId from user: $targetUserId');
      } else if (contentType == 'message') {
        // Messages are stored in: users/{userId}/chats/{chatId}/messages/{messageId}
        debugPrint('Removing message: $targetContentId from user: $targetUserId');
      }

      // Log moderation action
      await _logModerationAction(
        moderatorId: moderatorId,
        actionType: ModerationActionType.removeContent,
        targetUserId: targetUserId,
        targetContentId: targetContentId,
        reason: reason,
      );
    } catch (e) {
      debugPrint('Failed to remove content: $e');
      rethrow;
    }
  }

  /// Eject user (ban from platform)
  static Future<void> ejectUser({
    required String moderatorId,
    required String targetUserId,
    required String reason,
  }) async {
    try {
      // Mark user as ejected in their profile
      await _firestore.collection('users').doc(targetUserId).update({
        'ejected': true,
        'ejectedAt': FieldValue.serverTimestamp(),
        'ejectedReason': reason,
        'ejectedBy': moderatorId,
      });

      // Log moderation action
      await _logModerationAction(
        moderatorId: moderatorId,
        actionType: ModerationActionType.ejectUser,
        targetUserId: targetUserId,
        reason: reason,
      );

      debugPrint('User ejected: $targetUserId');
    } catch (e) {
      debugPrint('Failed to eject user: $e');
      rethrow;
    }
  }

  /// Warn user
  static Future<void> warnUser({
    required String moderatorId,
    required String targetUserId,
    required String reason,
  }) async {
    try {
      // Add warning to user's profile
      final warningId = _firestore.collection('warnings').doc().id;
      await _firestore.collection('users').doc(targetUserId).collection('warnings').doc(warningId).set({
        'warningId': warningId,
        'reason': reason,
        'warnedAt': FieldValue.serverTimestamp(),
        'warnedBy': moderatorId,
      });

      // Log moderation action
      await _logModerationAction(
        moderatorId: moderatorId,
        actionType: ModerationActionType.warnUser,
        targetUserId: targetUserId,
        reason: reason,
      );

      debugPrint('User warned: $targetUserId');
    } catch (e) {
      debugPrint('Failed to warn user: $e');
      rethrow;
    }
  }

  /// Log moderation action
  static Future<void> _logModerationAction({
    required String moderatorId,
    required ModerationActionType actionType,
    required String targetUserId,
    String? targetContentId,
    required String reason,
  }) async {
    try {
      final actionId = _firestore.collection('moderationActions').doc().id;
      await _firestore.collection('moderationActions').doc(actionId).set({
        'moderatorId': moderatorId,
        'actionType': actionType.toString(),
        'targetUserId': targetUserId,
        if (targetContentId != null) 'targetContentId': targetContentId,
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Failed to log moderation action: $e');
    }
  }

  /// Get moderation actions for a user
  static Future<List<Map<String, dynamic>>> getModerationActionsForUser(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('moderationActions')
          .where('targetUserId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'moderatorId': data['moderatorId'] as String,
          'actionType': data['actionType'] as String,
          'targetUserId': data['targetUserId'] as String,
          'targetContentId': data['targetContentId'] as String?,
          'reason': data['reason'] as String,
          'createdAt': (data['createdAt'] as Timestamp).toDate(),
        };
      }).toList();
    } catch (e) {
      debugPrint('Failed to get moderation actions: $e');
      return [];
    }
  }
}

enum ModerationActionType {
  removeContent,
  ejectUser,
  warnUser;

  @override
  String toString() {
    switch (this) {
      case ModerationActionType.removeContent:
        return 'remove_content';
      case ModerationActionType.ejectUser:
        return 'eject_user';
      case ModerationActionType.warnUser:
        return 'warn_user';
    }
  }
}
