import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/cloth.dart';
import '../../providers/cloth_provider.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../providers/wardrobe_provider.dart';
import '../../services/tag_list_service.dart';
import '../../models/wardrobe.dart';

/// Edit cloth screen
class EditClothScreen extends StatefulWidget {
  final Cloth cloth;
  final String wardrobeId;

  const EditClothScreen({
    super.key,
    required this.cloth,
    required this.wardrobeId,
  });

  @override
  State<EditClothScreen> createState() => _EditClothScreenState();
}

class _EditClothScreenState extends State<EditClothScreen> {
  final _formKey = GlobalKey<FormState>();
  
  String? _selectedClothType;
  String _selectedPrimaryColor = '';
  String? _selectedSecondaryColor;
  List<String> _selectedColors = [];
  String? _selectedSeason;
  String? _selectedPlacement;
  String? _selectedCategory;
  List<String> _selectedOccasions = [];
  String? _selectedWardrobeId;
  List<Wardrobe> _wardrobes = [];
  bool _isLoadingWardrobes = true;
  
  bool _isUpdating = false;
  bool _isLoadingTags = true;

  @override
  void initState() {
    super.initState();
    _loadTagLists();
    _loadWardrobes();
    _initializeFields();
  }

  void _initializeFields() {
    _selectedClothType = widget.cloth.clothType;
    _selectedSeason = widget.cloth.season;
    _selectedPlacement = widget.cloth.placement;
    _selectedCategory = widget.cloth.category;
    _selectedOccasions = List<String>.from(widget.cloth.occasions);
    _selectedWardrobeId = widget.cloth.wardrobeId;
    
    final colorTags = widget.cloth.colorTags;
    _selectedPrimaryColor = colorTags.primary;
    _selectedSecondaryColor = colorTags.secondary;
    _selectedColors = List<String>.from(colorTags.colors);
  }

  Future<void> _loadWardrobes() async {
    final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
    final wardrobeProvider = Provider.of<WardrobeProvider>(context, listen: false);
    
    if (authProvider.user != null) {
      await wardrobeProvider.loadWardrobes(authProvider.user!.uid);
      if (mounted) {
        setState(() {
          _wardrobes = wardrobeProvider.wardrobes;
          _isLoadingWardrobes = false;
        });
      }
    }
  }

  Future<void> _loadTagLists() async {
    try {
      await TagListService.fetchTagLists();
      if (mounted) {
        setState(() {
          _isLoadingTags = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingTags = false;
        });
      }
    }
  }

