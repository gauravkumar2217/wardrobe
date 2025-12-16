import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/friend_provider.dart';
import '../../services/user_service.dart';
import '../../services/chat_service.dart';
import '../../models/friend_request.dart';
import '../../models/user_profile.dart';
import '../chat/chat_detail_screen.dart';

/// Search users screen with friend requests
class SearchUsersScreen extends StatefulWidget {
  const SearchUsersScreen({super.key});

  @override
  State<SearchUsersScreen> createState() => _SearchUsersScreenState();
}

class _SearchUsersScreenState extends State<SearchUsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Map<String, bool> _friendshipStatus = {};
  final Map<String, String> _requestStatus =
      {}; // 'none', 'outgoing', 'incoming', 'friends'
  final Map<String, String?> _requestIds =
      {}; // Store request IDs for accepting
  final Map<String, UserProfile?> _requestProfiles =
      {}; // Profiles for friend requests
  bool _isSearching = false;
  bool _hasLoadedRequests = false;

  @override
  void initState() {
    super.initState();
    // Load friend requests when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFriendRequests();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFriendRequests() async {
    if (_hasLoadedRequests) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final friendProvider = Provider.of<FriendProvider>(context, listen: false);

    if (authProvider.user != null) {
      // Only load and watch if user is authenticated
      if (authProvider.isAuthenticated && authProvider.user != null) {
        await friendProvider.loadFriendRequests(authProvider.user!.uid);
        friendProvider.watchFriendRequests(authProvider.user!.uid);
      }

      // Load profiles for all incoming requests
      for (var request in friendProvider.incomingRequests) {
        _loadRequestProfile(request.fromUserId);
      }

      if (mounted) {
        setState(() {
          _hasLoadedRequests = true;
        });
      }
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

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      final friendProvider =
          Provider.of<FriendProvider>(context, listen: false);
      friendProvider.clearSearchResults();
      return;
    }

    setState(() {
      _isSearching = true;
    });

    final friendProvider = Provider.of<FriendProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    await friendProvider.searchUsers(query.trim());

    // Check friendship and request status for each result
    if (authProvider.user != null) {
      for (var result in friendProvider.searchResults) {
        final userId = result['userId'] as String;
        if (userId != authProvider.user!.uid) {
          _checkFriendshipAndRequestStatus(userId);
        }
      }
    }

    setState(() {
      _isSearching = false;
    });
  }

  Future<void> _checkFriendshipAndRequestStatus(String userId,
      {bool forceRefresh = false}) async {
    if (!forceRefresh && _requestStatus.containsKey(userId)) return;

    final friendProvider = Provider.of<FriendProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.user == null) return;

    final result = await friendProvider.checkFriendRequestStatus(
      userId1: authProvider.user!.uid,
      userId2: userId,
    );

    if (mounted) {
      setState(() {
        _requestStatus[userId] = result['status'] as String;
        _requestIds[userId] = result['requestId'] as String?;
        _friendshipStatus[userId] = result['status'] == 'friends';
      });
    }
  }

  Future<void> _sendFriendRequest(String userId) async {
    final friendProvider = Provider.of<FriendProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.user == null) return;

    final success = await friendProvider.sendFriendRequest(
      fromUserId: authProvider.user!.uid,
      toUserId: userId,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request sent')),
        );
        setState(() {
          _requestStatus[userId] = 'outgoing'; // Mark as request sent
          _friendshipStatus[userId] = false;
          // Refresh to get the request ID
          _checkFriendshipAndRequestStatus(userId);
        });
      } else {
        // Check if error is because request already exists
        if (friendProvider.errorMessage?.contains('already sent') ?? false) {
          // Refresh status to get the request ID
          _checkFriendshipAndRequestStatus(userId);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    friendProvider.errorMessage ?? 'Failed to send request')),
          );
        }
      }
    }
  }

  Future<void> _acceptFriendRequest(FriendRequest request) async {
    final friendProvider = Provider.of<FriendProvider>(context, listen: false);

    final success = await friendProvider.acceptFriendRequest(request.id);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request accepted')),
        );

        // Refresh the status to ensure it shows as friends
        await _checkFriendshipAndRequestStatus(request.fromUserId,
            forceRefresh: true);

        if (!mounted) return;
        // Also reload friends list in the provider to ensure sync
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.user != null) {
          await friendProvider.loadFriends(authProvider.user!.uid);
        }

        // Reload friend requests
        await _loadFriendRequests();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  friendProvider.errorMessage ?? 'Failed to accept request')),
        );
      }
    }
  }

  Future<void> _rejectFriendRequest(FriendRequest request) async {
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
        await _loadFriendRequests();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  friendProvider.errorMessage ?? 'Failed to reject request')),
        );
      }
    }
  }

  Future<void> _startChat(String userId) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.user == null) return;

    try {
      final chatId = await ChatService.getOrCreateChat(
        userId1: authProvider.user!.uid,
        userId2: userId,
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

  @override
  Widget build(BuildContext context) {
    final friendProvider = Provider.of<FriendProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final hasSearchQuery = _searchController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Friends'),
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search by name, email, or phone',
                hintStyle: const TextStyle(fontSize: 13),
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          friendProvider.clearSearchResults();
                          setState(() {
                            _friendshipStatus.clear();
                            _requestStatus.clear();
                            _requestIds.clear();
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              onChanged: (value) {
                setState(() {});
                if (value.trim().isNotEmpty) {
                  // Debounce search
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (_searchController.text == value) {
                      _searchUsers(value);
                    }
                  });
                } else {
                  friendProvider.clearSearchResults();
                  setState(() {
                    _friendshipStatus.clear();
                    _requestStatus.clear();
                    _requestIds.clear();
                  });
                }
              },
            ),
          ),
          // Content: Friend Requests (when no search) or Search Results
          Expanded(
            child: hasSearchQuery
                ? _buildSearchResults(friendProvider, authProvider)
                : _buildFriendRequestsView(friendProvider, authProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendRequestsView(
      FriendProvider friendProvider, AuthProvider authProvider) {
    if (!_hasLoadedRequests) {
      return const Center(child: CircularProgressIndicator());
    }

    if (friendProvider.incomingRequests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'No friend requests',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            SizedBox(height: 6),
            Text(
              'Search for users to send friend requests',
              style: TextStyle(fontSize: 13, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFriendRequests,
      child: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
              child: Row(
                children: [
                  const Icon(Icons.inbox, color: Color(0xFF7C3AED), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Friend Requests (${friendProvider.incomingRequests.length})',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF7C3AED),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Friend requests list
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final request = friendProvider.incomingRequests[index];
                final profile = _requestProfiles[request.fromUserId];

                return Card(
                  margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        // Avatar
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFF7C3AED),
                          backgroundImage: profile?.photoUrl != null
                              ? NetworkImage(profile!.photoUrl!)
                              : null,
                          child: profile?.photoUrl == null
                              ? Text(
                                  profile?.displayName
                                          ?.substring(0, 1)
                                          .toUpperCase() ??
                                      '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        // Name and date
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile?.displayName ?? 'Unknown User',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Sent ${_formatDate(request.createdAt)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Action buttons
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Reject button
                            IconButton(
                              icon: const Icon(Icons.close,
                                  color: Colors.red, size: 18),
                              onPressed: () => _rejectFriendRequest(request),
                              tooltip: 'Reject',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 6),
                            // Accept button
                            ElevatedButton(
                              onPressed: () => _acceptFriendRequest(request),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7C3AED),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              child: const Text('Accept',
                                  style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
              childCount: friendProvider.incomingRequests.length,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(
      FriendProvider friendProvider, AuthProvider authProvider) {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (friendProvider.searchResults.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'No users found',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            SizedBox(height: 6),
            Text(
              'Try searching with a different name, email, or phone',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      itemCount: friendProvider.searchResults.length,
      itemBuilder: (context, index) {
        final result = friendProvider.searchResults[index];
        final userId = result['userId'] as String;
        final displayName = result['displayName'] as String?;
        final photoUrl = result['photoUrl'] as String?;
        final isCurrentUser = authProvider.user?.uid == userId;
        final requestStatus = _requestStatus[userId] ?? 'none';

        if (isCurrentUser) {
          return const SizedBox.shrink();
        }

        // Determine button text and icon based on status
        String buttonText;
        IconData buttonIcon;
        Color buttonColor;
        VoidCallback? buttonAction;
        bool isButtonEnabled = true;

        switch (requestStatus) {
          case 'friends':
            buttonText = 'Message';
            buttonIcon = Icons.chat;
            buttonColor = const Color(0xFF7C3AED);
            buttonAction = () => _startChat(userId);
            break;
          case 'outgoing':
            buttonText = 'Request Sent';
            buttonIcon = Icons.hourglass_empty;
            buttonColor = Colors.grey;
            buttonAction = null; // Disabled
            isButtonEnabled = false;
            break;
          case 'incoming':
            buttonText = 'Accept';
            buttonIcon = Icons.check;
            buttonColor = const Color(0xFF7C3AED);
            buttonAction = () {
              final requestId = _requestIds[userId];
              if (requestId != null) {
                final request = friendProvider.incomingRequests
                    .firstWhere((r) => r.id == requestId);
                _acceptFriendRequest(request);
              }
            };
            break;
          default: // 'none'
            buttonText = 'Add Friend';
            buttonIcon = Icons.person_add;
            buttonColor = const Color(0xFF7C3AED);
            buttonAction = () => _sendFriendRequest(userId);
            break;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 1,
          child: ListTile(
            dense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFF7C3AED),
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null
                  ? Text(
                      displayName?.isNotEmpty == true
                          ? displayName!.substring(0, 1).toUpperCase()
                          : '?',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    )
                  : null,
            ),
            title: Text(
              displayName ?? 'Unknown User',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            subtitle: Text(
              result['username'] != null &&
                      result['username'].toString().isNotEmpty
                  ? '@${result['username']}'
                  : (result['phone'] ?? userId.substring(0, 8)),
              style: TextStyle(color: Colors.grey[600], fontSize: 11),
            ),
            trailing: ElevatedButton.icon(
              onPressed: isButtonEnabled ? buttonAction : null,
              icon: Icon(buttonIcon, size: 14),
              label: Text(buttonText, style: const TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
                disabledForegroundColor: Colors.grey[600],
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
            ),
          ),
        );
      },
    );
  }
}
