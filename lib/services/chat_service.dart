import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/chat.dart';
import 'content_filter_service.dart';
import 'laravel_api_client.dart';
import 'laravel_auth_service.dart';

/// Chat service backed by Laravel API.
class ChatService {
  static Chat _parseChat(Map<String, dynamic> json) => Chat.fromApiJson(json);

  static ChatMessage _parseMessage(Map<String, dynamic> json) =>
      ChatMessage.fromApiJson(json);

  static List<Chat> _parseChatList(dynamic data) {
    if (data is! List) return [];
    return data.whereType<Map<String, dynamic>>().map(_parseChat).toList();
  }

  static List<ChatMessage> _parseMessageList(dynamic data) {
    Iterable<dynamic> items;
    if (data is Map<String, dynamic> && data['data'] is List) {
      items = data['data'] as List;
    } else if (data is List) {
      items = data;
    } else {
      return [];
    }
    return items
        .whereType<Map<String, dynamic>>()
        .map(_parseMessage)
        .toList();
  }

  /// Create or get existing chat between two users
  static Future<String> getOrCreateChat({
    required String userId1,
    required String userId2,
  }) async {
    try {
      final body = await LaravelApiClient.postJson(
        ApiConfig.chats,
        {
          'participants': [userId1, userId2],
          'is_group': false,
        },
      );
      final data = LaravelApiClient.extractData(body);
      if (data is Map<String, dynamic>) {
        return data['id']?.toString() ?? '';
      }
      throw Exception('Invalid chat response');
    } catch (e) {
      debugPrint('Failed to create/get chat: $e');
      rethrow;
    }
  }

  /// Get chat by ID
  static Future<Chat?> getChat({
    required String userId,
    required String chatId,
  }) async {
    try {
      final body = await LaravelApiClient.getJson(ApiConfig.chat(chatId));
      final data = LaravelApiClient.extractData(body);
      if (data is Map<String, dynamic>) return _parseChat(data);
      return null;
    } catch (e) {
      debugPrint('Failed to get chat: $e');
      return null;
    }
  }

  /// Get all chats for a user
  static Future<List<Chat>> getUserChats(String userId) async {
    try {
      final body = await LaravelApiClient.getJson(ApiConfig.chats);
      return _parseChatList(LaravelApiClient.extractData(body));
    } catch (e) {
      debugPrint('Failed to get user chats: $e');
      return [];
    }
  }

  /// Send message in chat
  static Future<String> sendMessage({
    required String userId,
    required String chatId,
    String? text,
    String? imageUrl,
    String? clothId,
    String? clothOwnerId,
    String? clothWardrobeId,
  }) async {
    try {
      if (text == null && imageUrl == null && clothId == null) {
        throw Exception('Message must have text, image, or cloth');
      }

      if (text != null && text.isNotEmpty) {
        final isSafe = await ContentFilterService.isContentSafe(text);
        if (!isSafe) {
          throw Exception(
            'Your message contains inappropriate content and cannot be sent.',
          );
        }
      }

      final chat = await getChat(userId: userId, chatId: chatId);
      if (chat == null) throw Exception('Chat not found');

      final payload = <String, dynamic>{};
      if (text != null) payload['text'] = text;
      if (imageUrl != null) payload['image_url'] = imageUrl;
      if (clothId != null) {
        payload['cloth_id'] = clothId;
        if (clothOwnerId != null) payload['cloth_owner_id'] = clothOwnerId;
        if (clothWardrobeId != null) {
          payload['cloth_wardrobe_id'] = clothWardrobeId;
        }
      }

      final body = await LaravelApiClient.postJson(
        ApiConfig.chatMessages(chatId),
        payload,
      );
      final data = LaravelApiClient.extractData(body);
      if (data is! Map<String, dynamic>) {
        throw Exception('Invalid message response');
      }
      final messageId = data['id']?.toString() ?? '';

      // Push + in-app notification are sent by Laravel MessageController
      // (AppNotificationService / FCM). Do not use Firestore triggers.

      if (clothId != null && clothOwnerId != null) {
        try {
          final recipientIds =
              chat.participants.where((id) => id != userId).toList();
          if (recipientIds.isNotEmpty) {
            await LaravelApiClient.putJson(
              ApiConfig.clothShare(clothId),
              {'user_ids': recipientIds},
            );
          }
        } catch (e) {
          debugPrint('Cloth share via API failed (message still sent): $e');
        }
      }

      return messageId;
    } catch (e) {
      debugPrint('Failed to send message: $e');
      rethrow;
    }
  }

