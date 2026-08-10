import 'package:flutter/foundation.dart';

/// Legacy client-side push helpers.
///
/// Chat / social notifications are sent by Laravel
/// (`AppNotificationService` + `FcmPushService`). This class is kept so older
/// call sites compile, but it no longer writes to Firestore.
class PushNotificationService {
  static Future<void> sendChatMessageNotification({
    required String recipientUserId,
    required String senderUserId,
    required String chatId,
    required String messageId,
    String? messageText,
    String? senderName,
  }) async {
    _skip('sendChatMessageNotification');
  }

  static Future<bool> isUserAppInForeground(String userId) async => false;

  static Future<List<String>> getActiveTokensForUser(String userId) async =>
      const [];

  static Future<void> sendFriendRequestNotification({
    required String recipientUserId,
    required String senderUserId,
    required String requestId,
    String? senderName,
  }) async {
    _skip('sendFriendRequestNotification');
  }

  static Future<void> sendFriendAcceptNotification({
    required String recipientUserId,
    required String accepterUserId,
    String? accepterName,
  }) async {
    _skip('sendFriendAcceptNotification');
  }

  static Future<void> sendClothLikeNotification({
    required String recipientUserId,
    required String likerUserId,
    required String clothId,
    required String clothOwnerId,
    required String clothWardrobeId,
    String? likerName,
  }) async {
    _skip('sendClothLikeNotification');
  }

  static Future<void> sendClothCommentNotification({
    required String recipientUserId,
    required String commenterUserId,
    required String clothId,
    required String clothOwnerId,
    required String clothWardrobeId,
    required String commentId,
    String? commentText,
    String? commenterName,
  }) async {
    _skip('sendClothCommentNotification');
  }

  static Future<void> sendClothShareNotification({
    required String recipientUserId,
    required String sharerUserId,
    required String clothId,
    required String clothOwnerId,
    required String clothWardrobeId,
    String? sharerName,
  }) async {
    _skip('sendClothShareNotification');
  }

  static void _skip(String name) {
    if (kDebugMode) {
      debugPrint('$name: skipped (Laravel FCM handles notifications)');
    }
  }
}
