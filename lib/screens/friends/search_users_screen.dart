import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/friend_provider.dart';
import '../../services/chat_service.dart';
import '../chat/chat_detail_screen.dart';

/// Search users screen
class SearchUsersScreen extends StatefulWidget {
  const SearchUsersScreen({super.key});

  @override
  State<SearchUsersScreen> createState() => _SearchUsersScreenState();
}

class _SearchUsersScreenState extends State<SearchUsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Map<String, bool> _friendshipStatus = {};
  final Map<String, String> _requestStatus = {}; // 'none', 'outgoing', 'incoming', 'friends'
  final Map<String, String?> _requestIds = {}; // Store request IDs for accepting
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      final friendProvider = Provider.of<FriendProvider>(context, listen: false);
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

  Future<void> _checkFriendshipAndRequestStatus(String userId) async {
    if (_requestStatus.containsKey(userId)) return;

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
            SnackBar(content: Text(friendProvider.errorMessage ?? 'Failed to send request')),
          );
        }
      }
    }
  }

  Future<void> _acceptFriendRequest(String userId) async {
    final friendProvider = Provider.of<FriendProvider>(context, listen: false);
    final requestId = _requestIds[userId];

    if (requestId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request ID not found')),
      );
      return;
    }

    final success = await friendProvider.acceptFriendRequest(requestId);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request accepted')),
        );
        setState(() {
          _requestStatus[userId] = 'friends';
          _friendshipStatus[userId] = true;
          _requestIds.remove(userId);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendProvider.errorMessage ?? 'Failed to accept request')),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Users'),
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, email, or phone',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
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
          // Search results
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : friendProvider.searchResults.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.trim().isEmpty
                                  ? 'Enter a name, email, or phone to search'
                                  : 'No users found',
                              style: const TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: friendProvider.searchResults.length,
                        itemBuilder: (context, index) {
                          final result = friendProvider.searchResults[index];
                          final userId = result['userId'] as String;
                          final displayName = result['displayName'] as String?;
                          final photoUrl = result['photoUrl'] as String?;
                          final email = result['email'] as String?;
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
                              buttonText = 'Accept Request';
                              buttonIcon = Icons.check;
                              buttonColor = const Color(0xFF7C3AED);
                              buttonAction = () => _acceptFriendRequest(userId);
                              break;
                            default: // 'none'
                              buttonText = 'Add Friend';
                              buttonIcon = Icons.person_add;
                              buttonColor = const Color(0xFF7C3AED);
                              buttonAction = () => _sendFriendRequest(userId);
                              break;
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF7C3AED),
                                backgroundImage: photoUrl != null
                                    ? NetworkImage(photoUrl)
                                    : null,
                                child: photoUrl == null
                                    ? Text(
                                        displayName?.substring(0, 1).toUpperCase() ?? '?',
                                        style: const TextStyle(color: Colors.white),
                                      )
                                    : null,
                              ),
                              title: Text(
                                displayName ?? 'Unknown User',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                result['username'] != null 
                                    ? '@${result['username']}'
                                    : (email ?? result['phone'] ?? userId.substring(0, 8)),
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              trailing: ElevatedButton.icon(
                                onPressed: isButtonEnabled ? buttonAction : null,
                                icon: Icon(buttonIcon, size: 18),
                                label: Text(buttonText),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: buttonColor,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: Colors.grey[300],
                                  disabledForegroundColor: Colors.grey[600],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

