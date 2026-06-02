import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/cloth.dart';

/// Enhanced clothing selector widget with category-based selection
/// Supports multi-select for layering multiple items
class ClothingSelectorWidget extends StatefulWidget {
  final List<Cloth> allItems;
  final List<Cloth> selectedItems;
  final Function(List<Cloth>) onSelectionChanged;
  final bool multiSelect;
  final String? selectedCategory;

  const ClothingSelectorWidget({
    super.key,
    required this.allItems,
    required this.selectedItems,
    required this.onSelectionChanged,
    this.multiSelect = false,
    this.selectedCategory,
  });

  @override
  State<ClothingSelectorWidget> createState() => _ClothingSelectorWidgetState();
}

class _ClothingSelectorWidgetState extends State<ClothingSelectorWidget> {
  String? _selectedCategory;
  final Map<String, List<Cloth>> _itemsByCategory = {};

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.selectedCategory;
    _organizeItemsByCategory();
  }

  void _organizeItemsByCategory() {
    _itemsByCategory.clear();
    
    // Organize by itemKind (cloth, footwear, accessories)
    for (final item in widget.allItems) {
      final category = item.itemKind;
      if (!_itemsByCategory.containsKey(category)) {
        _itemsByCategory[category] = [];
      }
      _itemsByCategory[category]!.add(item);
    }

    // Also organize by clothType for more granular selection
    for (final item in widget.allItems) {
      final type = item.clothType.toLowerCase();
      if (!_itemsByCategory.containsKey(type)) {
        _itemsByCategory[type] = [];
      }
      _itemsByCategory[type]!.add(item);
    }
  }

  List<Cloth> get _currentItems {
    if (_selectedCategory != null && _itemsByCategory.containsKey(_selectedCategory)) {
      return _itemsByCategory[_selectedCategory]!;
    }
    return widget.allItems;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Category selector
        _buildCategorySelector(),

        // Items grid
        Expanded(
          child: _currentItems.isEmpty
              ? _buildEmptyState()
              : _buildItemsGrid(),
        ),
      ],
    );
  }

  Widget _buildCategorySelector() {
    final categories = ['All', ..._itemsByCategory.keys.toList()];

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = _selectedCategory == category || 
              (category == 'All' && _selectedCategory == null);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = category == 'All' ? null : category;
                });
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.checkroom, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            'No items in this category',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.75,
      ),
      itemCount: _currentItems.length,
      itemBuilder: (context, index) {
        final item = _currentItems[index];
        final isSelected = widget.selectedItems.any((i) => i.id == item.id);

        return GestureDetector(
          onTap: () => _handleItemTap(item, isSelected),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[300]!,
                width: isSelected ? 3 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Item image
                ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: CachedNetworkImage(
                    imageUrl: item.processedImageUrl ?? item.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.image_not_supported),
                    ),
                  ),
                ),

                // Selected indicator
                if (isSelected)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),

                // Item type label
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(7),
                      ),
                    ),
                    child: Text(
                      item.clothType,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleItemTap(Cloth item, bool isSelected) {
    if (widget.multiSelect) {
      // Multi-select mode
      final newSelection = List<Cloth>.from(widget.selectedItems);
      if (isSelected) {
        newSelection.removeWhere((i) => i.id == item.id);
      } else {
        // Check if item type conflicts with existing selection
        // (e.g., can't wear two shirts at once)
        final conflictingType = _getConflictingType(item.itemKind);
        if (conflictingType != null) {
          newSelection.removeWhere((i) => _getConflictingType(i.itemKind) == conflictingType);
        }
        newSelection.add(item);
      }
      widget.onSelectionChanged(newSelection);
    } else {
      // Single-select mode
      widget.onSelectionChanged([item]);
    }
  }

  String? _getConflictingType(String itemKind) {
    // Items that conflict (can't wear multiple of same type)
    const conflictingTypes = ['cloth', 'footwear'];
    return conflictingTypes.contains(itemKind) ? itemKind : null;
  }
}
