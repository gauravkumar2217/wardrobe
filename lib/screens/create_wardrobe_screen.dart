import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/wardrobe_provider.dart';
import '../models/wardrobe.dart';
import 'wardrobe_detail_screen.dart';

class CreateWardrobeScreen extends StatefulWidget {
  const CreateWardrobeScreen({super.key});

  @override
  State<CreateWardrobeScreen> createState() => _CreateWardrobeScreenState();
}

class _CreateWardrobeScreenState extends State<CreateWardrobeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  String _selectedSeason = Wardrobe.seasons[0];

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _createWardrobe() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showErrorSnackBar('User not authenticated');
      return;
    }

    final wardrobeProvider = context.read<WardrobeProvider>();

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final wardrobeId = await wardrobeProvider.createWardrobe(
        user.uid,
        _titleController.text.trim(),
        _locationController.text.trim(),
        _selectedSeason,
      );

      if (mounted && wardrobeId != null) {
        Navigator.of(context).pop(); // Close loading dialog
        
        // Create a temporary Wardrobe object for navigation
        final newWardrobe = Wardrobe(
          id: wardrobeId,
          title: _titleController.text.trim(),
          location: _locationController.text.trim(),
          season: _selectedSeason,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          clothCount: 0,
        );
        
        // Navigate to Wardrobe Detail screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => WardrobeDetailScreen(wardrobe: newWardrobe),
          ),
        );
      } else if (mounted && wardrobeProvider.errorMessage != null) {
        Navigator.of(context).pop(); // Close loading dialog
        _showErrorSnackBar(wardrobeProvider.errorMessage!);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        _showErrorSnackBar('Failed to create wardrobe: ${e.toString()}');
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
                        'Create Wardrobe',
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

                            // Title Field
                            TextFormField(
                              controller: _titleController,
                              decoration: InputDecoration(
                                labelText: 'Wardrobe Title',
                                hintText: 'e.g., Office Clothes',
                                prefixIcon: const Icon(Icons.title),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter a title';
                                }
                                if (value.trim().length < 2) {
                                  return 'Title must be at least 2 characters';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 24),

                            // Location Field
                            TextFormField(
                              controller: _locationController,
                              decoration: InputDecoration(
                                labelText: 'Location / Room',
                                hintText: 'e.g., Master Bedroom',
                                prefixIcon: const Icon(Icons.location_on),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Season Dropdown
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

                            // Create Button
                            ElevatedButton(
                              onPressed: _createWardrobe,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7C3AED),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Create Wardrobe',
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

