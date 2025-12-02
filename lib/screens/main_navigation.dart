import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/chat_provider.dart';
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

class _MainNavigationState extends State<MainNavigation> {
  final List<Widget> _screens = [
    const HomeScreen(),
    const WardrobeListScreen(),
    const FriendsListScreen(),
    const ChatListScreen(),
    const ProfileScreen(),
  ];
  int _previousIndex = 0;

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

