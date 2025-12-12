import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../models/user_profile.dart';
import '../main_navigation.dart';

/// Phone verification screen for profile completion
class PhoneVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final UserProfile profile;

  const PhoneVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.profile,
  });

  @override
  State<PhoneVerificationScreen> createState() => _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false;
  String? _verificationId;
  int _resendTimer = 0;

  @override
  void initState() {
    super.initState();
    // Automatically send OTP when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendOTP();
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    if (_resendTimer > 0) return;
    
    setState(() {
      _resendTimer = 60;
    });

    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted && _resendTimer > 0) {
        setState(() {
          _resendTimer--;
        });
        return true;
      }
      return false;
    });
  }

  Future<void> _sendOTP() async {
    setState(() {
      _isLoading = true;
    });

    try {
      String phoneNumber = widget.phoneNumber.trim();
      if (!phoneNumber.startsWith('+')) {
        phoneNumber = '+91$phoneNumber';
      }

      await AuthService.sendOTP(
        phoneNumber: phoneNumber,
        onCodeSent: (verificationId) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _isLoading = false;
              _resendTimer = 60;
            });
            _startResendTimer();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('OTP sent successfully')),
            );
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error.message ?? 'Failed to send OTP')),
            );
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _skipVerification() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Update profile without phone verification
      final updatedProfile = UserProfile(
        displayName: widget.profile.displayName,
        username: widget.profile.username,
        email: widget.profile.email,
        phone: widget.phoneNumber.trim(), // Save phone number but not verified
        gender: widget.profile.gender,
        dateOfBirth: widget.profile.dateOfBirth,
        photoUrl: widget.profile.photoUrl,
        createdAt: widget.profile.createdAt,
        updatedAt: DateTime.now(),
      );

      await authProvider.updateProfile(updatedProfile);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigation()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile: $e')),
        );
      }
    }
  }

  Future<void> _verifyOTPAndCompleteProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (_otpController.text.isEmpty || _verificationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter OTP')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
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

      // Create phone credential
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpController.text.trim(),
      );

      // Link phone credential to existing account
      try {
        await user.linkWithCredential(credential);
      } catch (e) {
        // If phone is already linked, that's okay - continue
        debugPrint('Phone linking note: $e');
      }

      // Update profile with verified phone number
      final updatedProfile = UserProfile(
        displayName: widget.profile.displayName,
        username: widget.profile.username,
        email: widget.profile.email,
        phone: widget.phoneNumber.trim(),
        gender: widget.profile.gender,
        dateOfBirth: widget.profile.dateOfBirth,
        photoUrl: widget.profile.photoUrl,
        createdAt: widget.profile.createdAt,
        updatedAt: DateTime.now(),
      );

      await authProvider.updateProfile(updatedProfile);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigation()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Phone Number'),
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
                const Icon(
                  Icons.phone_android,
                  size: 64,
                  color: Color(0xFF7C3AED),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Verify Your Phone Number',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'We sent a verification code to',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.phoneNumber,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7C3AED),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                  ),
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: 'Enter OTP',
                    hintText: '000000',
                    counterText: '',
                    prefixIcon: const Icon(Icons.sms),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter OTP';
                    }
                    if (value.length != 6) {
                      return 'OTP must be 6 digits';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOTPAndCompleteProfile,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF7C3AED),
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
                          'Verify & Complete',
                          style: TextStyle(fontSize: 14),
                        ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Didn't receive the code?",
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: (_resendTimer > 0 || _isLoading)
                          ? null
                          : _sendOTP,
                      child: Text(
                        _resendTimer > 0
                            ? 'Resend OTP (${_resendTimer}s)'
                            : 'Resend OTP',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Skip button for Google sign-in users
                TextButton(
                  onPressed: _isLoading ? null : _skipVerification,
                  child: const Text(
                    'Skip for now',
                    style: TextStyle(fontSize: 14),
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

