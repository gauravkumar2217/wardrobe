import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_profile.dart';
import '../../services/storage_service.dart';

/// Edit profile screen for updating user profile information
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _selectedGender;
  DateTime? _selectedDateOfBirth;
  bool _isLoading = false;
  File? _selectedImage;
  String? _currentPhotoUrl;

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  Future<void> _loadCurrentProfile() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final profile = authProvider.userProfile;
    final user = authProvider.user;

    if (profile != null) {
      setState(() {
        _nameController.text = profile.displayName ?? '';
        _usernameController.text = profile.username ?? '';
        _phoneController.text = profile.phone ?? '';
        _selectedGender = profile.gender;
        _selectedDateOfBirth = profile.dateOfBirth;
        _currentPhotoUrl = profile.photoUrl;
      });
    } else if (user != null) {
      // Fallback to user data if profile not loaded
      setState(() {
        _nameController.text = user.displayName ?? '';
        _phoneController.text = user.phoneNumber ?? '';
        _currentPhotoUrl = user.photoURL;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to take photo: $e')),
        );
      }
    }
  }

  Future<void> _showImageSourceDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Image Source', style: TextStyle(fontSize: 14)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              leading: const Icon(Icons.photo_library, size: 18),
              title: const Text('Choose from Gallery', style: TextStyle(fontSize: 13)),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              leading: const Icon(Icons.camera_alt, size: 18),
              title: const Text('Take Photo', style: TextStyle(fontSize: 13)),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _selectDateOfBirth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateOfBirth ?? DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDateOfBirth = picked;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;


    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    
    if (user == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not found. Please sign in again.')),
        );
      }
      return;
    }

    try {
      String? photoUrl = _currentPhotoUrl;

      // Upload new profile photo if selected
      if (_selectedImage != null) {
        photoUrl = await StorageService.uploadProfilePhoto(
          userId: user.uid,
          imageFile: _selectedImage!,
        );
      }

      // Create updated profile (preserve original username)
      final currentProfile = authProvider.userProfile;
      final phoneNumber = _phoneController.text.trim();
      final updatedProfile = UserProfile(
        displayName: _nameController.text.trim(),
        username: currentProfile?.username ?? _usernameController.text.trim().toLowerCase(), // Keep original username
        email: user.email,
        phone: phoneNumber.isNotEmpty ? phoneNumber : null,
        gender: _selectedGender,
        dateOfBirth: _selectedDateOfBirth,
        photoUrl: photoUrl,
        createdAt: currentProfile?.createdAt,
        updatedAt: DateTime.now(),
        settings: currentProfile?.settings,
      );

      // Update profile
      await authProvider.updateProfile(updatedProfile);
      
      // Refresh profile to get latest data from Firestore
      await authProvider.refreshProfile();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                // Profile photo
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 45,
                        backgroundColor: const Color(0xFF7C3AED),
                        backgroundImage: _selectedImage != null
                            ? FileImage(_selectedImage!)
                            : (_currentPhotoUrl != null
                                ? NetworkImage(_currentPhotoUrl!)
                                : null) as ImageProvider?,
                        child: _selectedImage == null && _currentPhotoUrl == null
                            ? Text(
                                _nameController.text.isNotEmpty
                                    ? _nameController.text.substring(0, 1).toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFF7C3AED),
                          child: IconButton(
                            icon: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                            onPressed: _showImageSourceDialog,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Name field
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person, size: 18),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                // Username field (read-only)
                TextFormField(
                  controller: _usernameController,
                  enabled: false,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Username',
                    prefixIcon: const Icon(Icons.alternate_email, size: 18),
                    suffixIcon: const Icon(Icons.lock, size: 16),
                    helperText: 'Username cannot be changed',
                    helperStyle: const TextStyle(fontSize: 11),
                    filled: true,
                    fillColor: Colors.grey[200],
                  ),
                ),
                const SizedBox(height: 12),
                // Phone number field (optional)
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    labelText: 'Phone Number (Optional)',
                    prefixIcon: Icon(Icons.phone, size: 18),
                  ),
                ),
                const SizedBox(height: 12),
                // Gender field (optional)
                DropdownButtonFormField<String>(
                  value: _selectedGender,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                  decoration: const InputDecoration(
                    labelText: 'Gender (Optional)',
                    prefixIcon: Icon(Icons.person_outline, size: 18),
                  ),
                  dropdownColor: Colors.white,
                  items: const [
                    DropdownMenuItem(
                      value: null,
                      child: Text('Select gender (optional)', style: TextStyle(fontSize: 14, color: Colors.black87)),
                    ),
                    DropdownMenuItem(
                      value: 'male',
                      child: Text('Male', style: TextStyle(fontSize: 14, color: Colors.black87)),
                    ),
                    DropdownMenuItem(
                      value: 'female',
                      child: Text('Female', style: TextStyle(fontSize: 14, color: Colors.black87)),
                    ),
                    DropdownMenuItem(
                      value: 'other',
                      child: Text('Other', style: TextStyle(fontSize: 14, color: Colors.black87)),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedGender = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                // Date of Birth field (optional)
                InkWell(
                  onTap: _selectDateOfBirth,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date of Birth (Optional)',
                      prefixIcon: Icon(Icons.calendar_today, size: 18),
                    ),
                    child: Text(
                      _selectedDateOfBirth != null
                          ? DateFormat('yyyy-MM-dd').format(_selectedDateOfBirth!)
                          : 'Select date of birth (optional)',
                      style: TextStyle(
                        fontSize: 14,
                        color: _selectedDateOfBirth != null
                            ? Colors.black
                            : Colors.grey[600],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save Changes', style: TextStyle(fontSize: 14)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

