import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Row(
        mainAxisAlignment:
            isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isCurrentUser && showAvatar) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: Colors.grey[300],
              child: const Icon(Icons.person, size: 16),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isCurrentUser
                    ? Theme.of(context).primaryColor
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomRight: isCurrentUser
                      ? const Radius.circular(4)
                      : const Radius.circular(16),
                  bottomLeft: isCurrentUser
                      ? const Radius.circular(16)
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
                        fontSize: 13,
                      ),
                    ),
                  if (message.isImage && message.imageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: message.imageUrl!,
                        width: 200,
                        height: 200,
                        fit: BoxFit.cover,
                        memCacheWidth: 400,
                        placeholder: (context, url) => Container(
                          width: 200,
                          height: 200,
                          color: Colors.grey[200],
                          child: const Center(
                              child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 200,
                          height: 200,
                          color: Colors.grey[300],
                          child: const Icon(Icons.error),
                        ),
                      ),
                    ),
                  if (message.isClothShare && message.clothId != null)
                    _ClothShareCard(
                      key: ValueKey('cloth_share_${message.clothId}'),
                      clothId: message.clothId!,
                      ownerId: message.clothOwnerId,
                      wardrobeId: message.clothWardrobeId,
                    )
                  else if (message.isClothShare)
                    _buildFallbackChip('Shared item'),
                ],
              ),
            ),
          ),
          if (isCurrentUser && showAvatar) ...[
            const SizedBox(width: 6),
            CircleAvatar(
              radius: 14,
              backgroundColor: Colors.grey[300],
              child: const Icon(Icons.person, size: 16),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFallbackChip(String text) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.checkroom, size: 20, color: Colors.black87),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Colors.black87, fontSize: 13)),
        ],
      ),
    );
  }
}

/// Loads a shared cloth by id (Laravel). Safe against rebuild / load races.
class _ClothShareCard extends StatefulWidget {
  final String clothId;
  final String? ownerId;
  final String? wardrobeId;

  const _ClothShareCard({
    super.key,
    required this.clothId,
    this.ownerId,
    this.wardrobeId,
  });

  @override
  State<_ClothShareCard> createState() => _ClothShareCardState();
}

class _ClothShareCardState extends State<_ClothShareCard> {
  Cloth? _cloth;
  bool _isLoading = true;
  bool _hasError = false;

  static final Map<String, Cloth> _cache = {};
  static final Map<String, Future<Cloth?>> _inflight = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_ClothShareCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clothId != widget.clothId) {
      _cloth = null;
      _hasError = false;
      _isLoading = true;
      _load();
    }
  }

  Future<void> _load() async {
    final id = widget.clothId;
    final cached = _cache[id];
    if (cached != null) {
      if (!mounted) return;
      setState(() {
        _cloth = cached;
        _isLoading = false;
        _hasError = false;
      });
      return;
    }

    final future = _inflight.putIfAbsent(id, () {
      final owner = widget.ownerId ?? '';
      final wardrobe = widget.wardrobeId ?? '';
      return ClothService.getCloth(
        userId: owner,
        wardrobeId: wardrobe,
        clothId: id,
      ).whenComplete(() => _inflight.remove(id));
    });

    try {
      final cloth = await future;
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (cloth != null) {
          _cloth = cloth;
          _cache[id] = cloth;
          _hasError = false;
        } else {
          _cloth = null;
          _hasError = true;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
        _cloth = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _chip('Loading…', showLoader: true);
    }

    if (_hasError || _cloth == null) {
      return GestureDetector(
        onTap: () {
          setState(() {
            _isLoading = true;
            _hasError = false;
          });
          _inflight.remove(widget.clothId);
          _load();
        },
        child: _chip('Shared item unavailable'),
      );
    }

    final cloth = _cloth!;
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: CachedNetworkImage(
              imageUrl: cloth.imageUrl,
              width: double.infinity,
              height: 140,
              fit: BoxFit.cover,
              memCacheWidth: 400,
              placeholder: (context, url) => Container(
                height: 140,
                color: Colors.grey[200],
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => Container(
                height: 140,
                color: Colors.grey[300],
                child: const Icon(Icons.image_not_supported, size: 36),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cloth.clothType,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${cloth.season} · ${cloth.category}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, {bool showLoader = false}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showLoader)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            const Icon(Icons.checkroom, size: 20, color: Colors.black87),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(color: Colors.black87, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
