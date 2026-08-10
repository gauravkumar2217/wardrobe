import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/chat.dart';
import '../../models/report.dart';
import '../../providers/chat_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/chat_bubble.dart';
import '../../services/report_service.dart';
import '../../services/block_service.dart';
import '../cloth/cloth_detail_screen.dart';

/// Chat detail screen for a specific chat
class ChatDetailScreen extends StatefulWidget {
  final Chat chat;

  const ChatDetailScreen({
    super.key,
    required this.chat,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<String> _blockedUserIds = [];

  @override
  void initState() {
    super.initState();
    // Defer provider updates — calling notifyListeners during mount/build crashes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadMessages();
      _loadBlockedUsers();
    });
  }

  Future<void> _loadBlockedUsers() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user == null) return;

    // Blocks are Laravel-only now (no Firestore).
    final blockedIds =
        await BlockService.getBlockedUserIds(authProvider.user!.uid);
    if (!mounted) return;
    setState(() {
      _blockedUserIds = blockedIds;
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _loadMessages() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    if (authProvider.user != null) {
      chatProvider.loadMessages(
        userId: authProvider.user!.uid,
        chatId: widget.chat.id,
      );
      chatProvider.watchMessages(
        userId: authProvider.user!.uid,
        chatId: widget.chat.id,
      );

      // Mark all messages as seen when opening the chat
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted && authProvider.user != null) {
          await chatProvider.markAllMessagesAsSeen(
            userId: authProvider.user!.uid,
            chatId: widget.chat.id,
          );
        }
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _handleClothTap(ChatMessage message) async {
    if (message.clothId == null) {
      debugPrint('❌ ChatDetailScreen: clothId is null');
      return;
    }

    debugPrint('👆 ChatDetailScreen: Cloth tapped');
    debugPrint('   clothId: ${message.clothId}');
    debugPrint('   clothOwnerId: ${message.clothOwnerId}');
    debugPrint('   clothWardrobeId: ${message.clothWardrobeId}');

    // Navigate to cloth detail screen if we have all required data
    if (message.clothOwnerId != null && message.clothWardrobeId != null) {
      debugPrint('✅ ChatDetailScreen: Navigating to ClothDetailScreen');
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final isOwner = authProvider.user?.uid == message.clothOwnerId;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ClothDetailScreen(
            clothId: message.clothId!,
            ownerId: message.clothOwnerId!,
            wardrobeId: message.clothWardrobeId!,
            isShared: true, // Mark as shared since it came from DM
            isOwner: isOwner,
          ),
        ),
      ).then((_) {
        debugPrint('📱 ChatDetailScreen: Returned from ClothDetailScreen');
      });
    } else {
      debugPrint('❌ ChatDetailScreen: Missing cloth information');
      debugPrint('   clothOwnerId: ${message.clothOwnerId}');
      debugPrint('   clothWardrobeId: ${message.clothWardrobeId}');
      // Fallback: show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to view cloth: missing information'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showBlockDialog(String userId) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User'),
        content: const Text(
          'Are you sure you want to block this user? You will no longer see their messages, and they will be removed from your feed immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Block'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await BlockService.blockUser(
          blockerId: authProvider.user!.uid,
          blockedUserId: userId,
          reason: 'Blocked from chat screen',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'User blocked. Their messages have been removed from your feed.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context); // Close chat screen
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to block user: $e')),
          );
        }
      }
    }
  }

  Future<void> _showReportUserDialog(String userId) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user == null) return;

    final reasons = ReportService.getReportReasons();
    String? selectedReason;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Report User'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Why are you reporting this user?'),
              const SizedBox(height: 16),
              ...reasons.map((reason) => RadioListTile<String>(
                    title: Text(reason),
                    value: reason,
                    groupValue: selectedReason,
                    onChanged: (value) =>
                        setState(() => selectedReason = value),
                  )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedReason != null
                  ? () => Navigator.pop(context, true)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF043915),
                foregroundColor: Colors.white,
              ),
              child: const Text('Report'),
            ),
          ],
        ),
      ),
    );

    if (result == true && selectedReason != null && mounted) {
      try {
        await ReportService.createReport(
          reporterId: authProvider.user!.uid,
          reportedUserId: userId,
          contentType: ReportContentType.user,
          reason: selectedReason!,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'User reported. Thank you for helping keep our community safe.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to report user: $e')),
          );
        }
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    if (authProvider.user == null) return;

    // Clear immediately so typing feels instant.
    _messageController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToBottom();
    });

    final success = await chatProvider.sendTextMessage(
      userId: authProvider.user!.uid,
      chatId: widget.chat.id,
      text: text,
    );

    if (mounted) {
      if (success) {
        _scrollToBottom();
      } else {
        _messageController.text = text;
        _messageController.selection = TextSelection.collapsed(
          offset: text.length,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(chatProvider.errorMessage ?? 'Failed to send message'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final currentUid = authProvider.user?.uid ?? '';
    final otherParticipantId = widget.chat.getOtherParticipant(currentUid);
    final peerName = currentUid.isNotEmpty
        ? widget.chat.displayNameFor(currentUid)
        : 'Chat';
    final peerLetter =
        peerName.isNotEmpty ? peerName.substring(0, 1).toUpperCase() : '?';

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: widget.chat.isGroup
            ? const Text('Group Chat', style: TextStyle(fontSize: 14))
            : Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                    child: Text(
                      peerLetter,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      peerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
        backgroundColor: const Color(0xFF043915),
        foregroundColor: Colors.white,
        actions: widget.chat.isGroup
            ? null
            : [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'block' && otherParticipantId != null) {
                      _showBlockDialog(otherParticipantId);
                    } else if (value == 'report' &&
                        otherParticipantId != null) {
                      _showReportUserDialog(otherParticipantId);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'report',
                      child: Row(
                        children: [
                          Icon(Icons.flag_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Report User'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'block',
                      child: Row(
                        children: [
                          Icon(Icons.block, size: 18),
                          SizedBox(width: 8),
                          Text('Block User'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: chatProvider.isLoading && chatProvider.messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : chatProvider.errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 48, color: Colors.red),
                            const SizedBox(height: 12),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              child: Text(
                                chatProvider.errorMessage!,
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () {
                                chatProvider.clearError();
                                _loadMessages();
                              },
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Retry',
                                  style: TextStyle(fontSize: 14)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF043915),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      )
                    : chatProvider.messages
                            .where((msg) =>
                                !_blockedUserIds.contains(msg.senderId))
                            .isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.chat_bubble_outline,
                                    size: 48, color: Colors.grey),
                                SizedBox(height: 12),
                                Text(
                                  'No messages yet',
                                  style: TextStyle(
                                      fontSize: 13, color: Colors.grey),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Start the conversation!',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            itemCount: chatProvider.messages
                                .where((msg) =>
                                    !_blockedUserIds.contains(msg.senderId))
                                .length,
                            itemBuilder: (context, index) {
                              final filteredMessages = chatProvider.messages
                                  .where((msg) =>
                                      !_blockedUserIds.contains(msg.senderId))
                                  .toList();
                              final message = filteredMessages[index];
                              return GestureDetector(
                                onTap: message.isClothShare &&
                                        message.clothId != null
                                    ? () => _handleClothTap(message)
                                    : null,
                                child: ChatBubble(
                                  message: message,
                                  currentUserId: authProvider.user?.uid ?? '',
                                ),
                              );
                            },
                          ),
          ),
          // Message input — SafeArea so bar clears home indicator (e.g. from Friends → chat)
          SafeArea(
            top: false,
            minimum: EdgeInsets.zero,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.2),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: const TextStyle(fontSize: 13),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.send,
                        color: Color(0xFF043915), size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
