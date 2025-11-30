import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cloth_provider.dart';
import '../../providers/wardrobe_provider.dart';
import '../../providers/friend_provider.dart';
import '../../models/cloth.dart';
import '../../widgets/cloth_card.dart';
import '../wardrobe/wardrobe_list_screen.dart';
import '../cloth/add_cloth_screen.dart';
import '../cloth/edit_cloth_screen.dart';
import '../cloth/comment_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_screen.dart';
import '../../services/chat_service.dart';
import '../../models/wardrobe.dart';

/// Home screen with swipeable fullscreen cloth cards
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController();
  final Map<String, bool> _likedStatus = {};
  final Map<String, Future<bool>> _likeStatusFutures = {};

  @override
  void initState() {
    super.initState();
    // Defer loading until after build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadClothes();
    });
  }

  Future<void> _loadClothes() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final clothProvider = Provider.of<ClothProvider>(context, listen: false);
    final wardrobeProvider = Provider.of<WardrobeProvider>(context, listen: false);
    
    if (authProvider.user != null) {
      final selectedWardrobe = wardrobeProvider.selectedWardrobe;
      await clothProvider.loadClothes(
        userId: authProvider.user!.uid,
        wardrobeId: selectedWardrobe?.id,
      );
      
      // Pre-load like status for all clothes
      if (mounted) {
        final clothes = clothProvider.clothes;
        for (var cloth in clothes) {
          _loadLikeStatus(cloth, authProvider.user!.uid);
        }
      }
      
      // Load wardrobes if not loaded
      if (wardrobeProvider.wardrobes.isEmpty) {
        await wardrobeProvider.loadWardrobes(authProvider.user!.uid);
      }
    }
  }

  Future<void> _loadLikeStatus(Cloth cloth, String userId) async {
    if (_likeStatusFutures.containsKey(cloth.id)) return;
    
    final clothProvider = Provider.of<ClothProvider>(context, listen: false);
    final future = clothProvider.isLiked(
      userId: userId,
      ownerId: cloth.ownerId,
      wardrobeId: cloth.wardrobeId,
      clothId: cloth.id,
    );
    
    _likeStatusFutures[cloth.id] = future;
    final isLiked = await future;
    
    if (mounted) {
      setState(() {
        _likedStatus[cloth.id] = isLiked;
      });
    }
  }

  Future<bool> _getLikeStatus(Cloth cloth, String userId) async {
    if (_likedStatus.containsKey(cloth.id)) {
      return _likedStatus[cloth.id]!;
    }
    await _loadLikeStatus(cloth, userId);
    return _likedStatus[cloth.id] ?? false;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handleLike(Cloth cloth) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final clothProvider = Provider.of<ClothProvider>(context, listen: false);
    
    if (authProvider.user == null) return;
    
    // Optimistically update UI
    setState(() {
      _likedStatus[cloth.id] = !(_likedStatus[cloth.id] ?? false);
    });
    
    try {
      await clothProvider.toggleLike(
        userId: authProvider.user!.uid,
        ownerId: cloth.ownerId,
        wardrobeId: cloth.wardrobeId,
        clothId: cloth.id,
      );
      
      // Refresh like status from Firestore
      final updatedIsLiked = await clothProvider.isLiked(
        userId: authProvider.user!.uid,
        ownerId: cloth.ownerId,
        wardrobeId: cloth.wardrobeId,
        clothId: cloth.id,
      );
      
      // Update like status from Firestore
      // Note: clothProvider already updated the likesCount via notifyListeners()
      // The widget will rebuild automatically since it listens to clothProvider
      // and the PageView will maintain its position since we're not reloading the list
      if (mounted) {
        setState(() {
          _likedStatus[cloth.id] = updatedIsLiked;
        });
      }
    } catch (e) {
      // Revert on error and refresh from Firestore
      final actualIsLiked = await clothProvider.isLiked(
        userId: authProvider.user!.uid,
        ownerId: cloth.ownerId,
        wardrobeId: cloth.wardrobeId,
        clothId: cloth.id,
      );
      
      if (mounted) {
        setState(() {
          _likedStatus[cloth.id] = actualIsLiked;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to ${actualIsLiked ? "unlike" : "like"} cloth')),
        );
      }
    }
  }

  void _handleComment(Cloth cloth) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommentScreen(
          cloth: cloth,
        ),
      ),
    );
  }

  Future<void> _handleShare(Cloth cloth) async {
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
    
    if (selectedChat != null && mounted) {
      try {
        await ChatService.sendMessage(
          userId: authProvider.user!.uid,
          chatId: selectedChat,
          clothId: cloth.id,
          clothOwnerId: cloth.ownerId,
          clothWardrobeId: cloth.wardrobeId,
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

  Future<void> _handleToggleWorn(Cloth cloth) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final clothProvider = Provider.of<ClothProvider>(context, listen: false);
    
    if (authProvider.user == null) return;
    
    final wasWornToday = cloth.wornAt != null &&
        _isSameDay(cloth.wornAt!, DateTime.now());
    
    try {
      await clothProvider.toggleWornStatus(
        userId: authProvider.user!.uid,
        wardrobeId: cloth.wardrobeId,
        cloth: cloth,
      );
      
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

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final clothProvider = Provider.of<ClothProvider>(context);
    final wardrobeProvider = Provider.of<WardrobeProvider>(context);
    
    final filteredClothes = wardrobeProvider.selectedWardrobe != null
        ? clothProvider.clothes.where((c) => c.wardrobeId == wardrobeProvider.selectedWardrobe!.id).toList()
        : clothProvider.clothes;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Main content
            RefreshIndicator(
              onRefresh: _loadClothes,
              color: Colors.white,
              child: clothProvider.isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : clothProvider.errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 64, color: Colors.red),
                              const SizedBox(height: 16),
                              Text(
                                clothProvider.errorMessage!,
                                style: const TextStyle(color: Colors.white70, fontSize: 16),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () {
                                  clothProvider.clearError();
                                  _loadClothes();
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
                      : filteredClothes.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.checkroom, size: 64, color: Colors.white54),
                                  const SizedBox(height: 16),
                                  Text(
                                    wardrobeProvider.selectedWardrobe != null
                                        ? 'No clothes in this wardrobe'
                                        : 'No clothes found',
                                    style: const TextStyle(color: Colors.white54, fontSize: 18),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    wardrobeProvider.selectedWardrobe != null
                                        ? 'Try adding clothes or selecting a different wardrobe'
                                        : 'Start by adding your first piece of clothing!',
                                    style: const TextStyle(color: Colors.white38, fontSize: 14),
                                    textAlign: TextAlign.center,
                                  ),
                                  if (wardrobeProvider.selectedWardrobe != null) ...[
                                    const SizedBox(height: 16),
                                    TextButton(
                                      onPressed: () {
                                        wardrobeProvider.setSelectedWardrobe(null);
                                        _loadClothes();
                                      },
                                      child: const Text('Clear filter', style: TextStyle(color: Colors.white)),
                                    ),
                                  ],
                                ],
                              ),
                            )
                      : PageView.builder(
                          scrollDirection: Axis.vertical,
                          controller: _pageController,
                          itemCount: filteredClothes.length,
                          onPageChanged: (index) {
                            // Load like status for current cloth
                            if (authProvider.user != null && index < filteredClothes.length) {
                              _loadLikeStatus(filteredClothes[index], authProvider.user!.uid);
                            }
                          },
                          itemBuilder: (context, index) {
                            final cloth = filteredClothes[index];
                            final isOwner = authProvider.user?.uid == cloth.ownerId;
                            
                            return FutureBuilder<bool>(
                              future: _getLikeStatus(cloth, authProvider.user?.uid ?? ''),
                              builder: (context, snapshot) {
                                final isLiked = snapshot.data ?? (_likedStatus[cloth.id] ?? false);
                                
                                return ClothCard(
                                  cloth: cloth,
                                  isOwner: isOwner,
                                  isLiked: isLiked,
                                  showBackButton: false,
                                  onLike: () => _handleLike(cloth),
                                  onComment: () => _handleComment(cloth),
                                  onShare: isOwner ? () => _handleShare(cloth) : null,
                                  onMarkWorn: isOwner
                                      ? () => _handleToggleWorn(cloth)
                                      : null,
                                  onEdit: isOwner
                                      ? () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => EditClothScreen(
                                                cloth: cloth,
                                                wardrobeId: cloth.wardrobeId,
                                              ),
                                            ),
                                          ).then((_) => _loadClothes());
                                        }
                                      : null,
                                );
                              },
                            );
                          },
                        ),
            ),
            // Top controls
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.black.withValues(alpha: 0.0),
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back button (only show if HomeScreen was pushed, not if part of MainNavigation)
                    if (Navigator.canPop(context))
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      )
                    else
                      const SizedBox(width: 48), // Spacer to maintain layout
                    // Wardrobe filter button
                    GestureDetector(
                      onTap: () async {
                        // Navigate to wardrobe list screen
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const WardrobeListScreen()),
                        );
                        // Reload clothes after returning (wardrobe might have been selected)
                        if (mounted) {
                          await _loadClothes();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: wardrobeProvider.selectedWardrobe != null
                              ? Colors.purple.withValues(alpha: 0.8)
                              : Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.filter_list, color: Colors.white, size: 20),
                            if (wardrobeProvider.selectedWardrobe != null) ...[
                              const SizedBox(width: 4),
                              Text(
                                wardrobeProvider.selectedWardrobe!.name,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    // Notification and profile buttons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.person_outline, color: Colors.white),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ProfileScreen()),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final wardrobeProvider = Provider.of<WardrobeProvider>(context, listen: false);
          
          // If no wardrobe selected, navigate to wardrobe list first
          if (wardrobeProvider.wardrobes.isEmpty) {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WardrobeListScreen()),
            );
            return;
          }
          
          // If wardrobe selected, use it; otherwise show dialog to select
          String? wardrobeId = wardrobeProvider.selectedWardrobe?.id;
          if (wardrobeId == null) {
            wardrobeId = await showDialog<String>(
              context: context,
              builder: (context) => _SelectWardrobeDialog(
                wardrobes: wardrobeProvider.wardrobes,
              ),
            );
          }
          
          if (wardrobeId != null) {
            if (!mounted) return;
            final navigator = Navigator.of(context);
            await navigator.push(
              MaterialPageRoute(
                builder: (_) => AddClothScreen(wardrobeId: wardrobeId!),
              ),
            );
            if (mounted) {
              await _loadClothes();
            }
          }
        },
        backgroundColor: const Color(0xFF7C3AED),
        child: const Icon(Icons.add, color: Colors.white),
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
                      if (context.mounted) {
                        Navigator.pop(context, chatId);
                      }
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

class _SelectWardrobeDialog extends StatelessWidget {
  final List<Wardrobe> wardrobes;

  const _SelectWardrobeDialog({required this.wardrobes});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Wardrobe'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: wardrobes.length,
          itemBuilder: (context, index) {
            final wardrobe = wardrobes[index];
            return ListTile(
              title: Text(wardrobe.name),
              subtitle: Text(wardrobe.location),
              onTap: () => Navigator.pop(context, wardrobe.id),
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

