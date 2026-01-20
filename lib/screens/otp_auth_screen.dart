import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sms_autofill/sms_autofill.dart';
import 'home/home_screen.dart';
import '../services/fcm_token_service.dart';

class OTPAuthScreen extends StatefulWidget {
  const OTPAuthScreen({super.key});

  @override
  State<OTPAuthScreen> createState() => _OTPAuthScreenState();
}

class _OTPAuthScreenState extends State<OTPAuthScreen> with CodeAutoFill {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  // Configure Google Sign-In with web client ID from Firebase
  // Note: For Android, the web client ID is optional but recommended for better compatibility
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    // Server client ID from Firebase Console (OAuth 2.0 Client ID for Web application)
    // Get this from: Firebase Console > Authentication > Sign-in method > Google > Web client ID
    // If not provided, Google Sign-In will use the default client ID from google-services.json
  );

  bool _isLoading = false;
  bool _isOTPSent = false;
  String? _verificationId;
  int _resendTimer = 0;
  bool _isManualInput = false; // Track if user is manually entering OTP
  DateTime? _lastManualInputTime; // Track when user last typed manually
  bool _isGoogleSignInLoading = false;

  @override
  void initState() {
    super.initState();
    _listenForSms();
    // Listen to controller changes to detect manual input
    _otpController.addListener(_onOTPControllerChanged);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.removeListener(_onOTPControllerChanged);
    _otpController.dispose();
    SmsAutoFill().unregisterListener();
    super.dispose();
  }

  void _onOTPControllerChanged() {
    // Detect if user is manually typing
    final currentText = _otpController.text;
    final currentLength = currentText.length;

    // If text is being typed character by character (not all at once), it's manual input
    if (currentLength > 0 && currentLength < 6) {
      // Check if this is a gradual input (manual) vs instant fill (auto)
      final now = DateTime.now();
      if (_lastManualInputTime == null ||
          now.difference(_lastManualInputTime!) <
              const Duration(milliseconds: 100)) {
        // User is typing manually
        _isManualInput = true;
        _lastManualInputTime = now;
      }
    }
  }

  void _listenForSms() {
    SmsAutoFill().listenForCode;
  }

  @override
  void codeUpdated() {
    // Only auto-fill if:
    // 1. User hasn't started manual input, OR
    // 2. The field is empty, OR
    // 3. The auto-fill code is different from what's already there (new OTP received)
    if (code != null && code!.length == 6) {
      final currentText = _otpController.text;

      // Allow auto-fill only if:
      // - Field is completely empty, OR
      // - User hasn't manually typed AND this is a different code, OR
      // - Field has less than 6 digits AND user hasn't typed recently
      final now = DateTime.now();
      final timeSinceLastManualInput = _lastManualInputTime != null
          ? now.difference(_lastManualInputTime!)
          : const Duration(days: 1);

      if (currentText.isEmpty ||
          (!_isManualInput &&
              currentText != code &&
              timeSinceLastManualInput > const Duration(seconds: 2)) ||
          (currentText.length < 6 &&
              timeSinceLastManualInput > const Duration(seconds: 2))) {
        setState(() {
          _otpController.text = code!;
          // Reset manual input flag when auto-fill succeeds on empty field
          if (currentText.isEmpty) {
            _isManualInput = false;
            _lastManualInputTime = null;
          }
        });
        // Auto verify OTP when received via auto-fill
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && _otpController.text == code && !_isManualInput) {
            _verifyOTP();
          }
        });
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
          final userCredential =
              await FirebaseAuth.instance.signInWithCredential(credential);

          // Save FCM token for the newly logged in user
          if (userCredential.user != null) {
            try {
              await FCMTokenService.saveTokenForCurrentUser();
            } catch (e) {
              debugPrint(
                  'Failed to save FCM token after auto-verification: $e');
            }
          }

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            _isLoading = false;
          });

          // Handle redirect errors specifically for web
          String errorMessage = 'Verification failed: ${e.message}';
          if (kIsWeb &&
              e.message != null &&
              (e.message!.contains('missing initial state') ||
                  e.message!.contains('sessionStorage') ||
                  e.message!.contains('redirect'))) {
            errorMessage = 'Authentication error on web. Please ensure:\n'
                '1. Cookies and sessionStorage are enabled\n'
                '2. Not using private/incognito mode\n'
                '3. Try a different browser\n'
                '4. Clear browser cache and try again';
          }

          _showErrorSnackBar(errorMessage);
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _isLoading = false;
            _isOTPSent = true;
            _verificationId = verificationId;
            _resendTimer = 60;
            _isManualInput = false; // Reset manual input flag for new OTP
            _lastManualInputTime = null; // Reset manual input tracking
            _otpController.clear(); // Clear any previous OTP
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
      if (_otpController.text == '123456' &&
          _phoneController.text == '9899204201') {
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
        // Save FCM token for the newly logged in user
        try {
          await FCMTokenService.saveTokenForCurrentUser();
        } catch (e) {
          // Log error but don't block login
          debugPrint('Failed to save FCM token after login: $e');
        }

        if (mounted) {
          // Show success message before navigation
          _showSuccessSnackBar('Login successful! Redirecting...');

          // Add a small delay to ensure the success message is visible
          await Future.delayed(const Duration(milliseconds: 500));

          // Check mounted again after async operation
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
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
                  MaterialPageRoute(
                      builder: (context) => const HomeScreen()),
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

  /// Get Google authentication tokens from GoogleSignInAccount
  ///
  /// Note: This method uses GoogleSignInAccount (the official class) and avoids
  /// the deprecated PigeonUserDetails internally used by google_sign_in package.
  ///
  /// If the authentication property fails due to type casting issues, we rely on
  /// Firebase auth state checking as a fallback since authentication often succeeds
  /// on the native side even when the Dart API fails.
  Future<GoogleSignInAuthentication?> _getGoogleAuthentication(
    GoogleSignInAccount googleUser,
  ) async {
    try {
      // Try to get authentication using GoogleSignInAccount (official API)
      // Note: This internally may use deprecated PigeonUserDetails, but we handle errors gracefully
      final auth = await googleUser.authentication;
      return auth;
    } catch (e) {
      final errorString = e.toString();

      // Check if this is a type casting error related to deprecated PigeonUserDetails
      final isTypeCastingError = (errorString.contains('List<Object?>') &&
              errorString.contains('PigeonUserDetails')) ||
          (errorString.contains('type') &&
              errorString.contains('subtype') &&
              errorString.contains('PigeonUserDetails')) ||
          (errorString.contains('type') &&
              errorString.contains('cast') &&
              errorString.contains('Pigeon'));

      if (isTypeCastingError) {
        debugPrint(
            'Type casting error detected (likely due to deprecated PigeonUserDetails). '
            'Will check Firebase auth state as fallback.');

        // The google_sign_in package internally uses deprecated PigeonUserDetails
        // Instead of trying to work around this, we'll rely on Firebase auth state
        // since authentication often succeeds on native side even when Dart API fails
        return null; // Return null to trigger Firebase auth state check
      }

      // If it's a different error, rethrow it
      rethrow;
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isGoogleSignInLoading = true;
    });

    try {
      // First, sign out any existing Google account to ensure fresh sign-in
      await _googleSignIn.signOut();

      // Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User canceled the sign-in
        setState(() {
          _isGoogleSignInLoading = false;
        });
        return;
      }

      // Obtain the auth details from GoogleSignInAccount (official API)
      // Note: We use GoogleSignInAccount, not the deprecated PigeonUserDetails
      // If authentication property fails due to internal PigeonUserDetails issues,
      // we fall back to checking Firebase auth state
      GoogleSignInAuthentication? googleAuth;

      try {
        googleAuth = await _getGoogleAuthentication(googleUser);
      } catch (e) {
        debugPrint('Error getting authentication from GoogleSignInAccount: $e');
      }

      // If we couldn't get authentication due to type casting error, try alternative approaches
      if (googleAuth == null) {
        debugPrint(
            'Authentication object is null, trying alternative methods...');

        // Method 1: Try to get authentication from a fresh sign-in
        try {
          // Don't sign out - keep the current user signed in
          // Try to get authentication with a small delay
          await Future.delayed(const Duration(milliseconds: 300));

          // Try accessing authentication again - sometimes it works on retry
          try {
            googleAuth = await googleUser.authentication;
            debugPrint('Successfully got authentication on retry');
          } catch (retryError) {
            debugPrint('Retry also failed: $retryError');

            // Method 2: Try with a completely fresh GoogleSignIn instance
            try {
              final freshGoogleSignIn =
                  GoogleSignIn(scopes: ['email', 'profile']);
              final freshUser = await freshGoogleSignIn.signInSilently();

              if (freshUser != null && freshUser.id == googleUser.id) {
                try {
                  googleAuth = await freshUser.authentication;
                  debugPrint(
                      'Successfully got authentication from fresh instance');
                } catch (_) {
                  // Still failed
                }
              }
            } catch (_) {
              // Fresh instance approach failed
            }
          }
        } catch (altError) {
          debugPrint('Alternative authentication methods failed: $altError');
        }
      }

      // If we still don't have authentication, check if Firebase already authenticated the user
      // This can happen when:
      // 1. The google_sign_in package internally uses deprecated PigeonUserDetails
      // 2. Native side completes authentication successfully
      // 3. Dart API fails due to type casting, but Firebase auth still works
      // We use GoogleSignInAccount (official) and rely on Firebase auth state as fallback
      UserCredential? userCredential;
      bool useExistingUser = false;

      if (googleAuth != null) {
        // We have authentication - proceed normally
        // Validate that we have at least one token
        if (googleAuth.accessToken == null && googleAuth.idToken == null) {
          setState(() {
            _isGoogleSignInLoading = false;
          });
          _showErrorSnackBar(
              'Failed to get authentication tokens. Please try again.');
          return;
        }

        // Create a new credential with null-safe token handling
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        // Sign in to Firebase with the Google credential
        userCredential =
            await FirebaseAuth.instance.signInWithCredential(credential);
      } else {
        // No authentication object - check if user is already signed in to Firebase
        // This can happen if the native Google Sign-In completed but Dart API failed
        // Wait a moment for Firebase to update its auth state
        await Future.delayed(const Duration(milliseconds: 500));

        final currentUser = FirebaseAuth.instance.currentUser;

        if (currentUser != null) {
          // Check if the current user matches the Google account
          // Match by email (most reliable) or by checking if it's a Google provider
          final isGoogleUser = currentUser.providerData.any((info) =>
              info.providerId == 'google.com' &&
              (info.email == googleUser.email ||
                  currentUser.email == googleUser.email));

          if (isGoogleUser || currentUser.email == googleUser.email) {
            // User is already authenticated in Firebase - authentication succeeded on native side
            debugPrint(
                'User already authenticated in Firebase (email: ${currentUser.email}), proceeding without credential');
            useExistingUser = true;
            // We'll use currentUser directly instead of userCredential
          } else {
            // Different user signed in - show error
            setState(() {
              _isGoogleSignInLoading = false;
            });
            _showErrorSnackBar(
                'Failed to complete Google Sign-In. A different account is signed in. '
                'Please try again or use phone authentication.');
            return;
          }
        } else {
          // No authentication and user not in Firebase - show error
          setState(() {
            _isGoogleSignInLoading = false;
          });
          _showErrorSnackBar(
              'Failed to complete Google Sign-In due to a technical issue. '
              'Please try again or use phone authentication.\n\n'
              'Note: This may be a temporary issue with the Google Sign-In package.');
          return;
        }
      }

      // Check if sign in was successful
      final User? firebaseUser = useExistingUser
          ? FirebaseAuth.instance.currentUser
          : userCredential?.user;

      if (firebaseUser != null) {
        // Save FCM token for the newly logged in user
        try {
          await FCMTokenService.saveTokenForCurrentUser();
        } catch (e) {
          debugPrint('Failed to save FCM token after Google sign-in: $e');
        }

        // Log success (especially if we used the workaround)
        if (useExistingUser) {
          debugPrint(
              'Google Sign-In completed using existing Firebase user (workaround for type casting error)');
        }

        if (mounted) {
          setState(() {
            _isGoogleSignInLoading = false;
          });

          // Show success message
          _showSuccessSnackBar('Login successful! Redirecting...');

          // Add a small delay to ensure the success message is visible
          await Future.delayed(const Duration(milliseconds: 500));

          // Check mounted again after async operation
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          }
        }
      } else {
        throw Exception('Authentication failed - no user returned');
      }
    } catch (e) {
      // Before showing error, check if authentication actually succeeded on the native side
      // This can happen when the type casting error occurs but Firebase auth still works
      final errorString = e.toString().toLowerCase();
      final isTypeCastingError = errorString.contains('type') &&
          (errorString.contains('cast') || errorString.contains('subtype')) &&
          (errorString.contains('pigeon') ||
              errorString.contains('list<object?>'));

      if (isTypeCastingError) {
        // For type casting errors, check if Firebase already authenticated the user
        // Wait a moment for Firebase to update its auth state
        await Future.delayed(const Duration(milliseconds: 500));

        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          // Authentication succeeded on native side despite Dart API error
          debugPrint(
              'Type casting error occurred, but user is authenticated in Firebase (${currentUser.email}). '
              'Proceeding with successful sign-in.');

          // Save FCM token
          try {
            await FCMTokenService.saveTokenForCurrentUser();
          } catch (fcmError) {
            debugPrint('Failed to save FCM token: $fcmError');
          }

          if (mounted) {
            setState(() {
              _isGoogleSignInLoading = false;
            });

            // Show success message
            _showSuccessSnackBar('Login successful! Redirecting...');

            // Add a small delay to ensure the success message is visible
            await Future.delayed(const Duration(milliseconds: 500));

            // Check mounted again after async operation
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
            }
          }
          return; // Exit early - authentication succeeded
        }
      }

      setState(() {
        _isGoogleSignInLoading = false;
      });

      String errorMessage = 'Failed to sign in with Google. Please try again.';

      // Handle specific error types
      if (errorString.contains('network') || errorString.contains('internet')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else if (errorString.contains('cancel') ||
          errorString.contains('sign_in_canceled')) {
        // User canceled - don't show error
        return;
      } else if (errorString.contains('sign_in_failed') ||
          errorString.contains('apiexception: 10') ||
          errorString.contains('developer_error')) {
        errorMessage = 'Google Sign-In configuration error. Please ensure:\n'
            '1. SHA-1 fingerprint is added to Firebase Console\n'
            '2. Google Sign-In is enabled in Firebase Authentication\n'
            '3. OAuth client is properly configured';
      } else if (isTypeCastingError) {
        // Type casting error - but we already checked Firebase above
        // If we reach here, Firebase doesn't have the user, so show error
        errorMessage =
            'Sign-in error occurred. Please try again or use phone authentication.';
        debugPrint(
            'Type casting error in Google Sign-In (Firebase auth check failed): $e');
      } else if (errorString.contains('invalid_credential') ||
          errorString.contains('account-exists-with-different-credential')) {
        errorMessage =
            'This account is already registered with a different sign-in method.';
      }

      _showErrorSnackBar(errorMessage);
      debugPrint('Google Sign-In Error: $e');
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
        width: double.infinity,
        height: double.infinity,
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
                              'assets/images/logo-chat.png',
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
                    // OTP Input Field - supports both auto-fill and manual entry
                    TextFormField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Enter OTP',
                        hintText: '000000',
                        counterText: '',
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
                          fontSize: 24,
                          letterSpacing: 8,
                        ),
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 8,
                      ),
                      onChanged: (value) {
                        // Mark as manual input when user types
                        if (value.isNotEmpty) {
                          setState(() {
                            _isManualInput = true;
                            _lastManualInputTime = DateTime.now();
                          });
                        }
                        // Auto-verify when 6 digits are entered manually
                        if (value.length == 6) {
                          Future.delayed(const Duration(milliseconds: 300), () {
                            if (mounted && _otpController.text.length == 6) {
                              _verifyOTP();
                            }
                          });
                        }
                      },
                      onTap: () {
                        // When user taps the field, allow manual input
                        setState(() {
                          _isManualInput = true;
                        });
                      },
                    ),

                    const SizedBox(height: 8),

                    // Helper text
                    Text(
                      'OTP will be auto-filled if received via SMS',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
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

                  const SizedBox(height: 24),

                  // OR Divider
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: Colors.white.withValues(alpha: 0.3),
                          thickness: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: Colors.white.withValues(alpha: 0.3),
                          thickness: 1,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Google Sign-In Button
                  OutlinedButton.icon(
                    onPressed: _isGoogleSignInLoading || _isLoading
                        ? null
                        : _signInWithGoogle,
                    icon: _isGoogleSignInLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Image.asset(
                            'assets/images/google_logo.png',
                            width: 20,
                            height: 20,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.g_mobiledata,
                                color: Colors.white,
                                size: 24,
                              );
                            },
                          ),
                    label: Text(
                      _isGoogleSignInLoading
                          ? 'Signing in...'
                          : 'Continue with Google',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
