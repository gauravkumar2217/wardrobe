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

    // Check friendship status for each result
    if (authProvider.user != null) {
      for (var result in friendProvider.searchResults) {
        final userId = result['userId'] as String;
        if (userId != authProvider.user!.uid) {
          _checkFriendship(userId);
        }
      }
    }

    setState(() {
      _isSearching = false;
    });
  }

  Future<void> _checkFriendship(String userId) async {
    if (_friendshipStatus.containsKey(userId)) return;

    final friendProvider = Provider.of<FriendProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.user == null) return;

    final isFriend = await friendProvider.checkFriendship(
      authProvider.user!.uid,
      userId,
    );

    if (mounted) {
      setState(() {
        _friendshipStatus[userId] = isFriend;
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
          _friendshipStatus[userId] = false; // Mark as request sent
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendProvider.errorMessage ?? 'Failed to send request')),
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
                          final isFriend = _friendshipStatus[userId] ?? false;

                          if (isCurrentUser) {
                            return const SizedBox.shrink();
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
                                email ?? userId.substring(0, 8),
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              trailing: isFriend
                                  ? ElevatedButton.icon(
                                      onPressed: () => _startChat(userId),
                                      icon: const Icon(Icons.chat, size: 18),
                                      label: const Text('Message'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF7C3AED),
                                        foregroundColor: Colors.white,
                                      ),
                                    )
                                  : ElevatedButton.icon(
                                      onPressed: () => _sendFriendRequest(userId),
                                      icon: const Icon(Icons.person_add, size: 18),
                                      label: const Text('Add Friend'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF7C3AED),
                                        foregroundColor: Colors.white,
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

