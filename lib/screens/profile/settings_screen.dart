import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/user_service.dart';
import '../../models/user_profile.dart';
import '../auth/login_screen.dart';
import '../privacy_policy_screen.dart';
import '../terms_conditions_screen.dart';

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

  Future<void> _loadSettings() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.userProfile?.settings != null) {
      setState(() {
        _notificationSettings = authProvider.userProfile!.settings!.notifications;
        _privacySettings = authProvider.userProfile!.settings!.privacy;
      });
    } else {
      setState(() {
        _notificationSettings = NotificationSettings();
        _privacySettings = PrivacySettings();
      });
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
      // TODO: Implement OTP confirmation for account deletion
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account deletion requires OTP confirmation')),
      );
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
                  onTap: () {
                    // TODO: Navigate to edit profile screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Edit profile coming soon')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.lock, color: Color(0xFF7C3AED)),
                  title: const Text('Change Password'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Navigate to change password screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Change password coming soon')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.verified, color: Color(0xFF7C3AED)),
                  title: const Text('Verify Phone/Email'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Navigate to verification screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Verification coming soon')),
                    );
                  },
                ),
                const SizedBox(height: 16),
                // Notifications section
                const _SectionHeader(title: 'Notifications'),
                if (_notificationSettings != null) ...[
                  SwitchListTile(
                    secondary: const Icon(Icons.person_add, color: Color(0xFF7C3AED)),
                    title: const Text('Friend Requests'),
                    value: _notificationSettings!.friendRequests,
                    onChanged: (value) {
                      setState(() {
                        _notificationSettings = NotificationSettings(
                          friendRequests: value,
                          friendAccepts: _notificationSettings!.friendAccepts,
                          dmMessages: _notificationSettings!.dmMessages,
                          clothLikes: _notificationSettings!.clothLikes,
                          clothComments: _notificationSettings!.clothComments,
                          suggestions: _notificationSettings!.suggestions,
                          quietHoursStart: _notificationSettings!.quietHoursStart,
                          quietHoursEnd: _notificationSettings!.quietHoursEnd,
                        );
                      });
                      _saveNotificationSettings();
                    },
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.check_circle, color: Color(0xFF7C3AED)),
                    title: const Text('Friend Accepts'),
                    value: _notificationSettings!.friendAccepts,
                    onChanged: (value) {
                      setState(() {
                        _notificationSettings = NotificationSettings(
                          friendRequests: _notificationSettings!.friendRequests,
                          friendAccepts: value,
                          dmMessages: _notificationSettings!.dmMessages,
                          clothLikes: _notificationSettings!.clothLikes,
                          clothComments: _notificationSettings!.clothComments,
                          suggestions: _notificationSettings!.suggestions,
                          quietHoursStart: _notificationSettings!.quietHoursStart,
                          quietHoursEnd: _notificationSettings!.quietHoursEnd,
                        );
                      });
                      _saveNotificationSettings();
                    },
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.chat, color: Color(0xFF7C3AED)),
                    title: const Text('DM Messages'),
                    value: _notificationSettings!.dmMessages,
                    onChanged: (value) {
                      setState(() {
                        _notificationSettings = NotificationSettings(
                          friendRequests: _notificationSettings!.friendRequests,
                          friendAccepts: _notificationSettings!.friendAccepts,
                          dmMessages: value,
                          clothLikes: _notificationSettings!.clothLikes,
                          clothComments: _notificationSettings!.clothComments,
                          suggestions: _notificationSettings!.suggestions,
                          quietHoursStart: _notificationSettings!.quietHoursStart,
                          quietHoursEnd: _notificationSettings!.quietHoursEnd,
                        );
                      });
                      _saveNotificationSettings();
                    },
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.favorite, color: Color(0xFF7C3AED)),
                    title: const Text('Cloth Likes'),
                    value: _notificationSettings!.clothLikes,
                    onChanged: (value) {
                      setState(() {
                        _notificationSettings = NotificationSettings(
                          friendRequests: _notificationSettings!.friendRequests,
                          friendAccepts: _notificationSettings!.friendAccepts,
                          dmMessages: _notificationSettings!.dmMessages,
                          clothLikes: value,
                          clothComments: _notificationSettings!.clothComments,
                          suggestions: _notificationSettings!.suggestions,
                          quietHoursStart: _notificationSettings!.quietHoursStart,
                          quietHoursEnd: _notificationSettings!.quietHoursEnd,
                        );
                      });
                      _saveNotificationSettings();
                    },
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.comment, color: Color(0xFF7C3AED)),
                    title: const Text('Cloth Comments'),
                    value: _notificationSettings!.clothComments,
                    onChanged: (value) {
                      setState(() {
                        _notificationSettings = NotificationSettings(
                          friendRequests: _notificationSettings!.friendRequests,
                          friendAccepts: _notificationSettings!.friendAccepts,
                          dmMessages: _notificationSettings!.dmMessages,
                          clothLikes: _notificationSettings!.clothLikes,
                          clothComments: value,
                          suggestions: _notificationSettings!.suggestions,
                          quietHoursStart: _notificationSettings!.quietHoursStart,
                          quietHoursEnd: _notificationSettings!.quietHoursEnd,
                        );
                      });
                      _saveNotificationSettings();
                    },
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.lightbulb, color: Color(0xFF7C3AED)),
                    title: const Text('Suggestions'),
                    value: _notificationSettings!.suggestions,
                    onChanged: (value) {
                      setState(() {
                        _notificationSettings = NotificationSettings(
                          friendRequests: _notificationSettings!.friendRequests,
                          friendAccepts: _notificationSettings!.friendAccepts,
                          dmMessages: _notificationSettings!.dmMessages,
                          clothLikes: _notificationSettings!.clothLikes,
                          clothComments: _notificationSettings!.clothComments,
                          suggestions: value,
                          quietHoursStart: _notificationSettings!.quietHoursStart,
                          quietHoursEnd: _notificationSettings!.quietHoursEnd,
                        );
                      });
                      _saveNotificationSettings();
                    },
                  ),
                ],
                const SizedBox(height: 16),
                // Privacy section
                const _SectionHeader(title: 'Privacy'),
                if (_privacySettings != null) ...[
                  ListTile(
                    leading: const Icon(Icons.visibility, color: Color(0xFF7C3AED)),
                    title: const Text('Profile Visibility'),
                    subtitle: Text(_privacySettings!.profileVisibility),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      _showProfileVisibilityDialog();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.inventory_2, color: Color(0xFF7C3AED)),
                    title: const Text('Wardrobe Visibility'),
                    subtitle: Text(_privacySettings!.wardrobeVisibility),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      _showWardrobeVisibilityDialog();
                    },
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.message, color: Color(0xFF7C3AED)),
                    title: const Text('Allow DM from Non-Friends'),
                    value: _privacySettings!.allowDmFromNonFriends,
                    onChanged: (value) {
                      setState(() {
                        _privacySettings = PrivacySettings(
                          profileVisibility: _privacySettings!.profileVisibility,
                          wardrobeVisibility: _privacySettings!.wardrobeVisibility,
                          allowDmFromNonFriends: value,
                        );
                      });
                      _savePrivacySettings();
                    },
                  ),
                ],
                const SizedBox(height: 16),
                // About section
                const _SectionHeader(title: 'About'),
                ListTile(
                  leading: const Icon(Icons.privacy_tip, color: Color(0xFF7C3AED)),
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.description, color: Color(0xFF7C3AED)),
                  title: const Text('Terms & Conditions'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TermsConditionsScreen()),
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
                  title: const Text('Logout', style: TextStyle(color: Colors.red)),
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
                            child: const Text('Logout', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );

                    if (confirmed == true) {
                      await authProvider.signOut();
                      if (context.mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (route) => false,
                        );
                      }
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
                  onTap: _deleteAccount,
                ),
              ],
            ),
    );
  }

  void _showProfileVisibilityDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profile Visibility'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Public'),
              value: 'public',
              groupValue: _privacySettings?.profileVisibility,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _privacySettings = PrivacySettings(
                      profileVisibility: value,
                      wardrobeVisibility: _privacySettings!.wardrobeVisibility,
                      allowDmFromNonFriends: _privacySettings!.allowDmFromNonFriends,
                    );
                  });
                  _savePrivacySettings();
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('Friends Only'),
              value: 'friends',
              groupValue: _privacySettings?.profileVisibility,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _privacySettings = PrivacySettings(
                      profileVisibility: value,
                      wardrobeVisibility: _privacySettings!.wardrobeVisibility,
                      allowDmFromNonFriends: _privacySettings!.allowDmFromNonFriends,
                    );
                  });
                  _savePrivacySettings();
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('Private'),
              value: 'private',
              groupValue: _privacySettings?.profileVisibility,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _privacySettings = PrivacySettings(
                      profileVisibility: value,
                      wardrobeVisibility: _privacySettings!.wardrobeVisibility,
                      allowDmFromNonFriends: _privacySettings!.allowDmFromNonFriends,
                    );
                  });
                  _savePrivacySettings();
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showWardrobeVisibilityDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wardrobe Visibility'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Public'),
              value: 'public',
              groupValue: _privacySettings?.wardrobeVisibility,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _privacySettings = PrivacySettings(
                      profileVisibility: _privacySettings!.profileVisibility,
                      wardrobeVisibility: value,
                      allowDmFromNonFriends: _privacySettings!.allowDmFromNonFriends,
                    );
                  });
                  _savePrivacySettings();
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('Friends Only'),
              value: 'friends',
              groupValue: _privacySettings?.wardrobeVisibility,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _privacySettings = PrivacySettings(
                      profileVisibility: _privacySettings!.profileVisibility,
                      wardrobeVisibility: value,
                      allowDmFromNonFriends: _privacySettings!.allowDmFromNonFriends,
                    );
                  });
                  _savePrivacySettings();
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('Private'),
              value: 'private',
              groupValue: _privacySettings?.wardrobeVisibility,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _privacySettings = PrivacySettings(
                      profileVisibility: _privacySettings!.profileVisibility,
                      wardrobeVisibility: value,
                      allowDmFromNonFriends: _privacySettings!.allowDmFromNonFriends,
                    );
                  });
                  _savePrivacySettings();
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
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

