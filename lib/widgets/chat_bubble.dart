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
    // Debug logging for cloth share messages
    if (message.isClothShare) {
      debugPrint('👕 ChatBubble: Rendering cloth share message');
      debugPrint('   clothId: ${message.clothId}');
      debugPrint('   clothOwnerId: ${message.clothOwnerId}');
      debugPrint('   clothWardrobeId: ${message.clothWardrobeId}');
      debugPrint('   isCurrentUser: $isCurrentUser');
    }
    
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
                      child: CachedNetworkImage(
                        imageUrl: message.imageUrl!,
                        width: 200,
                        height: 200,
                        fit: BoxFit.cover,
                        memCacheWidth: 400, // Resize to reduce memory usage
                        placeholder: (context, url) => Container(
                          width: 200,
                          height: 200,
                          color: Colors.grey[200],
                          child: const Center(child: CircularProgressIndicator()),
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
                      clothId: message.clothId!,
                      ownerId: message.clothOwnerId,
                      wardrobeId: message.clothWardrobeId,
                      isCurrentUser: isCurrentUser,
                    )
                  else if (message.isClothShare && message.clothId == null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      child: const Text(
                        'Cloth shared (missing ID)',
                        style: TextStyle(color: Colors.red),
                      ),
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
    debugPrint('🚀 ClothShareCard: initState called');
    debugPrint('   ownerId: ${widget.ownerId}');
    debugPrint('   wardrobeId: ${widget.wardrobeId}');
    debugPrint('   clothId: ${widget.clothId}');
    // Defer loading to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('📋 ClothShareCard: PostFrameCallback executing');
      if (mounted) {
        _loadCloth();
      } else {
        debugPrint('⚠️ ClothShareCard: Widget not mounted, skipping load');
      }
    });
  }
  
  @override
  void didUpdateWidget(_ClothShareCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload if clothId, ownerId, or wardrobeId changed
    if (oldWidget.clothId != widget.clothId ||
        oldWidget.ownerId != widget.ownerId ||
        oldWidget.wardrobeId != widget.wardrobeId) {
      debugPrint('🔄 ClothShareCard: Widget updated, reloading cloth');
      _cachedCloth = null;
      _hasError = false;
      _isLoading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadCloth();
        }
      });
    }
  }

  Future<void> _loadCloth() async {
    if (widget.ownerId == null || widget.wardrobeId == null) {
      debugPrint('❌ ClothShareCard: Missing ownerId or wardrobeId');
      debugPrint('   ownerId: ${widget.ownerId}');
      debugPrint('   wardrobeId: ${widget.wardrobeId}');
      debugPrint('   clothId: ${widget.clothId}');
      return;
    }

    debugPrint('📦 ClothShareCard: Loading cloth');
    debugPrint('   ownerId: ${widget.ownerId}');
    debugPrint('   wardrobeId: ${widget.wardrobeId}');
    debugPrint('   clothId: ${widget.clothId}');

    // Check global cache first
    final cacheKey = '${widget.ownerId}_${widget.wardrobeId}_${widget.clothId}';
    if (_globalCache.containsKey(cacheKey)) {
      debugPrint('✅ ClothShareCard: Found in cache');
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _cachedCloth = _globalCache[cacheKey];
            });
          }
        });
      }
      return;
    }

    // Check if already loading
    if (_loadingFutures.containsKey(cacheKey)) {
      debugPrint('⏳ ClothShareCard: Already loading, waiting...');
      final cloth = await _loadingFutures[cacheKey];
      if (mounted && cloth != null) {
        debugPrint('✅ ClothShareCard: Loaded from existing future');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _cachedCloth = cloth;
              _globalCache[cacheKey] = cloth;
            });
          }
        });
      }
      return;
    }

    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isLoading = true;
            _hasError = false;
          });
        }
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
      debugPrint('🔄 ClothShareCard: Fetching cloth from service...');
      final cloth = await future;
      debugPrint('📥 ClothShareCard: Received response');
      debugPrint('   cloth: ${cloth != null ? "✅ Found" : "❌ Null"}');
      
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              if (cloth != null) {
                debugPrint('✅ ClothShareCard: Cloth loaded successfully');
                debugPrint('   clothType: ${cloth.clothType}');
                debugPrint('   imageUrl: ${cloth.imageUrl.isNotEmpty ? "✅ Has image" : "❌ No image"}');
                _cachedCloth = cloth;
                _globalCache[cacheKey] = cloth;
              } else {
                debugPrint('❌ ClothShareCard: Cloth is null');
                _hasError = true;
              }
            });
          }
        });
      }
    } catch (e, stackTrace) {
      debugPrint('❌ ClothShareCard: Error loading cloth');
      debugPrint('   Error: $e');
      debugPrint('   StackTrace: $stackTrace');
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _hasError = true;
            });
          }
        });
      }
    } finally {
      _loadingFutures.remove(cacheKey);
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🎨 ClothShareCard: Building widget');
    debugPrint('   ownerId: ${widget.ownerId}');
    debugPrint('   wardrobeId: ${widget.wardrobeId}');
    debugPrint('   clothId: ${widget.clothId}');
    debugPrint('   isLoading: $_isLoading');
    debugPrint('   hasError: $_hasError');
    debugPrint('   cachedCloth: ${_cachedCloth != null ? "✅ Has cloth" : "❌ No cloth"}');
    
    if (widget.ownerId == null || widget.wardrobeId == null) {
      debugPrint('⚠️ ClothShareCard: Missing ownerId or wardrobeId, showing simple card');
      return _buildSimpleCard('Cloth shared');
    }

    // If we have an error but haven't tried loading yet, try loading
    if (_hasError && !_isLoading && _cachedCloth == null) {
      debugPrint('🔄 ClothShareCard: Had error, retrying load...');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _hasError = false;
          _loadCloth();
        }
      });
    }

    if (_isLoading) {
      debugPrint('⏳ ClothShareCard: Still loading, showing loader');
      return _buildSimpleCard('Loading...', showLoader: true);
    }

    if (_hasError || _cachedCloth == null) {
      debugPrint('❌ ClothShareCard: Error or null cloth, showing simple card');
      debugPrint('   hasError: $_hasError');
      debugPrint('   cachedCloth is null: ${_cachedCloth == null}');
      // Show a clickable card that will try to load when tapped
      return GestureDetector(
        onTap: () {
          debugPrint('👆 ClothShareCard: Tapped, retrying load...');
          setState(() {
            _hasError = false;
            _isLoading = true;
          });
          _loadCloth();
        },
        child: _buildSimpleCard('Tap to load cloth'),
      );
    }

    final cloth = _cachedCloth!;
    debugPrint('✅ ClothShareCard: Rendering full cloth card');
    debugPrint('   clothType: ${cloth.clothType}');
    debugPrint('   imageUrl length: ${cloth.imageUrl.length}');

    // Make the card look the same for both users (consistent styling)
    return Container(
          constraints: const BoxConstraints(maxWidth: 280),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey[300]!,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
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
                child: CachedNetworkImage(
                  imageUrl: cloth.imageUrl,
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                  memCacheWidth: 400, // Resize to reduce memory usage
                  placeholder: (context, url) => Container(
                    height: 180,
                    color: Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 180,
                    color: Colors.grey[300],
                    child: const Icon(
                      Icons.image_not_supported,
                      size: 48,
                      color: Colors.grey,
                    ),
                  ),
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
                          color: Colors.grey[700],
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            cloth.clothType,
                            style: const TextStyle(
                              color: Colors.black87,
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
                          color: Colors.grey[700],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          cloth.season,
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Category
                        Icon(
                          Icons.category,
                          size: 16,
                          color: Colors.grey[700],
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            cloth.category,
                            style: TextStyle(
                              color: Colors.grey[700],
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
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              occasion,
                              style: const TextStyle(
                                color: Colors.black87,
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
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.black87,
              ),
            )
          else
            Icon(
              Icons.checkroom,
              size: 20,
              color: Colors.black87,
            ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
