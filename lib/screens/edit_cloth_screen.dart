import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/cloth.dart';
import '../services/cloth_service.dart';

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
  
  String _selectedType = '';
  String _colorController = '';
  List<String> _selectedOccasions = [];
  String _selectedSeason = '';
  
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.cloth.type;
    _colorController = widget.cloth.color;
    _selectedOccasions = List<String>.from(widget.cloth.occasions);
    _selectedSeason = widget.cloth.season;
  }

  Future<void> _updateCloth() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedOccasions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one occasion'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User not authenticated'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      await ClothService.updateCloth(
        user.uid,
        widget.wardrobeId,
        widget.cloth.id,
        {
          'type': _selectedType,
          'color': _colorController.trim(),
          'occasions': _selectedOccasions,
          'occasion': _selectedOccasions.isNotEmpty ? _selectedOccasions.first : 'Other',
          'season': _selectedSeason,
        },
      );

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
                        'Edit Cloth',
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

                            // Type Dropdown
                            DropdownButtonFormField<String>(
                              value: _selectedType,
                              decoration: InputDecoration(
                                labelText: 'Type',
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
                            ),

                            const SizedBox(height: 24),

                            // Color Input
                            TextFormField(
                              initialValue: _colorController,
                              decoration: InputDecoration(
                                labelText: 'Color',
                                hintText: 'e.g., Blue, Red, Black',
                                prefixIcon: const Icon(Icons.palette),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter a color';
                                }
                                return null;
                              },
                              onChanged: (value) {
                                _colorController = value;
                              },
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
                                  children: Cloth.occasionOptions.map((occasion) {
                                    final isSelected = _selectedOccasions.contains(occasion);
                                    return FilterChip(
                                      label: Text(occasion),
                                      selected: isSelected,
                                      onSelected: (selected) {
                                        setState(() {
                                          if (selected) {
                                            if (!_selectedOccasions.contains(occasion)) {
                                              _selectedOccasions.add(occasion);
                                            }
                                          } else {
                                            _selectedOccasions.remove(occasion);
                                            // Ensure at least one occasion is selected
                                            if (_selectedOccasions.isEmpty) {
                                              _selectedOccasions = [Cloth.occasionOptions[0]];
                                            }
                                          }
                                        });
                                      },
                                      selectedColor: const Color(0xFF7C3AED).withValues(alpha: 0.2),
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

                            // Season Dropdown
                            DropdownButtonFormField<String>(
                              value: _selectedSeason,
                              decoration: InputDecoration(
                                labelText: 'Season',
                                prefixIcon: const Icon(Icons.wb_sunny),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              items: ['Spring', 'Summer', 'Fall', 'Winter', 'All-season'].map((season) {
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

                            // Update Button
                            ElevatedButton(
                              onPressed: _isUpdating ? null : _updateCloth,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7C3AED),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: _isUpdating
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
                                      'Update Cloth',
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

