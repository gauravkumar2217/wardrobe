import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/cloth.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cloth_provider.dart';
import '../../services/cloth_service.dart';
import '../../services/user_service.dart';
import '../../models/user_profile.dart';

/// Comment screen for viewing and adding comments on a cloth
class CommentScreen extends StatefulWidget {
  final Cloth cloth;

  const CommentScreen({
    super.key,
    required this.cloth,
  });

  @override
  State<CommentScreen> createState() => _CommentScreenState();
}

class _CommentScreenState extends State<CommentScreen> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSubmitting = false;
  final Map<String, UserProfile?> _userProfiles = {};

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
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

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty || _isSubmitting) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final clothProvider = Provider.of<ClothProvider>(context, listen: false);

    if (authProvider.user == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      await ClothService.addComment(
        userId: authProvider.user!.uid,
        ownerId: widget.cloth.ownerId,
        wardrobeId: widget.cloth.wardrobeId,
        clothId: widget.cloth.id,
        text: _commentController.text.trim(),
      );

      _commentController.clear();
      
      // Refresh comment count from Firestore
      final actualCount = await clothProvider.getCommentCount(
        ownerId: widget.cloth.ownerId,
        wardrobeId: widget.cloth.wardrobeId,
        clothId: widget.cloth.id,
      );
      
      // Update the cloth in the provider with the actual count
      clothProvider.updateClothLocally(
        clothId: widget.cloth.id,
        commentsCount: actualCount,
      );

      // Scroll to bottom
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add comment: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final clothProvider = Provider.of<ClothProvider>(context, listen: false);

    if (authProvider.user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ClothService.deleteComment(
          userId: authProvider.user!.uid,
          ownerId: widget.cloth.ownerId,
          wardrobeId: widget.cloth.wardrobeId,
          clothId: widget.cloth.id,
          commentId: commentId,
        );

        // Refresh comment count from Firestore
        final actualCount = await clothProvider.getCommentCount(
          ownerId: widget.cloth.ownerId,
          wardrobeId: widget.cloth.wardrobeId,
          clothId: widget.cloth.id,
        );
        
        // Update the cloth in the provider with the actual count
        clothProvider.updateClothLocally(
          clothId: widget.cloth.id,
          commentsCount: actualCount,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete comment: $e')),
          );
        }
      }
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comments'),
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Comments list
          Expanded(
            child: StreamBuilder<List<Comment>>(
              stream: _getCommentsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            'Error loading comments: ${snapshot.error}',
                            style: const TextStyle(fontSize: 16, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {}); // Trigger rebuild to retry stream
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
                  );
                }

                final comments = snapshot.data ?? [];

                if (comments.isEmpty) {
                  return const Center(
                    child: Text('No comments yet. Be the first to comment!'),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    _loadUserProfile(comment.userId);
                    final profile = _userProfiles[comment.userId];
                    final isOwner = authProvider.user?.uid == comment.userId;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF7C3AED),
                          child: profile?.photoUrl != null
                              ? ClipOval(
                                  child: Image.network(
                                    profile!.photoUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  profile?.displayName?.substring(0, 1).toUpperCase() ?? '?',
                                  style: const TextStyle(color: Colors.white),
                                ),
                        ),
                        title: Text(
                          profile?.displayName ?? 'Unknown User',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(comment.text),
                            const SizedBox(height: 4),
                            Text(
                              _formatDate(comment.createdAt),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        trailing: isOwner
                            ? IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20),
                                onPressed: () => _deleteComment(comment.id),
                              )
                            : null,
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Comment input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send, color: Color(0xFF7C3AED)),
                    onPressed: _isSubmitting ? null : _submitComment,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Stream<List<Comment>> _getCommentsStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(widget.cloth.ownerId)
        .collection('wardrobes')
        .doc(widget.cloth.wardrobeId)
        .collection('clothes')
        .doc(widget.cloth.id)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Comment.fromJson(doc.data(), doc.id))
            .toList());
  }
}

