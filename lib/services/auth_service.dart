import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'fcm_service.dart';

/// Authentication service supporting Phone, Google, and Email/Password
class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  /// Get current user
  static User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// Check if user is logged in
  static bool isUserLoggedIn() {
    return _auth.currentUser != null;
  }

  /// Get user UID
  static String? getUserUID() {
    return _auth.currentUser?.uid;
  }

  /// Get user email
  static String? getUserEmail() {
    return _auth.currentUser?.email;
  }

  /// Get user phone number
  static String? getUserPhoneNumber() {
    return _auth.currentUser?.phoneNumber;
  }

  /// Get user display name
  static String? getUserDisplayName() {
    return _auth.currentUser?.displayName;
  }

  /// Get user photo URL
  static String? getUserPhotoURL() {
    return _auth.currentUser?.photoURL;
  }

  /// Sign in with phone number (OTP)
  static Future<UserCredential> signInWithPhone({
    required String phoneNumber,
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      
      // Register FCM token after successful login
      if (userCredential.user != null) {
        await FCMService.registerDeviceToken(userCredential.user!.uid);
      }

      return userCredential;
    } catch (e) {
      debugPrint('Phone sign-in error: $e');
      rethrow;
    }
  }

  /// Send OTP to phone number
  static Future<void> sendOTP({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(FirebaseAuthException error) onError,
    Function(PhoneAuthCredential credential)? onVerificationCompleted,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: onVerificationCompleted ?? (credential) {},
        verificationFailed: onError,
        codeSent: (verificationId, resendToken) {
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (verificationId) {},
      );
    } catch (e) {
      onError(FirebaseAuthException(code: 'unknown', message: e.toString()));
    }
  }

  /// Sign in with Google
  /// 
  /// Handles known type casting error: 'List<Object?>' is not a subtype of 'PigeonUserDetails?'
  /// This is a known issue with google_sign_in package on certain Android versions
  static Future<UserCredential> signInWithGoogle() async {
    GoogleSignInAccount? googleUser;
    GoogleSignInAuthentication? googleAuth;
    
    try {
      // Step 1: Sign out any existing Google account
      try {
        await _googleSignIn.signOut();
      } catch (e) {
        debugPrint('Warning: Error signing out previous Google account: $e');
        // Continue anyway
      }

      // Step 2: Trigger the Google Sign-In flow with error handling
      try {
        googleUser = await _googleSignIn.signIn();
      } catch (e) {
        final errorStr = e.toString();
        if (errorStr.contains('List<Object?>') || errorStr.contains('PigeonUserDetails')) {
          debugPrint('Type casting error during signIn(). Trying alternative approach...');
          // Try signInSilently first, then force new sign-in
          try {
            googleUser = await _googleSignIn.signInSilently();
            if (googleUser == null) {
              // Force a new sign-in by clearing cache
              await _googleSignIn.signOut();
              await Future.delayed(const Duration(milliseconds: 300));
              googleUser = await _googleSignIn.signIn();
            }
          } catch (silentError) {
            debugPrint('Alternative sign-in also failed: $silentError');
            throw Exception('Google sign-in failed. Please try again or use another sign-in method.');
          }
        } else {
          rethrow;
        }
      }

      if (googleUser == null) {
        throw Exception('Google sign-in was canceled');
      }

      // Step 3: Obtain authentication tokens with multiple retry strategies
      int attempts = 0;
      const maxAttempts = 3;
      
      // googleUser is guaranteed to be non-null here (checked above)
      var currentUser = googleUser;
      
      while (googleAuth == null && attempts < maxAttempts) {
        attempts++;
        try {
          googleAuth = await currentUser.authentication;
          break; // Success, exit loop
        } catch (e) {
          final errorStr = e.toString();
          debugPrint('Attempt $attempts: Error getting authentication: $e');
          
          // Check if this is the known type casting error
          if (errorStr.contains('List<Object?>') || 
              errorStr.contains('PigeonUserDetails') ||
              errorStr.contains('type') && errorStr.contains('subtype')) {
            
            if (attempts < maxAttempts) {
              // Try different strategies
              if (attempts == 1) {
                // Strategy 1: Wait and retry with same user
                debugPrint('Retrying with delay...');
                await Future.delayed(const Duration(milliseconds: 500));
                // Try again with same user
                continue;
              } else if (attempts == 2) {
                // Strategy 2: Get a fresh user object
                debugPrint('Trying with fresh sign-in...');
                try {
                  await _googleSignIn.signOut();
                  await Future.delayed(const Duration(milliseconds: 300));
                  final freshUser = await _googleSignIn.signIn();
                  if (freshUser != null) {
                    // Update currentUser reference for next iteration
                    // Note: We can't reassign currentUser, so we'll break and retry
                    googleUser = freshUser;
                    break; // Exit loop to retry with fresh user
                  }
                } catch (freshError) {
                  debugPrint('Fresh sign-in failed: $freshError');
                }
              }
            } else {
              // All attempts failed
              throw Exception(
                'Google Sign-In authentication failed due to a known compatibility issue. '
                'Please try:\n'
                '1. Restarting the app\n'
                '2. Using Phone or Email sign-in instead\n'
                '3. Updating Google Play Services on your device'
              );
            }
          } else {
            // Different error, rethrow immediately
            rethrow;
          }
        }
      }

      // Step 4: Handle case where authentication object is null
      // This can happen when native Google Sign-In succeeds but Dart API fails due to type casting
      UserCredential? userCredential;
      bool useExistingUser = false;

      if (googleAuth != null) {
        // We have authentication - proceed normally
        // Validate tokens
        final accessToken = googleAuth.accessToken;
        final idToken = googleAuth.idToken;
        if (accessToken == null && idToken == null) {
          throw Exception('Google authentication tokens are invalid');
        }

        // Create Firebase credential
        final credential = GoogleAuthProvider.credential(
          accessToken: accessToken,
          idToken: idToken,
        );

        // Sign in to Firebase
        userCredential = await _auth.signInWithCredential(credential);
      } else {
        // No authentication object - check if user is already signed in to Firebase
        // This can happen if the native Google Sign-In completed but Dart API failed
        // Wait a moment for Firebase to update its auth state
        debugPrint('Authentication object is null, checking Firebase auth state...');
        await Future.delayed(const Duration(milliseconds: 500));

        final currentUser = _auth.currentUser;
        final googleEmail = googleUser?.email;
        if (currentUser != null && googleEmail != null) {
          // Check if the current user matches the Google account
          // Match by email (most reliable) or by checking if it's a Google provider
          final isGoogleUser = currentUser.providerData.any((info) =>
              info.providerId == 'google.com' &&
              (info.email == googleEmail ||
                  currentUser.email == googleEmail));

          if (isGoogleUser || currentUser.email == googleEmail) {
            // User is already authenticated in Firebase - authentication succeeded on native side
            debugPrint(
                'User already authenticated in Firebase (email: ${currentUser.email}), proceeding without credential');
            useExistingUser = true;
            // We'll use currentUser directly instead of userCredential
          } else {
            // Different user signed in - show error
            throw Exception(
                'Failed to complete Google Sign-In. A different account is signed in. '
                'Please try again or use phone authentication.');
          }
        } else {
          // No authentication and user not in Firebase - show error
          throw Exception(
              'Failed to complete Google Sign-In due to a technical issue. '
              'Please try again or use phone authentication.\n\n'
              'Note: This may be a temporary issue with the Google Sign-In package.');
        }
      }

      // Step 5: Get the Firebase user
      final User? firebaseUser = useExistingUser
          ? _auth.currentUser
          : userCredential?.user;

      if (firebaseUser == null) {
        throw Exception('Authentication failed - no user returned');
      }

      // Step 6: Register FCM token after successful login
      try {
        await FCMService.registerDeviceToken(firebaseUser.uid);
      } catch (fcmError) {
        debugPrint('Warning: Failed to register FCM token: $fcmError');
        // Don't fail the sign-in if FCM registration fails
      }

      // Log success (especially if we used the workaround)
      if (useExistingUser) {
        debugPrint(
            'Google Sign-In completed using existing Firebase user (workaround for type casting error)');
      }

      // Return userCredential if we have it
      if (userCredential != null) {
        return userCredential;
      } else if (useExistingUser) {
        // User is already authenticated - we need to return a UserCredential
        // Since we can't create UserCredential directly, we'll try to get the ID token
        // and create a credential, or we can just re-authenticate
        // Actually, the simplest approach: try to get credential from current user's provider data
        // User is already authenticated via Google Sign-In (native side succeeded)
        // We can't recreate the Google credential, but the user is authenticated
        // The best approach: Since user is authenticated, we can't return UserCredential
        // but we can throw a special exception that indicates success
        // The caller should check if user is authenticated before showing error
        debugPrint('User already authenticated via Google Sign-In');
        debugPrint('Note: Cannot return UserCredential, but user is authenticated');
        
        // Throw a special exception that indicates authentication succeeded
        // The provider/caller should check Firebase auth state before showing error
        throw Exception('GOOGLE_SIGNIN_SUCCESS_USER_AUTHENTICATED');
      } else {
        throw Exception('Authentication failed - no user returned');
      }
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      
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

        final currentUser = _auth.currentUser;
        final googleEmail = googleUser?.email;
        if (currentUser != null && googleEmail != null) {
          // Check if the current user matches the Google account
          final isGoogleUser = currentUser.providerData.any((info) =>
              info.providerId == 'google.com' &&
              (info.email == googleEmail ||
                  currentUser.email == googleEmail));

          if (isGoogleUser || currentUser.email == googleEmail) {
            // Authentication succeeded on native side despite Dart API error
            debugPrint(
                'Type casting error occurred, but user is authenticated in Firebase (${currentUser.email}). '
                'Proceeding with successful sign-in.');

            // Register FCM token
            try {
              await FCMService.registerDeviceToken(currentUser.uid);
            } catch (fcmError) {
              debugPrint('Failed to save FCM token: $fcmError');
            }

            // User is authenticated - we can't recreate Google credential
            // but authentication succeeded, so we'll throw a special exception
            // that the provider can catch and handle as success
            throw Exception('GOOGLE_SIGNIN_SUCCESS_USER_AUTHENTICATED');
          }
        }
      }
      
      // Provide user-friendly error message
      final errorStr = e.toString();
      if (errorStr.contains('List<Object?>') || errorStr.contains('PigeonUserDetails')) {
        throw Exception(
          'Google Sign-In encountered a compatibility issue. '
          'Please try:\n'
          '• Restarting the app\n'
          '• Using Phone or Email sign-in\n'
          '• Updating Google Play Services'
        );
      }
      
      rethrow;
    }
  }

  /// Sign in with email and password
  static Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Register FCM token after successful login (non-blocking)
      // This is done in background to avoid blocking the sign-in flow
      if (userCredential.user != null) {
        FCMService.registerDeviceToken(userCredential.user!.uid).catchError((e) {
          debugPrint('Failed to register FCM token (non-critical): $e');
        });
      }

      return userCredential;
    } catch (e) {
      final errorStr = e.toString();
      debugPrint('Email sign-in error: $e');
      
      // Handle known type casting error (Firebase Auth plugin issue on Android)
      // This can occur even when sign-in succeeds - check if user is actually authenticated
      if (errorStr.contains('List<Object?>') || errorStr.contains('PigeonUserDetails')) {
        debugPrint('Type casting error detected, checking if user is authenticated...');
        // Wait a moment for Firebase to update auth state
        await Future.delayed(const Duration(milliseconds: 300));
        // Check if sign-in actually succeeded despite the error
        final currentUser = _auth.currentUser;
        if (currentUser != null && currentUser.email == email) {
          debugPrint('User is authenticated despite error. Sign-in succeeded.');
          // Register FCM token (non-blocking)
          FCMService.registerDeviceToken(currentUser.uid).catchError((e) {
            debugPrint('Failed to register FCM token (non-critical): $e');
          });
          // Return a UserCredential by getting the user's ID token and creating a credential
          // Since we can't easily create UserCredential, we'll rethrow the original error
          // and let the auth_provider handle it (it already checks for authenticated users)
        }
      }
      
      rethrow;
    }
  }

  /// Register with email and password
  static Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Register FCM token after successful registration
      if (userCredential.user != null) {
        await FCMService.registerDeviceToken(userCredential.user!.uid);
      }

      return userCredential;
    } catch (e) {
      debugPrint('Email registration error: $e');
      rethrow;
    }
  }

  /// Send password reset email
  static Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      debugPrint('Password reset error: $e');
      rethrow;
    }
  }

  /// Sign out
  static Future<void> signOut() async {
    try {
      final user = _auth.currentUser;
      
      // Deactivate FCM token before signing out
      if (user != null) {
        await FCMService.deactivateDeviceToken(user.uid);
      }

      // Sign out from Google if signed in
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }

      // Sign out from Firebase
      await _auth.signOut();
    } catch (e) {
      debugPrint('Sign out error: $e');
      rethrow;
    }
  }

  /// Listen to auth state changes
  static Stream<User?> get authStateChanges {
    return _auth.authStateChanges();
  }

  /// Update user profile
  static Future<void> updateProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      await _auth.currentUser?.updateDisplayName(displayName);
      await _auth.currentUser?.updatePhotoURL(photoURL);
      await _auth.currentUser?.reload();
    } catch (e) {
      debugPrint('Update profile error: $e');
      rethrow;
    }
  }
}

