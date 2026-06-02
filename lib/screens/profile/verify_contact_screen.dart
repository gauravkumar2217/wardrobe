import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';

/// Verify phone or email screen
class VerifyContactScreen extends StatefulWidget {
  const VerifyContactScreen({super.key});

  @override
  State<VerifyContactScreen> createState() => _VerifyContactScreenState();
}

class _VerifyContactScreenState extends State<VerifyContactScreen> {
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _verificationId;
  int _resendTimer = 0;
  bool _emailVerified = false;
  bool _phoneVerified = false;
  String? _phoneNumber;

  @override
  void initState() {
    super.initState();
    _checkVerificationStatus();
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _checkVerificationStatus() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    final profile = authProvider.userProfile;

    if (user != null) {
      // Email is verified if user has email and it's verified, or if account was created with email
      _emailVerified = user.email != null &&
          (user.emailVerified ||
              user.providerData.any((info) => info.providerId == 'password'));

      // Phone is verified if user has phoneNumber in Firebase Auth
      _phoneVerified = user.phoneNumber != null;
      _phoneNumber = user.phoneNumber ?? profile?.phone;
    }
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

  Future<void> _sendEmailVerification() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      if (user == null || user.email == null) {
        throw Exception('Email not found');
      }

      await user.sendEmailVerification();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email sent. Please check your inbox.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send verification email: $e')),
        );
      }
    }
  }

  Future<void> _sendPhoneOTP() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    final profile = authProvider.userProfile;

    String? phoneNumber = user?.phoneNumber ?? profile?.phone;

    if (phoneNumber == null || phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number not found in profile')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String formattedPhone = phoneNumber.trim();
      if (!formattedPhone.startsWith('+')) {
        formattedPhone = '+91$formattedPhone';
      }

      await AuthService.sendOTP(
        phoneNumber: formattedPhone,
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

  Future<void> _verifyEmail() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    if (user == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await user.reload();
      final updatedUser = FirebaseAuth.instance.currentUser;
      await authProvider.refreshProfile();
      _checkVerificationStatus();

      if (updatedUser?.emailVerified == true) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Email verified successfully')),
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Email not verified yet. Please check your inbox and click the verification link.'),
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
          SnackBar(content: Text('Failed to verify email: $e')),
        );
      }
    }
  }

  Future<void> _verifyPhoneOTP() async {
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
        throw Exception('User not found');
      }

      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpController.text.trim(),
      );

      await user.linkWithCredential(credential);

      // Update profile with verified phone
      final profile = authProvider.userProfile;
      if (profile != null && _phoneNumber != null) {
        final updatedProfile = profile.copyWith(
          phone: _phoneNumber,
        );
        await authProvider.updateProfile(updatedProfile);
      }

      // Refresh user to get updated phone number
      await user.reload();
      await authProvider.refreshProfile();
      _checkVerificationStatus();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phone verified successfully')),
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
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Contact'),
        backgroundColor: const Color(0xFF043915),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 6),
                    const Text(
                      'Verify Contact',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Verify your email and phone number for account security',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Email verification status
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: _emailVerified
                                        ? Colors.green.withValues(alpha: 0.1)
                                        : Colors.grey.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    _emailVerified
                                        ? Icons.check_circle
                                        : Icons.email_outlined,
                                    color: _emailVerified
                                        ? Colors.green
                                        : Colors.grey[600],
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Email Address',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        user?.email ?? 'No email',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _emailVerified
                                        ? Colors.green
                                        : Colors.orange,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    _emailVerified
                                        ? 'Verified'
                                        : 'Not Verified',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (!_emailVerified && user?.email != null) ...[
                              const SizedBox(height: 12),
                              const Divider(),
                              const SizedBox(height: 12),
                              const Text(
                                'A verification email will be sent to your email address. Please check your inbox and click the verification link.',
                                style: TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _isLoading
                                      ? null
                                      : _sendEmailVerification,
                                  icon: const Icon(Icons.send, size: 16),
                                  label: const Text('Send Verification Email',
                                      style: TextStyle(fontSize: 13)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF043915),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _isLoading ? null : _verifyEmail,
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text('Check Status',
                                      style: TextStyle(fontSize: 13)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF043915),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    side: const BorderSide(
                                      color: Color(0xFF043915),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Phone verification status
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: _phoneVerified
                                        ? Colors.green.withValues(alpha: 0.1)
                                        : Colors.grey.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    _phoneVerified
                                        ? Icons.check_circle
                                        : Icons.phone_outlined,
                                    color: _phoneVerified
                                        ? Colors.green
                                        : Colors.grey[600],
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Phone Number',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _phoneNumber != null &&
                                                _phoneNumber!.isNotEmpty
                                            ? _phoneNumber!
                                            : 'No phone number',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _phoneVerified
                                        ? Colors.green
                                        : Colors.orange,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    _phoneVerified
                                        ? 'Verified'
                                        : 'Not Verified',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (!_phoneVerified) ...[
                              const SizedBox(height: 12),
                              const Divider(),
                              const SizedBox(height: 12),
                              if (_phoneNumber == null ||
                                  _phoneNumber!.isEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        color: Colors.orange[700],
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Please add a phone number in your profile to verify it.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.orange[900],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else ...[
                                if (_verificationId == null) ...[
                                  const Text(
                                    'We will send a verification code to your phone number via SMS.',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed:
                                          _isLoading ? null : _sendPhoneOTP,
                                      icon: const Icon(Icons.sms, size: 16),
                                      label: const Text('Send OTP',
                                          style: TextStyle(fontSize: 13)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF043915),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),
                                ] else ...[
                                  const Text(
                                    'Enter the 6-digit code sent to your phone number.',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(height: 12),
                                  Form(
                                    key: _formKey,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
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
                                            labelStyle:
                                                const TextStyle(fontSize: 13),
                                            hintText: '000000',
                                            hintStyle:
                                                const TextStyle(fontSize: 20),
                                            counterText: '',
                                            prefixIcon:
                                                const Icon(Icons.pin, size: 18),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            filled: true,
                                            fillColor: Colors.grey[50],
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    vertical: 12),
                                          ),
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return 'Please enter OTP';
                                            }
                                            if (value.length != 6) {
                                              return 'OTP must be 6 digits';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 12),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton.icon(
                                            onPressed: _isLoading
                                                ? null
                                                : _verifyPhoneOTP,
                                            icon: const Icon(Icons.verified,
                                                size: 16),
                                            label: const Text('Verify OTP',
                                                style: TextStyle(fontSize: 13)),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  const Color(0xFF043915),
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                vertical: 10,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        if (_resendTimer > 0)
                                          Center(
                                            child: Text(
                                              'Resend OTP in $_resendTimer seconds',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12,
                                              ),
                                            ),
                                          )
                                        else
                                          Center(
                                            child: TextButton.icon(
                                              onPressed: _sendPhoneOTP,
                                              icon: const Icon(Icons.refresh,
                                                  size: 16),
                                              label: const Text('Resend OTP',
                                                  style:
                                                      TextStyle(fontSize: 13)),
                                              style: TextButton.styleFrom(
                                                foregroundColor:
                                                    const Color(0xFF043915),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
      ),
    );
  }
}
