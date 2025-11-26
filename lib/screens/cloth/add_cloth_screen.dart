import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/cloth.dart';
import '../../providers/cloth_provider.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../services/tag_list_service.dart';

/// Add cloth screen using dynamic tag lists from Firestore
class AddClothScreen extends StatefulWidget {
  final String wardrobeId;

  const AddClothScreen({
    super.key,
    required this.wardrobeId,
  });

  @override
  State<AddClothScreen> createState() => _AddClothScreenState();
}

class _AddClothScreenState extends State<AddClothScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  File? _selectedImage;
  String? _selectedClothType;
  String _selectedPrimaryColor = '';
  String? _selectedSecondaryColor;
  final List<String> _selectedColors = [];
  String? _selectedSeason;
  String? _selectedPlacement;
  String? _selectedCategory;
  List<String> _selectedOccasions = [];
  String _visibility = 'private';

  bool _isUploading = false;
  bool _isLoadingTags = true;

  @override
  void initState() {
    super.initState();
    _loadTagLists();
  }

  Future<void> _loadTagLists() async {
    try {
      await TagListService.fetchTagLists();
      if (mounted) {
        setState(() {
          _isLoadingTags = false;
          // Set defaults
          final tags = TagListService.getCachedTagLists();
          if (tags.seasons.isNotEmpty) _selectedSeason = tags.seasons.first;
          if (tags.placements.isNotEmpty) _selectedPlacement = tags.placements.first;
          if (tags.clothTypes.isNotEmpty) _selectedClothType = tags.clothTypes.first;
          if (tags.categories.isNotEmpty) _selectedCategory = tags.categories.first;
          if (tags.occasions.isNotEmpty) _selectedOccasions = [tags.occasions.first];
        });
      }
    } catch (e) {
      debugPrint('Failed to load tag lists: $e');
      if (mounted) {
        setState(() {
          _isLoadingTags = false;
        });
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick image: ${e.toString()}');
    }
  }

  Future<void> _showImageSourceDialog() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveCloth() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedImage == null) {
      _showErrorSnackBar('Please select an image');
      return;
    }

    if (_selectedOccasions.isEmpty) {
      _showErrorSnackBar('Please select at least one occasion');
      return;
    }

    if (_selectedSeason == null || _selectedPlacement == null ||
        _selectedClothType == null || _selectedCategory == null) {
      _showErrorSnackBar('Please fill all required fields');
      return;
    }

    final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) {
      _showErrorSnackBar('User not authenticated');
      return;
    }

    setState(() {
      _isUploading = true;
    });

    final clothProvider = Provider.of<ClothProvider>(context, listen: false);

    try {
      // Create color tags
      final colors = _selectedColors.isNotEmpty
          ? _selectedColors
          : (_selectedPrimaryColor.isNotEmpty ? [_selectedPrimaryColor] : ['Unknown']);
      
      final colorTags = ColorTags(
        primary: _selectedPrimaryColor.isNotEmpty ? _selectedPrimaryColor : colors.first,
        secondary: _selectedSecondaryColor,
        colors: colors,
        isMultiColor: colors.length > 1,
      );

      final clothId = await clothProvider.addCloth(
        userId: user.uid,
        wardrobeId: widget.wardrobeId,
        imageFile: _selectedImage!,
        season: _selectedSeason!,
        placement: _selectedPlacement!,
        colorTags: colorTags,
        clothType: _selectedClothType!,
        category: _selectedCategory!,
        occasions: _selectedOccasions,
        visibility: _visibility,
      );

      if (mounted) {
        setState(() {
          _isUploading = false;
        });

        if (clothId != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cloth added successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        } else {
          _showErrorSnackBar(clothProvider.errorMessage ?? 'Failed to add cloth');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
        _showErrorSnackBar('Failed to add cloth: ${e.toString()}');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingTags) {
      return Scaffold(
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final tags = TagListService.getCachedTagLists();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Cloth'),
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
              // Image Picker
              GestureDetector(
                onTap: _showImageSourceDialog,
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[400]!),
                  ),
                  child: _selectedImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            _selectedImage!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate, size: 64, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('Tap to add image', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),

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
              const SizedBox(height: 24),

              // Visibility
              DropdownButtonFormField<String>(
                value: _visibility,
                decoration: const InputDecoration(
                  labelText: 'Visibility',
                  prefixIcon: Icon(Icons.visibility),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'private', child: Text('Private')),
                  DropdownMenuItem(value: 'friends', child: Text('Friends Only')),
                  DropdownMenuItem(value: 'public', child: Text('Public')),
                ],
                onChanged: (value) => setState(() => _visibility = value ?? 'private'),
              ),
              const SizedBox(height: 32),

              // Save Button
              ElevatedButton(
                onPressed: _isUploading ? null : _saveCloth,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isUploading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save Cloth', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

