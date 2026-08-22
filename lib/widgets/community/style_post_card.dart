import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/style_post.dart';
import '../../theme/wardrobe_tokens.dart';

/// Community style post card with like, wishlist, and optional scan actions.
class StylePostCard extends StatelessWidget {
  final StylePost post;
  final bool isMine;
  final VoidCallback? onLike;
  final VoidCallback? onWishlist;
  final VoidCallback? onScan;
  final VoidCallback? onDelete;
  final bool showScan;
  final double? imageHeight;

  const StylePostCard({
    super.key,
    required this.post,
    this.isMine = false,
    this.onLike,
    this.onWishlist,
    this.onScan,
    this.onDelete,
    this.showScan = true,
    this.imageHeight,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      if (post.likesCount > 0)
                        Text(
                          '${post.likesCount} likes',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: scheme.onSurface.withValues(alpha: 0.65),
                              ),
                        ),
                    ],
                  ),
                ),
                if (onWishlist != null)
                  IconButton(
                    tooltip: post.wishlistedByMe
                        ? 'Remove from wishlist'
                        : 'Add to wishlist',
                    onPressed: onWishlist,
                    icon: Icon(
                      post.wishlistedByMe
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      color: post.wishlistedByMe ? scheme.primary : null,
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
          if (imageHeight != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: imageHeight,
                width: double.infinity,
                child: _PostImage(post: post, scheme: scheme),
              ),
            )
          else
            AspectRatio(
              aspectRatio: 3 / 4,
              child: _PostImage(post: post, scheme: scheme),
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
                if (onLike != null) ...[
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
                ],
                Icon(Icons.mode_comment_outlined,
                    size: 20,
                    color: scheme.onSurface.withValues(alpha: 0.75)),
                const SizedBox(width: 6),
                Text('${post.commentsCount}'),
                const Spacer(),
                if (showScan && onScan != null)
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

class _PostImage extends StatelessWidget {
  final StylePost post;
  final ColorScheme scheme;

  const _PostImage({required this.post, required this.scheme});

  @override
  Widget build(BuildContext context) {
    if (post.imageUrl.isEmpty) {
      return ColoredBox(
        color: scheme.primary.withValues(alpha: 0.1),
        child: const Icon(Icons.image_not_supported),
      );
    }

    return CachedNetworkImage(
      imageUrl: post.imageUrl,
      fit: BoxFit.cover,
      placeholder: (_, __) => const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined),
    );
  }
}
