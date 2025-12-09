import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cloth_provider.dart';
import '../../providers/wardrobe_provider.dart';
import '../../providers/friend_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/filter_provider.dart';
import '../../models/cloth.dart';
import '../../widgets/cloth_card.dart';
import '../wardrobe/wardrobe_list_screen.dart';
import '../filter/filter_selection_screen.dart';
import '../cloth/add_cloth_screen.dart';
import '../cloth/edit_cloth_screen.dart';
import '../cloth/comment_screen.dart';
import '../cloth/worn_history_screen.dart';
import '../notifications/notifications_screen.dart';
import '../../services/chat_service.dart';
import '../../services/user_service.dart';
import '../../models/wardrobe.dart';

/// Home screen with swipeable fullscreen cloth cards
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  final Map<String, bool> _likedStatus = {};
  final Map<String, Future<bool>> _likeStatusFutures = {};
  bool _isRefreshingCounts = false;
  bool _hasInitialLoad = false;
  int _lastNavigationIndex = -1;
  
  // Search state
  String? _searchQuery;
  final TextEditingController _searchController = TextEditingController();
  bool _showSearchBar = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Set initial loading state - UI will show loading until counts are refreshed
    _isRefreshingCounts = true;
    // Defer loading until after build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadClothes();
      _checkForFilterParameters();
    });
  }

  void _checkForFilterParameters() {
    // Check if we received filter parameters from statistics screen
    // This will be handled via FilterProvider
  }

  void _clearFilters() {
    final filterProvider = Provider.of<FilterProvider>(context, listen: false);
    filterProvider.clearFilters();
  }

  String _getFilterLabel() {
    final wardrobeProvider = Provider.of<WardrobeProvider>(context, listen: false);
    final filterProvider = Provider.of<FilterProvider>(context, listen: false);
    
    if (wardrobeProvider.selectedWardrobe != null) {
      return wardrobeProvider.selectedWardrobe!.name;
    }
    
    // Count total active filters
    final totalFilters = filterProvider.filterTypes.length +
        filterProvider.filterOccasions.length +
        filterProvider.filterSeasons.length +
        filterProvider.filterColors.length;
    
    if (totalFilters > 0) {
      return '$totalFilters filter${totalFilters > 1 ? 's' : ''}';
    }
    
    return '';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh when app comes back to foreground
    if (state == AppLifecycleState.resumed && _hasInitialLoad && mounted) {
      _refreshCountsOnly();
    }
  }

  /// Refresh only counts without reloading all clothes (faster)
  Future<void> _refreshCountsOnly() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final clothProvider = Provider.of<ClothProvider>(context, listen: false);

    if (authProvider.user == null) return;

    if (mounted) {
      final clothes = clothProvider.clothes;
      if (clothes.isEmpty) return;

      // Refresh counts for all clothes in parallel
      final refreshTasks = <Future>[];
      for (var cloth in clothes) {
        refreshTasks.add(_refreshLikeCount(cloth, batchUpdate: true));
        refreshTasks.add(_refreshCommentCount(cloth, batchUpdate: true));
      }
      // Wait for all refresh tasks to complete
      await Future.wait(refreshTasks);

      // Notify listeners once after all batch updates are complete
      clothProvider.notifyListenersUpdate();
    }
  }

  Future<void> _loadClothes() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final clothProvider = Provider.of<ClothProvider>(context, listen: false);
    final wardrobeProvider =
        Provider.of<WardrobeProvider>(context, listen: false);

    if (authProvider.user == null) return;

    // Set refreshing state
    if (mounted) {
      setState(() {
        _isRefreshingCounts = true;
      });
    }

    try {
      final selectedWardrobe = wardrobeProvider.selectedWardrobe;
      // Load clothes but skip final notify (we'll notify after refreshing counts)
      await clothProvider.loadClothes(
        userId: authProvider.user!.uid,
        wardrobeId: selectedWardrobe?.id,
        skipFinalNotify: true, // Skip notify until counts are refreshed
      );

      // Pre-load like status and actual like/comment counts for all clothes
      if (mounted) {
        final clothes = clothProvider.clothes;
        // Refresh counts for all clothes in parallel
        final refreshTasks = <Future>[];
        for (var cloth in clothes) {
          _loadLikeStatus(cloth, authProvider.user!.uid);
          refreshTasks.add(_refreshLikeCount(cloth, batchUpdate: true));
          refreshTasks.add(_refreshCommentCount(cloth, batchUpdate: true));
        }
        // Wait for all refresh tasks to complete
        await Future.wait(refreshTasks);

        // Notify listeners once after all batch updates are complete
        // This ensures the UI shows correct counts on first render
        clothProvider.notifyListenersUpdate();

        // Mark initial load as complete only after counts are refreshed
        if (mounted) {
          setState(() {
            _hasInitialLoad = true;
          });
        }
      }

      // Load wardrobes if not loaded
      if (wardrobeProvider.wardrobes.isEmpty) {
        await wardrobeProvider.loadWardrobes(authProvider.user!.uid);
      }
    } finally {
      // Clear refreshing state
      if (mounted) {
        setState(() {
          _isRefreshingCounts = false;
        });
      }
    }
  }

  Future<void> _refreshLikeCount(Cloth cloth,
      {bool batchUpdate = false}) async {
    final clothProvider = Provider.of<ClothProvider>(context, listen: false);

    try {
      // Get actual like count from Firestore
      final actualCount = await clothProvider.getLikeCount(
        ownerId: cloth.ownerId,
        wardrobeId: cloth.wardrobeId,
        clothId: cloth.id,
      );

      // Update the cloth in the provider with the actual count
      clothProvider.updateClothLocally(
        clothId: cloth.id,
        likesCount: actualCount,
        batchUpdate: batchUpdate,
      );
    } catch (e) {
      debugPrint('Failed to refresh like count for cloth ${cloth.id}: $e');
    }
  }

  Future<void> _refreshCommentCount(Cloth cloth,
      {bool batchUpdate = false}) async {
    final clothProvider = Provider.of<ClothProvider>(context, listen: false);

    try {
      // Get actual comment count from Firestore
      final actualCount = await clothProvider.getCommentCount(
        ownerId: cloth.ownerId,
        wardrobeId: cloth.wardrobeId,
        clothId: cloth.id,
      );

      // Update the cloth in the provider with the actual count
      clothProvider.updateClothLocally(
        clothId: cloth.id,
        commentsCount: actualCount,
        batchUpdate: batchUpdate,
      );
    } catch (e) {
      debugPrint('Failed to refresh comment count for cloth ${cloth.id}: $e');
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
          SnackBar(
              content:
                  Text('Failed to ${actualIsLiked ? "unlike" : "like"} cloth')),
        );
      }
    }
  }

  void _handleComment(Cloth cloth) async {
    // Navigate to comment screen
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommentScreen(
          cloth: cloth,
        ),
      ),
    );
    // Refresh counts when returning from comment screen (comments might have changed)
    if (mounted && _hasInitialLoad) {
      await _refreshCountsOnly();
    }
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

    final wasWornToday =
        cloth.wornAt != null && _isSameDay(cloth.wornAt!, DateTime.now());

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
        const SnackBar(
          content: Text('Failed to update worn status'),
        ),
      );
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _handleDelete(Cloth cloth) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final clothProvider = Provider.of<ClothProvider>(context, listen: false);
    final wardrobeProvider =
        Provider.of<WardrobeProvider>(context, listen: false);

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
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
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
      // Save current page index to navigate after deletion
      int? currentPage;
      if (_pageController.hasClients) {
        currentPage = _pageController.page?.round();
      }

      await clothProvider.deleteCloth(
        userId: authProvider.user!.uid,
        wardrobeId: cloth.wardrobeId,
        clothId: cloth.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cloth deleted successfully')),
        );

        // Navigate to previous cloth or first cloth if deleted was the last one
        final filteredClothes = wardrobeProvider.selectedWardrobe != null
            ? clothProvider.clothes
                .where((c) =>
                    c.wardrobeId == wardrobeProvider.selectedWardrobe!.id)
                .toList()
            : clothProvider.clothes;

        if (filteredClothes.isNotEmpty && _pageController.hasClients) {
          // If we deleted the last item, go to the new last item
          final newIndex =
              currentPage != null && currentPage < filteredClothes.length
                  ? currentPage
                  : filteredClothes.length - 1;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_pageController.hasClients) {
              _pageController.jumpToPage(newIndex);
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete cloth: ${e.toString()}')),
        );
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh counts when screen becomes visible again (e.g., returning from pushed screens)
    // This is called when the widget's dependencies change, including when it becomes visible
    if (_hasInitialLoad && mounted) {
      // Use a small delay to ensure the screen is fully visible
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _refreshCountsOnly();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final clothProvider = Provider.of<ClothProvider>(context);
    final wardrobeProvider = Provider.of<WardrobeProvider>(context);
    final navigationProvider = Provider.of<NavigationProvider>(context);
    final filterProvider = Provider.of<FilterProvider>(context);
    
    // Get multiple filter values from provider
    final filterTypes = filterProvider.filterTypes;
    final filterOccasions = filterProvider.filterOccasions;
    final filterSeasons = filterProvider.filterSeasons;
    final filterColors = filterProvider.filterColors;

    // Refresh counts when navigating back to home screen (index 0)
    if (_hasInitialLoad &&
        navigationProvider.currentIndex == 0 &&
        _lastNavigationIndex != 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _refreshCountsOnly();
        }
      });
    }
    _lastNavigationIndex = navigationProvider.currentIndex;

    // Apply all filters
    var filteredClothes = clothProvider.clothes;

    // Filter by wardrobe
    if (wardrobeProvider.selectedWardrobe != null) {
      filteredClothes = filteredClothes
          .where((c) => c.wardrobeId == wardrobeProvider.selectedWardrobe!.id)
          .toList();
    }

    // Filter by type (multiple selections)
    if (filterTypes.isNotEmpty) {
      filteredClothes = filteredClothes
          .where((c) => filterTypes.contains(c.clothType))
          .toList();
    }

    // Filter by occasion (multiple selections)
    if (filterOccasions.isNotEmpty) {
      filteredClothes = filteredClothes
          .where((c) => c.occasions.any((occ) => filterOccasions.contains(occ)))
          .toList();
    }

    // Filter by season (multiple selections)
    if (filterSeasons.isNotEmpty) {
      filteredClothes = filteredClothes
          .where((c) => filterSeasons.contains(c.season))
          .toList();
    }

    // Filter by color (multiple selections)
    if (filterColors.isNotEmpty) {
      filteredClothes = filteredClothes
          .where((c) => c.colorTags.colors.any((color) => filterColors.contains(color)))
          .toList();
    }

    // Filter by search query
    if (_searchQuery != null && _searchQuery!.isNotEmpty) {
      final query = _searchQuery!.toLowerCase();
      filteredClothes = filteredClothes.where((c) {
        return c.clothType.toLowerCase().contains(query) ||
            c.category.toLowerCase().contains(query) ||
            c.season.toLowerCase().contains(query) ||
            c.occasions.any((occ) => occ.toLowerCase().contains(query)) ||
            c.colorTags.colors.any((color) => color.toLowerCase().contains(query));
      }).toList();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Main content
            RefreshIndicator(
              onRefresh: _loadClothes,
              color: Colors.white,
              child: (clothProvider.isLoading ||
                      _isRefreshingCounts ||
                      !_hasInitialLoad)
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white))
                  : clothProvider.errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline,
                                  size: 64, color: Colors.red),
                              const SizedBox(height: 16),
                              Text(
                                clothProvider.errorMessage!,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 16),
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
                                  const Icon(Icons.checkroom,
                                      size: 64, color: Colors.white54),
                                  const SizedBox(height: 16),
                                  Text(
                                    wardrobeProvider.selectedWardrobe != null
                                        ? 'No clothes in this wardrobe'
                                        : 'No clothes found',
                                    style: const TextStyle(
                                        color: Colors.white54, fontSize: 18),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    wardrobeProvider.selectedWardrobe != null
                                        ? 'Try adding clothes or selecting a different wardrobe'
                                        : 'Start by adding your first piece of clothing!',
                                    style: const TextStyle(
                                        color: Colors.white38, fontSize: 14),
                                    textAlign: TextAlign.center,
                                  ),
                                  if (wardrobeProvider.selectedWardrobe !=
                                      null) ...[
                                    const SizedBox(height: 16),
                                    TextButton(
                                      onPressed: () {
                                        wardrobeProvider
                                            .setSelectedWardrobe(null);
                                        _clearFilters();
                                        _loadClothes();
                                      },
                                      child: const Text('Clear filter',
                                          style:
                                              TextStyle(color: Colors.white)),
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
                                if (authProvider.user != null &&
                                    index < filteredClothes.length) {
                                  _loadLikeStatus(filteredClothes[index],
                                      authProvider.user!.uid);
                                }
                              },
                              itemBuilder: (context, index) {
                                final cloth = filteredClothes[index];
                                final isOwner =
                                    authProvider.user?.uid == cloth.ownerId;

                                return FutureBuilder<bool>(
                                  future: _getLikeStatus(
                                      cloth, authProvider.user?.uid ?? ''),
                                  builder: (context, snapshot) {
                                    final isLiked = snapshot.data ??
                                        (_likedStatus[cloth.id] ?? false);

                                    return ClothCard(
                                      cloth: cloth,
                                      isOwner: isOwner,
                                      isLiked: isLiked,
                                      showBackButton: false,
                                      onLike: () => _handleLike(cloth),
                                      onComment: () => _handleComment(cloth),
                                      onShare: isOwner
                                          ? () => _handleShare(cloth)
                                          : null,
                                      onMarkWorn: isOwner
                                          ? () => _handleToggleWorn(cloth)
                                          : null,
                                      onWornHistory: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => WornHistoryScreen(cloth: cloth),
                                          ),
                                        );
                                      },
                                      onEdit: isOwner
                                          ? () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      EditClothScreen(
                                                    cloth: cloth,
                                                    wardrobeId:
                                                        cloth.wardrobeId,
                                                  ),
                                                ),
                                              ).then((_) => _loadClothes());
                                            }
                                          : null,
                                      onDelete: isOwner
                                          ? () => _handleDelete(cloth)
                                          : null,
                                    );
                                  },
                                );
                              },
                            ),
            ),
            // Search bar (if visible)
            if (_showSearchBar)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.95),
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search by type, occasion, season, color...',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                      prefixIcon: const Icon(Icons.search, color: Colors.white),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.white),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = null;
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.2),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.isEmpty ? null : value;
                      });
                    },
                  ),
                ),
              ),
            // Top controls
            Positioned(
              top: _showSearchBar ? 60 : 0,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    // Don't show back button on home screen (it's part of MainNavigation)
                    // Only show spacer to maintain layout
                    const SizedBox(width: 48),
                    // Filter button
                    GestureDetector(
                      onTap: () async {
                        // Navigate to filter selection screen
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const FilterSelectionScreen()),
                        );
                        // Reload clothes after returning (filters might have been applied)
                        if (mounted) {
                          await _loadClothes();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: filterProvider.hasActiveFilter ||
                                  wardrobeProvider.selectedWardrobe != null
                              ? Colors.purple.withValues(alpha: 0.8)
                              : Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.filter_list,
                                color: Colors.white, size: 20),
                            if (filterProvider.hasActiveFilter ||
                                wardrobeProvider.selectedWardrobe != null) ...[
                              const SizedBox(width: 4),
                              Text(
                                _getFilterLabel(),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 14),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    // Notification and search buttons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_outlined,
                              color: Colors.white),
                          onPressed: () async {
                            // Navigate to notifications screen
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const NotificationsScreen()),
                            );
                            // Refresh counts when returning from notifications screen
                            if (mounted && _hasInitialLoad) {
                              await _refreshCountsOnly();
                            }
                          },
                        ),
                        IconButton(
                          icon: Icon(
                            _showSearchBar ? Icons.close : Icons.search,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            setState(() {
                              _showSearchBar = !_showSearchBar;
                              if (!_showSearchBar) {
                                _searchQuery = null;
                                _searchController.clear();
                              }
                            });
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
          final wardrobeProvider =
              Provider.of<WardrobeProvider>(context, listen: false);

          // If no wardrobe selected, navigate to wardrobe list first
          if (wardrobeProvider.wardrobes.isEmpty) {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WardrobeListScreen()),
            );
            return;
          }

          // If wardrobe selected, use it; otherwise show dialog to select
          final wardrobeId = wardrobeProvider.selectedWardrobe?.id ?? await showDialog<String>(
            context: context,
            builder: (context) => _SelectWardrobeDialog(
              wardrobes: wardrobeProvider.wardrobes,
            ),
          );

          if (wardrobeId != null) {
            if (!mounted) return;
            if (!mounted) return;
            final navContext = context;
            if (!mounted) return;
            final navigator = Navigator.of(navContext);
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
