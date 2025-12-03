import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'user_service.dart';

/// Service to send push notifications
/// For now, creates notification trigger documents in Firestore
/// Cloud Functions should listen to these and send actual FCM notifications
class PushNotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Send push notification for a new chat message
  /// Only sends if recipient's app is in background
  static Future<void> sendChatMessageNotification({
    required String recipientUserId,
    required String senderUserId,
    required String chatId,
    required String messageId,
    String? messageText,
    String? senderName,
  }) async {
    try {
      // Check if recipient's app is in foreground
      // Note: This is a simplified check - in production, you'd check the recipient's
      // app state from a server-side perspective (e.g., via Cloud Functions)
      // For now, we'll always create the notification trigger and let Cloud Functions
      // decide based on the recipient's actual app state

      // Get sender's profile for notification
      final senderProfile = await UserService.getUserProfile(senderUserId);
      final displayName = senderProfile?.displayName ??
          (senderProfile?.username != null
              ? '@${senderProfile!.username}'
              : 'Someone');

      // Create notification trigger document
      // Cloud Function should listen to this and send actual push notification
      // if recipient's app is in background
      final notificationData = {
        'type': 'dm_message',
        'recipientUserId': recipientUserId,
        'senderUserId': senderUserId,
        'chatId': chatId,
        'messageId': messageId,
        'title': displayName,
        'body': messageText ?? 'Sent a message',
        'data': {
          'chatId': chatId,
          'messageId': messageId,
          'senderId': senderUserId,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'sent': false, // Cloud Function will mark as true after sending
      };

      // Store in a collection that Cloud Functions can listen to
      // For now, we'll also create an in-app notification
      await _firestore.collection('notificationTriggers').add(notificationData);

      // Also create in-app notification
      await _createInAppNotification(
        userId: recipientUserId,
        type: 'dm_message',
        title: displayName,
        body: messageText ?? 'Sent a message',
        data: {
          'chatId': chatId,
          'messageId': messageId,
          'senderId': senderUserId,
        },
      );

      if (kDebugMode) {
        debugPrint(
            'Chat message notification trigger created for user: $recipientUserId');
      }
    } catch (e) {
      debugPrint('Failed to send chat message notification: $e');
    }
  }

  /// Create in-app notification document
  static Future<void> _createInAppNotification({
    required String userId,
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final notificationData = {
        'type': type,
        'title': title,
        'body': body,
        'data': data ?? {},
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add(notificationData);
    } catch (e) {
      debugPrint('Failed to create in-app notification: $e');
    }
  }

  /// Check if user's app is likely in foreground
  /// This is a client-side check - for accurate server-side check,
  /// you'd need to track this in Firestore (e.g., lastActiveAt timestamp)
  static Future<bool> isUserAppInForeground(String userId) async {
    try {
      // Check last active timestamp
      // If lastActiveAt is very recent (within last 30 seconds), assume app is in foreground
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) return false;

      final data = userDoc.data();
      if (data == null) return false;

      // Check devices collection for active devices
      final devicesSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('devices')
          .where('isActive', isEqualTo: true)
          .get();

      if (devicesSnapshot.docs.isEmpty) return false;

      // Check if any device was active recently (within last 30 seconds)
      final now = DateTime.now();
      for (var deviceDoc in devicesSnapshot.docs) {
        final deviceData = deviceDoc.data();
        final lastActiveAt = deviceData['lastActiveAt'] as Timestamp?;
        if (lastActiveAt != null) {
          final lastActive = lastActiveAt.toDate();
          final difference = now.difference(lastActive);
          // If last active was within 30 seconds, assume app is in foreground
          if (difference.inSeconds < 30) {
            return true;
          }
        }
      }

      return false;
    } catch (e) {
      debugPrint('Failed to check if user app is in foreground: $e');
      return false;
    }
  }
}
