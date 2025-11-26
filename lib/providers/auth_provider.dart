import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
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
    notifyListeners();

    try {
      _user = AuthService.getCurrentUser();
      
      if (_user != null) {
        await _loadUserProfile(_user!.uid);
      }

      // Listen to auth state changes
      AuthService.authStateChanges.listen((user) async {
        _user = user;
        if (user != null) {
          await _loadUserProfile(user.uid);
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
      notifyListeners();
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
      }

      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = 'Failed to sign in with Google: $e';
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

