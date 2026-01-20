import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/user_service.dart';
import '../../models/user_profile.dart';
import 'profile_setup_screen.dart';
import 'eula_acceptance_screen.dart';
import '../main_navigation.dart';

/// Login screen with Username/Password and Google options
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSigningInWithUsername = false;
  bool _isSigningInWithGoogle = false;
  bool _isSigningInWithApple = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    if (_isSigningInWithGoogle || _isSigningInWithUsername || _isSigningInWithApple) return;

    setState(() {
      _isSigningInWithGoogle = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.signInWithGoogle();

      if (success && mounted) {
        final user = authProvider.user;
        if (user != null) {
          await _navigateAfterLogin(context, authProvider);
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authProvider.errorMessage ?? 'Sign in failed')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSigningInWithGoogle = false;
        });
      }
    }
  }

  Future<void> _signInWithApple() async {
    if (_isSigningInWithApple || _isSigningInWithUsername || _isSigningInWithGoogle) return;

    setState(() {
      _isSigningInWithApple = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.signInWithApple();

      if (success && mounted) {
        final user = authProvider.user;
        if (user != null) {
          await _navigateAfterLogin(context, authProvider);
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authProvider.errorMessage ?? 'Sign in failed')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSigningInWithApple = false;
        });
      }
    }
  }

  Future<void> _navigateAfterLogin(BuildContext context, AuthProvider authProvider) async {
    final user = authProvider.user;
    if (user == null) return;

    // Wait a moment for profile to be fully loaded (in case it was just copied)
    await Future.delayed(const Duration(milliseconds: 300));

    // Refresh profile to ensure we have the latest data
    await authProvider.refreshProfile();
    var profile = authProvider.userProfile;
    
    debugPrint('🔍 Navigation check - Initial status:');
    debugPrint('   User UID: ${user.uid}');
    debugPrint('   User Email: ${user.email}');
    debugPrint('   Profile exists: ${profile != null}');
    debugPrint('   Profile complete: ${profile?.isComplete ?? false}');
    
    // If profile doesn't exist or is incomplete, check if it exists by email
    if ((profile == null || !profile.isComplete) && user.email != null) {
      debugPrint('🔍 Checking for existing profile by email: ${user.email}');
      final existingUserId = await UserService.findUserIdByEmail(user.email!);
      if (existingUserId != null && existingUserId != user.uid) {
        debugPrint('✅ Found existing profile with userId: $existingUserId');
        // Profile exists with different UID - load it
        final existingProfile = await UserService.getUserProfile(existingUserId);
        if (existingProfile != null && existingProfile.isComplete) {
          debugPrint('📋 Copying profile to current user UID');
          // Create profile with existing data but ensure email is set
          final profileToSave = UserProfile(
            displayName: existingProfile.displayName,
            username: existingProfile.username,
            email: user.email, // Ensure email is set from current user
            phone: existingProfile.phone,
            gender: existingProfile.gender,
            dateOfBirth: existingProfile.dateOfBirth,
            photoUrl: existingProfile.photoUrl ?? user.photoURL,
            createdAt: existingProfile.createdAt,
            updatedAt: DateTime.now(),
            settings: existingProfile.settings,
          );
          // Copy profile to current user's UID
          await UserService.createOrUpdateProfile(
            userId: user.uid,
            profile: profileToSave,
          );
          // Reload profile in auth provider
          await authProvider.refreshProfile();
          profile = authProvider.userProfile;
          debugPrint('✅ Profile copied and reloaded');
        }
      }
    }
    
    // Now check BOTH EULA acceptance and profile completion
    final hasAcceptedEula = await UserService.hasAcceptedEula(user.uid);
    final hasCompleteProfile = profile != null && profile.isComplete;
    
    debugPrint('🔍 Final navigation check:');
    debugPrint('   EULA accepted: $hasAcceptedEula');
    debugPrint('   Profile complete: $hasCompleteProfile');
    
    // Decision logic:
    // 1. Both done → go to main app
    // 2. EULA done, profile not → show profile setup
    // 3. EULA not, profile done → show EULA
    // 4. Neither → show EULA first
    
    if (hasAcceptedEula && hasCompleteProfile) {
      // Both done - go directly to main app
      debugPrint('➡️ Both EULA and profile complete - Navigating to Main Navigation');
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigation()),
        );
      }
    } else if (hasAcceptedEula && !hasCompleteProfile) {
      // EULA accepted but profile incomplete - show profile setup only
      debugPrint('➡️ EULA accepted but profile incomplete - Navigating to Profile Setup');
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
        );
      }
    } else if (!hasAcceptedEula && hasCompleteProfile) {
      // Profile complete but EULA not accepted - show EULA only
      debugPrint('➡️ Profile complete but EULA not accepted - Navigating to EULA');
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const EulaAcceptanceScreen()),
        );
      }
    } else {
      // Neither - show EULA first (it will navigate to profile setup after acceptance)
      debugPrint('➡️ Neither EULA nor profile complete - Navigating to EULA first');
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const EulaAcceptanceScreen()),
        );
      }
    }
  }

  Future<void> _signInWithUsername() async {
    if (_isSigningInWithUsername || _isSigningInWithGoogle) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSigningInWithUsername = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.signInWithUsername(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );

      if (success && mounted) {
        final user = authProvider.user;
        if (user != null) {
          await _navigateAfterLogin(context, authProvider);
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authProvider.errorMessage ?? 'Sign in failed')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSigningInWithUsername = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = _isSigningInWithUsername || _isSigningInWithGoogle || _isSigningInWithApple;
    final isAppleAvailable = Platform.isIOS || Platform.isMacOS;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    const Text(
                      'Welcome',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Sign in to continue',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    TextFormField(
                      controller: _usernameController,
                      keyboardType: TextInputType.text,
                      enabled: !isLoading,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(Icons.alternate_email),
                        helperText: 'Enter your username',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter username';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      enabled: !isLoading,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: isLoading ? null : _signInWithUsername,
                      child: _isSigningInWithUsername
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Sign In'),
                    ),
                    const SizedBox(height: 8),
                    // TextButton(
                    //   onPressed: _registerWithEmail,
                    //   child: const Text('Create Account'),
                    // ),
                    const SizedBox(height: 24),
                    const Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text('OR'),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: isLoading ? null : _signInWithGoogle,
                      icon: _isSigningInWithGoogle
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.g_mobiledata),
                      label: _isSigningInWithGoogle
                          ? const Text('Signing in...')
                          : const Text('Continue with Google'),
                    ),
                    if (isAppleAvailable) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: isLoading ? null : _signInWithApple,
                        icon: _isSigningInWithApple
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.apple, color: Colors.black),
                        label: _isSigningInWithApple
                            ? const Text('Signing in...')
                            : const Text('Continue with Apple'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black,
                          side: const BorderSide(color: Colors.black),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (isLoading)
              Container(
                color: Colors.black.withValues(alpha: 0.3),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
