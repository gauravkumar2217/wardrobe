import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cloth_provider.dart';
import '../../models/avatar.dart' as avatar_model show Avatar;
import '../../models/cloth.dart';
import '../../models/tryon_outfit.dart';
import '../../services/user_service.dart';
import '../../services/tryon_2d_service.dart';
import '../../widgets/avatar_2d_display_widget.dart';

/// Changing room: Gemini try-on on your avatar; tap wardrobe thumbnails to try items.
class ChangingRoomScreen extends StatefulWidget {
  const ChangingRoomScreen({super.key});

  @override
  State<ChangingRoomScreen> createState() => _ChangingRoomScreenState();
}

class _ChangingRoomScreenState extends State<ChangingRoomScreen> {
  avatar_model.Avatar? _avatar;
  TryOnOutfit _currentOutfit = TryOnOutfit();

  /// `all` | `tops` | `bottoms` | `shoes` | `accessories`
  String _clothFilter = 'all';
  String? _activeTryOnClothId;

  bool _isLoading = true;
  String? _tryOnResultUrl;
  bool _isGeneratingTryOn = false;

  static const Color _brand = Color(0xFF043915);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadBodyProfile();
      await _loadClothes();
    });
  }

  Future<void> _loadBodyProfile() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final avatar = await UserService.getAvatar(authProvider.user!.uid);
      if (mounted) {
        setState(() {
          _avatar = avatar;
        });
      }
    } catch (e) {
      debugPrint('Error loading avatar: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadClothes() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final clothProvider = Provider.of<ClothProvider>(context, listen: false);
    if (authProvider.user == null) return;
    try {
      await clothProvider.loadClothes(userId: authProvider.user!.uid);
    } catch (e) {
      debugPrint('Error loading clothes: $e');
    }
  }

  bool _isTryOnEligible(Cloth c) {
    final k = c.itemKind.toLowerCase();
    return k == 'cloth' || k == 'footwear' || k == 'accessories';
  }

  bool _isShirtType(String type) {
    final t = type.toLowerCase();
    return [
      'shirt',
      't-shirt',
      'top',
      'blouse',
      'sweater',
      'hoodie',
      'dress',
      'jacket',
      'coat',
      'blazer',
      'cardigan',
      'vest',
      'kurta',
      'tank',
      'polo',
    ].contains(t);
  }

  bool _isPantsType(String type) {
    final t = type.toLowerCase();
    return [
      'pants',
      'trousers',
      'jeans',
      'shorts',
      'leggings',
      'skirt',
      'cargo',
    ].contains(t);
  }

  bool _isShoesType(String type) {
    final t = type.toLowerCase();
    return [
      'shoes',
      'sneakers',
      'boots',
      'sandals',
      'heels',
      'footwear',
      'loafers',
      'flats',
    ].contains(t);
  }

  bool _isAccessoryType(String type) {
    final t = type.toLowerCase();
    return [
      'accessory',
      'bag',
      'hat',
      'watch',
      'jewelry',
      'belt',
      'scarf',
    ].contains(t);
  }

  /// Outfit map key: shirt | pants | shoes | accessory
  String _outfitCategoryKey(Cloth c) {
    if (_isShirtType(c.clothType)) return 'shirt';
    if (_isPantsType(c.clothType)) return 'pants';
    if (_isShoesType(c.clothType)) return 'shoes';
    if (_isAccessoryType(c.clothType)) return 'accessory';
    return 'shirt';
  }

  void _applyOutfitSlot(Cloth item, String categoryKey) {
    final items = Map<String, Cloth?>.from(_currentOutfit.items);
    items[categoryKey] = item;
    switch (categoryKey) {
      case 'shirt':
        _currentOutfit = _currentOutfit.copyWith(
          shirtId: item.id,
          items: items,
        );
        break;
      case 'pants':
        _currentOutfit = _currentOutfit.copyWith(
          pantsId: item.id,
          items: items,
        );
        break;
      case 'shoes':
        _currentOutfit = _currentOutfit.copyWith(
          shoesId: item.id,
          items: items,
        );
        break;
      case 'accessory':
        _currentOutfit = _currentOutfit.copyWith(
          accessoryId: item.id,
          items: items,
        );
        break;
      default:
        _currentOutfit = _currentOutfit.copyWith(items: items);
    }
  }

  List<Cloth> _filteredClothes(List<Cloth> all) {
    final base = all.where(_isTryOnEligible).toList();
    switch (_clothFilter) {
      case 'tops':
        return base.where((c) => _isShirtType(c.clothType)).toList();
      case 'bottoms':
        return base.where((c) => _isPantsType(c.clothType)).toList();
      case 'shoes':
        return base.where((c) => _isShoesType(c.clothType)).toList();
      case 'accessories':
        return base.where((c) => _isAccessoryType(c.clothType)).toList();
      default:
        return base;
    }
  }

  Future<void> _selectClothForTryOn(Cloth item) async {
    if (_avatar == null || _avatar!.avatarImageUrl == null) return;

    final categoryKey = _outfitCategoryKey(item);
    setState(() {
      _activeTryOnClothId = item.id;
      _applyOutfitSlot(item, categoryKey);
    });

    await _generateTryOn(item);
  }

  Future<void> _generateTryOn(Cloth item) async {
    if (_avatar == null || _avatar!.avatarImageUrl == null) return;

    setState(() {
      _isGeneratingTryOn = true;
      _tryOnResultUrl = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user == null) return;

      final resultUrl = await TryOn2DService.createTryOnFromCloth(
        userId: authProvider.user!.uid,
        avatarUrl: _avatar!.avatarImageUrl!,
        cloth: item,
      );

      if (mounted) {
        setState(() {
          _tryOnResultUrl = resultUrl;
          _isGeneratingTryOn = false;
        });
      }
    } catch (e) {
      debugPrint('Error generating try-on: $e');
      if (mounted) {
        setState(() => _isGeneratingTryOn = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Try-on failed: $e')),
        );
      }
    }
  }

  void _clearTryOnResult() {
    setState(() {
      _tryOnResultUrl = null;
      _activeTryOnClothId = null;
    });
  }

  void _shuffleOutfitIdeas() {
    final clothProvider = Provider.of<ClothProvider>(context, listen: false);
    final clothes =
        clothProvider.clothes.where(_isTryOnEligible).toList();
    if (clothes.isEmpty) return;

    final random = DateTime.now().millisecondsSinceEpoch;
    Cloth? shirt;
    Cloth? pantsItem;
    Cloth? shoesItem;
    Cloth? accessory;

    final shirts = clothes.where((c) => _isShirtType(c.clothType)).toList();
    final pants = clothes.where((c) => _isPantsType(c.clothType)).toList();
    final shoes = clothes.where((c) => _isShoesType(c.clothType)).toList();
    final acc = clothes.where((c) => _isAccessoryType(c.clothType)).toList();

    if (shirts.isNotEmpty) shirt = shirts[random % shirts.length];
    if (pants.isNotEmpty) pantsItem = pants[random % pants.length];
    if (shoes.isNotEmpty) shoesItem = shoes[random % shoes.length];
    if (acc.isNotEmpty) accessory = acc[random % acc.length];

    setState(() {
      _currentOutfit = TryOnOutfit(
        shirtId: shirt?.id,
        pantsId: pantsItem?.id,
        shoesId: shoesItem?.id,
        accessoryId: accessory?.id,
        items: {
          if (shirt != null) 'shirt': shirt,
          if (pantsItem != null) 'pants': pantsItem,
          if (shoesItem != null) 'shoes': shoesItem,
          if (accessory != null) 'accessory': accessory,
        },
      );
      _tryOnResultUrl = null;
      _activeTryOnClothId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Changing Room'),
          backgroundColor: _brand,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_avatar == null || !_avatar!.isGenerated) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Changing Room'),
          backgroundColor: _brand,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.face_retouching_natural,
                    size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'Avatar required',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create your avatar in Profile first. Then you can try any wardrobe item here with AI.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[700], fontSize: 14),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final clothProvider = context.watch<ClothProvider>();
    final filtered = _filteredClothes(clothProvider.clothes);
    final w = MediaQuery.sizeOf(context).width;
    final heroHeight = MediaQuery.sizeOf(context).height * 0.48;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Changing Room'),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Show avatar only',
            onPressed: _tryOnResultUrl != null ? _clearTryOnResult : null,
          ),
          IconButton(
            icon: const Icon(Icons.shuffle),
            tooltip: 'Shuffle outfit ideas (highlights only)',
            onPressed: clothProvider.clothes.isEmpty ? null : _shuffleOutfitIdeas,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Tap a thumbnail to try it on your avatar (Gemini AI)',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[800],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFECEFF1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_tryOnResultUrl != null)
                      InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 3,
                        child: Center(
                          child: CachedNetworkImage(
                            imageUrl: _tryOnResultUrl!,
                            fit: BoxFit.contain,
                            placeholder: (_, __) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            errorWidget: (_, __, ___) => const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 48,
                            ),
                          ),
                        ),
                      )
                    else
                      Center(
                        child: Avatar2DDisplayWidget(
                          avatar: _avatar,
                          width: w * 0.88,
                          height: heroHeight,
                          fit: BoxFit.contain,
                          backgroundColor: Colors.transparent,
                        ),
                      ),
                    if (_isGeneratingTryOn)
                      Container(
                        color: Colors.black38,
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: Colors.white),
                              SizedBox(height: 12),
                              Text(
                                'Fitting outfit with AI…',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _FilterChip(
                    label: 'All',
                    selected: _clothFilter == 'all',
                    onTap: () => setState(() => _clothFilter = 'all'),
                  ),
                  _FilterChip(
                    label: 'Tops',
                    selected: _clothFilter == 'tops',
                    onTap: () => setState(() => _clothFilter = 'tops'),
                  ),
                  _FilterChip(
                    label: 'Bottoms',
                    selected: _clothFilter == 'bottoms',
                    onTap: () => setState(() => _clothFilter = 'bottoms'),
                  ),
                  _FilterChip(
                    label: 'Shoes',
                    selected: _clothFilter == 'shoes',
                    onTap: () => setState(() => _clothFilter = 'shoes'),
                  ),
                  _FilterChip(
                    label: 'Accessories',
                    selected: _clothFilter == 'accessories',
                    onTap: () => setState(() => _clothFilter = 'accessories'),
                  ),
                ],
              ),
            ),
            Container(
              height: 132,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        clothProvider.clothes.isEmpty
                            ? 'No clothes loaded yet'
                            : 'No items match this filter',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final thumbUrl =
                            item.processedImageUrl ?? item.imageUrl;
                        final selected = _activeTryOnClothId == item.id;
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: GestureDetector(
                            onTap: () => _selectClothForTryOn(item),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 86,
                                  height: 86,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: selected
                                          ? _brand
                                          : Colors.grey.shade400,
                                      width: selected ? 3 : 1,
                                    ),
                                    boxShadow: selected
                                        ? [
                                            BoxShadow(
                                              color: _brand.withValues(
                                                  alpha: 0.25),
                                              blurRadius: 8,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      CachedNetworkImage(
                                        imageUrl: thumbUrl,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) => Container(
                                          color: Colors.grey.shade200,
                                          child: const Center(
                                            child: SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            ),
                                          ),
                                        ),
                                        errorWidget: (_, __, ___) => Container(
                                          color: Colors.grey.shade200,
                                          child: const Icon(
                                              Icons.checkroom_outlined),
                                        ),
                                      ),
                                      if (selected)
                                        Container(
                                          alignment: Alignment.topRight,
                                          padding: const EdgeInsets.all(4),
                                          child: const Icon(
                                            Icons.auto_awesome,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                SizedBox(
                                  width: 86,
                                  child: Text(
                                    item.clothType,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: selected
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      color: selected
                                          ? _brand
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected
            ? const Color(0xFF043915)
            : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
