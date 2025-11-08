import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../models/cloth.dart';
import '../models/wardrobe.dart';
import '../providers/cloth_provider.dart';
import '../services/ai_vision_service.dart';

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
  List<String> _selectedOccasions = [
    Cloth.occasionOptions[0]
  ]; // Changed to support multiple
  String _selectedSeason = '';

  bool _isUploading = false;
  bool _isAnalyzing = false;

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

        // Auto-analyze image with AI
        _analyzeImage(File(image.path));
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick image: ${e.toString()}');
    }
  }

  Future<void> _analyzeImage(File imageFile) async {
    setState(() {
      _isAnalyzing = true;
    });

    try {
      final metadata = await AIVisionService.analyzeImage(imageFile);

      if (mounted) {
        setState(() {
          // Update form fields with AI-detected values
          if (Cloth.types.contains(metadata.type)) {
            _selectedType = metadata.type;
          }
          _colorController = metadata.color;
          if (Cloth.occasionOptions.contains(metadata.occasion)) {
            _selectedOccasions = [metadata.occasion];
          }
          _isAnalyzing = false;
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'AI detected: ${metadata.type}, ${metadata.color}, ${metadata.occasion} '
              '(Confidence: ${(metadata.confidence * 100).toStringAsFixed(0)}%)',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
        // Silently fail - user can still fill manually
        if (kDebugMode) {
          print('AI analysis failed: $e');
        }
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
    if (kDebugMode) {
      debugPrint('AddClothScreen: Starting save process');
    }

    if (!_formKey.currentState!.validate()) {
      if (kDebugMode) {
        debugPrint('AddClothScreen: Form validation failed');
      }
      return;
    }

    if (_selectedImage == null) {
      if (kDebugMode) {
        debugPrint('AddClothScreen: No image selected');
      }
      _showErrorSnackBar('Please select an image');
      return;
    }

    if (_selectedOccasions.isEmpty) {
      if (kDebugMode) {
        debugPrint('AddClothScreen: No occasions selected');
      }
      _showErrorSnackBar('Please select at least one occasion');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (kDebugMode) {
        debugPrint('AddClothScreen: User not authenticated');
      }
      _showErrorSnackBar('User not authenticated');
      return;
    }

    if (kDebugMode) {
      debugPrint('AddClothScreen: User ID: ${user.uid}');
      debugPrint('AddClothScreen: Wardrobe ID: ${widget.wardrobeId}');
      debugPrint('AddClothScreen: Image path: ${_selectedImage?.path}');
      debugPrint('AddClothScreen: Type: $_selectedType, Color: ${_colorController.trim()}, Occasions: $_selectedOccasions, Season: $_selectedSeason');
    }

    setState(() {
      _isUploading = true;
    });

    final clothProvider = context.read<ClothProvider>();

    try {
      if (kDebugMode) {
        debugPrint('AddClothScreen: Calling ClothProvider.addCloth');
      }

      final clothId = await clothProvider.addCloth(
        user.uid,
        widget.wardrobeId,
        _selectedImage,
        _selectedType,
        _colorController.trim(),
        _selectedOccasions,
        _selectedSeason,
      );

      if (kDebugMode) {
        debugPrint('AddClothScreen: ClothProvider.addCloth returned: $clothId');
        debugPrint('AddClothScreen: Error message: ${clothProvider.errorMessage}');
      }

      if (!mounted) return;

      if (clothId != null) {
        setState(() {
          _isUploading = false;
        });

        if (kDebugMode) {
          debugPrint('AddClothScreen: Cloth added successfully with ID: $clothId');
        }

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cloth added successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back to wardrobe detail screen (will refresh automatically via stream)
        Navigator.of(context).pop();
      } else {
        setState(() {
          _isUploading = false;
        });

        final errorMsg = clothProvider.errorMessage ?? 'Unknown error occurred';
        if (kDebugMode) {
          debugPrint('AddClothScreen: Failed to add cloth - $errorMsg');
        }
        _showErrorSnackBar(errorMsg);
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('AddClothScreen: Exception caught: $e');
        debugPrint('AddClothScreen: Stack trace: $stackTrace');
      }
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
                                    ? Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: Image.file(
                                              _selectedImage!,
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              height: double.infinity,
                                            ),
                                          ),
                                          if (_isAnalyzing)
                                            Container(
                                              decoration: BoxDecoration(
                                                color: Colors.black
                                                    .withValues(alpha: 0.5),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: const Center(
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    CircularProgressIndicator(
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                              Color>(
                                                        Colors.white,
                                                      ),
                                                    ),
                                                    SizedBox(height: 8),
                                                    Text(
                                                      'Analyzing with AI...',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                        ],
                                      )
                                    : const Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
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
                              value: _selectedType,
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

                            // Occasions Multi-Select
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.event, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Occasions (Select Multiple)',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children:
                                      Cloth.occasionOptions.map((occasion) {
                                    final isSelected =
                                        _selectedOccasions.contains(occasion);
                                    return FilterChip(
                                      label: Text(occasion),
                                      selected: isSelected,
                                      onSelected: (selected) {
                                        setState(() {
                                          if (selected) {
                                            if (!_selectedOccasions
                                                .contains(occasion)) {
                                              _selectedOccasions.add(occasion);
                                            }
                                          } else {
                                            _selectedOccasions.remove(occasion);
                                            // Ensure at least one occasion is selected
                                            if (_selectedOccasions.isEmpty) {
                                              _selectedOccasions = [
                                                Cloth.occasionOptions[0]
                                              ];
                                            }
                                          }
                                        });
                                      },
                                      selectedColor: const Color(0xFF7C3AED)
                                          .withValues(alpha: 0.2),
                                      checkmarkColor: const Color(0xFF7C3AED),
                                      labelStyle: TextStyle(
                                        color: isSelected
                                            ? const Color(0xFF7C3AED)
                                            : Colors.grey[700],
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                      side: BorderSide(
                                        color: isSelected
                                            ? const Color(0xFF7C3AED)
                                            : Colors.grey[300]!,
                                        width: isSelected ? 2 : 1,
                                      ),
                                    );
                                  }).toList(),
                                ),
                                if (_selectedOccasions.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      'Please select at least one occasion',
                                      style: TextStyle(
                                        color: Colors.red[400],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // Season Dropdown (pre-filled from wardrobe)
                            DropdownButtonFormField<String>(
                              value: _selectedSeason,
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
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
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
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
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
