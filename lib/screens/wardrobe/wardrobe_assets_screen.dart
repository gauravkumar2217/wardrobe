import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/cloth.dart';
import '../../models/wardrobe.dart';
import '../../providers/auth_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/wardrobe_provider.dart';
import '../../services/cloth_service.dart';
import '../../theme/wardrobe_tokens.dart';
import '../../widgets/shell_back_button.dart';
import '../../utils/cloth_image_url.dart';
import '../../utils/open_clothes_feed.dart';
import '../cloth/add_cloth_flow_screen.dart';
import '../cloth/cloth_detail_screen.dart';

/// Grid view of all items in a wardrobe (thumbnail gallery).
class WardrobeAssetsScreen extends StatefulWidget {
  final Wardrobe wardrobe;
  final VoidCallback? onClose;

  const WardrobeAssetsScreen({
    super.key,
    required this.wardrobe,
    this.onClose,
  });

  @override
  State<WardrobeAssetsScreen> createState() => _WardrobeAssetsScreenState();
}

class _WardrobeAssetsScreenState extends State<WardrobeAssetsScreen> {
  List<Cloth> _clothes = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadClothes());
  }

  Future<void> _loadClothes() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.user?.uid;
    if (userId == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final clothes = await ClothService.getClothes(
        userId: userId,
        wardrobeId: widget.wardrobe.id,
      );
      if (!mounted) return;
      setState(() {
        _clothes = clothes;
        _isLoading = false;
      });

      final wardrobeProvider =
          Provider.of<WardrobeProvider>(context, listen: false);
      await wardrobeProvider.refreshWardrobeCount(
        userId: userId,
        wardrobeId: widget.wardrobe.id,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load items: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _openAddCloth() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddClothFlowScreen(wardrobeId: widget.wardrobe.id),
      ),
    );
    if (!mounted) return;
    await _loadClothes();
  }

  void _openSwipeFeedBackup() {
    final wardrobeProvider =
        Provider.of<WardrobeProvider>(context, listen: false);
    wardrobeProvider.setSelectedWardrobe(widget.wardrobe);

    final navigationProvider =
        Provider.of<NavigationProvider>(context, listen: false);
    openClothesFeed(navigationProvider);
  }

  String _imageFor(Cloth cloth) => ClothImageUrl.forCloth(cloth);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final auth = Provider.of<AuthProvider>(context);
    final userId = auth.user?.uid;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddCloth,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
            child: Row(
              children: [
                Expanded(
                  child: widget.onClose != null
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            tooltip: 'Back',
                            onPressed: widget.onClose,
                            style: IconButton.styleFrom(
                              foregroundColor: scheme.onSurface,
                              backgroundColor:
                                  scheme.surface.withValues(alpha: 0.65),
                            ),
                            icon: const Icon(Icons.arrow_back_rounded, size: 22),
                          ),
                        )
                      : const ShellBackButton(),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'swipe_feed') _openSwipeFeedBackup();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'swipe_feed',
                      child: Row(
                        children: [
                          Icon(Icons.swipe_rounded, size: 20),
                          SizedBox(width: 10),
                          Text('Swipe feed view'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              widget.wardrobe.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Text(
                    '${_clothes.length} item${_clothes.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                ),
                Expanded(child: _buildBody(scheme, userId)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ColorScheme scheme, String? userId) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: scheme.error),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.8)),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadClothes,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_clothes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary.withValues(alpha: 0.12),
                  border: Border.all(color: WardrobeTokens.outlineGold),
                ),
                child: Icon(
                  Icons.checkroom_outlined,
                  size: 40,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No items yet',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap + to add your first item to this wardrobe.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadClothes,
      color: scheme.primary,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.82,
        ),
        itemCount: _clothes.length,
        itemBuilder: (context, index) {
          final cloth = _clothes[index];
          return _ClothThumbnail(
            imageUrl: _imageFor(cloth),
            label: cloth.clothType,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ClothDetailScreen(
                    cloth: cloth,
                    isOwner: userId == cloth.ownerId,
                  ),
                ),
              );
              if (!mounted) return;
              await _loadClothes();
            },
          );
        },
      ),
    );
  }
}

class _ClothThumbnail extends StatelessWidget {
  final String imageUrl;
  final String label;
  final VoidCallback onTap;

  const _ClothThumbnail({
    required this.imageUrl,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: WardrobeTokens.outlineGold.withValues(alpha: 0.6),
            ),
            color: scheme.surface,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(11),
                  ),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: scheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        color: scheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: scheme.surfaceContainerHighest,
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(scheme.primary),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface.withValues(alpha: 0.85),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
