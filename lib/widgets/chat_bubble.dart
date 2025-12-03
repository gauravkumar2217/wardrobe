import 'package:flutter/material.dart';
import '../models/chat.dart';
import '../models/cloth.dart';
import '../services/cloth_service.dart';

/// Chat bubble widget for displaying messages
class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final String currentUserId;
  final bool showAvatar;

  const ChatBubble({
    super.key,
    required this.message,
    required this.currentUserId,
    this.showAvatar = true,
  });

  bool get isCurrentUser => message.senderId == currentUserId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment:
            isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isCurrentUser && showAvatar) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[300],
              child: const Icon(Icons.person, size: 18),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isCurrentUser
                    ? Theme.of(context).primaryColor
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(18).copyWith(
                  bottomRight: isCurrentUser
                      ? const Radius.circular(4)
                      : const Radius.circular(18),
                  bottomLeft: isCurrentUser
                      ? const Radius.circular(18)
                      : const Radius.circular(4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.isText)
                    Text(
                      message.text!,
                      style: TextStyle(
                        color: isCurrentUser ? Colors.white : Colors.black87,
                        fontSize: 15,
                      ),
                    ),
                  if (message.isImage && message.imageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        message.imageUrl!,
                        width: 200,
                        height: 200,
                        fit: BoxFit.cover,
                      ),
                    ),
                  if (message.isClothShare && message.clothId != null)
                    _ClothShareCard(
                      clothId: message.clothId!,
                      ownerId: message.clothOwnerId,
                      wardrobeId: message.clothWardrobeId,
                      isCurrentUser: isCurrentUser,
                    ),
                ],
              ),
            ),
          ),
          if (isCurrentUser && showAvatar) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[300],
              child: const Icon(Icons.person, size: 18),
            ),
          ],
        ],
      ),
    );
  }
}

/// Cloth share card widget for displaying shared clothes in chat
class _ClothShareCard extends StatefulWidget {
  final String clothId;
  final String? ownerId;
  final String? wardrobeId;
  final bool isCurrentUser;

  const _ClothShareCard({
    required this.clothId,
    this.ownerId,
    this.wardrobeId,
    required this.isCurrentUser,
  });

  @override
  State<_ClothShareCard> createState() => _ClothShareCardState();
}

class _ClothShareCardState extends State<_ClothShareCard> {
  Cloth? _cachedCloth;
  bool _isLoading = false;
  bool _hasError = false;
  static final Map<String, Cloth> _globalCache = {};
  static final Map<String, Future<Cloth?>> _loadingFutures = {};

  @override
  void initState() {
    super.initState();
    _loadCloth();
  }

  Future<void> _loadCloth() async {
    if (widget.ownerId == null || widget.wardrobeId == null) {
      return;
    }

    // Check global cache first
    final cacheKey = '${widget.ownerId}_${widget.wardrobeId}_${widget.clothId}';
    if (_globalCache.containsKey(cacheKey)) {
      if (mounted) {
        setState(() {
          _cachedCloth = _globalCache[cacheKey];
        });
      }
      return;
    }

    // Check if already loading
    if (_loadingFutures.containsKey(cacheKey)) {
      final cloth = await _loadingFutures[cacheKey];
      if (mounted && cloth != null) {
        setState(() {
          _cachedCloth = cloth;
          _globalCache[cacheKey] = cloth;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    // Create loading future
    final future = ClothService.getCloth(
      userId: widget.ownerId!,
      wardrobeId: widget.wardrobeId!,
      clothId: widget.clothId,
    );
    _loadingFutures[cacheKey] = future;

    try {
      final cloth = await future;
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (cloth != null) {
            _cachedCloth = cloth;
            _globalCache[cacheKey] = cloth;
          } else {
            _hasError = true;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    } finally {
      _loadingFutures.remove(cacheKey);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ownerId == null || widget.wardrobeId == null) {
      return _buildSimpleCard('Cloth shared');
    }

    if (_isLoading) {
      return _buildSimpleCard('Loading...', showLoader: true);
    }

    if (_hasError || _cachedCloth == null) {
      return _buildSimpleCard('Cloth shared');
    }

    final cloth = _cachedCloth!;

    return Container(
          constraints: const BoxConstraints(maxWidth: 280),
          decoration: BoxDecoration(
            color: widget.isCurrentUser
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isCurrentUser
                  ? Colors.white.withValues(alpha: 0.3)
                  : Colors.grey[300]!,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Cloth image thumbnail
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                child: Image.network(
                  cloth.imageUrl,
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 180,
                      color: Colors.grey[300],
                      child: Icon(
                        Icons.image_not_supported,
                        size: 48,
                        color: Colors.grey[600],
                      ),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 180,
                      color: Colors.grey[200],
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Cloth details
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Cloth type
                    Row(
                      children: [
                        Icon(
                          Icons.checkroom,
                          size: 16,
                          color: widget.isCurrentUser ? Colors.white70 : Colors.grey[700],
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            cloth.clothType,
                            style: TextStyle(
                              color: widget.isCurrentUser ? Colors.white : Colors.black87,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Season
                    Row(
                      children: [
                        Icon(
                          Icons.wb_sunny,
                          size: 16,
                          color: widget.isCurrentUser ? Colors.white70 : Colors.grey[700],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          cloth.season,
                          style: TextStyle(
                            color: widget.isCurrentUser ? Colors.white70 : Colors.grey[700],
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Category
                        Icon(
                          Icons.category,
                          size: 16,
                          color: widget.isCurrentUser ? Colors.white70 : Colors.grey[700],
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            cloth.category,
                            style: TextStyle(
                              color: widget.isCurrentUser ? Colors.white70 : Colors.grey[700],
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (cloth.occasions.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: cloth.occasions.take(2).map((occasion) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: widget.isCurrentUser
                                  ? Colors.white.withValues(alpha: 0.2)
                                  : Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              occasion,
                              style: TextStyle(
                                color: widget.isCurrentUser ? Colors.white : Colors.black87,
                                fontSize: 11,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
  }

  Widget _buildSimpleCard(String text, {bool showLoader = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isCurrentUser
            ? Colors.white.withValues(alpha: 0.2)
            : Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showLoader)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: widget.isCurrentUser ? Colors.white : Colors.black87,
              ),
            )
          else
            Icon(
              Icons.checkroom,
              size: 20,
              color: widget.isCurrentUser ? Colors.white : Colors.black87,
            ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: widget.isCurrentUser ? Colors.white : Colors.black87,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
