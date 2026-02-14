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

  // Placement details for Laundry, DryCleaning, Repairing
  final TextEditingController _shopNameController = TextEditingController();
  DateTime? _givenDate;
  DateTime? _returnDate;

  bool _isUpdating = false;
  bool _isLoadingTags = true;

  @override
  void initState() {
    super.initState();
    _loadTagLists();
    _loadWardrobes();
    _initializeFields();
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    super.dispose();
  }

  void _initializeFields() {
    _selectedClothType = widget.cloth.clothType;
    _selectedSeason = widget.cloth.season;
    _selectedPlacement = widget.cloth.placement;
    _selectedCategory = widget.cloth.category;
    _selectedOccasions = List<String>.from(widget.cloth.occasions);
    _selectedWardrobeId = widget.cloth.wardrobeId;

    // Initialize placement details if they exist
    if (widget.cloth.placementDetails != null) {
      _shopNameController.text = widget.cloth.placementDetails!.shopName;
      _givenDate = widget.cloth.placementDetails!.givenDate;
      _returnDate = widget.cloth.placementDetails!.returnDate;
    }

    final colorTags = widget.cloth.colorTags;
    _selectedPrimaryColor = colorTags.primary;
    _selectedSecondaryColor = colorTags.secondary;
    _selectedColors = List<String>.from(colorTags.colors);
  }

  Future<void> _loadWardrobes() async {
    final authProvider =
        Provider.of<app_auth.AuthProvider>(context, listen: false);
    final wardrobeProvider =
        Provider.of<WardrobeProvider>(context, listen: false);

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

    // Check if placement requires details
    final requiresPlacementDetails = _selectedPlacement == 'Laundry' ||
        _selectedPlacement == 'DryCleaning' ||
        _selectedPlacement == 'Repairing';

    // Validate placement details only if placement requires them
    if (requiresPlacementDetails) {
      if (_shopNameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter shop name')),
        );
        return;
      }
      if (_givenDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select given date')),
        );
        return;
      }
      if (_returnDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select return date')),
        );
        return;
      }
      if (_returnDate!.isBefore(_givenDate!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Return date must be after given date')),
        );
        return;
      }
    }

    final authProvider =
        Provider.of<app_auth.AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;

    setState(() {
      _isUpdating = true;
    });

    final clothProvider = Provider.of<ClothProvider>(context, listen: false);

    try {
      final colors = _selectedColors.isNotEmpty
          ? _selectedColors
          : (_selectedPrimaryColor.isNotEmpty
              ? [_selectedPrimaryColor]
              : ['Unknown']);

      final colorTags = ColorTags(
        primary: _selectedPrimaryColor.isNotEmpty
            ? _selectedPrimaryColor
            : colors.first,
        secondary: _selectedSecondaryColor,
        colors: colors,
        isMultiColor: colors.length > 1,
      );

      // Create placement details only if placement requires them
      PlacementDetails? placementDetails;
      if (requiresPlacementDetails &&
          _shopNameController.text.trim().isNotEmpty &&
          _givenDate != null &&
          _returnDate != null) {
        placementDetails = PlacementDetails(
          shopName: _shopNameController.text.trim(),
          givenDate: _givenDate!,
          returnDate: _returnDate!,
        );
      } else {
        // Clear placement details if not required
        placementDetails = null;
      }

      final updatedCloth = widget.cloth.copyWith(
        clothType: _selectedClothType,
        season: _selectedSeason,
        placement: _selectedPlacement,
        placementDetails: placementDetails,
        category: _selectedCategory,
        occasions: _selectedOccasions,
        colorTags: colorTags,
        updatedAt: DateTime.now(),
      );

      // Check if wardrobe changed
      if (_selectedWardrobeId != null &&
          _selectedWardrobeId != widget.wardrobeId) {
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
        backgroundColor: const Color(0xFF043915),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
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
                  initialValue: _selectedWardrobeId,
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
                          Icon(Icons.inventory_2,
                              size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Text(
                            '${wardrobe.name} - ${wardrobe.location}',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) =>
                      setState(() => _selectedWardrobeId = value),
                  validator: (value) =>
                      value == null ? 'Please select a wardrobe' : null,
                ),
              const SizedBox(height: 12),

              // Cloth Type
              DropdownButtonFormField<String>(
                initialValue: _selectedClothType,
                decoration: const InputDecoration(
                  labelText: 'Cloth Type *',
                  prefixIcon: Icon(Icons.checkroom),
                  border: OutlineInputBorder(),
                ),
                items: tags.clothTypes.map((type) {
                  return DropdownMenuItem(
                      value: type,
                      child: Text(type, style: const TextStyle(fontSize: 14)));
                }).toList(),
                onChanged: (value) =>
                    setState(() => _selectedClothType = value),
                validator: (value) =>
                    value == null ? 'Please select cloth type' : null,
              ),
              const SizedBox(height: 12),

              // Category
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category *',
                  prefixIcon: Icon(Icons.category),
                  border: OutlineInputBorder(),
                ),
                items: tags.categories.map((cat) {
                  return DropdownMenuItem(
                      value: cat,
                      child: Text(cat, style: const TextStyle(fontSize: 14)));
                }).toList(),
                onChanged: (value) => setState(() => _selectedCategory = value),
                validator: (value) =>
                    value == null ? 'Please select category' : null,
              ),
              const SizedBox(height: 12),

              // Primary Color
              DropdownButtonFormField<String>(
                initialValue: _selectedPrimaryColor.isEmpty
                    ? null
                    : _selectedPrimaryColor,
                decoration: const InputDecoration(
                  labelText: 'Primary Color',
                  prefixIcon: Icon(Icons.palette),
                  border: OutlineInputBorder(),
                ),
                items: tags.commonColors.map((color) {
                  return DropdownMenuItem(
                      value: color,
                      child: Text(color, style: const TextStyle(fontSize: 14)));
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
              const SizedBox(height: 12),

              // Season
              DropdownButtonFormField<String>(
                initialValue: _selectedSeason,
                decoration: const InputDecoration(
                  labelText: 'Season *',
                  prefixIcon: Icon(Icons.wb_sunny),
                  border: OutlineInputBorder(),
                ),
                items: tags.seasons.map((season) {
                  return DropdownMenuItem(
                      value: season,
                      child:
                          Text(season, style: const TextStyle(fontSize: 14)));
                }).toList(),
                onChanged: (value) => setState(() => _selectedSeason = value),
                validator: (value) =>
                    value == null ? 'Please select season' : null,
              ),
              const SizedBox(height: 12),

              // Placement
              DropdownButtonFormField<String>(
                initialValue: _selectedPlacement,
                decoration: const InputDecoration(
                  labelText: 'Placement *',
                  prefixIcon: Icon(Icons.location_on),
                  border: OutlineInputBorder(),
                ),
                items: tags.placements.map((placement) {
                  return DropdownMenuItem(
                      value: placement,
                      child: Text(placement,
                          style: const TextStyle(fontSize: 14)));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPlacement = value;
                    // Clear placement details if placement changes to something other than Laundry, DryCleaning, or Repairing
                    if (value != 'Laundry' &&
                        value != 'DryCleaning' &&
                        value != 'Repairing') {
                      _shopNameController.clear();
                      _givenDate = null;
                      _returnDate = null;
                    }
                  });
                },
                validator: (value) =>
                    value == null ? 'Please select placement' : null,
              ),
              const SizedBox(height: 12),

              // Placement Details (for Laundry, DryCleaning, Repairing only)
              if (_selectedPlacement == 'Laundry' ||
                  _selectedPlacement == 'DryCleaning' ||
                  _selectedPlacement == 'Repairing')
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Placement Details *',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    // Shop Name
                    TextFormField(
                      controller: _shopNameController,
                      style: const TextStyle(fontSize: 14),
                      decoration: const InputDecoration(
                        labelText: 'Shop Name *',
                        prefixIcon: Icon(Icons.store),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (_selectedPlacement == 'Laundry' ||
                            _selectedPlacement == 'DryCleaning' ||
                            _selectedPlacement == 'Repairing') {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter shop name';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    // Given Date
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _givenDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() => _givenDate = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Given Date *',
                          prefixIcon: Icon(Icons.calendar_today),
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          _givenDate != null
                              ? '${_givenDate!.day}/${_givenDate!.month}/${_givenDate!.year}'
                              : 'Select given date',
                          style: TextStyle(
                            fontSize: 14,
                            color:
                                _givenDate != null ? Colors.black : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Return Date
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _returnDate ??
                              (_givenDate ?? DateTime.now())
                                  .add(const Duration(days: 7)),
                          firstDate: _givenDate ?? DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() => _returnDate = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Return Date *',
                          prefixIcon: Icon(Icons.event_available),
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          _returnDate != null
                              ? '${_returnDate!.day}/${_returnDate!.month}/${_returnDate!.year}'
                              : 'Select return date',
                          style: TextStyle(
                            fontSize: 14,
                            color: _returnDate != null
                                ? Colors.black
                                : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),

              // Occasions Multi-Select
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Occasions *',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: tags.occasions.map((occasion) {
                      final isSelected = _selectedOccasions.contains(occasion);
                      return FilterChip(
                        label: Text(occasion,
                            style: const TextStyle(fontSize: 12)),
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
              const SizedBox(height: 20),

              // Update Button
              ElevatedButton(
                onPressed: _isUpdating ? null : _updateCloth,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF043915),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: _isUpdating
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Update Cloth',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
