import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sms_autofill/sms_autofill.dart';
import 'welcome_screen.dart';

class OTPAuthScreen extends StatefulWidget {
  const OTPAuthScreen({super.key});

  @override
  State<OTPAuthScreen> createState() => _OTPAuthScreenState();
}

class _OTPAuthScreenState extends State<OTPAuthScreen> with CodeAutoFill {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isOTPSent = false;
  String? _verificationId;
  int _resendTimer = 0;
  bool _isManualInput = false; // Track if user is manually entering OTP

  @override
  void initState() {
    super.initState();
    _listenForSms();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    SmsAutoFill().unregisterListener();
    super.dispose();
  }

  void _listenForSms() {
    SmsAutoFill().listenForCode;
  }

  @override
  void codeUpdated() {
    // Only auto-fill if user hasn't started manual input
    if (!_isManualInput && code != null) {
      setState(() {
        _otpController.text = code!;
      });
      // Auto verify OTP when received
      if (code!.length == 6) {
        _verifyOTP();
      }
    }
  }

  Future<void> _sendOTP() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+91${_phoneController.text}',
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          await FirebaseAuth.instance.signInWithCredential(credential);
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const WelcomeScreen()),
            );
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            _isLoading = false;
          });
          _showErrorSnackBar('Verification failed: ${e.message}');
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _isLoading = false;
            _isOTPSent = true;
            _verificationId = verificationId;
            _resendTimer = 60;
            _isManualInput = false; // Reset manual input flag for new OTP
          });
          _startResendTimer();
          _showSuccessSnackBar('OTP sent successfully! Check your messages.');
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Error: ${e.toString()}');
    }
  }

  Future<void> _verifyOTP() async {
    if (_otpController.text.length != 6) {
      _showErrorSnackBar('Please enter a valid 6-digit OTP');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      PhoneAuthCredential credential;

      // For development: Handle test OTP
      if (_otpController.text == '123456' && _phoneController.text == '9899204201') {
        // For test phone numbers, Firebase returns verificationCompleted automatically
        // We just need to handle the credential
        if (_verificationId == null) {
          // If we don't have a verification ID, get a new one
          setState(() {
            _isLoading = false;
          });
          _showErrorSnackBar('Please resend OTP first');
          return;
        }
      }
      
      if (_verificationId == null) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('Verification ID not found. Please resend OTP.');
        return;
      }
      
      credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpController.text,
      );

      // Sign in with credential
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      // Check if sign in was successful
      if (userCredential.user != null) {
        if (mounted) {
          // Show success message before navigation
          _showSuccessSnackBar('Login successful! Redirecting...');

          // Add a small delay to ensure the success message is visible
          await Future.delayed(const Duration(milliseconds: 500));

          // Check mounted again after async operation
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const WelcomeScreen()),
            );
          }
        }
      } else {
        throw Exception('Authentication failed - no user returned');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      // More specific error handling
      String errorMessage = 'Invalid OTP. Please try again.';
      if (e.toString().contains('invalid-verification-code')) {
        errorMessage = 'Invalid OTP. Please check and try again.';
      } else if (e.toString().contains('invalid-verification-id')) {
        errorMessage = 'Session expired. Please resend OTP.';
      } else if (e.toString().contains('Verification ID not found')) {
        errorMessage = 'Please resend OTP first.';
      } else if (e.toString().contains('type')) {
        // Suppress type casting errors that occur after successful auth
        debugPrint('Auth completed but type error: $e');
        // Try to navigate anyway since auth might have succeeded
        if (FirebaseAuth.instance.currentUser != null) {
          if (mounted) {
            _showSuccessSnackBar('Login successful!');
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                );
              }
            });
          }
          return;
        }
      }

      _showErrorSnackBar(errorMessage);

      // Debug print for development
      debugPrint('OTP Verification Error: $e');
    }
  }

  void _startResendTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _resendTimer > 0) {
        setState(() {
          _resendTimer--;
        });
        _startResendTimer();
      } else if (mounted) {
        // Timer expired, reset manual input flag to allow auto-fill again
        setState(() {
          _isManualInput = false;
        });
      }
    });
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

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
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
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),

                  // Logo and Title
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Center(
                            child: Image.asset(
                              'assets/images/logo.png',
                              width: 60,
                              height: 60,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.text_fields,
                                  size: 50,
                                  color: Colors.white,
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Welcome to Wardrobe',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 28,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isOTPSent
                              ? 'Enter the OTP sent to your phone'
                              : 'Enter your mobile number to continue',
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 60),

                  // Phone Number or OTP Input
                  if (!_isOTPSent) ...[
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Mobile Number',
                        hintText: 'Enter 10-digit mobile number',
                        prefixText: '+91 ',
                        prefixStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                        labelStyle: const TextStyle(color: Colors.white),
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your mobile number';
                        }
                        if (value.length != 10) {
                          return 'Please enter a valid 10-digit number';
                        }
                        return null;
                      },
                    ),
                  ] else ...[
                    PinFieldAutoFill(
                      controller: _otpController,
                      codeLength: 6,
                      decoration: UnderlineDecoration(
                        textStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        colorBuilder: FixedColorBuilder(
                            Colors.white.withValues(alpha: 0.7)),
                      ),
                      onCodeChanged: (code) {
                        // Mark that user is manually entering OTP
                        _isManualInput = true;
                        if (code != null && code.length == 6) {
                          _verifyOTP();
                        }
                      },
                      onCodeSubmitted: (val) {
                        _isManualInput = true;
                        _verifyOTP();
                      },
                    ),

                    const SizedBox(height: 16),

                    // Development Helper
                    if (_phoneController.text == '9899204201')
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.5)),
                        ),
                        child: const Text(
                          'Development Mode: Use OTP 123456 for testing',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Resend OTP
                    if (_resendTimer > 0)
                      Text(
                        'Resend OTP in ${_resendTimer}s',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      )
                    else
                      TextButton(
                        onPressed: _sendOTP,
                        child: const Text(
                          'Resend OTP',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],

                  const SizedBox(height: 40),

                  // Action Button
                  ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : (_isOTPSent ? _verifyOTP : _sendOTP),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF7C3AED),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF7C3AED)),
                            ),
                          )
                        : Text(
                            _isOTPSent ? 'Verify OTP' : 'Send OTP',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),

                  const SizedBox(height: 40),

                  // Terms and Privacy
                  Text(
                    'By continuing, you agree to our Terms of Service and Privacy Policy',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