  Future<void> _updateCloth() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedOccasions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one occasion')),
      );
      return;
    }

    final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;

    setState(() {
      _isUpdating = true;
    });

    final clothProvider = Provider.of<ClothProvider>(context, listen: false);

    try {
      final colors = _selectedColors.isNotEmpty
          ? _selectedColors
          : (_selectedPrimaryColor.isNotEmpty ? [_selectedPrimaryColor] : ['Unknown']);
      
      final colorTags = ColorTags(
        primary: _selectedPrimaryColor.isNotEmpty ? _selectedPrimaryColor : colors.first,
        secondary: _selectedSecondaryColor,
        colors: colors,
        isMultiColor: colors.length > 1,
      );

      final updatedCloth = widget.cloth.copyWith(
        clothType: _selectedClothType,
        season: _selectedSeason,
        placement: _selectedPlacement,
        category: _selectedCategory,
        occasions: _selectedOccasions,
        colorTags: colorTags,
        updatedAt: DateTime.now(),
      );

      // Check if wardrobe changed
      if (_selectedWardrobeId != null && _selectedWardrobeId != widget.wardrobeId) {
        // Move cloth to new wardrobe
        await clothProvider.moveClothToWardrobe(
          userId: user.uid,
          oldWardrobeId: widget.wardrobeId,
          newWardrobeId: _selectedWardrobeId!,
          clothId: widget.cloth.id,
        );
        
        // Update cloth in new wardrobe
        await clothProvider.updateCloth(
          userId: user.uid,
          wardrobeId: _selectedWardrobeId!,
          clothId: widget.cloth.id,
          cloth: updatedCloth,
        );
      } else {
        // Just update cloth in same wardrobe
        await clothProvider.updateCloth(
          userId: user.uid,
          wardrobeId: widget.wardrobeId,
          clothId: widget.cloth.id,
          cloth: updatedCloth,
        );
      }

      if (mounted) {
        setState(() {
          _isUpdating = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cloth updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update cloth: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingTags) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Cloth')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final tags = TagListService.getCachedTagLists();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Cloth'),
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Wardrobe Selection
              if (_isLoadingWardrobes)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  value: _selectedWardrobeId,
                  decoration: const InputDecoration(
                    labelText: 'Wardrobe *',
                    prefixIcon: Icon(Icons.inventory_2),
                    border: OutlineInputBorder(),
                  ),
                  items: _wardrobes.map((wardrobe) {
                    return DropdownMenuItem(
                      value: wardrobe.id,
                      child: Row(
                        children: [
                          Icon(Icons.inventory_2, size: 18, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text(
                            '${wardrobe.name} - ${wardrobe.location}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedWardrobeId = value),
                  validator: (value) => value == null ? 'Please select a wardrobe' : null,
                ),
              const SizedBox(height: 16),

              // Cloth Type
              DropdownButtonFormField<String>(
                value: _selectedClothType,
                decoration: const InputDecoration(
                  labelText: 'Cloth Type *',
                  prefixIcon: Icon(Icons.checkroom),
                  border: OutlineInputBorder(),
                ),
                items: tags.clothTypes.map((type) {
                  return DropdownMenuItem(value: type, child: Text(type));
                }).toList(),
                onChanged: (value) => setState(() => _selectedClothType = value),
                validator: (value) => value == null ? 'Please select cloth type' : null,
              ),
              const SizedBox(height: 16),

              // Category
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category *',
                  prefixIcon: Icon(Icons.category),
                  border: OutlineInputBorder(),
                ),
                items: tags.categories.map((cat) {
                  return DropdownMenuItem(value: cat, child: Text(cat));
                }).toList(),
                onChanged: (value) => setState(() => _selectedCategory = value),
                validator: (value) => value == null ? 'Please select category' : null,
              ),
              const SizedBox(height: 16),

              // Primary Color
              DropdownButtonFormField<String>(
                value: _selectedPrimaryColor.isEmpty ? null : _selectedPrimaryColor,
                decoration: const InputDecoration(
                  labelText: 'Primary Color',
                  prefixIcon: Icon(Icons.palette),
                  border: OutlineInputBorder(),
                ),
                items: tags.commonColors.map((color) {
                  return DropdownMenuItem(value: color, child: Text(color));
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedPrimaryColor = value;
                      if (!_selectedColors.contains(value)) {
                        _selectedColors.add(value);
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // Season
              DropdownButtonFormField<String>(
                value: _selectedSeason,
                decoration: const InputDecoration(
                  labelText: 'Season *',
                  prefixIcon: Icon(Icons.wb_sunny),
                  border: OutlineInputBorder(),
                ),
                items: tags.seasons.map((season) {
                  return DropdownMenuItem(value: season, child: Text(season));
                }).toList(),
                onChanged: (value) => setState(() => _selectedSeason = value),
                validator: (value) => value == null ? 'Please select season' : null,
              ),
              const SizedBox(height: 16),

              // Placement
              DropdownButtonFormField<String>(
                value: _selectedPlacement,
                decoration: const InputDecoration(
                  labelText: 'Placement *',
                  prefixIcon: Icon(Icons.location_on),
                  border: OutlineInputBorder(),
                ),
                items: tags.placements.map((placement) {
                  return DropdownMenuItem(value: placement, child: Text(placement));
                }).toList(),
                onChanged: (value) => setState(() => _selectedPlacement = value),
                validator: (value) => value == null ? 'Please select placement' : null,
              ),
              const SizedBox(height: 16),

              // Occasions Multi-Select
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Occasions *', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tags.occasions.map((occasion) {
                      final isSelected = _selectedOccasions.contains(occasion);
                      return FilterChip(
                        label: Text(occasion),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedOccasions.add(occasion);
                            } else {
                              _selectedOccasions.remove(occasion);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Update Button
              ElevatedButton(
                onPressed: _isUpdating ? null : _updateCloth,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isUpdating
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Update Cloth', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

