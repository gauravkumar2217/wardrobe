import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/friend_provider.dart';
import 'chat_detail_screen.dart';
import '../../utils/main_shell_navigation.dart';

/// Chat list screen showing all user chats
class ChatListScreen extends StatefulWidget {
  /// When true, omit AppBar for embedding inside Community tabs.
  final bool embedded;

  const ChatListScreen({super.key, this.embedded = false});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadChats();
    });
  }

  Future<void> _loadChats() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final friendProvider = Provider.of<FriendProvider>(context, listen: false);

    if (authProvider.user != null && authProvider.isAuthenticated) {
      final uid = authProvider.user!.uid;
      // Friends list needed to hide chats with non-friends (client fallback).
      if (friendProvider.friends.isEmpty) {
        await friendProvider.loadFriends(uid);
      }
      await chatProvider.loadChats(uid);
      chatProvider.watchChats(uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final friendProvider = Provider.of<FriendProvider>(context);
    final currentUid = authProvider.user?.uid;
    final friendIds = friendProvider.friends.toSet();

    // Hide 1:1 chats where the other person is no longer a friend.
    final visibleChats = currentUid == null
        ? chatProvider.chats
        : chatProvider.chats.where((chat) {
            if (chat.isGroup) return true;
            final other = chat.getOtherParticipant(currentUid);
            if (other == null || other.isEmpty) return false;
            return friendIds.contains(other);
          }).toList();

    return Scaffold(
      appBar: widget.embedded
          ? AppBar(
              title: const Text('Chats'),
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              elevation: 0,
              automaticallyImplyLeading: false,
            )
          : AppBar(
              title: const Text('Messages'),
              backgroundColor: const Color(0xFF043915),
              foregroundColor: Colors.white,
              automaticallyImplyLeading: false,
              leading: mainShellAppBarLeading(context),
            ),
      body: chatProvider.isLoading && visibleChats.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : chatProvider.errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text(
                        chatProvider.errorMessage!,
                        style:
                            const TextStyle(fontSize: 14, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          chatProvider.clearError();
                          _loadChats();
                        },
                        icon: const Icon(Icons.refresh, size: 16),
                        label:
                            const Text('Retry', style: TextStyle(fontSize: 14)),
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
              : visibleChats.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline,
                              size: 48, color: Colors.grey),
                          SizedBox(height: 12),
                          Text(
                            'No chats yet',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Start a conversation with a friend!',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        if (currentUid != null) {
                          await friendProvider.loadFriends(currentUid);
                          await chatProvider.loadChats(currentUid);
                        }
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: visibleChats.length,
                        itemBuilder: (context, index) {
                          final chat = visibleChats[index];
                          var displayName = currentUid != null
                              ? chat.displayNameFor(currentUid)
                              : 'Chat';
                          if ((displayName == 'Chat' || displayName.isEmpty) &&
                              currentUid != null) {
                            final other = chat.getOtherParticipant(currentUid);
                            final fp = other != null
                                ? friendProvider.profileFor(other)
                                : null;
                            if (fp?.displayName != null &&
                                fp!.displayName!.trim().isNotEmpty) {
                              displayName = fp.displayName!.trim();
                            } else if (fp?.username != null &&
                                fp!.username!.trim().isNotEmpty) {
                              displayName = '@${fp.username!.trim()}';
                            }
                          }
                          final avatarLetter = displayName.isNotEmpty
                              ? displayName.substring(0, 1).toUpperCase()
                              : '?';
                          final unreadCount =
                              chatProvider.getUnreadCount(chat.id);

                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            leading: CircleAvatar(
                              radius: 22,
                              backgroundColor: const Color(0xFF043915),
                              child: Text(
                                avatarLetter,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    displayName,
                                    style: TextStyle(
                                      fontWeight: unreadCount > 0
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                if (unreadCount > 0)
                                  Container(
                                    margin: const EdgeInsets.only(left: 6),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF043915),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      unreadCount > 99 ? '99+' : '$unreadCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Text(
                              chat.lastMessage ?? 'No messages yet',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: unreadCount > 0
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                                fontSize: 11,
                              ),
                            ),
                            trailing: chat.lastMessageAt != null
                                ? Text(
                                    _formatTime(chat.lastMessageAt!),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[600],
                                      fontWeight: unreadCount > 0
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  )
                                : null,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatDetailScreen(chat: chat),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