  /// Get messages for a chat
  static Future<List<ChatMessage>> getMessages({
    required String userId,
    required String chatId,
    int limit = 50,
  }) async {
    try {
      final uri = Uri.parse(ApiConfig.chatMessages(chatId)).replace(
        queryParameters: {'per_page': limit.toString()},
      );
      final body = await LaravelApiClient.getJson(uri.toString());
      return _parseMessageList(LaravelApiClient.extractData(body));
    } catch (e) {
      debugPrint('Failed to get messages: $e');
      return [];
    }
  }

  /// Mark messages as seen
  static Future<void> markMessagesAsSeen({
    required String userId,
    required String chatId,
    required List<String> messageIds,
  }) async {
    for (final messageId in messageIds) {
      try {
        await LaravelApiClient.putJson(ApiConfig.messageSeen(messageId), {});
      } catch (e) {
        debugPrint('Failed to mark message $messageId as seen: $e');
      }
    }
  }

  /// Delete message
  static Future<void> deleteMessage({
    required String userId,
    required String chatId,
    required String messageId,
  }) async {
    try {
      await LaravelApiClient.deleteJson(ApiConfig.messageDelete(messageId));
    } catch (e) {
      debugPrint('Failed to delete message: $e');
      rethrow;
    }
  }

  /// Poll messages periodically (replaces Firestore stream).
  static Stream<List<ChatMessage>> watchMessages({
    required String userId,
    required String chatId,
    int limit = 50,
  }) async* {
    yield await getMessages(userId: userId, chatId: chatId, limit: limit);
    while (true) {
      await Future.delayed(const Duration(seconds: 5));
      yield await getMessages(userId: userId, chatId: chatId, limit: limit);
    }
  }

  /// Poll chats periodically (replaces Firestore stream).
  static Stream<List<Chat>> watchUserChats(String userId) async* {
    yield await getUserChats(userId);
    while (true) {
      await Future.delayed(const Duration(seconds: 45));
      yield await getUserChats(userId);
    }
  }

  /// Prefer [Chat.unreadCount] from the chat list API.
  /// Avoid calling this on every row — it loads messages and is slow.
  static Future<int> getUnreadCount({
    required String userId,
    required String chatId,
  }) async {
    try {
      final currentUserId = await LaravelAuthService.getCurrentUserId();
      if (currentUserId == null || currentUserId != userId) return 0;

      final messages =
          await getMessages(userId: userId, chatId: chatId, limit: 50);
      return messages
          .where((m) => m.senderId != userId && !m.isSeenBy(userId))
          .length;
    } catch (e) {
      debugPrint('Failed to get unread count: $e');
      return 0;
    }
  }

  /// Get unread message counts for all chats (from list payload only).
  static Future<Map<String, int>> getAllUnreadCounts(String userId) async {
    try {
      final currentUserId = await LaravelAuthService.getCurrentUserId();
      if (currentUserId == null || currentUserId != userId) return {};

      final chats = await getUserChats(userId);
      return {
        for (final chat in chats)
          if (chat.unreadCount > 0) chat.id: chat.unreadCount,
      };
    } catch (e) {
      debugPrint('Failed to get all unread counts: $e');
      return {};
    }
  }
}
