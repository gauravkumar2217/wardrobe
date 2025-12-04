import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/cloth.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/cloth_card.dart';
import '../cloth/comment_screen.dart';
import '../../services/chat_service.dart';
import '../../services/user_service.dart';
import '../../providers/cloth_provider.dart';
import '../../providers/friend_provider.dart';

/// Cloth detail screen for viewing a single cloth (e.g., from DM share)
class ClothDetailScreen extends StatefulWidget {
  final Cloth? cloth;
  final String? clothId;
  final String? ownerId;
  final String? wardrobeId;
  final bool isOwner;
  final bool isShared;

  const ClothDetailScreen({
    super.key,
    this.cloth,
    this.clothId,
    this.ownerId,
    this.wardrobeId,
    this.isOwner = false,
    this.isShared = false,
  }) : assert(
          (cloth != null) || (clothId != null && ownerId != null && wardrobeId != null),
          'Either cloth or (clothId, ownerId, wardrobeId) must be provided',
        );

  @override
  State<ClothDetailScreen> createState() => _ClothDetailScreenState();
}

class _ClothDetailScreenState extends State<ClothDetailScreen> {
  final PageController _pageController = PageController();
  Cloth? _cloth;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isLiked = false;
  final Map<String, bool> _likedStatus = {};

  @override
  void initState() {
    super.initState();
    if (widget.cloth != null) {
      _cloth = widget.cloth;
      _isLoading = false;
      _loadLikeStatus();
    } else {
      _loadCloth();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadCloth() async {
    if (widget.clothId == null || widget.ownerId == null || widget.wardrobeId == null) {
      debugPrint('❌ ClothDetailScreen: Missing required parameters');
      debugPrint('   clothId: ${widget.clothId}');
      debugPrint('   ownerId: ${widget.ownerId}');
      debugPrint('   wardrobeId: ${widget.wardrobeId}');
      setState(() {
        _errorMessage = 'Missing required parameters';
        _isLoading = false;
      });
      return;
    }

    debugPrint('📦 ClothDetailScreen: Loading cloth');
    debugPrint('   clothId: ${widget.clothId}');
    debugPrint('   ownerId: ${widget.ownerId}');
    debugPrint('   wardrobeId: ${widget.wardrobeId}');
    debugPrint('   isShared: ${widget.isShared}');
    debugPrint('   isOwner: ${widget.isOwner}');

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final clothProvider = Provider.of<ClothProvider>(context, listen: false);
      debugPrint('🔄 ClothDetailScreen: Calling getClothById...');
      
      final cloth = await clothProvider.getClothById(
        userId: widget.ownerId!,
        wardrobeId: widget.wardrobeId!,
        clothId: widget.clothId!,
      );

      debugPrint('📥 ClothDetailScreen: Received response');
      debugPrint('   cloth: ${cloth != null ? "✅ Found" : "❌ Null"}');

      if (cloth != null) {
        debugPrint('✅ ClothDetailScreen: Cloth loaded successfully');
        debugPrint('   clothType: ${cloth.clothType}');
        debugPrint('   imageUrl: ${cloth.imageUrl.isNotEmpty ? "✅ Has image" : "❌ No image"}');
        debugPrint('   visibility: ${cloth.visibility}');
        debugPrint('   commentsCount: ${cloth.commentsCount}');
        
        // Refresh comment count to ensure it's accurate
        Cloth updatedCloth = cloth;
        try {
          final actualCommentCount = await clothProvider.getCommentCount(
            ownerId: widget.ownerId!,
            wardrobeId: widget.wardrobeId!,
            clothId: widget.clothId!,
          );
          debugPrint('   actualCommentCount: $actualCommentCount');
          
          // Update cloth with actual count if different
          if (actualCommentCount != cloth.commentsCount) {
            updatedCloth = cloth.copyWith(commentsCount: actualCommentCount);
            debugPrint('   Updated commentsCount from ${cloth.commentsCount} to $actualCommentCount');
          }
        } catch (e) {
          debugPrint('⚠️ Failed to refresh comment count: $e');
        }
        
        setState(() {
          _cloth = updatedCloth;
          _isLoading = false;
        });
        _loadLikeStatus();
      } else {
        debugPrint('❌ ClothDetailScreen: Cloth is null');
        setState(() {
          _errorMessage = 'Cloth not found';
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('❌ ClothDetailScreen: Error loading cloth');
      debugPrint('   Error: $e');
      debugPrint('   StackTrace: $stackTrace');
      setState(() {
        _errorMessage = 'Failed to load cloth: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadLikeStatus() async {
    if (_cloth == null) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final clothProvider = Provider.of<ClothProvider>(context, listen: false);

    if (authProvider.user != null) {
      // Get like status from Firestore
      final isLiked = await clothProvider.isLiked(
        userId: authProvider.user!.uid,
        ownerId: _cloth!.ownerId,
        wardrobeId: _cloth!.wardrobeId,
        clothId: _cloth!.id,
      );
      
      // Get actual like count from Firestore
      final actualCount = await clothProvider.getLikeCount(
        ownerId: _cloth!.ownerId,
        wardrobeId: _cloth!.wardrobeId,
        clothId: _cloth!.id,
      );
      
      if (mounted) {
        setState(() {
          _isLiked = isLiked;
          _likedStatus[_cloth!.id] = isLiked;
          _cloth = _cloth!.copyWith(
            likesCount: actualCount,
          );
        });
      }
    }
  }

  Future<void> _handleToggleWorn() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final clothProvider = Provider.of<ClothProvider>(context, listen: false);

    if (_cloth == null || authProvider.user == null) return;

    final wasWornToday = _cloth!.wornAt != null &&
        _isSameDay(_cloth!.wornAt!, DateTime.now());

    try {
      final newWornAt = await clothProvider.toggleWornStatus(
        userId: authProvider.user!.uid,
        wardrobeId: _cloth!.wardrobeId,
        cloth: _cloth!,
      );

      if (!mounted) return;

      setState(() {
        _cloth = _cloth!.copyWith(
          wornAt: newWornAt,
          updatedAt: DateTime.now(),
        );
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasWornToday ? 'Removed worn today' : 'Marked as worn today',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update worn status'),
        ),
      );
    }
  }

  Future<void> _handleLike() async {
    if (_cloth == null) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final clothProvider = Provider.of<ClothProvider>(context, listen: false);

    if (authProvider.user == null) return;

    // Optimistically update UI
    setState(() {
      _isLiked = !_isLiked;
      _likedStatus[_cloth!.id] = _isLiked;
    });

    try {
      await clothProvider.toggleLike(
        userId: authProvider.user!.uid,
        ownerId: _cloth!.ownerId,
        wardrobeId: _cloth!.wardrobeId,
        clothId: _cloth!.id,
      );
      
      // Refresh like status and count from Firestore
      final updatedIsLiked = await clothProvider.isLiked(
        userId: authProvider.user!.uid,
        ownerId: _cloth!.ownerId,
        wardrobeId: _cloth!.wardrobeId,
        clothId: _cloth!.id,
      );
      
      final updatedCount = await clothProvider.getLikeCount(
        ownerId: _cloth!.ownerId,
        wardrobeId: _cloth!.wardrobeId,
        clothId: _cloth!.id,
      );
      
      if (mounted) {
        setState(() {
          _isLiked = updatedIsLiked;
          _likedStatus[_cloth!.id] = updatedIsLiked;
          _cloth = _cloth!.copyWith(
            likesCount: updatedCount,
          );
        });
      }
    } catch (e) {
      // Revert on error and refresh from Firestore
      final actualIsLiked = await clothProvider.isLiked(
        userId: authProvider.user!.uid,
        ownerId: _cloth!.ownerId,
        wardrobeId: _cloth!.wardrobeId,
        clothId: _cloth!.id,
      );
      
      final actualCount = await clothProvider.getLikeCount(
        ownerId: _cloth!.ownerId,
        wardrobeId: _cloth!.wardrobeId,
        clothId: _cloth!.id,
      );
      
      if (mounted) {
        setState(() {
          _isLiked = actualIsLiked;
          _likedStatus[_cloth!.id] = actualIsLiked;
          _cloth = _cloth!.copyWith(
            likesCount: actualCount,
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to ${actualIsLiked ? "unlike" : "like"} cloth')),
        );
      }
    }
  }

  Future<void> _handleDelete() async {
    if (_cloth == null) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final clothProvider = Provider.of<ClothProvider>(context, listen: false);

    if (authProvider.user == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Delete Cloth',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to delete this cloth? This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.redAccent,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await clothProvider.deleteCloth(
        userId: authProvider.user!.uid,
        wardrobeId: _cloth!.wardrobeId,
        clothId: _cloth!.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cloth deleted successfully')),
        );
        Navigator.pop(context); // Go back after deletion
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete cloth: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _handleShare() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final friendProvider = Provider.of<FriendProvider>(context, listen: false);

    if (authProvider.user == null) return;

    // Load friends if not loaded
    if (friendProvider.friends.isEmpty) {
      await friendProvider.loadFriends(authProvider.user!.uid);
    }

    if (!mounted) return;

    // Show dialog to select friend/chat
    final selectedChat = await showDialog<String>(
      context: context,
      builder: (context) => _ShareDialog(
        friends: friendProvider.friends,
        userId: authProvider.user!.uid,
      ),
    );

    if (selectedChat != null && mounted && _cloth != null) {
      try {
        await ChatService.sendMessage(
          userId: authProvider.user!.uid,
          chatId: selectedChat,
          clothId: _cloth!.id,
          clothOwnerId: _cloth!.ownerId,
          clothWardrobeId: _cloth!.wardrobeId,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cloth shared successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to share cloth: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_errorMessage != null || _cloth == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('Error'),
          backgroundColor: const Color(0xFF7C3AED),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Text(
            _errorMessage ?? 'Cloth not found',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final isOwner = widget.isOwner || (authProvider.user?.uid == _cloth!.ownerId);
    final isShared = widget.isShared;
    final isAuthenticated = authProvider.user != null;
    final canInteract = isAuthenticated && (isOwner || isShared);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: ClothCard(
          cloth: _cloth!,
          isOwner: isOwner,
          isLiked: _isLiked,
          showBackButton: true,
          onLike: canInteract ? _handleLike : null,
          onComment: canInteract ? () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CommentScreen(cloth: _cloth!),
              ),
            );
            
            // Refresh comment count after returning from comment screen
            if (mounted && _cloth != null) {
              try {
                final clothProvider = Provider.of<ClothProvider>(context, listen: false);
                final actualCount = await clothProvider.getCommentCount(
                  ownerId: _cloth!.ownerId,
                  wardrobeId: _cloth!.wardrobeId,
                  clothId: _cloth!.id,
                );
                
                if (mounted && actualCount != _cloth!.commentsCount) {
                  setState(() {
                    _cloth = _cloth!.copyWith(commentsCount: actualCount);
                  });
                }
              } catch (e) {
                debugPrint('Failed to refresh comment count: $e');
              }
            }
          } : null,
          // Both users can share if not already shared, but only owner can actually share
          // For shared cloths, disable share button for both users
          onShare: isShared ? null : (isOwner ? _handleShare : null),
          // Both users can mark as worn if shared (friends can mark each other's shared clothes)
          onMarkWorn: isShared ? _handleToggleWorn : (isOwner ? _handleToggleWorn : null),
          // Only owner can edit
          onEdit: null, // Edit is handled elsewhere
          // Only owner can delete, and not if shared
          onDelete: (isOwner && !isShared) ? _handleDelete : null,
        ),
      ),
    );
  }
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

class _ShareDialog extends StatelessWidget {
  final List<String> friends;
  final String userId;

  const _ShareDialog({
    required this.friends,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Share Cloth'),
      content: friends.isEmpty
          ? const Text('No friends to share with. Add friends first!')
          : SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: friends.length,
                itemBuilder: (context, index) {
                  final friendId = friends[index];
                  return FutureBuilder(
                    future: UserService.getUserProfile(friendId),
                    builder: (context, snapshot) {
                      final profile = snapshot.data;
                      final displayName = profile?.displayName ?? 
                                        (profile?.username != null 
                                          ? '@${profile!.username}' 
                                          : 'Friend');
                      
                      return ListTile(
                        leading: profile?.photoUrl != null
                            ? CircleAvatar(
                                backgroundImage: NetworkImage(profile!.photoUrl!),
                                radius: 20,
                              )
                            : CircleAvatar(
                                backgroundColor: Colors.grey[700],
                                radius: 20,
                                child: Text(
                                  displayName.isNotEmpty 
                                      ? displayName[0].toUpperCase() 
                                      : 'F',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                        title: Text(displayName),
                        subtitle: profile?.username != null
                            ? Text('@${profile!.username}')
                            : null,
                        onTap: () async {
                          final chatId = await ChatService.getOrCreateChat(
                            userId1: userId,
                            userId2: friendId,
                          );
                          if (context.mounted) {
                            Navigator.pop(context, chatId);
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

