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
    setState(() {
      _otpController.text = code!;
    });
    // Auto verify OTP when received
    if (code != null && code!.length == 6) {
      _verifyOTP();
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
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpController.text,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Invalid OTP. Please try again.');
    }
  }

  void _startResendTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _resendTimer > 0) {
        setState(() {
          _resendTimer--;
        });
        _startResendTimer();
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
                          'Welcome to WordRope',
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
                        if (code != null && code.length == 6) {
                          _verifyOTP();
                        }
                      },
                      onCodeSubmitted: (val) {
                        _verifyOTP();
                      },
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
