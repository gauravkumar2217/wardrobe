import 'package:flutter/material.dart';
import '../models/cloth.dart';

/// Fullscreen swipeable cloth card widget
class ClothCard extends StatelessWidget {
  final Cloth cloth;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onMarkWorn;
  final VoidCallback? onEdit;
  final bool isLiked;
  final bool isOwner;

  const ClothCard({
    super.key,
    required this.cloth,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onMarkWorn,
    this.onEdit,
    this.isLiked = false,
    this.isOwner = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black,
        image: cloth.imageUrl.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(cloth.imageUrl),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: Stack(
        children: [
          // Right side interaction panel
          Positioned(
            right: 16,
            top: 0,
            bottom: 0,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ActionButton(
                  icon: isLiked ? Icons.favorite : Icons.favorite_border,
                  label: '${cloth.likesCount}',
                  color: isLiked ? Colors.red : Colors.white,
                  onTap: onLike,
                ),
                const SizedBox(height: 24),
                _ActionButton(
                  icon: Icons.comment,
                  label: '${cloth.commentsCount}',
                  onTap: onComment,
                ),
                const SizedBox(height: 24),
                if (isOwner) ...[
                  _ActionButton(
                    icon: Icons.share,
                    label: 'Share',
                    onTap: onShare,
                  ),
                  const SizedBox(height: 24),
                  _ActionButton(
                    icon: Icons.check_circle_outline,
                    label: 'Worn',
                    onTap: onMarkWorn,
                  ),
                ],
              ],
            ),
          ),
          // Bottom information panel
          Positioned(
            left: 16,
            right: 80,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.black.withOpacity(0.0),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    cloth.clothType,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${cloth.category} • ${cloth.season}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  if (cloth.occasions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      children: cloth.occasions.map((occasion) {
                        return Chip(
                          label: Text(
                            occasion,
                            style: const TextStyle(fontSize: 12),
                          ),
                          backgroundColor: Colors.white.withOpacity(0.2),
                          labelStyle: const TextStyle(color: Colors.white),
                        );
                      }).toList(),
                    ),
                  ],
                  if (cloth.colorTags.colors.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      children: cloth.colorTags.colors.map((color) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            color,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Edit button (owner only)
          if (isOwner && onEdit != null)
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.edit, color: Colors.white),
                onPressed: onEdit,
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

