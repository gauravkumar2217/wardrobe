import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/style_post.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wardrobe_provider.dart';
import '../../services/style_post_service.dart';
import '../../theme/wardrobe_tokens.dart';
import '../../widgets/community/style_post_card.dart';
import '../cloth/add_cloth_flow_screen.dart';
import '../wardrobe/create_wardrobe_screen.dart';

/// Saved style looks from the community feed.
class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  bool _loading = true;
  String? _error;
  List<StylePost> _posts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final posts = await StylePostService.getWishlist();
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _toggleWishlist(StylePost post) async {
    final idx = _posts.indexWhere((p) => p.id == post.id);
    if (idx < 0) return;

    final wasWishlisted = post.wishlistedByMe;
    if (wasWishlisted) {
      setState(() => _posts.removeAt(idx));
    } else {
      setState(() {
        _posts[idx] = post.copyWith(wishlistedByMe: true);
      });
    }

    try {
      if (wasWishlisted) {
        await StylePostService.removeFromWishlist(post.id);
      } else {
        await StylePostService.addToWishlist(post.id);
      }
    } catch (e) {
      if (!mounted) return;
      await _load();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Wishlist update failed: $e')),
      );
    }
  }

  Future<void> _toggleLike(StylePost post) async {
    final idx = _posts.indexWhere((p) => p.id == post.id);
    if (idx < 0) return;

    final wasLiked = post.likedByMe;
    setState(() {
      _posts[idx] = post.copyWith(
        likedByMe: !wasLiked,
        likesCount: (post.likesCount + (wasLiked ? -1 : 1)).clamp(0, 999999),
      );
    });

    try {
      if (wasLiked) {
        await StylePostService.unlike(post.id);
      } else {
        await StylePostService.like(post.id);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _posts[idx] = post);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Like failed: $e')),
      );
    }
  }

  Future<void> _scanPost(StylePost post) async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;

    final wardrobeProvider = context.read<WardrobeProvider>();
    if (wardrobeProvider.wardrobes.isEmpty) {
      await wardrobeProvider.loadWardrobes(auth.user!.uid, refreshCounts: false);
    }
    if (!mounted) return;

    if (wardrobeProvider.wardrobes.isEmpty) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CreateWardrobeScreen()),
      );
      if (!mounted) return;
      await wardrobeProvider.loadWardrobes(auth.user!.uid, refreshCounts: false);
      if (!mounted) return;
      if (wardrobeProvider.wardrobes.isEmpty) return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final file = await StylePostService.downloadImageToTemp(post.imageUrl);
      if (!mounted) return;
      Navigator.of(context).pop();

      final wardrobeId = wardrobeProvider.wardrobes.first.id;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AddClothFlowScreen(
            wardrobeId: wardrobeId,
            initialImageFile: file,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start scan: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: WardrobeTokens.emeraldBg,
      appBar: AppBar(
        backgroundColor: WardrobeTokens.emeraldBg,
        title: const Text('Wishlist'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : _posts.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bookmark_border_rounded,
                                size: 48,
                                color: scheme.primary.withValues(alpha: 0.8)),
                            const SizedBox(height: 12),
                            Text(
                              'Your wishlist is empty',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Tap the bookmark on any community look to save it here.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: _posts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, i) {
                          final post = _posts[i];
                          return StylePostCard(
                            post: post,
                            onLike: () => _toggleLike(post),
                            onWishlist: () => _toggleWishlist(post),
                            onScan: () => _scanPost(post),
                          );
                        },
                      ),
                    ),
    );
  }
}
