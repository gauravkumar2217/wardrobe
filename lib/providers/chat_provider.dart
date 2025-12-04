import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/chat.dart';
import '../services/chat_service.dart';

/// Chat provider for managing chats and messages
class ChatProvider with ChangeNotifier {
  List<Chat> _chats = [];
  List<ChatMessage> _messages = [];
  Chat? _currentChat;
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, int> _unreadCounts = {}; // chatId -> unread count

  List<Chat> get chats => _chats;
  List<ChatMessage> get messages => _messages;
  Chat? get currentChat => _currentChat;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, int> get unreadCounts => _unreadCounts;
  
  /// Get total unread count across all chats
  int get totalUnreadCount {
    return _unreadCounts.values.fold(0, (sum, count) => sum + count);
  }
  
  /// Get unread count for a specific chat
  int getUnreadCount(String chatId) {
    return _unreadCounts[chatId] ?? 0;
  }

  /// Load chats for a user
  Future<void> loadChats(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _chats = await ChatService.getUserChats(userId);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load chats: ${e.toString()}';
      debugPrint('Error loading chats: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Watch chats for real-time updates
  void watchChats(String userId) {
    ChatService.watchUserChats(userId).listen((chats) {
      _chats = chats;
      _errorMessage = null;
      // Refresh unread counts when chats update
      _refreshUnreadCounts(userId);
      notifyListeners();
    }).onError((error) {
      _errorMessage = 'Failed to watch chats: ${error.toString()}';
      notifyListeners();
    });
  }

  /// Refresh unread counts for all chats
  /// Note: This is only called when needed (e.g., initial load or chat list update)
  /// For active chats, we calculate from loaded messages instead
  Future<void> _refreshUnreadCounts(String userId) async {
    try {
      // Only refresh counts for chats that aren't currently loaded
      // For the current chat, use calculated count from messages
      final allUnreadCounts = await ChatService.getAllUnreadCounts(userId);
      
      // Merge with calculated counts from loaded messages
      if (_currentChat != null && _unreadCounts.containsKey(_currentChat!.id)) {
        // Keep calculated count for current chat
        allUnreadCounts[_currentChat!.id] = _unreadCounts[_currentChat!.id]!;
      }
      
      _unreadCounts = allUnreadCounts;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to refresh unread counts: $e');
    }
  }

  /// Load unread counts for all chats
  Future<void> loadUnreadCounts(String userId) async {
    await _refreshUnreadCounts(userId);
  }

  /// Get or create chat between two users
  Future<String> getOrCreateChat({
    required String userId1,
    required String userId2,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final chatId = await ChatService.getOrCreateChat(
        userId1: userId1,
        userId2: userId2,
      );
      _errorMessage = null;
      return chatId;
    } catch (e) {
      _errorMessage = 'Failed to create/get chat: ${e.toString()}';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load messages for a chat
  Future<void> loadMessages({
    required String userId,
    required String chatId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentChat = await ChatService.getChat(userId: userId, chatId: chatId);
      _messages = await ChatService.getMessages(
        userId: userId,
        chatId: chatId,
      );
      // Calculate unread count from loaded messages (no extra query needed)
      _calculateUnreadCountFromMessages(userId: userId, chatId: chatId);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load messages: ${e.toString()}';
      debugPrint('Error loading messages: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Watch messages for real-time updates
  void watchMessages({
    required String userId,
    required String chatId,
  }) {
    ChatService.watchMessages(userId: userId, chatId: chatId).listen((messages) {
      _messages = messages;
      _errorMessage = null;
      // Calculate unread count from loaded messages (no Firestore query needed)
      _calculateUnreadCountFromMessages(userId: userId, chatId: chatId);
      notifyListeners();
    }).onError((error) {
      _errorMessage = 'Failed to watch messages: ${error.toString()}';
      notifyListeners();
    });
  }

  /// Calculate unread count from already-loaded messages (optimized - no Firestore query)
  void _calculateUnreadCountFromMessages({
    required String userId,
    required String chatId,
  }) {
    // Calculate from _messages instead of querying Firestore
    final unreadCount = _messages
        .where((msg) => msg.senderId != userId && !msg.isSeenBy(userId))
        .length;
    
    if (unreadCount > 0) {
      _unreadCounts[chatId] = unreadCount;
    } else {
      _unreadCounts.remove(chatId);
    }
  }


  /// Send text message
  Future<bool> sendTextMessage({
    required String userId,
    required String chatId,
    required String text,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await ChatService.sendMessage(
        userId: userId,
        chatId: chatId,
        text: text,
      );
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = 'Failed to send message: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Send image message
  Future<bool> sendImageMessage({
    required String userId,
    required String chatId,
    required String imageUrl,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await ChatService.sendMessage(
        userId: userId,
        chatId: chatId,
        imageUrl: imageUrl,
      );
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = 'Failed to send image: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Send cloth share message
  Future<bool> sendClothShare({
    required String userId,
    required String chatId,
    required String clothId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await ChatService.sendMessage(
        userId: userId,
        chatId: chatId,
        clothId: clothId,
      );
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = 'Failed to share cloth: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Mark messages as seen
  Future<void> markMessagesAsSeen({
    required String userId,
    required String chatId,
    required List<String> messageIds,
  }) async {
    try {
      await ChatService.markMessagesAsSeen(
        userId: userId,
        chatId: chatId,
        messageIds: messageIds,
      );
      // Recalculate unread count from loaded messages (no query needed)
      _calculateUnreadCountFromMessages(userId: userId, chatId: chatId);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to mark messages as seen: $e');
    }
  }

  /// Mark all messages in current chat as seen
  Future<void> markAllMessagesAsSeen({
    required String userId,
    required String chatId,
  }) async {
    try {
      // Get all unread messages
      final unreadMessages = _messages
          .where((msg) => msg.senderId != userId && !msg.isSeenBy(userId))
          .map((msg) => msg.id)
          .toList();

      if (unreadMessages.isNotEmpty) {
        await markMessagesAsSeen(
          userId: userId,
          chatId: chatId,
          messageIds: unreadMessages,
        );
      }
    } catch (e) {
      debugPrint('Failed to mark all messages as seen: $e');
    }
  }

  /// Delete message
  Future<bool> deleteMessage({
    required String userId,
    required String chatId,
    required String messageId,
  }) async {
    try {
      await ChatService.deleteMessage(
        userId: userId,
        chatId: chatId,
        messageId: messageId,
      );
      _messages.removeWhere((m) => m.id == messageId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete message: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Set current chat
  void setCurrentChat(Chat? chat) {
    _currentChat = chat;
    if (chat == null) {
      _messages = [];
    }
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
