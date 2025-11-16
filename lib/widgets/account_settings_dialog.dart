import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/account_deletion_service.dart';
import '../services/auth_service.dart';
import '../services/fcm_token_service.dart';
import '../screens/otp_auth_screen.dart';
import '../screens/about_screen.dart';
import '../screens/privacy_policy_screen.dart';
import '../screens/terms_conditions_screen.dart';
import '../screens/notification_schedule_screen.dart';
import '../main.dart';

class AccountSettingsDialog extends StatelessWidget {
  const AccountSettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Account Settings'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // About
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.blue),
              title: const Text('About'),
              subtitle: const Text('App information and credits'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AboutScreen(),
                  ),
                );
              },
            ),
            const Divider(),
            // Privacy Policy
            ListTile(
              leading: const Icon(Icons.privacy_tip, color: Colors.green),
              title: const Text('Privacy Policy'),
              subtitle: const Text('How we handle your data'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PrivacyPolicyScreen(),
                  ),
                );
              },
            ),
            const Divider(),
            // Terms & Conditions
            ListTile(
              leading: const Icon(Icons.description, color: Colors.purple),
              title: const Text('Terms & Conditions'),
              subtitle: const Text('Terms of service'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TermsConditionsScreen(),
                  ),
                );
              },
            ),
            const Divider(),
            // Notification Schedules
            ListTile(
              leading:
                  const Icon(Icons.notifications_active, color: Colors.purple),
              title: const Text('Notification Schedules'),
              subtitle: const Text('Schedule outfit notifications'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationScheduleScreen(),
                  ),
                );
              },
            ),
            const Divider(),
            // Logout
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.orange),
              title: const Text('Logout'),
              subtitle: const Text('Sign out from your account'),
              onTap: () {
                Navigator.pop(context);
                _showLogoutConfirmation(context);
              },
            ),
            const Divider(),
            // Delete Account
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Delete Account'),
              subtitle:
                  const Text('Permanently delete your account and all data'),
              onTap: () {
                Navigator.pop(context);
                _showDeleteAccountConfirmation(context);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close confirmation dialog
              await _performLogout(context);
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Future<void> _performLogout(BuildContext context) async {
    // Check if user is already logged out before attempting logout
    final currentUser = FirebaseAuth.instance.currentUser;
    final token = FCMTokenService.getCurrentToken();

    // If user is not authenticated and token is not available,
    // user is already logged out - redirect immediately
    if (currentUser == null && token == null) {
      debugPrint('User already logged out, redirecting to login screen');
      // Close any open dialogs first
      if (context.mounted) {
        Navigator.of(context)
            .popUntil((route) => route.isFirst || route.settings.name == '/');
      }

      // Try navigation with context first, then global navigator key
      bool redirectSuccess = false;
      if (context.mounted) {
        try {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const OTPAuthScreen(),
            ),
            (route) => false,
          );
          redirectSuccess = true;
        } catch (e) {
          debugPrint('Redirect using context failed: $e');
        }
      }

      // Fallback to global navigator key
      if (!redirectSuccess && navigatorKey.currentState != null) {
        try {
          navigatorKey.currentState!.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const OTPAuthScreen(),
            ),
            (route) => false,
          );
          redirectSuccess = true;
        } catch (e) {
          debugPrint('Redirect using global navigator key failed: $e');
        }
      }

      if (!redirectSuccess) {
        debugPrint('All redirect methods failed');
      }
      return;
    }

    // Show loading indicator
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Perform sign out with proper cleanup
      // AuthService.signOut() handles FCM token deactivation internally
      debugPrint('Starting sign out process...');
      await AuthService.signOut().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('Sign out timed out, proceeding with navigation');
        },
      );
      debugPrint('Sign out completed, verifying user state...');

      // Wait a moment to ensure Firebase auth state is fully cleared
      await Future.delayed(const Duration(milliseconds: 300));

      // Verify user is actually logged out
      final userAfterSignOut = FirebaseAuth.instance.currentUser;
      if (userAfterSignOut != null) {
        debugPrint('User still logged in after signOut, forcing sign out');
        // Force sign out again (this should be rare)
        try {
          await FirebaseAuth.instance.signOut().timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              debugPrint('Force sign out timed out');
            },
          );
          await Future.delayed(const Duration(milliseconds: 300));
        } catch (e) {
          debugPrint('Force sign out error: $e');
        }
      } else {
        debugPrint('User successfully logged out, proceeding with navigation');
      }

      // Close all dialogs first (including loading and settings dialogs)
      if (context.mounted) {
        // Pop all dialogs until we reach the base route
        Navigator.of(context).popUntil((route) {
          return route.isFirst ||
              route.settings.name == '/' ||
              !route.willHandlePopInternally;
        });
        // Small delay to ensure dialogs are closed
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Navigate to OTP Auth Screen and remove all previous routes
      // Use both context and global navigator key as fallback
      bool navigationSuccess = false;

      if (context.mounted) {
        debugPrint('Navigating to login screen using context...');
        try {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const OTPAuthScreen(),
            ),
            (route) => false,
          );
          navigationSuccess = true;
          debugPrint('Navigation completed using context');
        } catch (e) {
          debugPrint('Navigation using context failed: $e');
        }
      }

      // Fallback to global navigator key if context navigation failed
      if (!navigationSuccess && navigatorKey.currentState != null) {
        debugPrint('Using global navigator key for navigation...');
        try {
          navigatorKey.currentState!.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const OTPAuthScreen(),
            ),
            (route) => false,
          );
          navigationSuccess = true;
          debugPrint('Navigation completed using global navigator key');
        } catch (e) {
          debugPrint('Navigation using global navigator key failed: $e');
        }
      }

      if (!navigationSuccess) {
        debugPrint(
            'All navigation methods failed, user may need to restart app');
      }

      // Show success message after navigation
      Future.delayed(const Duration(milliseconds: 500), () {
        final navContext = navigatorKey.currentContext;
        if (navContext != null) {
          // navigatorKey.currentContext is safe to use after async gaps as it's a global navigator key
          final messenger = ScaffoldMessenger.maybeOf(
              navContext); // ignore: use_build_context_synchronously
          messenger?.showSnackBar(
            const SnackBar(
              content: Text('Logged out successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      });
    } catch (e) {
      debugPrint('Error during sign out: $e');

      // Close all dialogs
      if (context.mounted) {
        Navigator.of(context).popUntil((route) {
          return route.isFirst ||
              route.settings.name == '/' ||
              !route.willHandlePopInternally;
        });
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Even if there was an error, try to navigate to login screen
      // This ensures user can always get back to login
      debugPrint('Attempting emergency navigation to login screen...');
      // Force sign out from Firebase directly as last resort
      try {
        await FirebaseAuth.instance.signOut().timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            debugPrint('Emergency sign out timed out');
          },
        );
      } catch (e2) {
        debugPrint('Emergency sign out error: $e2');
      }

      // Try navigation with context first, then global navigator key
      bool emergencyNavigationSuccess = false;

      if (context.mounted) {
        try {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const OTPAuthScreen(),
            ),
            (route) => false,
          );
          emergencyNavigationSuccess = true;
          debugPrint('Emergency navigation completed using context');
        } catch (e) {
          debugPrint('Emergency navigation using context failed: $e');
        }
      }

      // Fallback to global navigator key
      if (!emergencyNavigationSuccess && navigatorKey.currentState != null) {
        try {
          navigatorKey.currentState!.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const OTPAuthScreen(),
            ),
            (route) => false,
          );
          emergencyNavigationSuccess = true;
          debugPrint(
              'Emergency navigation completed using global navigator key');
        } catch (e) {
          debugPrint(
              'Emergency navigation using global navigator key failed: $e');
        }
      }

      if (!emergencyNavigationSuccess) {
        debugPrint('Emergency navigation failed, user may need to restart app');
      }

      // Show message
      Future.delayed(const Duration(milliseconds: 500), () {
        final navContext = navigatorKey.currentContext;
        if (navContext != null) {
          // navigatorKey.currentContext is safe to use after async gaps as it's a global navigator key
          final messenger = ScaffoldMessenger.maybeOf(
              navContext); // ignore: use_build_context_synchronously
          messenger?.showSnackBar(
            const SnackBar(
              content: Text('Logged out successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      });
    }
  }

  void _showDeleteAccountConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone. All your wardrobes, clothes, suggestions, and chat history will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteAccount(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      await AccountDeletionService.deleteAccount(user.uid);

      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const OTPAuthScreen(),
          ),
          (route) => false,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete account: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
