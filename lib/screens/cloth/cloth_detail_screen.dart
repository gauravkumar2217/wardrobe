import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/cloth.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/cloth_card.dart';
import '../cloth/comment_screen.dart';
import '../../services/chat_service.dart';
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
      setState(() {
        _errorMessage = 'Missing required parameters';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final clothProvider = Provider.of<ClothProvider>(context, listen: false);
      final cloth = await clothProvider.getClothById(
        userId: widget.ownerId!,
        wardrobeId: widget.wardrobeId!,
        clothId: widget.clothId!,
      );

      if (cloth != null) {
        setState(() {
          _cloth = cloth;
          _isLoading = false;
        });
        _loadLikeStatus();
      } else {
        setState(() {
          _errorMessage = 'Cloth not found';
          _isLoading = false;
        });
      }
    } catch (e) {
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
      final isLiked = await clothProvider.isLiked(
        userId: authProvider.user!.uid,
        ownerId: _cloth!.ownerId,
        wardrobeId: _cloth!.wardrobeId,
        clothId: _cloth!.id,
      );
      setState(() {
        _isLiked = isLiked;
        _likedStatus[_cloth!.id] = isLiked;
      });
    }
  }

  Future<void> _handleLike() async {
    if (_cloth == null) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final clothProvider = Provider.of<ClothProvider>(context, listen: false);

    if (authProvider.user == null) return;

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
    } catch (e) {
      // Revert on error
      setState(() {
        _isLiked = !_isLiked;
        _likedStatus[_cloth!.id] = _isLiked;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to ${_isLiked ? "unlike" : "like"} cloth')),
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
    final clothProvider = Provider.of<ClothProvider>(context);

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

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: ClothCard(
          cloth: _cloth!,
          isOwner: isOwner,
          isLiked: _isLiked,
          showBackButton: true,
          onLike: _handleLike,
          onComment: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CommentScreen(cloth: _cloth!),
              ),
            );
          },
          onShare: (isOwner && !isShared) ? _handleShare : null,
          onMarkWorn: (isOwner && !isShared)
              ? () {
                  clothProvider.markAsWornToday(
                    userId: authProvider.user!.uid,
                    wardrobeId: _cloth!.wardrobeId,
                    clothId: _cloth!.id,
                  );
                }
              : null,
          onEdit: null, // Edit is handled elsewhere
        ),
      ),
    );
  }
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
                  return ListTile(
                    title: Text('Friend ${friendId.substring(0, 8)}...'),
                    onTap: () async {
                      final chatId = await ChatService.getOrCreateChat(
                        userId1: userId,
                        userId2: friendId,
                      );
                      Navigator.pop(context, chatId);
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

