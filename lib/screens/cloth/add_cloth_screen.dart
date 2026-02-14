import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/cloth.dart';
import '../../providers/cloth_provider.dart';
import '../../providers/wardrobe_provider.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../services/tag_list_service.dart';
import '../../services/ai_detection_service.dart';

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
  final String _visibility = 'private';

  // Placement details for Laundry, DryCleaning, Repairing
  final TextEditingController _shopNameController = TextEditingController();
  DateTime? _givenDate;
  DateTime? _returnDate;

  bool _isUploading = false;
  bool _isLoadingTags = true;
  bool _isDetecting = false;

  @override
  void initState() {
    super.initState();
    _loadTagLists();
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    super.dispose();
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
          if (tags.placements.isNotEmpty)
            _selectedPlacement = tags.placements.first;
          if (tags.clothTypes.isNotEmpty)
            _selectedClothType = tags.clothTypes.first;
          if (tags.categories.isNotEmpty)
            _selectedCategory = tags.categories.first;
          if (tags.occasions.isNotEmpty)
            _selectedOccasions = [tags.occasions.first];
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
          _isDetecting = true;
        });

        // Run AI detection
        await _detectClothDetails(File(image.path));
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick image: ${e.toString()}');
    }
  }

  /// Detect cloth details using AI
  Future<void> _detectClothDetails(File imageFile) async {
    try {
      final tags = TagListService.getCachedTagLists();
      String? detectedTypeMessage;
      String? detectedColorMessage;

      // Detect cloth type
      final detectedType = await AiDetectionService.detectClothType(imageFile);
      if (detectedType != null && detectedType.isNotEmpty && mounted) {
        // Check if type exists in list
        if (tags.clothTypes.contains(detectedType)) {
          // Type exists - set it directly
          setState(() {
            _selectedClothType = detectedType;
          });
          detectedTypeMessage = 'Detected: $detectedType';
        } else {
          // Type doesn't exist - add to Firestore (syncs across all users)
          await TagListService.addClothType(detectedType);
          // Reload tags to get updated list
          await TagListService.fetchTagLists(forceRefresh: true);

          // Now set it after the list is updated
          final updatedTags = TagListService.getCachedTagLists();
          if (updatedTags.clothTypes.contains(detectedType)) {
            setState(() {
              _selectedClothType = detectedType;
            });
            detectedTypeMessage = 'Detected: $detectedType (synced)';
          } else {
            detectedTypeMessage =
                'Detected: $detectedType (please select manually)';
          }
        }
      }

      // Detect colors
      final detectedColors = await AiDetectionService.detectColors(imageFile);
      if (detectedColors.isNotEmpty && mounted) {
        // Add new colors to Firestore (syncs across all users)
        await TagListService.addColors(detectedColors);
        // Reload tags to get updated list
        await TagListService.fetchTagLists(forceRefresh: true);

        // Filter colors to only those that exist in the list
        final updatedTags = TagListService.getCachedTagLists();
        final validColors = detectedColors
            .where((color) => updatedTags.commonColors.contains(color))
            .toList();

        if (validColors.isNotEmpty) {
          setState(() {
            _selectedPrimaryColor = validColors.first;
            _selectedColors.clear();
            _selectedColors.addAll(validColors);
          });
          detectedColorMessage = 'Colors: ${validColors.join(", ")}';
        } else if (detectedColors.isNotEmpty) {
          // Use first detected color even if not in list
          setState(() {
            _selectedPrimaryColor = detectedColors.first;
            _selectedColors.clear();
            _selectedColors.addAll(detectedColors);
          });
          detectedColorMessage = 'Colors: ${detectedColors.join(", ")}';
        }
      }

      // Detect season (optional)
      final detectedSeason = await AiDetectionService.detectSeason(imageFile);
      if (detectedSeason != null && mounted) {
        // Only set if season exists in list
        if (tags.seasons.contains(detectedSeason)) {
          setState(() {
            _selectedSeason = detectedSeason;
          });
        }
      }

      if (mounted) {
        setState(() {
          _isDetecting = false;
        });

        // Show success message with details
        final messages = <String>[];
        if (detectedTypeMessage != null) messages.add(detectedTypeMessage);
        if (detectedColorMessage != null) messages.add(detectedColorMessage);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(messages.isNotEmpty
                ? messages.join('\n')
                : 'AI detection completed!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error in AI detection: $e');
      if (mounted) {
        setState(() {
          _isDetecting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI detection failed: ${e.toString()}'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
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

    if (_selectedSeason == null ||
        _selectedPlacement == null ||
        _selectedClothType == null ||
        _selectedCategory == null) {
      _showErrorSnackBar('Please fill all required fields');
      return;
    }

    // Validate placement details only if placement requires them
    final requiresPlacementDetails = _selectedPlacement == 'Laundry' ||
        _selectedPlacement == 'DryCleaning' ||
        _selectedPlacement == 'Repairing';

    if (requiresPlacementDetails) {
      if (_shopNameController.text.trim().isEmpty) {
        _showErrorSnackBar('Please enter shop name');
        return;
      }
      if (_givenDate == null) {
        _showErrorSnackBar('Please select given date');
        return;
      }
      if (_returnDate == null) {
        _showErrorSnackBar('Please select return date');
        return;
      }
      if (_returnDate!.isBefore(_givenDate!)) {
        _showErrorSnackBar('Return date must be after given date');
        return;
      }
    }

    final authProvider =
        Provider.of<app_auth.AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) {
      _showErrorSnackBar('User not authenticated');
      return;
    }

    setState(() {
      _isUploading = true;
    });

    final clothProvider = Provider.of<ClothProvider>(context, listen: false);
    final wardrobeProvider =
        Provider.of<WardrobeProvider>(context, listen: false);

    try {
      // Create color tags
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

      final clothId = await clothProvider.addCloth(
        userId: user.uid,
        wardrobeId: widget.wardrobeId,
        imageFile: _selectedImage!,
        season: _selectedSeason!,
        placement: _selectedPlacement!,
        placementDetails: placementDetails,
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
          // Refresh wardrobe count after adding cloth
          await wardrobeProvider.refreshWardrobeCount(
            userId: user.uid,
            wardrobeId: widget.wardrobeId,
          );

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cloth added successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          if (!mounted) return;
          Navigator.of(context).pop();
        } else {
          _showErrorSnackBar(
              clothProvider.errorMessage ?? 'Failed to add cloth');
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final tags = TagListService.getCachedTagLists();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Cloth'),
        backgroundColor: const Color(0xFF043915),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
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
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                _selectedImage!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                            ),
                            if (_isDetecting)
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircularProgressIndicator(
                                        color: Colors.white,
                                      ),
                                      SizedBox(height: 12),
                                      Text(
                                        'AI Detecting...',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate,
                                size: 48, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('Tap to add image',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                ),
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

              // Save Button
              ElevatedButton(
                onPressed: _isUploading ? null : _saveCloth,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF043915),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: _isUploading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save Cloth',
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
