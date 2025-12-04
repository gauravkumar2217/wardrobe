import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/fcm_service.dart';
import '../models/user_profile.dart';

/// Auth provider for managing authentication state
class AuthProvider with ChangeNotifier {
  User? _user;
  UserProfile? _userProfile;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isInitialized = false;

  User? get user => _user;
  UserProfile? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;
  bool get isInitialized => _isInitialized;

  /// Initialize auth provider
  Future<void> initialize() async {
    if (_isInitialized) return;

    _isLoading = true;
    // Defer notifyListeners to avoid calling during build phase
    Future.microtask(() => notifyListeners());

    try {
      _user = AuthService.getCurrentUser();
      
      if (_user != null) {
        await _loadUserProfile(_user!.uid);
        // Register FCM token for already logged-in user
        try {
          await FCMService.registerDeviceToken(_user!.uid);
        } catch (e) {
          debugPrint('Failed to register FCM token on init: $e');
        }
      }

      // Listen to auth state changes
      AuthService.authStateChanges.listen((user) async {
        _user = user;
        if (user != null) {
          await _loadUserProfile(user.uid);
          // Register FCM token when user logs in
          try {
            await FCMService.registerDeviceToken(user.uid);
          } catch (e) {
            debugPrint('Failed to register FCM token on auth change: $e');
          }
        } else {
          _userProfile = null;
        }
        notifyListeners();
      });
    } catch (e) {
      _errorMessage = 'Failed to initialize auth: $e';
    } finally {
      _isLoading = false;
      _isInitialized = true;
      // Defer notifyListeners to avoid calling during build phase
      Future.microtask(() => notifyListeners());
    }
  }

  /// Load user profile
  Future<void> _loadUserProfile(String userId) async {
    try {
      _userProfile = await UserService.getUserProfile(userId);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load user profile: $e');
    }
  }

