import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cloth.dart';
import '../providers/wardrobe_provider.dart';
import '../providers/cloth_provider.dart';
import '../providers/auth_provider.dart';

/// Fullscreen swipeable cloth card widget
class ClothCard extends StatefulWidget {
  final Cloth cloth;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onMarkWorn;
  final VoidCallback? onEdit;
  final bool isLiked;
  final bool isOwner;
  final bool showBackButton;

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
    this.showBackButton = false,
  });

  @override
  State<ClothCard> createState() => _ClothCardState();
}

class _ClothCardState extends State<ClothCard> {
  String? _wardrobeName;
  String? _wearHistorySummary;
  bool _isLoadingImage = true;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    final wardrobeProvider = Provider.of<WardrobeProvider>(context, listen: false);
    final clothProvider = Provider.of<ClothProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Get wardrobe name
    final wardrobe = wardrobeProvider.getWardrobeById(widget.cloth.wardrobeId);
    if (wardrobe != null) {
      setState(() {
        _wardrobeName = wardrobe.name;
      });
    }
    
    // Get wear history summary (only for owner)
    if (widget.isOwner && authProvider.user != null) {
      try {
        final summary = await clothProvider.getWearHistorySummary(
          userId: authProvider.user!.uid,
          wardrobeId: widget.cloth.wardrobeId,
          clothId: widget.cloth.id,
        );
        setState(() {
          _wearHistorySummary = summary;
        });
      } catch (e) {
        setState(() {
          _wearHistorySummary = 'Wear history unavailable';
        });
      }
    }
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black,
        image: widget.cloth.imageUrl.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(widget.cloth.imageUrl),
                fit: BoxFit.cover,
                onError: (_, __) {
                  setState(() {
                    _isLoadingImage = false;
                  });
                },
              )
            : null,
      ),
      child: Stack(
        children: [
          // Loading indicator for image
          if (_isLoadingImage && widget.cloth.imageUrl.isNotEmpty)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          // Back button (if needed)
          if (widget.showBackButton)
            Positioned(
              top: 16,
              left: 16,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          // Right side interaction panel
          Positioned(
            right: 16,
            top: 0,
            bottom: 0,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ActionButton(
                  icon: widget.isLiked ? Icons.favorite : Icons.favorite_border,
                  label: '${widget.cloth.likesCount}',
                  color: widget.isLiked ? Colors.red : Colors.white,
                  onTap: widget.onLike,
                ),
                const SizedBox(height: 24),
                _ActionButton(
                  icon: Icons.comment,
                  label: '${widget.cloth.commentsCount}',
                  onTap: widget.onComment,
                ),
                const SizedBox(height: 24),
                if (widget.isOwner) ...[
                  if (widget.onShare != null) ...[
                    _ActionButton(
                      icon: Icons.share,
                      label: 'Share',
                      onTap: widget.onShare,
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (widget.onMarkWorn != null) ...[
                    _ActionButton(
                      icon: Icons.check_circle_outline,
                      label: 'Worn',
                      onTap: widget.onMarkWorn,
                    ),
                  ],
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
                    Colors.black.withOpacity(0.9),
                    Colors.black.withOpacity(0.7),
                    Colors.black.withOpacity(0.0),
                  ],
                  stops: const [0.0, 0.3, 1.0],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.cloth.clothType,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.cloth.category} • ${widget.cloth.season}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  if (widget.cloth.occasions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: widget.cloth.occasions.map((occasion) {
                        return Chip(
                          label: Text(
                            occasion,
                            style: const TextStyle(fontSize: 12),
                          ),
                          backgroundColor: Colors.white.withOpacity(0.2),
                          labelStyle: const TextStyle(color: Colors.white),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        );
                      }).toList(),
                    ),
                  ],
                  if (widget.cloth.colorTags.colors.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: widget.cloth.colorTags.colors.map((color) {
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
                  const SizedBox(height: 12),
                  // Wardrobe name
                  if (_wardrobeName != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.inventory_2, size: 16, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text(
                          _wardrobeName!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  // Added date
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(
                        'Added ${_formatDate(widget.cloth.createdAt)}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  // Wear history (only for owner)
                  if (widget.isOwner && _wearHistorySummary != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.check_circle, size: 16, color: Colors.white70),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _wearHistorySummary!,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Edit button (owner only)
          if (widget.isOwner && widget.onEdit != null)
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.edit, color: Colors.white),
                onPressed: widget.onEdit,
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

