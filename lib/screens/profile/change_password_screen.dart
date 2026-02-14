import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Change password screen
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (kDebugMode) {
      debugPrint('=== CHANGE PASSWORD START ===');
    }

    if (!_formKey.currentState!.validate()) {
      if (kDebugMode) {
        debugPrint('Form validation failed');
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (kDebugMode) {
        debugPrint('Step 1: Getting current user...');
      }

      final user = FirebaseAuth.instance.currentUser;

      if (kDebugMode) {
        debugPrint('Current user: ${user?.uid ?? 'null'}');
        debugPrint('User email: ${user?.email ?? 'null'}');
        debugPrint(
            'User providers: ${user?.providerData.map((p) => p.providerId).toList() ?? []}');
      }

      if (user == null || user.email == null) {
        if (kDebugMode) {
          debugPrint('ERROR: User not found or email is null');
        }
        throw Exception('User not found. Please sign in again.');
      }

      if (kDebugMode) {
        debugPrint('Step 2: Attempting to update password directly...');
        debugPrint(
            'New password length: ${_newPasswordController.text.length}');
      }

      // Try to update password directly first (might work if user was recently authenticated)
      try {
        await user.updatePassword(_newPasswordController.text);
        if (kDebugMode) {
          debugPrint(
              'SUCCESS: Password updated directly without re-authentication');
        }
      } on FirebaseAuthException catch (updateError) {
        if (updateError.code == 'requires-recent-login') {
          if (kDebugMode) {
            debugPrint(
                'Password update requires recent login. Verifying current password...');
            debugPrint('Step 3: Creating credential with email: ${user.email}');
            debugPrint(
                'Current password length: ${_currentPasswordController.text.length}');
          }

          // Verify current password by re-authenticating
          final credential = EmailAuthProvider.credential(
            email: user.email!,
            password: _currentPasswordController.text,
          );

          if (kDebugMode) {
            debugPrint('Step 4: Re-authenticating user...');
          }

          try {
            await user.reauthenticateWithCredential(credential);
            if (kDebugMode) {
              debugPrint('SUCCESS: Re-authentication successful');
            }
          } catch (reAuthError) {
            if (kDebugMode) {
              debugPrint('ERROR in re-authentication:');
              debugPrint('Error type: ${reAuthError.runtimeType}');
              debugPrint('Error toString: $reAuthError');
              if (reAuthError is FirebaseAuthException) {
                debugPrint('Error code: ${reAuthError.code}');
                debugPrint('Error message: ${reAuthError.message}');
              }
            }

            // Check if it's the known type cast error
            final errorStr = reAuthError.toString();
            if (errorStr.contains('List<Object?>') ||
                errorStr.contains('PigeonUserDetails')) {
              if (kDebugMode) {
                debugPrint(
                    'DETECTED: Known Firebase Auth bug with multi-provider accounts');
              }
              throw Exception(
                'Authentication error detected. This happens with Google sign-in accounts. '
                'Please sign out and sign in again with email/password, then try changing your password.',
              );
            }
            rethrow;
          }

          if (kDebugMode) {
            debugPrint('Step 5: Updating password after re-authentication...');
          }

          // Now update password after re-authentication
          await user.updatePassword(_newPasswordController.text);
          if (kDebugMode) {
            debugPrint('SUCCESS: Password updated after re-authentication');
          }
        } else {
          // Other error from direct update, rethrow
          rethrow;
        }
      } catch (updateError) {
        if (kDebugMode) {
          debugPrint('ERROR in password update:');
          debugPrint('Error type: ${updateError.runtimeType}');
          debugPrint('Error toString: $updateError');
          if (updateError is FirebaseAuthException) {
            debugPrint('Error code: ${updateError.code}');
            debugPrint('Error message: ${updateError.message}');
          }
        }
        rethrow;
      }

      if (mounted) {
        if (kDebugMode) {
          debugPrint('Step 5: Showing success message and closing screen');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password changed successfully')),
        );
        Navigator.pop(context);
      }

      if (kDebugMode) {
        debugPrint('=== CHANGE PASSWORD SUCCESS ===');
      }
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        debugPrint('=== FIREBASE AUTH EXCEPTION ===');
        debugPrint('Error code: ${e.code}');
        debugPrint('Error message: ${e.message}');
        debugPrint('Error details: ${e.toString()}');
        debugPrint('Stack trace: ${StackTrace.current}');
      }

      String errorMessage = 'Current password is incorrect';
      if (e.code == 'wrong-password') {
        errorMessage = 'Current password is incorrect';
      } else if (e.code == 'weak-password') {
        errorMessage = 'New password is too weak';
      } else if (e.code == 'requires-recent-login') {
        errorMessage = 'Please sign out and sign in again';
      } else if (e.code == 'invalid-credential') {
        errorMessage = 'Current password is incorrect';
      } else {
        errorMessage = 'Error: ${e.code} - ${e.message ?? 'Unknown error'}';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('=== GENERAL EXCEPTION ===');
        debugPrint('Error type: ${e.runtimeType}');
        debugPrint('Error toString: $e');
        debugPrint('Error message: ${e.toString()}');
        debugPrint('Stack trace: $stackTrace');
        if (e.toString().contains('List<Object?>')) {
          debugPrint('DETECTED: List<Object?> type cast error');
        }
        if (e.toString().contains('PigeonUserDetails')) {
          debugPrint('DETECTED: PigeonUserDetails type cast error');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to change password: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      if (kDebugMode) {
        debugPrint('=== CHANGE PASSWORD END ===');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Change Password'),
        backgroundColor: const Color(0xFF043915),
        foregroundColor: Colors.white,
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
                const Text(
                  'Change your password',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Enter your current password and choose a new one',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 32),
                // Current password field
                TextFormField(
                  controller: _currentPasswordController,
                  obscureText: _obscureCurrentPassword,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureCurrentPassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureCurrentPassword = !_obscureCurrentPassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter current password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // New password field
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: _obscureNewPassword,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNewPassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureNewPassword = !_obscureNewPassword;
                        });
                      },
                    ),
                    helperText: 'At least 6 characters',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter new password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    if (value == _currentPasswordController.text) {
                      return 'New password must be different from current password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Confirm password field
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm new password';
                    }
                    if (value != _newPasswordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _changePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF043915),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
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
                      : const Text('Change Password'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
