import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/friend_provider.dart';
import '../../services/user_service.dart';
import '../../models/user_profile.dart';
import '../../models/friend_request.dart';

/// Friend requests screen with Received and Sent tabs
class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  State<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<String, UserProfile?> _userProfiles = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFriendRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFriendRequests() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final friendProvider = Provider.of<FriendProvider>(context, listen: false);

    if (authProvider.user != null) {
      await friendProvider.loadFriendRequests(authProvider.user!.uid);
      friendProvider.watchFriendRequests(authProvider.user!.uid);

      // Load profiles for all requests
      for (var request in friendProvider.incomingRequests) {
        _loadUserProfile(request.fromUserId);
      }
      for (var request in friendProvider.outgoingRequests) {
        _loadUserProfile(request.toUserId);
      }
    }
  }

  Future<void> _loadUserProfile(String userId) async {
    if (_userProfiles.containsKey(userId)) return;

    final profile = await UserService.getUserProfile(userId);
    if (mounted) {
      setState(() {
        _userProfiles[userId] = profile;
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
        setState(() {
          _userProfiles.remove(request.fromUserId);
        });
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
          _userProfiles.remove(request.fromUserId);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendProvider.errorMessage ?? 'Failed to reject request')),
        );
      }
    }
  }

  Future<void> _cancelRequest(FriendRequest request) async {
    final friendProvider = Provider.of<FriendProvider>(context, listen: false);

    final success = await friendProvider.cancelFriendRequest(request.id);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request canceled')),
        );
        setState(() {
          _userProfiles.remove(request.toUserId);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendProvider.errorMessage ?? 'Failed to cancel request')),
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

  @override
  Widget build(BuildContext context) {
    final friendProvider = Provider.of<FriendProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friend Requests'),
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(
              text: 'Received',
              icon: Icon(Icons.inbox),
            ),
            Tab(
              text: 'Sent',
              icon: Icon(Icons.send),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Received requests
          friendProvider.isLoading && friendProvider.incomingRequests.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : friendProvider.errorMessage != null && friendProvider.incomingRequests.isEmpty
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
                  : friendProvider.incomingRequests.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              const Text(
                                'No incoming requests',
                                style: TextStyle(fontSize: 18, color: Colors.grey),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'When someone sends you a friend request, it will appear here',
                                style: TextStyle(fontSize: 14, color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                      onRefresh: _loadFriendRequests,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: friendProvider.incomingRequests.length,
                        itemBuilder: (context, index) {
                          final request = friendProvider.incomingRequests[index];
                          final profile = _userProfiles[request.fromUserId];

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
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
                      ),
                    ),
          // Sent requests
          friendProvider.isLoading && friendProvider.outgoingRequests.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : friendProvider.outgoingRequests.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.send_outlined, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text(
                            'No outgoing requests',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Friend requests you send will appear here',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadFriendRequests,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: friendProvider.outgoingRequests.length,
                        itemBuilder: (context, index) {
                          final request = friendProvider.outgoingRequests[index];
                          final profile = _userProfiles[request.toUserId];

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
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
                              trailing: TextButton(
                                onPressed: () => _cancelRequest(request),
                                child: const Text('Cancel', style: TextStyle(color: Colors.red)),
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

