import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/friend_provider.dart';
import '../../services/user_service.dart';
import '../../services/chat_service.dart';
import '../../models/user_profile.dart';
import '../../models/friend_request.dart';
import '../friends/search_users_screen.dart';
import '../chat/chat_detail_screen.dart';

/// Friends list screen
class FriendsListScreen extends StatefulWidget {
  const FriendsListScreen({super.key});

  @override
  State<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends State<FriendsListScreen> {
  final Map<String, UserProfile?> _friendProfiles = {};
  final Map<String, UserProfile?> _requestProfiles = {};

  @override
  void initState() {
    super.initState();
    // Defer loading until after build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFriends();
      _loadFriendRequests();
    });
  }

  Future<void> _loadFriends() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final friendProvider = Provider.of<FriendProvider>(context, listen: false);

    if (authProvider.user != null) {
      await friendProvider.loadFriends(authProvider.user!.uid);
      friendProvider.watchFriends(authProvider.user!.uid);

      // Load profiles for all friends
      for (var friendId in friendProvider.friends) {
        _loadFriendProfile(friendId);
      }
    }
  }

  Future<void> _loadFriendRequests() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final friendProvider = Provider.of<FriendProvider>(context, listen: false);

    if (authProvider.user != null) {
      await friendProvider.loadFriendRequests(authProvider.user!.uid);
      friendProvider.watchFriendRequests(authProvider.user!.uid);

      // Load profiles for all incoming requests
      for (var request in friendProvider.incomingRequests) {
        _loadRequestProfile(request.fromUserId);
      }
    }
  }

  Future<void> _loadFriendProfile(String friendId) async {
    if (_friendProfiles.containsKey(friendId)) return;

    final profile = await UserService.getUserProfile(friendId);
    if (mounted) {
      setState(() {
        _friendProfiles[friendId] = profile;
      });
    }
  }

  Future<void> _loadRequestProfile(String userId) async {
    if (_requestProfiles.containsKey(userId)) return;

    final profile = await UserService.getUserProfile(userId);
    if (mounted) {
      setState(() {
        _requestProfiles[userId] = profile;
      });
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
        
        // Load profile for the new friend
        _loadFriendProfile(request.fromUserId);
        
        // Reload both friends and requests to ensure sync
        await _loadFriends();
        await _loadFriendRequests();
        
        // Force a refresh by notifying listeners
        if (mounted) {
          setState(() {});
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendProvider.errorMessage ?? 'Failed to accept request')),
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
        setState(() {
          _requestProfiles.remove(request.fromUserId);
        });
        _loadFriendRequests();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendProvider.errorMessage ?? 'Failed to reject request')),
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
          setState(() {
            _friendProfiles.remove(friendId);
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(friendProvider.errorMessage ?? 'Failed to remove friend')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final friendProvider = Provider.of<FriendProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchUsersScreen()),
              ).then((_) {
                _loadFriends();
                _loadFriendRequests();
              });
            },
          ),
        ],
      ),
      body: friendProvider.isLoading && friendProvider.friends.isEmpty && friendProvider.incomingRequests.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : friendProvider.errorMessage != null && friendProvider.friends.isEmpty && friendProvider.incomingRequests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          friendProvider.errorMessage!,
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          friendProvider.clearError();
                          _loadFriends();
                          _loadFriendRequests();
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
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Row(
                              children: [
                                const Icon(Icons.inbox, color: Color(0xFF7C3AED)),
                                const SizedBox(width: 8),
                                Text(
                                  'Friend Requests (${friendProvider.incomingRequests.length})',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF7C3AED),
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
                              final request = friendProvider.incomingRequests[index];
                              final profile = _requestProfiles[request.fromUserId];

                              return Card(
                                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                color: Colors.grey[50],
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: const Color(0xFF7C3AED),
                                    backgroundImage: profile?.photoUrl != null
                                        ? NetworkImage(profile!.photoUrl!)
                                        : null,
                                    child: profile?.photoUrl == null
                                        ? Text(
                                            profile?.displayName?.substring(0, 1).toUpperCase() ?? '?',
                                            style: const TextStyle(color: Colors.white),
                                          )
                                        : null,
                                  ),
                                  title: Text(
                                    profile?.displayName ?? 'Unknown User',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    'Sent ${_formatDate(request.createdAt)}',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextButton(
                                        onPressed: () => _rejectRequest(request),
                                        child: const Text('Reject', style: TextStyle(color: Colors.red)),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: () => _acceptRequest(request),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF7C3AED),
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text('Accept'),
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
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Row(
                              children: [
                                const Icon(Icons.people, color: Color(0xFF7C3AED)),
                                const SizedBox(width: 8),
                                Text(
                                  'Friends (${friendProvider.friends.length})',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF7C3AED),
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
                              final profile = _friendProfiles[friendId];

                              return Card(
                                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: const Color(0xFF7C3AED),
                                    backgroundImage: profile?.photoUrl != null
                                        ? NetworkImage(profile!.photoUrl!)
                                        : null,
                                    child: profile?.photoUrl == null
                                        ? Text(
                                            profile?.displayName?.substring(0, 1).toUpperCase() ?? '?',
                                            style: const TextStyle(color: Colors.white),
                                          )
                                        : null,
                                  ),
                                  title: Text(
                                    profile?.displayName ?? 'Unknown User',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    profile?.email ?? friendId.substring(0, 8),
                                    style: TextStyle(color: Colors.grey[600]),
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
                                            Icon(Icons.chat, size: 20),
                                            SizedBox(width: 8),
                                            Text('Message'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'remove',
                                        child: Row(
                                          children: [
                                            Icon(Icons.person_remove, size: 20, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Remove Friend', style: TextStyle(color: Colors.red)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    // TODO: Navigate to friend's profile when profile screen is created
                                    // For now, start a chat
                                    _startChat(friendId);
                                  },
                                ),
                              );
                            },
                            childCount: friendProvider.friends.length,
                          ),
                        ),
                      // Empty state when no friends and no requests
                      if (friendProvider.friends.isEmpty && friendProvider.incomingRequests.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                                const SizedBox(height: 16),
                                const Text(
                                  'No friends yet',
                                  style: TextStyle(fontSize: 18, color: Colors.grey),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Add friends to share your wardrobe!',
                                  style: TextStyle(fontSize: 14, color: Colors.grey),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const SearchUsersScreen()),
                                    ).then((_) {
                                      _loadFriends();
                                      _loadFriendRequests();
                                    });
                                  },
                                  icon: const Icon(Icons.person_add),
                                  label: const Text('Add Friend'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF7C3AED),
                                    foregroundColor: Colors.white,
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

