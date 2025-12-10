import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/friend_provider.dart';
import '../../providers/scheduler_provider.dart';
import '../../services/user_service.dart';
import '../../models/user_profile.dart';
import 'edit_profile_screen.dart';
import 'verify_contact_screen.dart';
import '../auth/login_screen.dart';
import '../privacy_policy_screen.dart';
import '../terms_conditions_screen.dart';
import '../scheduler/scheduler_list_screen.dart';

/// Settings screen with Account, Notifications, Privacy, About, and Danger Zone
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  NotificationSettings? _notificationSettings;
  PrivacySettings? _privacySettings;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// Helper method to update notification settings
  void _updateNotificationSettings({
    bool? friendRequests,
    bool? friendAccepts,
    bool? dmMessages,
    bool? clothLikes,
    bool? clothComments,
    bool? suggestions,
    bool? scheduledNotifications,
  }) {
    if (_notificationSettings == null) return;
    
    setState(() {
      _notificationSettings = NotificationSettings(
        friendRequests: friendRequests ?? _notificationSettings!.friendRequests,
        friendAccepts: friendAccepts ?? _notificationSettings!.friendAccepts,
        dmMessages: dmMessages ?? _notificationSettings!.dmMessages,
        clothLikes: clothLikes ?? _notificationSettings!.clothLikes,
        clothComments: clothComments ?? _notificationSettings!.clothComments,
        suggestions: suggestions ?? _notificationSettings!.suggestions,
        scheduledNotifications: scheduledNotifications ?? _notificationSettings!.scheduledNotifications,
        quietHoursStart: _notificationSettings!.quietHoursStart,
        quietHoursEnd: _notificationSettings!.quietHoursEnd,
      );
    });
    _saveNotificationSettings();
  }

  Future<void> _loadSettings() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.userProfile?.settings != null) {
      final existingNotifications = authProvider.userProfile!.settings!.notifications;
      setState(() {
        // Recreate NotificationSettings by serializing and deserializing
        // This ensures all fields (including scheduledNotifications) are properly initialized
        final json = existingNotifications.toJson();
        _notificationSettings = NotificationSettings.fromJson(json);
        _privacySettings = authProvider.userProfile!.settings!.privacy;
      });
    } else {
      setState(() {
        _notificationSettings = NotificationSettings();
        _privacySettings = PrivacySettings(
          profileVisibility: 'friends',
          wardrobeVisibility: 'friends',
          allowDmFromNonFriends: false,
        );
      });
    }

    // Ensure privacy settings have default values (friends, friends, false)
    // These are set automatically and don't need to be shown in UI
    if (_privacySettings == null) {
      _privacySettings = PrivacySettings(
        profileVisibility: 'friends',
        wardrobeVisibility: 'friends',
        allowDmFromNonFriends: false,
      );
      // Save defaults if not set
      _savePrivacySettings();
    } else {
      // Ensure defaults are applied
      if (_privacySettings!.profileVisibility != 'friends' ||
          _privacySettings!.wardrobeVisibility != 'friends' ||
          _privacySettings!.allowDmFromNonFriends != false) {
        _privacySettings = PrivacySettings(
          profileVisibility: 'friends',
          wardrobeVisibility: 'friends',
          allowDmFromNonFriends: false,
        );
        _savePrivacySettings();
      }
    }
  }

  Future<void> _saveNotificationSettings() async {
    if (_notificationSettings == null) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await UserService.updateNotificationSettings(
        userId: authProvider.user!.uid,
        settings: _notificationSettings!,
      );

      // Refresh profile
      await authProvider.refreshProfile();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification settings saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _savePrivacySettings() async {
    if (_privacySettings == null) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await UserService.updatePrivacySettings(
        userId: authProvider.user!.uid,
        privacy: _privacySettings!,
      );

      // Refresh profile
      await authProvider.refreshProfile();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Privacy settings saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone. All your data will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _isLoading = true;
      });

      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final user = authProvider.user;

        if (user == null) {
          throw Exception('User not found');
        }

        // Delete user profile from Firestore
        await UserService.deleteAccount(user.uid);

        // Delete Firebase Auth account
        await user.delete();

        // Sign out
        await authProvider.signOut();

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete account: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Account section
                const _SectionHeader(title: 'Account'),
                ListTile(
                  leading: const Icon(Icons.person, color: Color(0xFF7C3AED)),
                  title: const Text('Edit Profile'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const EditProfileScreen()),
                    );
                    // Reload settings after editing profile
                    if (mounted) {
                      await _loadSettings();
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.verified, color: Color(0xFF7C3AED)),
                  title: const Text('Verify Phone/Email'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const VerifyContactScreen()),
                    );
                  },
                ),
                const SizedBox(height: 16),
                // Notifications section
                const _SectionHeader(title: 'Notifications'),
                // Always show notification toggles - initialize if null
                SwitchListTile(
                  secondary: const Icon(Icons.person_add, color: Color(0xFF7C3AED)),
                  title: const Text('Friend Requests'),
                  value: _notificationSettings?.friendRequests ?? true,
                  onChanged: (value) => _updateNotificationSettings(friendRequests: value),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.check_circle, color: Color(0xFF7C3AED)),
                  title: const Text('Friend Accepts'),
                  value: _notificationSettings?.friendAccepts ?? true,
                  onChanged: (value) => _updateNotificationSettings(friendAccepts: value),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.chat, color: Color(0xFF7C3AED)),
                  title: const Text('DM Messages'),
                  value: _notificationSettings?.dmMessages ?? true,
                  onChanged: (value) => _updateNotificationSettings(dmMessages: value),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.favorite, color: Color(0xFF7C3AED)),
                  title: const Text('Cloth Likes'),
                  value: _notificationSettings?.clothLikes ?? true,
                  onChanged: (value) => _updateNotificationSettings(clothLikes: value),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.comment, color: Color(0xFF7C3AED)),
                  title: const Text('Cloth Comments'),
                  value: _notificationSettings?.clothComments ?? true,
                  onChanged: (value) => _updateNotificationSettings(clothComments: value),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.lightbulb, color: Color(0xFF7C3AED)),
                  title: const Text('Suggestions'),
                  value: _notificationSettings?.suggestions ?? true,
                  onChanged: (value) => _updateNotificationSettings(suggestions: value),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.schedule, color: Color(0xFF7C3AED)),
                  title: const Text('Scheduled Notifications'),
                  subtitle: const Text('Daily reminders and scheduled alerts'),
                  value: _notificationSettings?.scheduledNotifications ?? true,
                  onChanged: (value) async {
                    // Initialize if null
                    if (_notificationSettings == null) {
                      setState(() {
                        _notificationSettings = NotificationSettings();
                      });
                    }
                    _updateNotificationSettings(scheduledNotifications: value);
                    
                    // Update scheduler provider
                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                    final schedulerProvider = Provider.of<SchedulerProvider>(context, listen: false);
                    if (authProvider.user != null) {
                      await schedulerProvider.setScheduledNotificationsEnabled(
                        authProvider.user!.uid,
                        value,
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.schedule, color: Color(0xFF7C3AED)),
                  title: const Text('Manage Schedules'),
                  subtitle: const Text('Create and edit notification schedules'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SchedulerListScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                // Privacy section - Hidden as per requirements (defaults are set automatically)
                // Privacy settings are set to defaults:
                // - profileVisibility: 'friends'
                // - wardrobeVisibility: 'friends'
                // - allowDmFromNonFriends: false
                // These are applied automatically and don't need to be shown in settings
                const SizedBox(height: 16),
                // About section
                const _SectionHeader(title: 'About'),
                ListTile(
                  leading:
                      const Icon(Icons.privacy_tip, color: Color(0xFF7C3AED)),
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PrivacyPolicyScreen()),
                    );
                  },
                ),
                ListTile(
                  leading:
                      const Icon(Icons.description, color: Color(0xFF7C3AED)),
                  title: const Text('Terms & Conditions'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const TermsConditionsScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.info, color: Color(0xFF7C3AED)),
                  title: const Text('About'),
                  subtitle: const Text('Wardrobe App v1.0.0'),
                ),
                const SizedBox(height: 16),
                // Danger Zone
                const _SectionHeader(title: 'Danger Zone', color: Colors.red),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title:
                      const Text('Logout', style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Logout'),
                        content: const Text('Are you sure you want to logout?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Logout',
                                style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );

                    if (confirmed == true) {
                      if (!mounted) return;
                      final logoutContext = this.context;
                      if (!mounted) return;
                      // Clean up providers before signing out
                      final chatProvider = Provider.of<ChatProvider>(
                          logoutContext,
                          listen: false);
                      final friendProvider = Provider.of<FriendProvider>(
                          logoutContext,
                          listen: false);
                      chatProvider.cleanup();
                      friendProvider.cleanup();

                      await authProvider.signOut();
                      if (context.mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen()),
                          (route) => false,
                        );
                      }
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('Delete Account',
                      style: TextStyle(color: Colors.red)),
                  onTap: _deleteAccount,
                ),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;

  const _SectionHeader({
    required this.title,
    this.color = const Color(0xFF7C3AED),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
