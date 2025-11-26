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

  List<Chat> get chats => _chats;
  List<ChatMessage> get messages => _messages;
  Chat? get currentChat => _currentChat;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

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
      notifyListeners();
    }).onError((error) {
      _errorMessage = 'Failed to watch chats: ${error.toString()}';
      notifyListeners();
    });
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
      notifyListeners();
    }).onError((error) {
      _errorMessage = 'Failed to watch messages: ${error.toString()}';
      notifyListeners();
    });
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
    } catch (e) {
      debugPrint('Failed to mark messages as seen: $e');
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
