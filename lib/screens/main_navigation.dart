import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/filter_provider.dart';
import '../providers/wardrobe_provider.dart';
import '../services/app_state_service.dart';
import '../services/fcm_service.dart';
import 'home/home_screen.dart';
import 'wardrobe/wardrobe_list_screen.dart';
import 'friends/friends_list_screen.dart';
import 'chat/chat_list_screen.dart';
import 'profile/profile_screen.dart';

/// Main navigation screen with bottom navigation bar
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with WidgetsBindingObserver {
  final List<Widget> _screens = [
    const HomeScreen(),
    const WardrobeListScreen(),
    const FriendsListScreen(),
    const ChatListScreen(),
    const ProfileScreen(),
  ];
  int _previousIndex = 0;
  final AppStateService _appStateService = AppStateService();
  Timer? _lastActiveTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Set initial state
    _appStateService.updateState(
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed);

    // Update last active on init if app is in foreground
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user != null && _appStateService.isInForeground) {
        FCMService.updateLastActive(authProvider.user!.uid);
        // Start periodic updates (every 20 seconds) when app is in foreground
        _startPeriodicUpdates(authProvider.user!.uid);
      }
    });
  }

  void _startPeriodicUpdates(String userId) {
    _lastActiveTimer?.cancel();
    _lastActiveTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      if (_appStateService.isInForeground && mounted) {
        FCMService.updateLastActive(userId);
      } else {
        timer.cancel();
      }
    });
  }

  void _stopPeriodicUpdates() {
    _lastActiveTimer?.cancel();
    _lastActiveTimer = null;
  }

  @override
  void dispose() {
    _stopPeriodicUpdates();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appStateService.updateState(state);

    // Update FCM device state in Firestore
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      final isInForeground = state == AppLifecycleState.resumed;
      FCMService.updateAppState(authProvider.user!.uid, isInForeground);

      if (isInForeground) {
        // Update last active when app comes to foreground
        FCMService.updateLastActive(authProvider.user!.uid);
        // Start periodic updates
        _startPeriodicUpdates(authProvider.user!.uid);
      } else {
        // Stop periodic updates when app goes to background
        _stopPeriodicUpdates();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final navigationProvider = Provider.of<NavigationProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);

    // Load unread counts when screen builds
    if (authProvider.user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        chatProvider.loadUnreadCounts(authProvider.user!.uid);
      });
    }

    if (!authProvider.isAuthenticated) {
      // This shouldn't happen, but handle it gracefully
      return const Scaffold(
        body: Center(child: Text('Please log in')),
      );
    }

    // Refresh home screen when navigating back to it
    if (navigationProvider.currentIndex == 0 && _previousIndex != 0) {
      // User navigated back to home screen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Trigger refresh of counts on home screen
        // The home screen will handle this via its lifecycle
      });
    }
    _previousIndex = navigationProvider.currentIndex;

    return Scaffold(
      body: IndexedStack(
        index: navigationProvider.currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationProvider.currentIndex,
        onTap: (index) {
          // If tapping home icon (index 0), clear all filters
          if (index == 0) {
            final filterProvider = Provider.of<FilterProvider>(context, listen: false);
            final wardrobeProvider = Provider.of<WardrobeProvider>(context, listen: false);
            
            // Clear all filters and selected wardrobe
            filterProvider.clearFilters();
            wardrobeProvider.setSelectedWardrobe(null);
          }
          
          navigationProvider.setCurrentIndex(index);
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF7C3AED),
        unselectedItemColor: Colors.grey,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2),
            label: 'Wardrobes',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Friends',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.chat),
                if (chatProvider.totalUnreadCount > 0)
                  Positioned(
                    right: -8,
                    top: -8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        chatProvider.totalUnreadCount > 99
                            ? '99+'
                            : '${chatProvider.totalUnreadCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Chats',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
