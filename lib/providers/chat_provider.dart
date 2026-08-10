import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/chat.dart';
import '../services/chat_service.dart';
import '../services/laravel_auth_service.dart';

/// Chat provider for managing chats and messages
class ChatProvider with ChangeNotifier {
  List<Chat> _chats = [];
  List<ChatMessage> _messages = [];
  Chat? _currentChat;
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, int> _unreadCounts = {}; // chatId -> unread count
  StreamSubscription<List<Chat>>? _chatsSubscription;
  StreamSubscription<List<ChatMessage>>? _messagesSubscription;

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
    // Check authentication before loading
    try {
      final currentUserId = await LaravelAuthService.getCurrentUserId();
      if (currentUserId == null || currentUserId != userId) {
        // User is not authenticated, clear chats and return
        _chats = [];
        _errorMessage = null;
        _isLoading = false;
        notifyListeners();
        return;
      }
    } catch (e) {
      // If auth check fails, don't load
      _chats = [];
      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
      return;
    }
    
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _chats = await ChatService.getUserChats(userId);
      // Unread counts come with the lightweight chat list — no N+1 message fetches.
      _unreadCounts = {
        for (final chat in _chats)
          if (chat.unreadCount > 0) chat.id: chat.unreadCount,
      };
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
    // Cancel existing subscription
    _chatsSubscription?.cancel();
    
    final currentUserId = LaravelAuthService.memoryUserId;
    if (currentUserId == null || currentUserId != userId) {
      _chats = [];
      _unreadCounts = {};
      notifyListeners();
      return;
    }

    _chatsSubscription = ChatService.watchUserChats(userId).listen((chats) {
      try {
        if (LaravelAuthService.memoryUserId != userId) {
          // User signed out, cancel subscription
          _chatsSubscription?.cancel();
          _chats = [];
          _unreadCounts = {};
          notifyListeners();
          return;
        }
      } catch (e) {
        // If auth check fails, cancel subscription
        _chatsSubscription?.cancel();
        return;
      }
      
      _chats = chats;
      _unreadCounts = {
        for (final chat in chats)
          if (chat.unreadCount > 0) chat.id: chat.unreadCount,
      };
      // Keep calculated count for open chat if present
      if (_currentChat != null &&
          _unreadCounts.containsKey(_currentChat!.id) == false) {
        // no-op; open chat uses message-based count via mark seen
      }
      _errorMessage = null;
      notifyListeners();
    }, onError: (error) {
      _errorMessage = 'Failed to watch chats: ${error.toString()}';
      notifyListeners();
    });
  }
  
  /// Clean up all subscriptions and reset state
  void cleanup() {
    _chatsSubscription?.cancel();
    _chatsSubscription = null;
    _messagesSubscription?.cancel();
    _messagesSubscription = null;
    _chats = [];
    _messages = [];
    _currentChat = null;
    _unreadCounts = {};
    _errorMessage = null;
    notifyListeners();
  }

  /// Refresh unread counts for all chats from the lightweight chat list payload.
  Future<void> _refreshUnreadCounts(String userId) async {
    try {
      final currentUserId = await LaravelAuthService.getCurrentUserId();
      if (currentUserId == null || currentUserId != userId) {
        _unreadCounts = {};
        notifyListeners();
        return;
      }
    } catch (e) {
      return;
    }

    try {
      final chats = _chats.isNotEmpty
          ? _chats
          : await ChatService.getUserChats(userId);
      final allUnreadCounts = <String, int>{
        for (final chat in chats)
          if (chat.unreadCount > 0) chat.id: chat.unreadCount,
      };

      if (_currentChat != null && _unreadCounts.containsKey(_currentChat!.id)) {
        allUnreadCounts[_currentChat!.id] = _unreadCounts[_currentChat!.id]!;
      }

      _unreadCounts = allUnreadCounts;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to refresh unread counts: $e');
    }
  }

  /// Load unread counts for all chats
  /// Only loads if user is authenticated
  Future<void> loadUnreadCounts(String userId) async {
    // Check authentication first
    try {
      final currentUserId = await LaravelAuthService.getCurrentUserId();
      if (currentUserId == null || currentUserId != userId) {
        // User is not authenticated, clear counts and return
        _unreadCounts = {};
        notifyListeners();
        return;
      }
    } catch (e) {
      // If auth check fails, don't make queries
      return;
    }
    
    // Only load if we have chats loaded
    if (_chats.isEmpty) {
      // Try to load chats first
      try {
        await loadChats(userId);
      } catch (e) {
        debugPrint('Failed to load chats before getting counts: $e');
        return;
      }
    }
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
    // Avoid notifyListeners during widget build/mount.
    scheduleMicrotask(() {
      notifyListeners();
    });

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
    // Cancel existing subscription
    _messagesSubscription?.cancel();
    
    final currentUserId = LaravelAuthService.memoryUserId;
    if (currentUserId == null || currentUserId != userId) {
      _messages = [];
      notifyListeners();
      return;
    }

    _messagesSubscription = ChatService.watchMessages(userId: userId, chatId: chatId).listen((messages) {
      try {
        if (LaravelAuthService.memoryUserId != userId) {
          // User signed out, cancel subscription
          _messagesSubscription?.cancel();
          _messages = [];
          notifyListeners();
          return;
        }
      } catch (e) {
        // If auth check fails, cancel subscription
        _messagesSubscription?.cancel();
        return;
      }

      // Keep optimistic local messages until the server list includes them.
      final pendingLocal = _messages
          .where((m) => m.id.startsWith('local_'))
          .toList();
      _messages = messages;
      for (final local in pendingLocal) {
        final arrived = _messages.any((m) =>
            m.senderId == local.senderId &&
            m.text == local.text &&
            m.createdAt.difference(local.createdAt).abs() <
                const Duration(minutes: 2));
        if (!arrived) {
          _messages = [..._messages, local];
        }
      }
      _errorMessage = null;
      // Calculate unread count from loaded messages (no Firestore query needed)
      _calculateUnreadCountFromMessages(userId: userId, chatId: chatId);
      notifyListeners();
    }, onError: (error) {
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


  /// Send text message (optimistic — shows instantly, syncs in background).
  Future<bool> sendTextMessage({
    required String userId,
    required String chatId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;

    final tempId = 'local_${DateTime.now().microsecondsSinceEpoch}';
    final optimistic = ChatMessage(
      id: tempId,
      senderId: userId,
      text: trimmed,
      createdAt: DateTime.now(),
      seenBy: [userId],
    );

    _messages = [..._messages, optimistic];
    _errorMessage = null;
    notifyListeners();

    try {
      final messageId = await ChatService.sendMessage(
        userId: userId,
        chatId: chatId,
        text: trimmed,
      );

      final idx = _messages.indexWhere((m) => m.id == tempId);
      if (idx != -1) {
        final updated = List<ChatMessage>.from(_messages);
        updated[idx] = ChatMessage(
          id: messageId.isNotEmpty ? messageId : tempId,
          senderId: userId,
          text: trimmed,
          createdAt: optimistic.createdAt,
          seenBy: [userId],
        );
        _messages = updated;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _messages = _messages.where((m) => m.id != tempId).toList();
      _errorMessage = 'Failed to send message: ${e.toString()}';
      notifyListeners();
      return false;
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
    required String clothOwnerId,
    required String clothWardrobeId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await ChatService.sendMessage(
        userId: userId,
        chatId: chatId,
        clothId: clothId,
        clothOwnerId: clothOwnerId,
        clothWardrobeId: clothWardrobeId,
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
