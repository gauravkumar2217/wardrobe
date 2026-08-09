import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/style_post.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wardrobe_provider.dart';
import '../../services/style_post_service.dart';
import '../../theme/wardrobe_tokens.dart';
import '../cloth/add_cloth_flow_screen.dart';
import '../wardrobe/create_wardrobe_screen.dart';
import 'create_style_post_screen.dart';

/// Style Feed: user look posts (not wardrobe inventory).
class StyleFeedTab extends StatefulWidget {
  const StyleFeedTab({super.key});

  @override
  State<StyleFeedTab> createState() => _StyleFeedTabState();
}

class _StyleFeedTabState extends State<StyleFeedTab> {
  String _scope = 'all'; // mine | all
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
      final scope = _scope == 'mine' ? 'mine' : 'all';
      final posts = await StylePostService.getPosts(scope: scope);
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

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreateStylePostScreen()),
    );
    if (created == true) {
      await _load();
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
      Navigator.of(context).pop(); // dialog

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
        Navigator.of(context).pop(); // dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start scan: $e')),
        );
      }
    }
  }

  Future<void> _deletePost(StylePost post) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete style post?'),
        content: const Text('This removes the look from Style Feed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await StylePostService.deletePost(post.id);
      if (!mounted) return;
      setState(() => _posts.removeWhere((p) => p.id == post.id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final me = context.watch<AuthProvider>().user?.uid;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'all', label: Text('All Styles')),
                    ButtonSegment(value: 'mine', label: Text('Your Style')),
                  ],
                  selected: {_scope},
                  onSelectionChanged: (s) {
                    setState(() => _scope = s.first);
                    _load();
                  },
                ),
              ),
              IconButton(
                tooltip: 'Post a look',
                onPressed: _openCreate,
                icon: const Icon(Icons.add_a_photo_outlined),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
          child: Text(
            'Style Feed shows look photos you post. Wardrobe items come from scanning a photo (including posts here).',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.65),
                ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          ElevatedButton(
                              onPressed: _load, child: const Text('Retry')),
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
                                Icon(Icons.auto_awesome_outlined,
                                    size: 48,
                                    color: scheme.primary.withValues(alpha: 0.8)),
                                const SizedBox(height: 12),
                                Text(
                                  _scope == 'mine'
                                      ? 'No style posts yet'
                                      : 'No styles to show yet',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Post a real photo of your look. Later you (or friends) can scan it to save clothes & accessories into a wardrobe.',
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _openCreate,
                                  icon: const Icon(Icons.add_a_photo),
                                  label: const Text('Post your style'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF043915),
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: _posts.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 14),
                            itemBuilder: (context, i) {
                              final post = _posts[i];
                              final isMine = me != null && post.userId == me;
                              return _StylePostCard(
                                post: post,
                                isMine: isMine,
                                onLike: () => _toggleLike(post),
                                onScan: () => _scanPost(post),
                                onDelete:
                                    isMine ? () => _deletePost(post) : null,
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }
}

class _StylePostCard extends StatelessWidget {
  final StylePost post;
  final bool isMine;
  final VoidCallback onLike;
  final VoidCallback onScan;
  final VoidCallback? onDelete;

  const _StylePostCard({
    required this.post,
    required this.isMine,
    required this.onLike,
    required this.onScan,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = post.user?.displayLabel ?? 'User';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WardrobeTokens.outlineGold),
        color: const Color(0xFF06231E),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: scheme.primary.withValues(alpha: 0.2),
                  backgroundImage: (post.user?.photoUrl != null &&
                          post.user!.photoUrl!.isNotEmpty)
                      ? NetworkImage(post.user!.photoUrl!)
                      : null,
                  child: (post.user?.photoUrl == null ||
                          post.user!.photoUrl!.isEmpty)
                      ? Icon(Icons.person, size: 18, color: scheme.primary)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 20),
                  ),
              ],
            ),
          ),
          AspectRatio(
            aspectRatio: 3 / 4,
            child: post.imageUrl.isEmpty
                ? ColoredBox(
                    color: scheme.primary.withValues(alpha: 0.1),
                    child: const Icon(Icons.image_not_supported),
                  )
                : CachedNetworkImage(
                    imageUrl: post.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    errorWidget: (_, __, ___) =>
                        const Icon(Icons.broken_image_outlined),
                  ),
          ),
          if (post.caption != null && post.caption!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Text(post.caption!.trim()),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: onLike,
                  icon: Icon(
                    post.likedByMe
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: post.likedByMe ? Colors.redAccent : null,
                  ),
                ),
                Text('${post.likesCount}'),
                const SizedBox(width: 8),
                Icon(Icons.mode_comment_outlined,
                    size: 20,
                    color: scheme.onSurface.withValues(alpha: 0.75)),
                const SizedBox(width: 6),
                Text('${post.commentsCount}'),
                const Spacer(),
                TextButton.icon(
                  onPressed: onScan,
                  icon: const Icon(Icons.document_scanner_outlined, size: 18),
                  label: const Text('Scan to wardrobe'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
