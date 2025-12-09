import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/chat.dart';
import 'push_notification_service.dart';
import 'user_service.dart';

/// Chat service for managing chats and messages
class ChatService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Create or get existing chat between two users
  static Future<String> getOrCreateChat({
    required String userId1,
    required String userId2,
  }) async {
    try {
      // Check if chat already exists
      final existingChats = await _firestore
          .collection('users')
          .doc(userId1)
          .collection('chats')
          .where('participants', arrayContains: userId2)
          .where('isGroup', isEqualTo: false)
          .limit(1)
          .get();

      if (existingChats.docs.isNotEmpty) {
        return existingChats.docs.first.id;
      }

      // Create new chat
      final participants = [userId1, userId2];
      final now = DateTime.now();

      final chatData = {
        'participants': participants,
        'isGroup': false,
        'createdAt': Timestamp.fromDate(now),
      };

      // Create chat in both users' chats subcollections
      final chatId = _firestore.collection('chats').doc().id;

      final batch = _firestore.batch();

      // Create in userId1's chats
      batch.set(
        _firestore
            .collection('users')
            .doc(userId1)
            .collection('chats')
            .doc(chatId),
        chatData,
      );

      // Create in userId2's chats
      batch.set(
        _firestore
            .collection('users')
            .doc(userId2)
            .collection('chats')
            .doc(chatId),
        chatData,
      );

      // Also create in top-level chats collection for queries
      batch.set(
        _firestore.collection('chats').doc(chatId),
        chatData,
      );

      await batch.commit();

      return chatId;
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
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('chats')
          .doc(chatId)
          .get();

      if (!doc.exists) return null;

      return Chat.fromJson(doc.data()!, chatId);
    } catch (e) {
      debugPrint('Failed to get chat: $e');
      return null;
    }
  }

  /// Get all chats for a user
  static Future<List<Chat>> getUserChats(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('chats')
          .orderBy('lastMessageAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Chat.fromJson(doc.data(), doc.id))
          .toList();
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

      final messageId = _firestore.collection('chats').doc().id;
      final now = DateTime.now();

      final messageData = {
        'senderId': userId,
        if (text != null) 'text': text,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (clothId != null) 'clothId': clothId,
        if (clothOwnerId != null) 'clothOwnerId': clothOwnerId,
        if (clothWardrobeId != null) 'clothWardrobeId': clothWardrobeId,
        'createdAt': Timestamp.fromDate(now),
        'seenBy': [userId],
      };

      // Get chat to find all participants
      final chat = await getChat(userId: userId, chatId: chatId);
      if (chat == null) {
        throw Exception('Chat not found');
      }

      // Create message in ALL participants' message subcollections
      // This ensures all participants can see all messages
      final batch = _firestore.batch();
      final previewText = text ?? (imageUrl != null ? '📷 Image' : '👕 Cloth');

      for (var participantId in chat.participants) {
        // Create message in each participant's messages subcollection
        batch.set(
          _firestore
              .collection('users')
              .doc(participantId)
              .collection('chats')
              .doc(chatId)
              .collection('messages')
              .doc(messageId),
          messageData,
        );

        // Update chat's lastMessage and lastMessageAt for each participant
        batch.update(
          _firestore
              .collection('users')
              .doc(participantId)
              .collection('chats')
              .doc(chatId),
          {
            'lastMessage': previewText,
            'lastMessageAt': Timestamp.fromDate(now),
          },
        );
      }

      // If sharing a cloth, add recipients to cloth's sharedWith array
      if (clothId != null && clothOwnerId != null && clothWardrobeId != null) {
        try {
          debugPrint('👕 ChatService: Updating sharedWith for cloth $clothId');
          debugPrint('   ownerId: $clothOwnerId');
          debugPrint('   participants: ${chat.participants}');
          
          // Get the cloth document to update sharedWith
          final clothRef = _firestore
              .collection('users')
              .doc(clothOwnerId)
              .collection('wardrobes')
              .doc(clothWardrobeId)
              .collection('clothes')
              .doc(clothId);

          // Get current sharedWith array
          final clothDoc = await clothRef.get();
          if (clothDoc.exists) {
            final clothData = clothDoc.data()!;
            final currentSharedWith = clothData['sharedWith'] as List<dynamic>? ?? [];
            final sharedWithList = List<String>.from(currentSharedWith.map((e) => e.toString()));
            
            debugPrint('   current sharedWith: $sharedWithList');

            // Add all participants (except the sender) to sharedWith
            bool hasChanges = false;
            for (var participantId in chat.participants) {
              if (participantId != userId && !sharedWithList.contains(participantId)) {
                sharedWithList.add(participantId);
                hasChanges = true;
                debugPrint('   Adding $participantId to sharedWith');
              }
            }

            if (hasChanges) {
              debugPrint('   Updating sharedWith to: $sharedWithList');
              
              // Update sharedWith in both subcollection and top-level collection
              batch.update(clothRef, {
                'sharedWith': sharedWithList,
                'updatedAt': FieldValue.serverTimestamp(),
              });

              // Also update top-level clothes collection
              batch.update(
                _firestore.collection('clothes').doc(clothId),
                {
                  'sharedWith': sharedWithList,
                  'updatedAt': FieldValue.serverTimestamp(),
                },
              );
              
              debugPrint('✅ ChatService: Successfully queued sharedWith update');
            } else {
              debugPrint('ℹ️ ChatService: No changes to sharedWith (all participants already added)');
            }
          } else {
            debugPrint('⚠️ ChatService: Cloth document not found, cannot update sharedWith');
          }
        } catch (e, stackTrace) {
          debugPrint('❌ ChatService: Failed to update cloth sharedWith: $e');
          debugPrint('   StackTrace: $stackTrace');
          // Don't fail the message send if this fails, but log the error
          // The user will still see the message, but might not be able to view the cloth
          // if permissions don't allow it
        }
      }

      // Commit all writes atomically
      try {
        await batch.commit();
        debugPrint('✅ ChatService: Batch commit successful');
        
        // Verify sharedWith was updated if we tried to update it
        if (clothId != null && clothOwnerId != null && clothWardrobeId != null) {
          try {
            final verifyDoc = await _firestore
                .collection('clothes')
                .doc(clothId)
                .get();
            if (verifyDoc.exists) {
              final verifyData = verifyDoc.data();
              debugPrint('🔍 ChatService: Verifying sharedWith update');
              debugPrint('   sharedWith after commit: ${verifyData?['sharedWith']}');
            }
          } catch (e) {
            debugPrint('⚠️ ChatService: Could not verify sharedWith update: $e');
          }
        }
      } catch (e, stackTrace) {
        debugPrint('❌ ChatService: Batch commit failed: $e');
        debugPrint('   StackTrace: $stackTrace');
        rethrow;
      }

      // Send push notifications to other participants if their app is in background
      // Skip the sender
      for (var participantId in chat.participants) {
        if (participantId != userId) {
          // Check if recipient's app is likely in foreground
          // If not, send push notification
          final isInForeground =
              await PushNotificationService.isUserAppInForeground(
                  participantId);

          if (!isInForeground) {
            // Get sender's profile for notification
            final senderProfile = await UserService.getUserProfile(userId);
            final senderName = senderProfile?.displayName ??
                (senderProfile?.username != null
                    ? '@${senderProfile!.username}'
                    : 'Someone');

            // Send push notification
            try {
              await PushNotificationService.sendChatMessageNotification(
                recipientUserId: participantId,
                senderUserId: userId,
                chatId: chatId,
                messageId: messageId,
                messageText: previewText,
                senderName: senderName,
              );
            } catch (e) {
              debugPrint('Failed to send push notification: $e');
              // Don't fail the message send if notification fails
            }
          }
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
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => ChatMessage.fromJson(doc.data(), doc.id))
          .toList()
          .reversed
          .toList(); // Reverse to show oldest first
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
    try {
      final batch = _firestore.batch();

      for (var messageId in messageIds) {
        final messageRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .doc(messageId);

        batch.update(messageRef, {
          'seenBy': FieldValue.arrayUnion([userId]),
        });
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Failed to mark messages as seen: $e');
    }
  }

  /// Delete message
  static Future<void> deleteMessage({
    required String userId,
    required String chatId,
    required String messageId,
  }) async {
    try {
      final messageDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .get();

      if (!messageDoc.exists) return;

      final message = ChatMessage.fromJson(messageDoc.data()!, messageId);

      // Only sender can delete
      if (message.senderId != userId) {
        throw Exception('Only message sender can delete');
      }

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .delete();
    } catch (e) {
      debugPrint('Failed to delete message: $e');
      rethrow;
    }
  }

  /// Stream messages for real-time updates
  static Stream<List<ChatMessage>> watchMessages({
    required String userId,
    required String chatId,
    int limit = 50,
  }) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromJson(doc.data(), doc.id))
            .toList()
            .reversed
            .toList());
  }

  /// Stream chats for real-time updates
  static Stream<List<Chat>> watchUserChats(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('chats')
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Chat.fromJson(doc.data(), doc.id))
            .toList());
  }

  /// Get unread message count for a specific chat
  static Future<int> getUnreadCount({
    required String userId,
    required String chatId,
  }) async {
    // Check if user is authenticated before making query
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null || currentUser.uid != userId) {
        // User is not authenticated, return 0
        return 0;
      }
    } catch (e) {
      // If auth check fails, don't make query
      return 0;
    }
    
    try {
      // Get all messages and filter client-side
      // Note: Firestore doesn't support isNotEqualTo, so we get all and filter
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .get();

      int unreadCount = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final senderId = data['senderId'] as String?;
        final seenBy = data['seenBy'] as List<dynamic>? ?? [];

        // Count only messages from others that haven't been seen by this user
        if (senderId != null &&
            senderId != userId &&
            !seenBy.contains(userId)) {
          unreadCount++;
        }
      }

      return unreadCount;
    } catch (e) {
      debugPrint('Failed to get unread count: $e');
      return 0;
    }
  }

  /// Get unread message counts for all chats
  static Future<Map<String, int>> getAllUnreadCounts(String userId) async {
    // Check if user is authenticated before making query
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null || currentUser.uid != userId) {
        // User is not authenticated, return empty map
        return {};
      }
    } catch (e) {
      // If auth check fails, don't make query
      return {};
    }
    
    try {
      final chatsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('chats')
          .get();

      final Map<String, int> unreadCounts = {};

      for (var chatDoc in chatsSnapshot.docs) {
        final chatId = chatDoc.id;
        final count = await getUnreadCount(userId: userId, chatId: chatId);
        if (count > 0) {
          unreadCounts[chatId] = count;
        }
      }

      return unreadCounts;
    } catch (e) {
      debugPrint('Failed to get all unread counts: $e');
      return {};
    }
  }
}
