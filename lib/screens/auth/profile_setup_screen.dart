import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
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
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _selectedGender;
  DateTime? _selectedDateOfBirth;
  bool _isCheckingUsername = false;
  bool _isUsernameAvailable = false;
  bool _isLoading = false;
  bool _isAppleUser = false;
  bool _isGoogleUser = false;
  bool _showOptionalFields = false;

  @override
  void initState() {
    super.initState();
    _initializeFromAuth();
  }

  void _initializeFromAuth() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    
    if (user != null) {
      // Check if user signed in with Apple or Google
      _isAppleUser = user.providerData.any((info) => info.providerId == 'apple.com');
      _isGoogleUser = user.providerData.any((info) => info.providerId == 'google.com');
      
      // Pre-populate name from Firebase Auth (Apple/Google Sign-In provides this)
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        _nameController.text = user.displayName!;
        
        // Auto-generate username suggestion from name for Apple/Google users
        if (_isAppleUser || _isGoogleUser) {
          final nameParts = user.displayName!.toLowerCase().split(' ');
          if (nameParts.isNotEmpty) {
            // Generate username from first name + last initial, or just first name
            String suggestedUsername = nameParts[0];
            if (nameParts.length > 1 && nameParts[1].isNotEmpty) {
              suggestedUsername = '${nameParts[0]}${nameParts[1][0]}';
            }
            // Remove any special characters and limit length
            suggestedUsername = suggestedUsername.replaceAll(RegExp(r'[^a-z0-9_]'), '');
            if (suggestedUsername.length > 20) {
              suggestedUsername = suggestedUsername.substring(0, 20);
            }
            if (suggestedUsername.length >= 3) {
              _usernameController.text = suggestedUsername;
              // Check availability of suggested username
              _checkUsernameAvailability();
            }
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
    // For Apple/Google users, validate only username (name/email already provided)
    final isSocialSignIn = _isAppleUser || _isGoogleUser;
    if (!isSocialSignIn && !_formKey.currentState!.validate()) return;
    
    // For Apple/Google users, still validate username
    if (isSocialSignIn) {
      final username = _usernameController.text.trim().toLowerCase();
      if (username.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a username')),
        );
        return;
      }
      if (username.length < 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Username must be at least 3 characters')),
        );
        return;
      }
      if (!RegExp(r'^[a-z0-9_]+$').hasMatch(username)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Username can only contain letters, numbers, and underscores')),
        );
        return;
      }
      if (!_isUsernameAvailable && username.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please choose an available username')),
        );
        return;
      }
    } else {
      // For non-social sign-in users, validate form normally
      if (!_formKey.currentState!.validate()) return;

      // Check if username is available
      if (!_isUsernameAvailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please choose an available username')),
        );
        return;
      }
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

    // Check if user is Google user (needs password)
    final isGoogleUser = user.providerData.any((info) => info.providerId == 'google.com');
    
    // For Google users, link email/password credential if password is provided
    if (isGoogleUser && _passwordController.text.isNotEmpty && user.email != null) {
      try {
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: _passwordController.text,
        );
        await user.linkWithCredential(credential);
      } catch (e) {
        // If linking fails (e.g., email already linked), that's okay
        // User can still continue
        debugPrint('Failed to link password credential: $e');
      }
    }

    final phoneNumber = _phoneController.text.trim();
    
    // For Apple/Google users, use displayName from Firebase Auth if name field is empty
    // (This handles cases where social sign-in provided the name but it wasn't shown in the field)
    String displayName = _nameController.text.trim();
    if (displayName.isEmpty && (_isAppleUser || _isGoogleUser) && user.displayName != null && user.displayName!.isNotEmpty) {
      displayName = user.displayName!;
    }
    
    final profile = UserProfile(
      displayName: displayName.isNotEmpty ? displayName : null,
      username: _usernameController.text.trim().toLowerCase(),
      email: user.email, // Email is already provided by Apple/Google Sign-In
      phone: phoneNumber.isNotEmpty ? phoneNumber : null,
      gender: _selectedGender,
      dateOfBirth: _selectedDateOfBirth,
      photoUrl: user.photoURL,
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
                Builder(
                  builder: (context) {
                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                    final user = authProvider.user;
                    final isAppleUser = user?.providerData.any((info) => info.providerId == 'apple.com') ?? false;
                    
                    final isGoogleUser = user?.providerData.any((info) => info.providerId == 'google.com') ?? false;
                    final isSocialSignIn = isAppleUser || isGoogleUser;
                    final socialProviderName = isAppleUser ? 'Apple Sign-In' : (isGoogleUser ? 'Google Sign-In' : '');
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Let\'s get started',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isSocialSignIn 
                              ? 'Choose a username to complete your profile'
                              : 'Complete your profile to continue',
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                        if (isSocialSignIn) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle_outline, size: 18, color: Colors.green[700]),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Your name and email from $socialProviderName are already set up. Just choose a username to continue.',
                                    style: TextStyle(fontSize: 12, color: Colors.green[900]),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),
                // Name field - hidden for Apple/Google users (already provided), required for others
                Builder(
                  builder: (context) {
                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                    final user = authProvider.user;
                    final isAppleUser = user?.providerData.any((info) => info.providerId == 'apple.com') ?? false;
                    final isGoogleUser = user?.providerData.any((info) => info.providerId == 'google.com') ?? false;
                    final isSocialSignIn = isAppleUser || isGoogleUser;
                    
                    // For Apple/Google users, don't show name field at all - it's already provided by social sign-in
                    if (isSocialSignIn) {
                      return const SizedBox.shrink();
                    }
                    
                    // For non-social sign-in users, name is required
                    return Column(
                      children: [
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
                      ],
                    );
                  },
                ),
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
                // Password fields (only for Google users)
                Builder(
                  builder: (context) {
                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                    final user = authProvider.user;
                    final isGoogleUser = user?.providerData.any((info) => info.providerId == 'google.com') ?? false;
                    
                    if (isGoogleUser) {
                      return Column(
                        children: [
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Password *',
                              prefixIcon: Icon(Icons.lock),
                              helperText: 'At least 6 characters',
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter password';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Confirm Password *',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please confirm password';
                              }
                              if (value != _passwordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
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
