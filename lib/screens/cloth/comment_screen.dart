import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
  final Map<String, bool> _loadingProfiles = {}; // Track loading state for each profile

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile(String userId) async {
    // If already loaded or currently loading, return
    if (_userProfiles.containsKey(userId)) return;
    if (_loadingProfiles[userId] == true) return;
    
    if (mounted) {
      setState(() {
        _loadingProfiles[userId] = true;
      });
    }
    
    try {
      debugPrint('📥 CommentScreen: Loading profile for userId: $userId');
      // Increase timeout to 5 seconds to give more time for profile loading
      final profile = await UserService.getUserProfile(userId)
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              debugPrint('⏱️ CommentScreen: Profile load timeout for $userId');
              return null;
            },
          );
      
      debugPrint('📥 CommentScreen: Profile loaded for $userId');
      debugPrint('   Profile: ${profile != null ? "✅ Found" : "❌ Null"}');
      if (profile != null) {
        debugPrint('   displayName: ${profile.displayName}');
        debugPrint('   photoUrl: ${profile.photoUrl}');
      }
      
      if (mounted) {
        setState(() {
          _userProfiles[userId] = profile; // Can be null if user doesn't exist or timeout
          _loadingProfiles[userId] = false; // Always mark as done loading
        });
        debugPrint('✅ CommentScreen: Profile stored and UI updated for $userId');
      }
    } catch (e, stackTrace) {
      // Handle error - set profile to null and mark as not loading
      // This ensures we show the comment even if profile fails to load
      debugPrint('❌ CommentScreen: Error loading profile for $userId: $e');
      debugPrint('   StackTrace: $stackTrace');
      if (mounted) {
        setState(() {
          _userProfiles[userId] = null; // Store null to indicate we tried
          _loadingProfiles[userId] = false; // Mark as done loading
        });
      }
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
        
        // Refresh comment count after deletion
        final deletedCount = await clothProvider.getCommentCount(
          ownerId: widget.cloth.ownerId,
          wardrobeId: widget.cloth.wardrobeId,
          clothId: widget.cloth.id,
        );
        
        // Update the cloth in the provider with the actual count
        clothProvider.updateClothLocally(
          clothId: widget.cloth.id,
          commentsCount: deletedCount,
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
                            // Use postFrameCallback to avoid setState during build
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                setState(() {}); // Trigger rebuild to retry stream
                              }
                            });
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

                // Load all profiles in parallel when comments are first loaded
                if (comments.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    for (var comment in comments) {
                      if (!_userProfiles.containsKey(comment.userId) && 
                          _loadingProfiles[comment.userId] != true) {
                        _loadUserProfile(comment.userId);
                      }
                    }
                  });
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    final isLoading = _loadingProfiles[comment.userId] == true;
                    final profile = _userProfiles[comment.userId];
                    final isOwner = authProvider.user?.uid == comment.userId;

                    // Start loading profile if not already loaded or loading
                    // Use postFrameCallback to avoid calling setState during build
                    if (!_userProfiles.containsKey(comment.userId) && !isLoading) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && !_userProfiles.containsKey(comment.userId) && 
                            _loadingProfiles[comment.userId] != true) {
                          _loadUserProfile(comment.userId);
                        }
                      });
                    }

                    // Show skeleton ONLY if we're actively loading AND haven't shown comment yet
                    // After 1.5 seconds max, always show comment (even if profile is null)
                    final isFirstAttempt = !_userProfiles.containsKey(comment.userId);
                    if (isFirstAttempt && isLoading) {
                      // Force show comment after 1.5 seconds even if profile still loading
                      Future.delayed(const Duration(milliseconds: 1500), () {
                        if (mounted && 
                            _loadingProfiles[comment.userId] == true && 
                            !_userProfiles.containsKey(comment.userId)) {
                          setState(() {
                            _loadingProfiles[comment.userId] = false;
                            _userProfiles[comment.userId] = null; // Mark as tried, show "User"
                          });
                        }
                      });
                      return _buildCommentSkeleton();
                    }

                    // Always show comment - profile may be null, show "User" as fallback
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey[200]!,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Avatar
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: const Color(0xFF7C3AED),
                            child: (profile != null && profile.photoUrl != null && profile.photoUrl!.isNotEmpty)
                                ? ClipOval(
                                    child: CachedNetworkImage(
                                      imageUrl: profile.photoUrl!,
                                      fit: BoxFit.cover,
                                      width: 40,
                                      height: 40,
                                      placeholder: (context, url) => Container(
                                        color: Colors.grey[300],
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      errorWidget: (_, __, ___) => const Icon(
                                        Icons.person,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  )
                                : Text(
                                    profile?.displayName?.substring(0, 1).toUpperCase() ?? '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 12),
                          // Comment content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Username and delete button
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        profile?.displayName ?? 'User',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                    if (isOwner)
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                          color: Colors.grey,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () => _deleteComment(comment.id),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                // Comment text
                                Text(
                                  comment.text,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                // Timestamp
                                Text(
                                  _formatDate(comment.createdAt),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Comment input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _commentController,
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          hintStyle: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED),
                      shape: BoxShape.circle,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _isSubmitting ? null : _submitComment,
                        borderRadius: BorderRadius.circular(24),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.send,
                                  color: Colors.white,
                                  size: 20,
                                ),
                        ),
                      ),
                    ),
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

  /// Build skeleton/placeholder for loading comments
  Widget _buildCommentSkeleton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar skeleton
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          // Content skeleton
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Username skeleton
                Container(
                  width: 120,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                // Comment text skeleton
                Container(
                  width: double.infinity,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 200,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                // Timestamp skeleton
                Container(
                  width: 80,
                  height: 11,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

