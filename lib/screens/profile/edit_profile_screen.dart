import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_profile.dart';
import '../../services/storage_service.dart';
import '../../theme/wardrobe_tokens.dart';
import '../../utils/shell_navigation.dart';
import '../../widgets/shell_back_button.dart';

/// Edit profile screen for updating user profile information
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const _brandColor = Color(0xFF043915);
  static const _cardBg = Colors.white;
  static const _fieldFill = Color(0xFFF9FAFB);
  static const _textColor = Color(0xFF111827);
  static const _labelColor = Color(0xFF374151);
  static const _hintColor = Color(0xFF9CA3AF);
  static const _borderColor = Color(0xFFE5E7EB);

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
      setState(() {
        _nameController.text = user.displayName ?? '';
        _phoneController.text = user.phoneNumber ?? '';
        _currentPhotoUrl = user.photoUrl;
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
    final onSurface = Theme.of(context).colorScheme.onSurface;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: WardrobeTokens.emeraldCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: WardrobeTokens.hairlineGold,
        ),
        title: Text(
          'Update profile photo',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: onSurface,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.photo_library_outlined,
                  size: 22, color: WardrobeTokens.goldPrimary),
              title: Text(
                'Choose from gallery',
                style: TextStyle(fontSize: 14, color: onSurface),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.camera_alt_outlined,
                  size: 22, color: WardrobeTokens.goldPrimary),
              title: Text(
                'Take a photo',
                style: TextStyle(fontSize: 14, color: onSurface),
              ),
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
      initialDate: _selectedDateOfBirth ??
          DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: _brandColor,
                  onPrimary: Colors.white,
                  surface: _cardBg,
                  onSurface: _textColor,
                ),
            dialogTheme: const DialogThemeData(backgroundColor: _cardBg),
          ),
          child: child!,
        );
      },
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
          const SnackBar(
              content: Text('User not found. Please sign in again.')),
        );
      }
      return;
    }

    try {
      String? photoUrl = _currentPhotoUrl;

      if (_selectedImage != null) {
        photoUrl = await StorageService.uploadProfilePhoto(
          userId: user.uid,
          imageFile: _selectedImage!,
        );
      }

      final currentProfile = authProvider.userProfile;
      final phoneNumber = _phoneController.text.trim();
      final updatedProfile = UserProfile(
        displayName: _nameController.text.trim(),
        username: currentProfile?.username ??
            _usernameController.text.trim().toLowerCase(),
        email: user.email,
        phone: phoneNumber.isNotEmpty ? phoneNumber : null,
        gender: _selectedGender,
        dateOfBirth: _selectedDateOfBirth,
        photoUrl: photoUrl,
        createdAt: currentProfile?.createdAt,
        updatedAt: DateTime.now(),
        settings: currentProfile?.settings,
      );

      await authProvider.updateProfile(updatedProfile);
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

  TextStyle get _inputTextStyle => const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: _textColor,
        height: 1.3,
      );

  InputDecoration _fieldDecoration({
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    Color? fillColor,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _borderColor),
    );
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: _hintColor,
      ),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: fillColor ?? _fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: _brandColor, width: 1.5),
      ),
      disabledBorder: border,
      border: border,
      errorStyle: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFB91C1C)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFB91C1C), width: 1.5),
      ),
    );
  }

  Widget _fieldLabel(String label, {bool optional = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _labelColor,
              letterSpacing: 0.1,
            ),
          ),
          if (optional)
            const Text(
              '  ·  Optional',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: _hintColor,
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: _brandColor,
        ),
      ),
    );
  }

  Widget _formCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _fieldSpacer() => const SizedBox(height: 16);

  @override
  Widget build(BuildContext context) {
    final embedded = isShellEmbedded(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: embedded
          ? null
          : AppBar(
              title: const Text('Edit Profile'),
              backgroundColor: _brandColor,
              foregroundColor: Colors.white,
            ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (embedded) const ShellBackButton(),
                if (embedded) ...[
                  Text(
                    'Edit Profile',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Update your photo and personal details',
                    style: TextStyle(
                      fontSize: 13,
                      color: onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                _sectionHeader('Profile Photo'),
                Center(
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: WardrobeTokens.goldPrimary
                                    .withValues(alpha: 0.5),
                                width: 2,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 48,
                              backgroundColor: _brandColor,
                              backgroundImage: _selectedImage != null
                                  ? FileImage(_selectedImage!)
                                  : (_currentPhotoUrl != null
                                      ? NetworkImage(_currentPhotoUrl!)
                                      : null) as ImageProvider?,
                              child: _selectedImage == null &&
                                      _currentPhotoUrl == null
                                  ? Text(
                                      _nameController.text.isNotEmpty
                                          ? _nameController.text
                                              .substring(0, 1)
                                              .toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 36,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Material(
                              color: _brandColor,
                              shape: const CircleBorder(),
                              elevation: 2,
                              child: InkWell(
                                onTap: _showImageSourceDialog,
                                customBorder: const CircleBorder(),
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.camera_alt_rounded,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Tap camera to change photo',
                        style: TextStyle(
                          fontSize: 12,
                          color: onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _sectionHeader('Personal Information'),
                _formCard(
                  children: [
                    _fieldLabel('Full Name'),
                    TextFormField(
                      controller: _nameController,
                      style: _inputTextStyle,
                      cursorColor: _brandColor,
                      textInputAction: TextInputAction.next,
                      decoration: _fieldDecoration(
                        hintText: 'Enter your full name',
                        prefixIcon: const Icon(
                          Icons.person_outline_rounded,
                          size: 20,
                          color: _hintColor,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    _fieldSpacer(),
                    _fieldLabel('Username'),
                    TextFormField(
                      controller: _usernameController,
                      enabled: false,
                      style: _inputTextStyle.copyWith(color: _hintColor),
                      decoration: _fieldDecoration(
                        hintText: 'Your unique username',
                        fillColor: const Color(0xFFF3F4F6),
                        prefixIcon: const Icon(
                          Icons.alternate_email_rounded,
                          size: 20,
                          color: _hintColor,
                        ),
                        suffixIcon: const Icon(
                          Icons.lock_outline_rounded,
                          size: 18,
                          color: _hintColor,
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 6, left: 2),
                      child: Text(
                        'Username cannot be changed',
                        style: TextStyle(fontSize: 11, color: _hintColor),
                      ),
                    ),
                    _fieldSpacer(),
                    _fieldLabel('Phone Number', optional: true),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: _inputTextStyle,
                      cursorColor: _brandColor,
                      textInputAction: TextInputAction.next,
                      decoration: _fieldDecoration(
                        hintText: 'e.g. +1 555 123 4567',
                        prefixIcon: const Icon(
                          Icons.phone_outlined,
                          size: 20,
                          color: _hintColor,
                        ),
                      ),
                    ),
                    _fieldSpacer(),
                    _fieldLabel('Gender', optional: true),
                    DropdownButtonFormField<String>(
                      value: _selectedGender,
                      style: _inputTextStyle,
                      dropdownColor: _cardBg,
                      iconEnabledColor: _hintColor,
                      isExpanded: true,
                      decoration: _fieldDecoration(
                        hintText: 'Select gender',
                        prefixIcon: const Icon(
                          Icons.wc_outlined,
                          size: 20,
                          color: _hintColor,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'male',
                          child: Text('Male',
                              style: TextStyle(
                                  fontSize: 15, color: _textColor)),
                        ),
                        DropdownMenuItem(
                          value: 'female',
                          child: Text('Female',
                              style: TextStyle(
                                  fontSize: 15, color: _textColor)),
                        ),
                        DropdownMenuItem(
                          value: 'other',
                          child: Text('Other',
                              style: TextStyle(
                                  fontSize: 15, color: _textColor)),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedGender = value;
                        });
                      },
                    ),
                    _fieldSpacer(),
                    _fieldLabel('Date of Birth', optional: true),
                    InkWell(
                      onTap: _selectDateOfBirth,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: _fieldDecoration(
                          hintText: 'Select date of birth',
                          prefixIcon: const Icon(
                            Icons.calendar_today_outlined,
                            size: 20,
                            color: _hintColor,
                          ),
                          suffixIcon: const Icon(
                            Icons.chevron_right_rounded,
                            color: _hintColor,
                          ),
                        ),
                        child: Text(
                          _selectedDateOfBirth != null
                              ? DateFormat('MMMM d, yyyy')
                                  .format(_selectedDateOfBirth!)
                              : 'Select date of birth',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: _selectedDateOfBirth != null
                                ? _textColor
                                : _hintColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brandColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          _brandColor.withValues(alpha: 0.5),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Save Changes',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
