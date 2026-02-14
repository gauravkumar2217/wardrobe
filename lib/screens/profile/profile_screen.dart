import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/friend_provider.dart';
import '../../providers/wardrobe_provider.dart';
import '../../providers/cloth_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../models/cloth.dart';
import '../wardrobe/wardrobe_list_screen.dart';
import '../friends/friends_list_screen.dart';
import '../friends/friend_requests_screen.dart';
import '../statistics/statistics_screen.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import '../auth/login_screen.dart';

/// Profile screen displaying user info and stats
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Cloth? _mostWornCloth;
  int _totalClothes = 0;

  @override
  void initState() {
    super.initState();
    // Defer loading until after build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStats();
    });
  }

  Future<void> _loadStats() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final wardrobeProvider =
        Provider.of<WardrobeProvider>(context, listen: false);
    final clothProvider = Provider.of<ClothProvider>(context, listen: false);

    if (authProvider.user != null) {
      // Load wardrobes
      if (wardrobeProvider.wardrobes.isEmpty) {
        await wardrobeProvider.loadWardrobes(authProvider.user!.uid);
      }

      // Load all clothes
      await clothProvider.loadClothes(userId: authProvider.user!.uid);

      // Find most worn cloth
      if (clothProvider.clothes.isNotEmpty) {
        Cloth? mostWorn;

        for (var cloth in clothProvider.clothes) {
          // Get wear history count (simplified - in production, query wearHistory)
          if (cloth.wornAt != null) {
            // For now, just use wornAt as indicator
            // In production, count wearHistory entries
            if (mostWorn == null ||
                cloth.wornAt!.isAfter(mostWorn.wornAt ?? DateTime(1970))) {
              mostWorn = cloth;
            }
          }
        }

        setState(() {
          _mostWornCloth = mostWorn;
          _totalClothes = clothProvider.clothes.length;
        });
      } else {
        setState(() {
          _totalClothes = 0;
        });
      }
    }
  }

  Future<void> _logout() async {
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

    if (confirmed == true && mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      final friendProvider =
          Provider.of<FriendProvider>(context, listen: false);

      // Clean up providers before signing out
      chatProvider.cleanup();
      friendProvider.cleanup();

      await authProvider.signOut();

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final wardrobeProvider = Provider.of<WardrobeProvider>(context);
    final profile = authProvider.userProfile;
    final user = authProvider.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: const Color(0xFF043915),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile header
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: const Color(0xFF043915),
                        backgroundImage: profile?.photoUrl != null
                            ? NetworkImage(profile!.photoUrl!)
                            : null,
                        child: profile?.photoUrl == null
                            ? Text(
                                profile?.displayName
                                        ?.substring(0, 1)
                                        .toUpperCase() ??
                                    user?.email
                                        ?.substring(0, 1)
                                        .toUpperCase() ??
                                    '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile?.displayName ?? user?.email ?? 'User',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (user?.email != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                user!.email!,
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 11),
                              ),
                            ],
                            if (user?.phoneNumber != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                user!.phoneNumber!,
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 11),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Stats
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Statistics',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatItem(
                            icon: Icons.inventory_2,
                            label: 'Wardrobes',
                            value: '${wardrobeProvider.wardrobes.length}',
                          ),
                          _StatItem(
                            icon: Icons.checkroom,
                            label: 'Clothes',
                            value: '$_totalClothes',
                          ),
                        ],
                      ),
                      if (_mostWornCloth != null) ...[
                        const SizedBox(height: 8),
                        const Divider(),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.star,
                                color: Colors.amber, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Most worn: ${_mostWornCloth!.clothType}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Quick actions
              Card(
                child: Column(
                  children: [
                    ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 2),
                      leading: const Icon(Icons.inventory_2,
                          color: Color(0xFF043915), size: 18),
                      title: const Text('My Wardrobes',
                          style: TextStyle(fontSize: 13)),
                      trailing: const Icon(Icons.chevron_right, size: 18),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const WardrobeListScreen()),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 2),
                      leading: const Icon(Icons.people,
                          color: Color(0xFF043915), size: 18),
                      title:
                          const Text('Friends', style: TextStyle(fontSize: 13)),
                      trailing: const Icon(Icons.chevron_right, size: 18),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const FriendsListScreen()),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 2),
                      leading: const Icon(Icons.person_add,
                          color: Color(0xFF043915), size: 18),
                      title: const Text('Friend Requests',
                          style: TextStyle(fontSize: 13)),
                      trailing: const Icon(Icons.chevron_right, size: 18),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const FriendRequestsScreen()),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 2),
                      leading: const Icon(Icons.bar_chart,
                          color: Color(0xFF043915), size: 18),
                      title: const Text('Statistics',
                          style: TextStyle(fontSize: 13)),
                      trailing: const Icon(Icons.chevron_right, size: 18),
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const StatisticsScreen()),
                        );
                        // If filter was selected, navigate to home with filter
                        if (result != null) {
                          if (!mounted) return;
                          if (!mounted) return;
                          if (!mounted) return;
                          final navContext = this.context;
                          if (!mounted) return;
                          final navigationProvider =
                              Provider.of<NavigationProvider>(navContext,
                                  listen: false);
                          navigationProvider
                              .setCurrentIndex(0); // Navigate to home
                          // The filter will be applied when home screen loads
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Account actions
              Card(
                child: Column(
                  children: [
                    ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 2),
                      leading: const Icon(Icons.edit,
                          color: Color(0xFF043915), size: 18),
                      title: const Text('Edit Profile',
                          style: TextStyle(fontSize: 13)),
                      trailing: const Icon(Icons.chevron_right, size: 18),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const EditProfileScreen()),
                        );
                        // Reload profile after editing
                        if (!mounted) return;
                        if (!mounted) return;
                        if (!mounted) return;
                        final authContext = this.context;
                        if (!mounted) return;
                        final authProvider = Provider.of<AuthProvider>(
                            authContext,
                            listen: false);
                        if (authProvider.user != null) {
                          // Profile is automatically updated via AuthProvider when updateProfile is called
                          _loadStats(); // Reload stats to reflect any changes
                        }
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 2),
                      leading: const Icon(Icons.settings,
                          color: Color(0xFF043915), size: 18),
                      title: const Text('Settings',
                          style: TextStyle(fontSize: 13)),
                      trailing: const Icon(Icons.chevron_right, size: 18),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SettingsScreen()),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 2),
                      leading:
                          const Icon(Icons.logout, color: Colors.red, size: 18),
                      title: const Text('Logout',
                          style: TextStyle(color: Colors.red, fontSize: 13)),
                      onTap: _logout,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF043915), size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
