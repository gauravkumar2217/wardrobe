import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cloth_provider.dart';
import '../../models/body_profile.dart';
import '../../models/cloth.dart';
import '../../models/tryon_outfit.dart';
import '../../services/user_service.dart';
import '../../widgets/body_with_clothes_widget.dart';
import '../../widgets/item_selector_widget.dart';

/// Changing room screen for virtual try-on
class ChangingRoomScreen extends StatefulWidget {
  const ChangingRoomScreen({super.key});

  @override
  State<ChangingRoomScreen> createState() => _ChangingRoomScreenState();
}

class _ChangingRoomScreenState extends State<ChangingRoomScreen> {
  BodyProfile? _bodyProfile;
  TryOnOutfit _currentOutfit = TryOnOutfit();
  String? _selectedCategory; // 'shirt', 'pants', 'shoes', 'accessory'
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Defer async work that triggers provider notifications until
    // after the first frame to avoid setState/notifyListeners during build.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadBodyProfile();
      await _loadClothes();
      _generateRandomOutfit();
    });
  }

  Future<void> _loadBodyProfile() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final bodyProfile = await UserService.getBodyProfile(authProvider.user!.uid);
      if (mounted) {
        setState(() {
          _bodyProfile = bodyProfile;
        });
      }
    } catch (e) {
      debugPrint('Error loading body profile: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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

  void _generateRandomOutfit() {
    final clothProvider = Provider.of<ClothProvider>(context, listen: false);
    final clothes = clothProvider.clothes;

    if (clothes.isEmpty) return;

    // Get items by category
    final shirts = clothes.where((c) => _isShirtType(c.clothType)).toList();
    final pants = clothes.where((c) => _isPantsType(c.clothType)).toList();
    final shoes = clothes.where((c) => _isShoesType(c.clothType)).toList();
    final accessories = clothes.where((c) => _isAccessoryType(c.clothType)).toList();

    // Select random items
    final random = DateTime.now().millisecondsSinceEpoch;
    Cloth? shirt;
    Cloth? pantsItem;
    Cloth? shoesItem;
    Cloth? accessory;

    if (shirts.isNotEmpty) {
      shirt = shirts[random % shirts.length];
    }
    if (pants.isNotEmpty) {
      pantsItem = pants[random % pants.length];
    }
    if (shoes.isNotEmpty) {
      shoesItem = shoes[random % shoes.length];
    }
    if (accessories.isNotEmpty) {
      accessory = accessories[random % accessories.length];
    }

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
    });
  }

  bool _isShirtType(String type) {
    return ['shirt', 't-shirt', 'top', 'blouse', 'sweater', 'hoodie']
        .contains(type.toLowerCase());
  }

  bool _isPantsType(String type) {
    return ['pants', 'trousers', 'jeans', 'shorts', 'leggings']
        .contains(type.toLowerCase());
  }

  bool _isShoesType(String type) {
    return ['shoes', 'sneakers', 'boots', 'sandals', 'heels']
        .contains(type.toLowerCase());
  }

  bool _isAccessoryType(String type) {
    return ['accessory', 'bag', 'hat', 'watch', 'jewelry', 'belt']
        .contains(type.toLowerCase());
  }

  List<Cloth> _getItemsByCategory(String category) {
    final clothProvider = Provider.of<ClothProvider>(context, listen: false);
    final clothes = clothProvider.clothes;
    List<Cloth> filtered;
    switch (category) {
      case 'shirt':
        filtered = clothes.where((c) => _isShirtType(c.clothType)).toList();
        break;
      case 'pants':
        filtered = clothes.where((c) => _isPantsType(c.clothType)).toList();
        break;
      case 'shoes':
        filtered = clothes.where((c) => _isShoesType(c.clothType)).toList();
        break;
      case 'accessory':
        filtered = clothes.where((c) => _isAccessoryType(c.clothType)).toList();
        break;
      default:
        filtered = [];
    }

    // If no items match the specific category, fall back to showing all clothes
    // so the user can still try items on in the changing room.
    return filtered.isNotEmpty ? filtered : clothes;
  }

  void _onItemCategoryTapped(String category) {
    setState(() {
      _selectedCategory = _selectedCategory == category ? null : category;
    });
  }

  void _onItemSelected(Cloth item) {
    setState(() {
      final category = _selectedCategory ?? 'shirt';
      _currentOutfit = _currentOutfit.copyWith(
        items: {
          ..._currentOutfit.items,
          category: item,
        },
      );

      // Update specific ID based on category
      switch (category) {
        case 'shirt':
          _currentOutfit = _currentOutfit.copyWith(shirtId: item.id);
          break;
        case 'pants':
          _currentOutfit = _currentOutfit.copyWith(pantsId: item.id);
          break;
        case 'shoes':
          _currentOutfit = _currentOutfit.copyWith(shoesId: item.id);
          break;
        case 'accessory':
          _currentOutfit = _currentOutfit.copyWith(accessoryId: item.id);
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Changing Room'),
          backgroundColor: const Color(0xFF043915),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_bodyProfile == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Changing Room'),
          backgroundColor: const Color(0xFF043915),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Body profile required',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please scan your body profile first',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go to Profile'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Changing Room'),
        backgroundColor: const Color(0xFF043915),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _generateRandomOutfit,
            tooltip: 'Random Outfit',
          ),
        ],
      ),
      body: Column(
        children: [
          // Body with clothes display
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: BodyWithClothesWidget(
                  bodyProfile: _bodyProfile,
                  shirt: _currentOutfit.items['shirt'],
                  pants: _currentOutfit.items['pants'],
                  shoes: _currentOutfit.items['shoes'],
                  accessory: _currentOutfit.items['accessory'],
                  width: MediaQuery.of(context).size.width * 0.6,
                  height: MediaQuery.of(context).size.height * 0.5,
                ),
              ),
            ),
          ),

          // Category buttons
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _CategoryButton(
                  label: 'Shirt',
                  icon: Icons.checkroom,
                  isSelected: _selectedCategory == 'shirt',
                  onTap: () => _onItemCategoryTapped('shirt'),
                ),
                _CategoryButton(
                  label: 'Pants',
                  icon: Icons.checkroom,
                  isSelected: _selectedCategory == 'pants',
                  onTap: () => _onItemCategoryTapped('pants'),
                ),
                _CategoryButton(
                  label: 'Shoes',
                  icon: Icons.checkroom,
                  isSelected: _selectedCategory == 'shoes',
                  onTap: () => _onItemCategoryTapped('shoes'),
                ),
                _CategoryButton(
                  label: 'Accessory',
                  icon: Icons.checkroom,
                  isSelected: _selectedCategory == 'accessory',
                  onTap: () => _onItemCategoryTapped('accessory'),
                ),
              ],
            ),
          ),

          // Item selector (shows when category is selected)
          if (_selectedCategory != null)
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border(
                  top: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Select ${_selectedCategory!.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ItemSelectorWidget(
                      items: _getItemsByCategory(_selectedCategory!),
                      selectedItem: _currentOutfit.items[_selectedCategory!],
                      onItemSelected: _onItemSelected,
                      category: _selectedCategory!,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.black87,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
