import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../models/cloth.dart';
import '../models/wardrobe.dart';
import '../providers/cloth_provider.dart';

class AddClothFirstScreen extends StatefulWidget {
  final String wardrobeId;
  final String? wardrobeSeason; // Optional: pass season from wardrobe

  const AddClothFirstScreen({
    super.key,
    required this.wardrobeId,
    this.wardrobeSeason,
  });

  @override
  State<AddClothFirstScreen> createState() => _AddClothFirstScreenState();
}

class _AddClothFirstScreenState extends State<AddClothFirstScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  
  File? _selectedImage;
  String _selectedType = Cloth.types[0];
  String _colorController = '';
  String _selectedOccasion = Cloth.occasions[0];
  String _selectedSeason = '';
  
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    // Use wardrobe season if provided, otherwise default
    _selectedSeason = widget.wardrobeSeason ?? Wardrobe.seasons[0];
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
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
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedImage == null) {
      _showErrorSnackBar('Please select an image');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showErrorSnackBar('User not authenticated');
      return;
    }

    setState(() {
      _isUploading = true;
    });

    final clothProvider = context.read<ClothProvider>();

    try {
      final clothId = await clothProvider.addCloth(
        user.uid,
        widget.wardrobeId,
        _selectedImage,
        _selectedType,
        _colorController.trim(),
        _selectedOccasion,
        _selectedSeason,
      );

      if (mounted && clothId != null) {
        setState(() {
          _isUploading = false;
        });
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cloth added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate back to wardrobe detail screen (will refresh automatically via stream)
        Navigator.of(context).pop();
      } else if (mounted && clothProvider.errorMessage != null) {
        setState(() {
          _isUploading = false;
        });
        _showErrorSnackBar(clothProvider.errorMessage!);
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
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFFA855F7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'Add Cloth',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Form Content
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 20),

                            // Image Picker
                            GestureDetector(
                              onTap: _showImageSourceDialog,
                              child: Container(
                                height: 200,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey[400]!,
                                    width: 2,
                                    strokeAlign: BorderSide.strokeAlignInside,
                                  ),
                                ),
                                child: _selectedImage != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.file(
                                          _selectedImage!,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : const Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add_photo_alternate,
                                            size: 64,
                                            color: Colors.grey,
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'Tap to add image',
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Type Dropdown
                            DropdownButtonFormField<String>(
                              initialValue: _selectedType,
                              decoration: InputDecoration(
                                labelText: 'Type *',
                                prefixIcon: const Icon(Icons.checkroom),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              items: Cloth.types.map((type) {
                                return DropdownMenuItem(
                                  value: type,
                                  child: Text(type),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedType = value;
                                  });
                                }
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select a type';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 24),

                            // Color Field
                            TextFormField(
                              onChanged: (value) {
                                _colorController = value;
                              },
                              decoration: InputDecoration(
                                labelText: 'Color',
                                hintText: 'e.g., Blue, Red, Black',
                                prefixIcon: const Icon(Icons.palette),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Occasion Dropdown
                            DropdownButtonFormField<String>(
                              initialValue: _selectedOccasion,
                              decoration: InputDecoration(
                                labelText: 'Occasion',
                                prefixIcon: const Icon(Icons.event),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              items: Cloth.occasions.map((occasion) {
                                return DropdownMenuItem(
                                  value: occasion,
                                  child: Text(occasion),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedOccasion = value;
                                  });
                                }
                              },
                            ),

                            const SizedBox(height: 24),

                            // Season Dropdown (pre-filled from wardrobe)
                            DropdownButtonFormField<String>(
                              initialValue: _selectedSeason,
                              decoration: InputDecoration(
                                labelText: 'Season',
                                prefixIcon: const Icon(Icons.wb_sunny),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              items: Wardrobe.seasons.map((season) {
                                return DropdownMenuItem(
                                  value: season,
                                  child: Text(season),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedSeason = value;
                                  });
                                }
                              },
                            ),

                            const SizedBox(height: 40),

                            // Save Button
                            ElevatedButton(
                              onPressed: _isUploading ? null : _saveCloth,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7C3AED),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: _isUploading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : const Text(
                                      'Save Cloth',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