  /// Sign in with phone (OTP)
  Future<bool> signInWithPhone({
    required String phoneNumber,
    required String verificationId,
    required String smsCode,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final userCredential = await AuthService.signInWithPhone(
        phoneNumber: phoneNumber,
        verificationId: verificationId,
        smsCode: smsCode,
      );

      _user = userCredential.user;
      if (_user != null) {
        await _loadUserProfile(_user!.uid);
        // Register FCM token after successful phone sign-in
        try {
          await FCMService.registerDeviceToken(_user!.uid);
        } catch (e) {
          debugPrint('Failed to register FCM token after phone sign-in: $e');
        }
      }

      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = 'Failed to sign in: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sign in with Google
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final userCredential = await AuthService.signInWithGoogle();
      _user = userCredential.user;
      
      if (_user != null) {
        await _loadUserProfile(_user!.uid);
        // Register FCM token after successful Google sign-in
        try {
          await FCMService.registerDeviceToken(_user!.uid);
        } catch (e) {
          debugPrint('Failed to register FCM token after Google sign-in: $e');
        }
      }

      _errorMessage = null;
      return true;
    } catch (e) {
      final errorStr = e.toString();
      
      // Check if this is a special success indicator (user authenticated but can't return credential)
      if (errorStr.contains('GOOGLE_SIGNIN_SUCCESS_USER_AUTHENTICATED')) {
        // User is already authenticated - check Firebase auth state
        final currentUser = AuthService.getCurrentUser();
        if (currentUser != null) {
          _user = currentUser;
          await _loadUserProfile(_user!.uid);
          // Register FCM token after successful Google sign-in (workaround case)
          try {
            await FCMService.registerDeviceToken(_user!.uid);
          } catch (e) {
            debugPrint('Failed to register FCM token after Google sign-in (workaround): $e');
          }
          _errorMessage = null;
          _isLoading = false;
          notifyListeners();
          return true; // Success - user is authenticated
        }
      }
      
      _errorMessage = 'Failed to sign in with Google: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sign in with username and password
  Future<bool> signInWithUsername({
    required String username,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Look up email from username
      debugPrint('Attempting to sign in with username: $username');
      final email = await UserService.getEmailByUsername(username);
      
      if (email == null) {
        _errorMessage = 'Username not found. Please check your username or create an account.';
        debugPrint('Username lookup failed for: $username');
        _isLoading = false;
        notifyListeners();
        return false;
      }

      debugPrint('Found email for username, attempting sign in: $email');

      // Sign in with email and password
      UserCredential? userCredential;
      try {
        userCredential = await AuthService.signInWithEmail(
          email: email,
          password: password,
        );
      } catch (e) {
        final errorStr = e.toString();
        debugPrint('Sign in error: $errorStr');
        
        // Handle type casting error - check if user is actually authenticated
        if (errorStr.contains('List<Object?>') || errorStr.contains('PigeonUserDetails')) {
          // Wait a moment for Firebase to update auth state
          await Future.delayed(const Duration(milliseconds: 300));
          final currentUser = AuthService.getCurrentUser();
          if (currentUser != null && currentUser.email == email) {
            // User is authenticated despite the error - proceed with sign-in
            debugPrint('User authenticated despite error, proceeding with sign-in');
            _user = currentUser;
            await _loadUserProfile(_user!.uid);
            // Register FCM token after successful email sign-in (recovered from error)
            try {
              await FCMService.registerDeviceToken(_user!.uid);
            } catch (e) {
              debugPrint('Failed to register FCM token after email sign-in (recovered): $e');
            }
            _errorMessage = null;
            debugPrint('Sign in successful (recovered from error)');
            return true;
          }
        }
        
        // Re-throw if it's not a recoverable error
        rethrow;
      }

      _user = userCredential.user;
      if (_user != null) {
        await _loadUserProfile(_user!.uid);
        // Register FCM token after successful email sign-in
        try {
          await FCMService.registerDeviceToken(_user!.uid);
        } catch (e) {
          debugPrint('Failed to register FCM token after email sign-in: $e');
        }
      }

      _errorMessage = null;
      debugPrint('Sign in successful');
      return true;
    } catch (e) {
      final errorStr = e.toString();
      debugPrint('Sign in error: $errorStr');
      
      // Provide more specific error messages
      if (errorStr.contains('wrong-password') || errorStr.contains('invalid-credential')) {
        _errorMessage = 'Incorrect password. Please try again.';
      } else if (errorStr.contains('user-not-found')) {
        _errorMessage = 'User not found. Please check your username.';
      } else if (errorStr.contains('index') || errorStr.contains('Index')) {
        _errorMessage = 'Database configuration error. Please contact support.';
      } else if (errorStr.contains('List<Object?>') || errorStr.contains('PigeonUserDetails')) {
        _errorMessage = 'Sign-in encountered a compatibility issue. Please try again.';
      } else {
        _errorMessage = 'Failed to sign in: $e';
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sign in with email and password
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final userCredential = await AuthService.signInWithEmail(
        email: email,
        password: password,
      );

      _user = userCredential.user;
      if (_user != null) {
        await _loadUserProfile(_user!.uid);
        // Register FCM token after successful email sign-in
        try {
          await FCMService.registerDeviceToken(_user!.uid);
        } catch (e) {
          debugPrint('Failed to register FCM token after email sign-in: $e');
        }
      }

      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = 'Failed to sign in: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Register with email and password
  Future<bool> registerWithEmail({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final userCredential = await AuthService.registerWithEmail(
        email: email,
        password: password,
      );

      _user = userCredential.user;
      if (_user != null) {
        await _loadUserProfile(_user!.uid);
        // Register FCM token after successful email registration
        try {
          await FCMService.registerDeviceToken(_user!.uid);
        } catch (e) {
          debugPrint('Failed to register FCM token after email registration: $e');
        }
      }

      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = 'Failed to register: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sign out
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      await AuthService.signOut();
      _user = null;
      _userProfile = null;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to sign out: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update user profile
  Future<void> updateProfile(UserProfile profile) async {
    if (_user == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await UserService.createOrUpdateProfile(
        userId: _user!.uid,
        profile: profile,
      );
      _userProfile = profile;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to update profile: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh user profile
  Future<void> refreshProfile() async {
    if (_user != null) {
      await _loadUserProfile(_user!.uid);
    }
  }

  /// Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

