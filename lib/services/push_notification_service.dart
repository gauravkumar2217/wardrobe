import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'user_service.dart';
import '../models/user_profile.dart';

/// Service to send push notifications
/// For now, creates notification trigger documents in Firestore
/// Cloud Functions should listen to these and send actual FCM notifications
class PushNotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Check if user has notification enabled for a specific type
  static Future<bool> _isNotificationEnabled({
    required String userId,
    required String notificationType,
  }) async {
    try {
      final profile = await UserService.getUserProfile(userId);
      if (profile?.settings?.notifications == null) {
        return true; // Default to enabled if settings not found
      }

      final settings = profile!.settings!.notifications;
      switch (notificationType) {
        case 'friend_request':
          return settings.friendRequests;
        case 'friend_accept':
          return settings.friendAccepts;
        case 'dm_message':
          return settings.dmMessages;
        case 'cloth_like':
          return settings.clothLikes;
        case 'cloth_comment':
          return settings.clothComments;
        case 'suggestion':
          return settings.suggestions;
        default:
          return true;
      }
    } catch (e) {
      debugPrint('Failed to check notification settings: $e');
      return true; // Default to enabled on error
    }
  }

  /// Check if current time is within quiet hours
  static bool _isQuietHours(NotificationSettings? settings) {
    if (settings == null) return false;
    if (settings.quietHoursStart == null || settings.quietHoursEnd == null) {
      return false;
    }

    try {
      final now = DateTime.now();
      
      final startParts = settings.quietHoursStart!.split(':');
      final endParts = settings.quietHoursEnd!.split(':');
      final startHour = int.parse(startParts[0]);
      final startMinute = int.parse(startParts[1]);
      final endHour = int.parse(endParts[0]);
      final endMinute = int.parse(endParts[1]);

      final startTime = DateTime(now.year, now.month, now.day, startHour, startMinute);
      final endTime = DateTime(now.year, now.month, now.day, endHour, endMinute);

      // Handle quiet hours that span midnight
      if (endTime.isBefore(startTime) || endTime == startTime) {
        // Quiet hours span midnight (e.g., 22:00 to 08:00)
        return now.isAfter(startTime) || now.isBefore(endTime);
      } else {
        // Quiet hours within same day
        return now.isAfter(startTime) && now.isBefore(endTime);
      }
    } catch (e) {
      debugPrint('Failed to check quiet hours: $e');
      return false;
    }
  }

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
      // Check if notifications are enabled for recipient
      final isEnabled = await _isNotificationEnabled(
        userId: recipientUserId,
        notificationType: 'dm_message',
      );
      if (!isEnabled) {
        if (kDebugMode) {
          debugPrint('DM message notifications disabled for user: $recipientUserId');
        }
        return;
      }

      // Check quiet hours
      final profile = await UserService.getUserProfile(recipientUserId);
      if (_isQuietHours(profile?.settings?.notifications)) {
        if (kDebugMode) {
          debugPrint('Quiet hours active, skipping DM message notification');
        }
        return;
      }

      // Get sender's profile for notification
      final senderProfile = await UserService.getUserProfile(senderUserId);
      final displayName = senderName ?? 
          (senderProfile?.displayName ??
              (senderProfile?.username != null
                  ? '@${senderProfile!.username}'
                  : 'Someone'));

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
  /// Uses the new fcmTokens collection for faster queries
  static Future<bool> isUserAppInForeground(String userId) async {
    try {
      // Check fcmTokens collection for active devices
      final tokensSnapshot = await _firestore
          .collection('fcmTokens')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      if (tokensSnapshot.docs.isEmpty) return false;

      // Check if any device was active recently (within last 30 seconds)
      final now = DateTime.now();
      for (var tokenDoc in tokensSnapshot.docs) {
        final tokenData = tokenDoc.data();
        final lastActiveAt = tokenData['lastActiveAt'] as Timestamp?;
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
      // Fallback to old method
      try {
        final devicesSnapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('devices')
            .where('isActive', isEqualTo: true)
            .get();

        if (devicesSnapshot.docs.isEmpty) return false;

        final now = DateTime.now();
        for (var deviceDoc in devicesSnapshot.docs) {
          final deviceData = deviceDoc.data();
          final lastActiveAt = deviceData['lastActiveAt'] as Timestamp?;
          if (lastActiveAt != null) {
            final lastActive = lastActiveAt.toDate();
            final difference = now.difference(lastActive);
            if (difference.inSeconds < 30) {
              return true;
            }
          }
        }
        return false;
      } catch (e2) {
        debugPrint('Failed to check if user app is in foreground (fallback): $e2');
        return false;
      }
    }
  }

  /// Get all active FCM tokens for a user (for Cloud Functions)
  /// Uses the new fcmTokens collection
  static Future<List<String>> getActiveTokensForUser(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('fcmTokens')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => doc.data()['fcmToken'] as String)
          .where((token) => token.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('Failed to get active tokens for user: $e');
      return [];
    }
  }

  /// Send push notification for friend request
  static Future<void> sendFriendRequestNotification({
    required String recipientUserId,
    required String senderUserId,
    required String requestId,
  }) async {
    try {
      // Check if notifications are enabled for recipient
      final isEnabled = await _isNotificationEnabled(
        userId: recipientUserId,
        notificationType: 'friend_request',
      );
      if (!isEnabled) {
        if (kDebugMode) {
          debugPrint('Friend request notifications disabled for user: $recipientUserId');
        }
        return;
      }

      // Check quiet hours
      final profile = await UserService.getUserProfile(recipientUserId);
      if (_isQuietHours(profile?.settings?.notifications)) {
        if (kDebugMode) {
          debugPrint('Quiet hours active, skipping friend request notification');
        }
        return;
      }

      // Get sender's profile
      final senderProfile = await UserService.getUserProfile(senderUserId);
      final senderName = senderProfile?.displayName ??
          (senderProfile?.username != null ? '@${senderProfile!.username}' : 'Someone');

      // Create notification trigger
      final notificationData = {
        'type': 'friend_request',
        'recipientUserId': recipientUserId,
        'senderUserId': senderUserId,
        'requestId': requestId,
        'title': 'New Friend Request',
        'body': '$senderName wants to be your friend',
        'data': {
          'type': 'friend_request',
          'fromUserId': senderUserId,
          'requestId': requestId,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'sent': false,
      };

      await _firestore.collection('notificationTriggers').add(notificationData);

      // Create in-app notification
      await _createInAppNotification(
        userId: recipientUserId,
        type: 'friend_request',
        title: 'New Friend Request',
        body: '$senderName wants to be your friend',
        data: {
          'type': 'friend_request',
          'fromUserId': senderUserId,
          'requestId': requestId,
        },
      );

      if (kDebugMode) {
        debugPrint('Friend request notification trigger created for user: $recipientUserId');
      }
    } catch (e) {
      debugPrint('Failed to send friend request notification: $e');
    }
  }

  /// Send push notification for friend request accepted
  static Future<void> sendFriendAcceptNotification({
    required String recipientUserId,
    required String accepterUserId,
    required String requestId,
  }) async {
    try {
      // Check if notifications are enabled for recipient
      final isEnabled = await _isNotificationEnabled(
        userId: recipientUserId,
        notificationType: 'friend_accept',
      );
      if (!isEnabled) {
        if (kDebugMode) {
          debugPrint('Friend accept notifications disabled for user: $recipientUserId');
        }
        return;
      }

      // Check quiet hours
      final profile = await UserService.getUserProfile(recipientUserId);
      if (_isQuietHours(profile?.settings?.notifications)) {
        if (kDebugMode) {
          debugPrint('Quiet hours active, skipping friend accept notification');
        }
        return;
      }

      // Get accepter's profile
      final accepterProfile = await UserService.getUserProfile(accepterUserId);
      final accepterName = accepterProfile?.displayName ??
          (accepterProfile?.username != null ? '@${accepterProfile!.username}' : 'Someone');

      // Create notification trigger
      final notificationData = {
        'type': 'friend_accept',
        'recipientUserId': recipientUserId,
        'senderUserId': accepterUserId,
        'requestId': requestId,
        'title': 'Friend Request Accepted',
        'body': '$accepterName accepted your friend request',
        'data': {
          'type': 'friend_accept',
          'toUserId': accepterUserId,
          'requestId': requestId,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'sent': false,
      };

      await _firestore.collection('notificationTriggers').add(notificationData);

      // Create in-app notification
      await _createInAppNotification(
        userId: recipientUserId,
        type: 'friend_accept',
        title: 'Friend Request Accepted',
        body: '$accepterName accepted your friend request',
        data: {
          'type': 'friend_accept',
          'toUserId': accepterUserId,
          'requestId': requestId,
        },
      );

      if (kDebugMode) {
        debugPrint('Friend accept notification trigger created for user: $recipientUserId');
      }
    } catch (e) {
      debugPrint('Failed to send friend accept notification: $e');
    }
  }

  /// Send push notification for cloth like
  static Future<void> sendClothLikeNotification({
    required String recipientUserId,
    required String likerUserId,
    required String clothId,
    required String clothOwnerId,
    required String clothWardrobeId,
  }) async {
    try {
      // Don't notify if user liked their own cloth
      if (recipientUserId == likerUserId) {
        return;
      }

      // Check if notifications are enabled for recipient
      final isEnabled = await _isNotificationEnabled(
        userId: recipientUserId,
        notificationType: 'cloth_like',
      );
      if (!isEnabled) {
        if (kDebugMode) {
          debugPrint('Cloth like notifications disabled for user: $recipientUserId');
        }
        return;
      }

      // Check quiet hours
      final profile = await UserService.getUserProfile(recipientUserId);
      if (_isQuietHours(profile?.settings?.notifications)) {
        if (kDebugMode) {
          debugPrint('Quiet hours active, skipping cloth like notification');
        }
        return;
      }

      // Get liker's profile
      final likerProfile = await UserService.getUserProfile(likerUserId);
      final likerName = likerProfile?.displayName ??
          (likerProfile?.username != null ? '@${likerProfile!.username}' : 'Someone');

      // Create notification trigger
      final notificationData = {
        'type': 'cloth_like',
        'recipientUserId': recipientUserId,
        'senderUserId': likerUserId,
        'clothId': clothId,
        'clothOwnerId': clothOwnerId,
        'clothWardrobeId': clothWardrobeId,
        'title': 'New Like',
        'body': '$likerName liked your cloth',
        'data': {
          'type': 'cloth_like',
          'clothId': clothId,
          'likerId': likerUserId,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'sent': false,
      };

      await _firestore.collection('notificationTriggers').add(notificationData);

      // Create in-app notification
      await _createInAppNotification(
        userId: recipientUserId,
        type: 'cloth_like',
        title: 'New Like',
        body: '$likerName liked your cloth',
        data: {
          'type': 'cloth_like',
          'clothId': clothId,
          'likerId': likerUserId,
        },
      );

      if (kDebugMode) {
        debugPrint('Cloth like notification trigger created for user: $recipientUserId');
      }
    } catch (e) {
      debugPrint('Failed to send cloth like notification: $e');
    }
  }

  /// Send push notification for cloth comment
  static Future<void> sendClothCommentNotification({
    required String recipientUserId,
    required String commenterUserId,
    required String clothId,
    required String commentId,
    required String clothOwnerId,
    required String clothWardrobeId,
    String? commentText,
  }) async {
    try {
      // Don't notify if user commented on their own cloth
      if (recipientUserId == commenterUserId) {
        return;
      }

      // Check if notifications are enabled for recipient
      final isEnabled = await _isNotificationEnabled(
        userId: recipientUserId,
        notificationType: 'cloth_comment',
      );
      if (!isEnabled) {
        if (kDebugMode) {
          debugPrint('Cloth comment notifications disabled for user: $recipientUserId');
        }
        return;
      }

      // Check quiet hours
      final profile = await UserService.getUserProfile(recipientUserId);
      if (_isQuietHours(profile?.settings?.notifications)) {
        if (kDebugMode) {
          debugPrint('Quiet hours active, skipping cloth comment notification');
        }
        return;
      }

      // Get commenter's profile
      final commenterProfile = await UserService.getUserProfile(commenterUserId);
      final commenterName = commenterProfile?.displayName ??
          (commenterProfile?.username != null ? '@${commenterProfile!.username}' : 'Someone');

      final body = commentText != null && commentText.length > 50
          ? '${commentText.substring(0, 50)}...'
          : (commentText ?? 'commented on your cloth');

      // Create notification trigger
      final notificationData = {
        'type': 'cloth_comment',
        'recipientUserId': recipientUserId,
        'senderUserId': commenterUserId,
        'clothId': clothId,
        'commentId': commentId,
        'clothOwnerId': clothOwnerId,
        'clothWardrobeId': clothWardrobeId,
        'title': 'New Comment',
        'body': '$commenterName: $body',
        'data': {
          'type': 'cloth_comment',
          'clothId': clothId,
          'commentId': commentId,
          'commenterId': commenterUserId,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'sent': false,
      };

      await _firestore.collection('notificationTriggers').add(notificationData);

      // Create in-app notification
      await _createInAppNotification(
        userId: recipientUserId,
        type: 'cloth_comment',
        title: 'New Comment',
        body: '$commenterName: $body',
        data: {
          'type': 'cloth_comment',
          'clothId': clothId,
          'commentId': commentId,
          'commenterId': commenterUserId,
        },
      );

      if (kDebugMode) {
        debugPrint('Cloth comment notification trigger created for user: $recipientUserId');
      }
    } catch (e) {
      debugPrint('Failed to send cloth comment notification: $e');
    }
  }

  /// Send push notification for cloth sharing (via chat message)
  /// This is already handled by sendChatMessageNotification when clothId is present
  /// This method is for explicit cloth sharing notifications if needed
  static Future<void> sendClothShareNotification({
    required String recipientUserId,
    required String sharerUserId,
    required String clothId,
    required String chatId,
  }) async {
    try {
      // Cloth sharing notifications are sent via chat messages
      // This method can be used for additional notifications if needed
      // For now, we rely on sendChatMessageNotification which is called when sharing
      
      if (kDebugMode) {
        debugPrint('Cloth share notification handled via chat message notification');
      }
    } catch (e) {
      debugPrint('Failed to send cloth share notification: $e');
    }
  }
}
