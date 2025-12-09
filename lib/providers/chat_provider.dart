import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
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
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.uid != userId) {
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
    
    // Check authentication before setting up stream
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.uid != userId) {
        // User is not authenticated, don't set up stream
        _chats = [];
        _unreadCounts = {};
        notifyListeners();
        return;
      }
    } catch (e) {
      // If auth check fails, don't set up stream
      return;
    }
    
    _chatsSubscription = ChatService.watchUserChats(userId).listen((chats) {
      // Check authentication in stream callback
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null || currentUser.uid != userId) {
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
      _errorMessage = null;
      // Refresh unread counts when chats update
      _refreshUnreadCounts(userId);
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

  /// Refresh unread counts for all chats
  /// Note: This is only called when needed (e.g., initial load or chat list update)
  /// For active chats, we calculate from loaded messages instead
  /// Uses simple get() queries instead of snapshots() for better performance
  Future<void> _refreshUnreadCounts(String userId) async {
    // Check authentication before making any queries
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.uid != userId) {
        // User is not authenticated, clear counts and return
        _unreadCounts = {};
        notifyListeners();
        return;
      }
    } catch (e) {
      // If auth check fails, don't make queries
      return;
    }
    
    try {
      // Use simple get() queries like cloth detail screen does
      // This is more efficient and doesn't require real-time listeners
      final allUnreadCounts = <String, int>{};
      
      // Get all chats first
      final chats = await ChatService.getUserChats(userId);
      
      // For each chat, get unread count using simple get() query
      for (var chat in chats) {
        try {
          final count = await ChatService.getUnreadCount(
            userId: userId,
            chatId: chat.id,
          );
          if (count > 0) {
            allUnreadCounts[chat.id] = count;
          }
        } catch (e) {
          // Skip if permission denied (user might have signed out)
          debugPrint('Failed to get unread count for chat ${chat.id}: $e');
        }
      }
      
      // Merge with calculated counts from loaded messages
      if (_currentChat != null && _unreadCounts.containsKey(_currentChat!.id)) {
        // Keep calculated count for current chat
        allUnreadCounts[_currentChat!.id] = _unreadCounts[_currentChat!.id]!;
      }
      
      _unreadCounts = allUnreadCounts;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to refresh unread counts: $e');
      // Don't throw - just log the error
    }
  }

  /// Load unread counts for all chats
  /// Only loads if user is authenticated
  Future<void> loadUnreadCounts(String userId) async {
    // Check authentication first
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.uid != userId) {
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
    // Cancel existing subscription
    _messagesSubscription?.cancel();
    
    // Check authentication before setting up stream
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.uid != userId) {
        // User is not authenticated, don't set up stream
        _messages = [];
        notifyListeners();
        return;
      }
    } catch (e) {
      // If auth check fails, don't set up stream
      return;
    }
    
    _messagesSubscription = ChatService.watchMessages(userId: userId, chatId: chatId).listen((messages) {
      // Check authentication in stream callback
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null || currentUser.uid != userId) {
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
      
      _messages = messages;
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
