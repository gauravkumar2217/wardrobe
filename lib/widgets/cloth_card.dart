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
  final VoidCallback? onWornHistory;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
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
    this.onWornHistory,
    this.onEdit,
    this.onDelete,
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
  bool _isInfoPanelVisible = true; // Default: unhidden
  bool _isLoadingInfo = false;
  bool _isWornToday = false;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  @override
  void didUpdateWidget(covariant ClothCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cloth.id != widget.cloth.id ||
        oldWidget.cloth.wornAt != widget.cloth.wornAt) {
      _loadInfo();
    }
  }

  Future<void> _loadInfo() async {
    if (mounted) {
      setState(() {
        _isLoadingInfo = true;
      });
    }
    final wardrobeProvider =
        Provider.of<WardrobeProvider>(context, listen: false);
    final clothProvider = Provider.of<ClothProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Get wardrobe name
    final wardrobe = wardrobeProvider.getWardrobeById(widget.cloth.wardrobeId);
    if (wardrobe != null && mounted) {
      setState(() {
        _wardrobeName = wardrobe.name;
      });
    }

    // Get wear history summary (only for owner)
    if (widget.isOwner && authProvider.user != null) {
      try {
        final info = await clothProvider.getWearHistoryInfo(
          userId: authProvider.user!.uid,
          wardrobeId: widget.cloth.wardrobeId,
          clothId: widget.cloth.id,
        );
        if (mounted) {
          setState(() {
            _wearHistorySummary = info.summary;
            _isWornToday = info.isWornToday;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _wearHistorySummary = 'Wear history unavailable';
            _isWornToday = false;
          });
        }
      }
    } else if (mounted) {
      setState(() {
        _isWornToday = widget.cloth.wornAt != null &&
            _isSameDay(widget.cloth.wornAt!, DateTime.now());
      });
    }

    if (mounted) {
      setState(() {
        _isLoadingInfo = false;
      });
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
    final isWornToday = widget.isOwner
        ? _isWornToday
        : widget.cloth.wornAt != null &&
            _isSameDay(widget.cloth.wornAt!, DateTime.now());

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.black,
      ),
      child: widget.cloth.imageUrl.isNotEmpty
          ? Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  widget.cloth.imageUrl,
                  fit: BoxFit.cover,
                  frameBuilder:
                      (context, child, frame, wasSynchronouslyLoaded) {
                    if (wasSynchronouslyLoaded || frame != null) {
                      // Image loaded successfully
                      if (mounted && _isLoadingImage) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            setState(() {
                              _isLoadingImage = false;
                            });
                          }
                        });
                      }
                      return child;
                    }
                    return child;
                  },
                  errorBuilder: (context, error, stackTrace) {
                    // Image failed to load
                    if (mounted) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() {
                            _isLoadingImage = false;
                          });
                        }
                      });
                    }
                    return Container(
                      color: Colors.grey[900],
                      child: const Center(
                        child: Icon(Icons.broken_image,
                            color: Colors.white54, size: 64),
                      ),
                    );
                  },
                ),
                // Loading indicator
                if (_isLoadingImage)
                  const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                // Back button (if needed)
                if (widget.showBackButton)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: Colors.white, size: 20),
                      iconSize: 20,
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
                        icon: widget.isLiked
                            ? Icons.favorite
                            : Icons.favorite_border,
                        label: '${widget.cloth.likesCount}',
                        color: widget.isLiked ? Colors.red : Colors.white,
                        onTap: widget.onLike,
                      ),
                      const SizedBox(height: 8),
                      _ActionButton(
                        icon: Icons.comment,
                        label: '${widget.cloth.commentsCount}',
                        onTap: widget.onComment,
                      ),
                      const SizedBox(height: 8),
                      // Information icon to toggle bottom panel
                      _ActionButton(
                        icon: _isInfoPanelVisible
                            ? Icons.info
                            : Icons.info_outline,
                        label: 'Info',
                        onTap: () {
                          setState(() {
                            _isInfoPanelVisible = !_isInfoPanelVisible;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      // Worn history icon
                      if (widget.onWornHistory != null)
                        _ActionButton(
                          icon: Icons.history,
                          label: 'History',
                          onTap: widget.onWornHistory,
                        ),
                      if (widget.onWornHistory != null)
                        const SizedBox(height: 8),
                      // Owner-only actions: Share, Edit, Mark Worn, Delete
                      if (widget.isOwner) ...[
                        if (widget.onShare != null) ...[
                          _ActionButton(
                            icon: Icons.share,
                            label: 'Share',
                            onTap: widget.onShare,
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (widget.onEdit != null) ...[
                          _ActionButton(
                            icon: Icons.edit,
                            label: 'Edit',
                            onTap: widget.onEdit,
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (widget.onMarkWorn != null) ...[
                          _ActionButton(
                            icon: isWornToday
                                ? Icons.check_circle
                                : Icons.check_circle_outline,
                            label: isWornToday ? 'Worn' : 'Worn',
                            color:
                                isWornToday ? Colors.greenAccent : Colors.white,
                            onTap: widget.onMarkWorn,
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (widget.onDelete != null) ...[
                          _ActionButton(
                            icon: Icons.delete,
                            label: 'Delete',
                            color: Colors.redAccent,
                            onTap: widget.onDelete,
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                // Bottom information panel (toggleable)
                if (_isInfoPanelVisible)
                  Positioned(
                    left: 16,
                    right: 80,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.9),
                            Colors.black.withValues(alpha: 0.7),
                            Colors.black.withValues(alpha: 0.0),
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
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${widget.cloth.category} • ${widget.cloth.season}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                          if (widget.cloth.occasions.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Wrap(
                              spacing: 2,
                              runSpacing: 2,
                              children: widget.cloth.occasions.map((occasion) {
                                return Chip(
                                  label: Text(
                                    occasion,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                  backgroundColor:
                                      const Color.fromARGB(255, 0, 0, 0)
                                          .withValues(alpha: 0.5),
                                  labelStyle:
                                      const TextStyle(color: Colors.white),
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 3),
                                );
                              }).toList(),
                            ),
                          ],
                          if (widget.cloth.colorTags.colors.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Wrap(
                              spacing: 2,
                              runSpacing: 2,
                              children:
                                  widget.cloth.colorTags.colors.map((color) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    color,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                          const SizedBox(height: 4),
                          // Wardrobe name
                          if (_wardrobeName != null) ...[
                            Row(
                              children: [
                                const Icon(Icons.inventory_2,
                                    size: 12, color: Colors.white70),
                                const SizedBox(width: 3),
                                Text(
                                  _wardrobeName!,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                          ],
                          // Added date
                          Row(
                            children: [
                              const Icon(Icons.calendar_today,
                                  size: 12, color: Colors.white70),
                              const SizedBox(width: 3),
                              Text(
                                'Added ${_formatDate(widget.cloth.createdAt)}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                          // Wear history (only for owner)
                          if (widget.isOwner &&
                              _wearHistorySummary != null) ...[
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(Icons.check_circle,
                                    size: 12, color: Colors.white70),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    _wearHistorySummary!,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ] else if (widget.isOwner && _isLoadingInfo) ...[
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white70,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Refreshing wear history...',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            )
          : Stack(
              children: [
                const Center(
                  child: Icon(Icons.image_not_supported,
                      color: Colors.white54, size: 64),
                ),
                // Back button (if needed)
                if (widget.showBackButton)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: Colors.white, size: 20),
                      iconSize: 20,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
              ],
            ),
    );
  }
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 9),
          ),
        ],
      ),
    );
  }
}
