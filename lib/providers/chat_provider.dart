import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import '../services/ai_chat_service.dart';

class ChatProvider with ChangeNotifier {
  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _currentChatId;

  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get currentChatId => _currentChatId;

  /// Send a message and get AI response
  Future<void> sendMessage(String userId, String userMessage) async {
    if (userMessage.trim().isEmpty) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Add user message
      final userMsg = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: 'user',
        content: userMessage.trim(),
        timestamp: DateTime.now(),
      );
      _messages.add(userMsg);
      notifyListeners();

      // Save user message to Firestore
      await _saveMessage(userId, userMsg);

      // Get AI response
      final aiResponse = await AIChatService.getResponse(
        userMessage,
        _messages.where((m) => m.id != userMsg.id).toList(),
        userId,
      );

      // Add AI response
      final aiMsg = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: 'assistant',
        content: aiResponse,
        timestamp: DateTime.now(),
      );
      _messages.add(aiMsg);
      notifyListeners();

      // Save AI message to Firestore
      await _saveMessage(userId, aiMsg);

      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to get response: ${e.toString()}';
      if (kDebugMode) {
        debugPrint('Chat error: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load chat history from Firestore
  Future<void> loadChatHistory(String userId, {String? chatId}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final chatIdToUse = chatId ?? _currentChatId ?? _getOrCreateChatId(userId);
      _currentChatId = chatIdToUse;

      final snapshot = await FirebaseFirestore.instance
          .collection('users/$userId/chats/$chatIdToUse/messages')
          .orderBy('timestamp', descending: false)
          .get();

      _messages = snapshot.docs
          .map((doc) => ChatMessage.fromJson(doc.data(), doc.id))
          .toList();

      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load chat history: ${e.toString()}';
      if (kDebugMode) {
        debugPrint('Error loading chat: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Watch chat messages for real-time updates
  void watchChat(String userId, {String? chatId}) {
    final chatIdToUse = chatId ?? _currentChatId ?? _getOrCreateChatId(userId);
    _currentChatId = chatIdToUse;

    FirebaseFirestore.instance
        .collection('users/$userId/chats/$chatIdToUse/messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen((snapshot) {
      _messages = snapshot.docs
          .map((doc) => ChatMessage.fromJson(doc.data(), doc.id))
          .toList();
      notifyListeners();
    });
  }

  /// Save message to Firestore
  Future<void> _saveMessage(String userId, ChatMessage message) async {
    final chatId = _currentChatId ?? _getOrCreateChatId(userId);
    _currentChatId = chatId;

    await FirebaseFirestore.instance
        .collection('users/$userId/chats/$chatId/messages')
        .doc(message.id)
        .set(message.toJson());

    // Update chat metadata
    await FirebaseFirestore.instance
        .collection('users/$userId/chats')
        .doc(chatId)
        .set({
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Get or create a chat ID
  String _getOrCreateChatId(String userId) {
    if (_currentChatId != null) {
      return _currentChatId!;
    }
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// Clear messages
  void clearMessages() {
    _messages = [];
    _currentChatId = null;
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

