import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_profile.dart';
import '../../services/user_service.dart';
import 'chat_detail_screen.dart';

/// Chat list screen showing all user chats
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final Map<String, UserProfile?> _participantProfiles = {};

  @override
  void initState() {
    super.initState();
    // Defer loading until after build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadChats();
    });
  }

  Future<void> _loadParticipantProfile(String userId) async {
    if (_participantProfiles.containsKey(userId)) return;

    try {
      final profile = await UserService.getUserProfile(userId);
      if (mounted) {
        setState(() {
          _participantProfiles[userId] = profile;
        });
      }
    } catch (e) {
      // Silently fail - will show fallback UI
    }
  }

  void _loadChats() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    if (authProvider.user != null) {
      chatProvider.loadChats(authProvider.user!.uid);
      // Only watch chats if user is authenticated
      if (authProvider.isAuthenticated && authProvider.user != null) {
        chatProvider.watchChats(authProvider.user!.uid);
      }
      // Load unread counts
      // Only load unread counts if user is authenticated
      if (authProvider.isAuthenticated && authProvider.user != null) {
        chatProvider.loadUnreadCounts(authProvider.user!.uid).catchError((e) {
          // Silently handle errors (user might have signed out)
          debugPrint('Failed to load unread counts: $e');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    // Load profiles for all chat participants
    if (authProvider.user != null) {
      for (var chat in chatProvider.chats) {
        if (!chat.isGroup) {
          final otherParticipantId = chat.getOtherParticipant(authProvider.user!.uid);
          if (otherParticipantId != null) {
            _loadParticipantProfile(otherParticipantId);
          }
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
      ),
      body: chatProvider.isLoading && chatProvider.chats.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : chatProvider.errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        chatProvider.errorMessage!,
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          chatProvider.clearError();
                          _loadChats();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : chatProvider.chats.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No chats yet',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Start a conversation with a friend!',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        _loadChats();
                        await Future.delayed(const Duration(milliseconds: 500));
                      },
                      child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: chatProvider.chats.length,
                  itemBuilder: (context, index) {
                    final chat = chatProvider.chats[index];
                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                    
                    // Get other participant for non-group chats
                    String? otherParticipantId;
                    UserProfile? otherParticipantProfile;
                    
                    if (!chat.isGroup && authProvider.user != null) {
                      otherParticipantId = chat.getOtherParticipant(authProvider.user!.uid);
                      if (otherParticipantId != null) {
                        otherParticipantProfile = _participantProfiles[otherParticipantId];
                        // Trigger profile load if not already loaded
                        _loadParticipantProfile(otherParticipantId);
                      }
                    }

                    // Determine display name and avatar
                    String displayName;
                    String? photoUrl;
                    String avatarLetter;

                    if (chat.isGroup) {
                      displayName = 'Group Chat';
                      avatarLetter = 'G';
                    } else if (otherParticipantProfile != null) {
                      displayName = otherParticipantProfile.displayName ?? 
                                   (otherParticipantProfile.username != null 
                                       ? '@${otherParticipantProfile.username}' 
                                       : 'Chat');
                      photoUrl = otherParticipantProfile.photoUrl;
                      avatarLetter = otherParticipantProfile.displayName?.substring(0, 1).toUpperCase() ?? 
                                   (otherParticipantId != null && otherParticipantId.isNotEmpty 
                                       ? otherParticipantId.substring(0, 1).toUpperCase() 
                                       : '?');
                    } else {
                      displayName = 'Chat';
                      avatarLetter = otherParticipantId != null && otherParticipantId.isNotEmpty
                          ? otherParticipantId.substring(0, 1).toUpperCase()
                          : '?';
                    }

                    final unreadCount = chatProvider.getUnreadCount(chat.id);

                    return ListTile(
                      leading: CircleAvatar(
                        radius: 28,
                        backgroundColor: const Color(0xFF7C3AED),
                        backgroundImage: photoUrl != null
                            ? NetworkImage(photoUrl)
                            : null,
                        child: photoUrl == null
                            ? Text(
                                avatarLetter,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
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
                              ),
                            ),
                          ),
                          if (unreadCount > 0)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C3AED),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                unreadCount > 99 ? '99+' : '$unreadCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
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
                        ),
                      ),
                      trailing: chat.lastMessageAt != null
                          ? Text(
                              _formatTime(chat.lastMessageAt!),
                              style: TextStyle(
                                fontSize: 12,
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

