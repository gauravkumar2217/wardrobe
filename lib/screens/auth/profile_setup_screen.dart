import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_profile.dart';
import '../../services/user_service.dart';
import 'phone_verification_screen.dart';
import '../main_navigation.dart';

/// Profile setup screen for new users
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _selectedGender;
  DateTime? _selectedDateOfBirth;
  bool _isCheckingUsername = false;
  bool _isUsernameAvailable = false;
  bool _isLoading = false;
  bool _showOptionalFields = false;

  @override
  void initState() {
    super.initState();
    _initializeFromAuth();
  }

  void _initializeFromAuth() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    final profile = authProvider.userProfile;

    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      _nameController.text = user.displayName!;
    } else if (profile?.displayName != null) {
      _nameController.text = profile!.displayName!;
    }
    if (profile?.username != null && profile!.username!.isNotEmpty) {
      _usernameController.text = profile.username!;
      _checkUsernameAvailability();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _checkUsernameAvailability() async {
    final username = _usernameController.text.trim().toLowerCase();
    if (username.isEmpty) {
      setState(() {
        _isUsernameAvailable = false;
      });
      return;
    }

    // Validate username format
    if (username.length < 3) {
      setState(() {
        _isUsernameAvailable = false;
      });
      return;
    }

    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(username)) {
      setState(() {
        _isUsernameAvailable = false;
      });
      return;
    }

    setState(() {
      _isCheckingUsername = true;
    });

    final isAvailable = await UserService.isUsernameAvailable(username);
    
    if (mounted) {
      setState(() {
        _isCheckingUsername = false;
        _isUsernameAvailable = isAvailable;
      });
    }
  }


  Future<void> _selectDateOfBirth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
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

    if (!_isUsernameAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose an available username')),
      );
      return;
    }

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

    final phoneNumber = _phoneController.text.trim();
    final displayName = _nameController.text.trim();

    final profile = UserProfile(
      displayName: displayName.isNotEmpty ? displayName : null,
      username: _usernameController.text.trim().toLowerCase(),
      email: user.email,
      phone: phoneNumber.isNotEmpty ? phoneNumber : null,
      gender: _selectedGender,
      dateOfBirth: _selectedDateOfBirth,
      photoUrl: user.photoUrl,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      // Save profile
      await authProvider.updateProfile(profile);

      if (mounted) {
        // Navigate to phone verification screen only if phone number was provided
        if (phoneNumber.isNotEmpty) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => PhoneVerificationScreen(
                phoneNumber: phoneNumber,
                profile: profile,
              ),
            ),
          );
        } else {
          // Skip phone verification and go directly to main app
          // Pass a flag to indicate user just completed profile setup
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const MainNavigation(justCompletedProfileSetup: true),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete Your Profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                const Text(
                  'Let\'s get started',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Complete your profile to continue',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Username field
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Username *',
                    prefixIcon: const Icon(Icons.alternate_email),
                    suffixIcon: _isCheckingUsername
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : _usernameController.text.isNotEmpty
                            ? Icon(
                                _isUsernameAvailable
                                    ? Icons.check_circle
                                    : Icons.cancel,
                                color: _isUsernameAvailable
                                    ? Colors.green
                                    : Colors.red,
                              )
                            : null,
                    helperText: '3-20 characters, letters, numbers, and underscores only',
                  ),
                  onChanged: (_) => _checkUsernameAvailability(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter username';
                    }
                    if (value.length < 3) {
                      return 'Username must be at least 3 characters';
                    }
                    if (value.length > 20) {
                      return 'Username must be less than 20 characters';
                    }
                    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
                      return 'Username can only contain letters, numbers, and underscores';
                    }
                    if (!_isUsernameAvailable && value.isNotEmpty) {
                      return 'Username is already taken';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                // Optional fields section - collapsible
                InkWell(
                  onTap: () {
                    setState(() {
                      _showOptionalFields = !_showOptionalFields;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Additional Information (Optional)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[800],
                          ),
                        ),
                        Icon(
                          _showOptionalFields ? Icons.expand_less : Icons.expand_more,
                          color: Colors.grey[600],
                        ),
                      ],
                    ),
                  ),
                ),
                if (_showOptionalFields) ...[
                  const SizedBox(height: 16),
                  // Phone number field (optional)
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number (Optional)',
                      prefixIcon: Icon(Icons.phone),
                      helperText: 'Include country code (e.g., +91). Verification will be done next.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Gender field (optional)
                  DropdownButtonFormField<String>(
                    value: _selectedGender,
                    decoration: const InputDecoration(
                      labelText: 'Gender (Optional)',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Select gender (optional)')),
                      DropdownMenuItem(value: 'male', child: Text('Male')),
                      DropdownMenuItem(value: 'female', child: Text('Female')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedGender = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  // Date of Birth field (optional)
                  InkWell(
                    onTap: _selectDateOfBirth,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date of Birth (Optional)',
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        _selectedDateOfBirth != null
                            ? DateFormat('yyyy-MM-dd').format(_selectedDateOfBirth!)
                            : 'Select date of birth (optional)',
                        style: TextStyle(
                          color: _selectedDateOfBirth != null
                              ? Colors.black
                              : Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
