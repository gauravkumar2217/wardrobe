import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/friend_provider.dart';
import '../../services/chat_service.dart';
import '../../models/friend_request.dart';
import '../friends/search_users_screen.dart';
import '../chat/chat_detail_screen.dart';
import '../../utils/main_shell_navigation.dart';

/// Friends list screen
class FriendsListScreen extends StatefulWidget {
  /// When true, omit AppBar for embedding inside Community tabs.
  final bool embedded;

  const FriendsListScreen({super.key, this.embedded = false});

  @override
  State<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends State<FriendsListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFriends();
      _loadFriendRequests();
    });
  }

  Future<void> _loadFriends() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final friendProvider = Provider.of<FriendProvider>(context, listen: false);

    if (authProvider.user != null && authProvider.isAuthenticated) {
      await friendProvider.loadFriends(authProvider.user!.uid);
      // Pull-to-refresh + slower background poll only — avoid aggressive reload
      friendProvider.watchFriends(authProvider.user!.uid);
    }
  }

  Future<void> _loadFriendRequests() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final friendProvider = Provider.of<FriendProvider>(context, listen: false);

    if (authProvider.user != null && authProvider.isAuthenticated) {
      await friendProvider.loadFriendRequests(authProvider.user!.uid);
      friendProvider.watchFriendRequests(authProvider.user!.uid);
    }
  }

  Future<void> _acceptRequest(FriendRequest request) async {
    final friendProvider = Provider.of<FriendProvider>(context, listen: false);

    final success = await friendProvider.acceptFriendRequest(request.id);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request accepted')),
        );

        // Reload both friends and requests to ensure sync
        await _loadFriends();
        await _loadFriendRequests();

        if (mounted) {
          setState(() {});
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  friendProvider.errorMessage ?? 'Failed to accept request')),
        );
      }
    }
  }

  Future<void> _rejectRequest(FriendRequest request) async {
    final friendProvider = Provider.of<FriendProvider>(context, listen: false);

    final success = await friendProvider.rejectFriendRequest(request.id);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request rejected')),
        );
        _loadFriendRequests();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  friendProvider.errorMessage ?? 'Failed to reject request')),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Future<void> _startChat(String friendId) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.user == null) return;

    try {
      final chatId = await ChatService.getOrCreateChat(
        userId1: authProvider.user!.uid,
        userId2: friendId,
      );

      if (mounted) {
        final chat = await ChatService.getChat(
          userId: authProvider.user!.uid,
          chatId: chatId,
        );
        if (chat != null && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatDetailScreen(chat: chat),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start chat: $e')),
        );
      }
    }
  }

  Future<void> _removeFriend(String friendId) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final friendProvider = Provider.of<FriendProvider>(context, listen: false);

    if (authProvider.user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Friend'),
        content: const Text('Are you sure you want to remove this friend?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await friendProvider.removeFriend(
        userId: authProvider.user!.uid,
        friendId: friendId,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Friend removed')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    friendProvider.errorMessage ?? 'Failed to remove friend')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final friendProvider = Provider.of<FriendProvider>(context);

    return Scaffold(
      appBar: widget.embedded
          ? AppBar(
              title: const Text('Friends'),
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              elevation: 0,
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.person_add),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SearchUsersScreen()),
                    ).then((_) {
                      _loadFriends();
                      _loadFriendRequests();
                    });
                  },
                ),
              ],
            )
          : AppBar(
              title: const Text('Friends'),
              backgroundColor: const Color(0xFF043915),
              foregroundColor: Colors.white,
              automaticallyImplyLeading: false,
              leading: mainShellAppBarLeading(context),
              actions: [
                IconButton(
                  icon: const Icon(Icons.person_add),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SearchUsersScreen()),
                    ).then((_) {
                      _loadFriends();
                      _loadFriendRequests();
                    });
                  },
                ),
              ],
            ),
      body: friendProvider.isLoading &&
              friendProvider.friends.isEmpty &&
              friendProvider.incomingRequests.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : friendProvider.errorMessage != null &&
                  friendProvider.friends.isEmpty &&
                  friendProvider.incomingRequests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          friendProvider.errorMessage!,
                          style:
                              const TextStyle(fontSize: 14, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          friendProvider.clearError();
                          _loadFriends();
                          _loadFriendRequests();
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
              : RefreshIndicator(
                  onRefresh: () async {
                    await _loadFriends();
                    await _loadFriendRequests();
                  },
                  child: CustomScrollView(
                    slivers: [
                      // Friend Requests Section
                      if (friendProvider.incomingRequests.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                            child: Row(
                              children: [
                                const Icon(Icons.inbox,
                                    color: Color(0xFF043915), size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  'Friend Requests (${friendProvider.incomingRequests.length})',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF043915),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (friendProvider.incomingRequests.isNotEmpty)
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final request =
                                  friendProvider.incomingRequests[index];
                              final label = request.fromLabel;
                              final letter = label.isNotEmpty
                                  ? label.substring(0, 1).toUpperCase()
                                  : '?';

                              return Card(
                                margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                                color: Colors.grey[50],
                                child: ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  leading: CircleAvatar(
                                    radius: 20,
                                    backgroundColor: const Color(0xFF043915),
                                    child: Text(
                                      letter,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 14),
                                    ),
                                  ),
                                  title: Text(
                                    label,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13),
                                  ),
                                  subtitle: Text(
                                    'Sent ${_formatDate(request.createdAt)}',
                                    style: TextStyle(
                                        color: Colors.grey[600], fontSize: 11),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextButton(
                                        onPressed: () =>
                                            _rejectRequest(request),
                                        child: const Text('Reject',
                                            style: TextStyle(
                                                color: Colors.red,
                                                fontSize: 12)),
                                      ),
                                      const SizedBox(width: 4),
                                      ElevatedButton(
                                        onPressed: () =>
                                            _acceptRequest(request),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF043915),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                        ),
                                        child: const Text('Accept',
                                            style: TextStyle(fontSize: 12)),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            childCount: friendProvider.incomingRequests.length,
                          ),
                        ),
                      // Friends Section
                      if (friendProvider.friends.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                            child: Row(
                              children: [
                                const Icon(Icons.people,
                                    color: Color(0xFF043915), size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  'Friends (${friendProvider.friends.length})',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF043915),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (friendProvider.friends.isNotEmpty)
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final friendId = friendProvider.friends[index];
                              final profile =
                                  friendProvider.profileFor(friendId);
                              final displayName = profile?.displayName ??
                                  (profile?.username != null
                                      ? '@${profile!.username}'
                                      : 'Friend');
                              final letter = displayName.isNotEmpty
                                  ? displayName.substring(0, 1).toUpperCase()
                                  : '?';

                              return Card(
                                margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                                child: ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  leading: CircleAvatar(
                                    radius: 20,
                                    backgroundColor: const Color(0xFF043915),
                                    child: Text(
                                      letter,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 14),
                                    ),
                                  ),
                                  title: Text(
                                    displayName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13),
                                  ),
                                  subtitle: Text(
                                    profile?.username != null &&
                                            profile!.username!.isNotEmpty
                                        ? '@${profile.username}'
                                        : friendId.length > 8
                                            ? friendId.substring(0, 8)
                                            : friendId,
                                    style: TextStyle(
                                        color: Colors.grey[600], fontSize: 11),
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'chat') {
                                        _startChat(friendId);
                                      } else if (value == 'remove') {
                                        _removeFriend(friendId);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'chat',
                                        child: Row(
                                          children: [
                                            Icon(Icons.chat, size: 16),
                                            SizedBox(width: 6),
                                            Text('Message',
                                                style: TextStyle(fontSize: 13)),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'remove',
                                        child: Row(
                                          children: [
                                            Icon(Icons.person_remove,
                                                size: 16, color: Colors.red),
                                            SizedBox(width: 6),
                                            Text('Remove Friend',
                                                style: TextStyle(
                                                    color: Colors.red,
                                                    fontSize: 13)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    _startChat(friendId);
                                  },
                                ),
                              );
                            },
                            childCount: friendProvider.friends.length,
                          ),
                        ),
                      // Empty state when no friends and no requests
                      if (friendProvider.friends.isEmpty &&
                          friendProvider.incomingRequests.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.people_outline,
                                    size: 48, color: Colors.grey),
                                const SizedBox(height: 12),
                                const Text(
                                  'No friends yet',
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.grey),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Add friends to share your wardrobe!',
                                  style: TextStyle(
                                      fontSize: 13, color: Colors.grey),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const SearchUsersScreen()),
                                    ).then((_) {
                                      _loadFriends();
                                      _loadFriendRequests();
                                    });
                                  },
                                  icon: const Icon(Icons.person_add, size: 16),
                                  label: const Text('Add Friend',
                                      style: TextStyle(fontSize: 13)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF043915),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 10),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}
