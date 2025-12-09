import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/filter_provider.dart';
import '../providers/wardrobe_provider.dart';
import '../providers/onboarding_provider.dart';
import '../services/app_state_service.dart';
import '../services/fcm_service.dart';
import '../services/onboarding_service.dart';
import '../widgets/tooltip_overlay.dart';
import 'home/home_screen.dart';
import 'wardrobe/wardrobe_list_screen.dart';
import 'friends/friends_list_screen.dart';
import 'chat/chat_list_screen.dart';
import 'profile/profile_screen.dart';
import 'auth/login_screen.dart';

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
  bool _hasCheckedOnboarding = false;
  
  // Keys for onboarding targets
  final GlobalKey _bottomNavKey = GlobalKey();

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
      
      // Check onboarding status
      _checkOnboardingStatus();
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

  Future<void> _checkOnboardingStatus() async {
    if (_hasCheckedOnboarding) return;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final onboardingProvider = Provider.of<OnboardingProvider>(context, listen: false);
    
    if (authProvider.user == null) return;
    
    _hasCheckedOnboarding = true;
    
    // Check if user has completed onboarding
    final hasCompleted = await OnboardingService.hasCompletedOnboarding(
      authProvider.user!.uid,
    );
    
      if (!hasCompleted && mounted) {
      // Wait a bit for UI to be ready, then start onboarding
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        _startOnboarding(onboardingProvider, context);
      }
    }
  }

  void _startOnboarding(OnboardingProvider onboardingProvider, BuildContext context) {
    // Wait a bit more for the bottom navigation bar to be fully rendered
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      
      if (!mounted) return;
      if (!mounted) return;
      final navContext = this.context;
      if (!mounted) return;
      final screenWidth = MediaQuery.of(navContext).size.width;
      final screenHeight = MediaQuery.of(navContext).size.height;
      const bottomNavHeight = 60.0;
      final itemWidth = screenWidth / 5;
      
      // Calculate center positions for each navigation item
      // Items are centered in their 1/5 width sections
      final steps = [
        OnboardingStep(
          id: 'home',
          title: 'Welcome to Wardrobe!',
          description: 'Swipe through your clothes here. Tap on any cloth to see details, like, comment, or share with friends.',
          targetOffset: Offset(itemWidth * 0.5, screenHeight - bottomNavHeight / 2 - 10),
          targetSize: const Size(70, 70),
          alignment: Alignment.topCenter,
        ),
        OnboardingStep(
          id: 'wardrobes',
          title: 'Organize Your Wardrobes',
          description: 'Create different wardrobes to organize your clothes by location or category. Tap here to manage your wardrobes.',
          targetOffset: Offset(itemWidth * 1.5, screenHeight - bottomNavHeight / 2 - 10),
          targetSize: const Size(70, 70),
          alignment: Alignment.topCenter,
        ),
        OnboardingStep(
          id: 'friends',
          title: 'Connect with Friends',
          description: 'Add friends to share your clothes and get style inspiration. You can see what your friends are wearing!',
          targetOffset: Offset(itemWidth * 2.5, screenHeight - bottomNavHeight / 2 - 10),
          targetSize: const Size(70, 70),
          alignment: Alignment.topCenter,
        ),
        OnboardingStep(
          id: 'chat',
          title: 'Chat & Share',
          description: 'Message your friends and share your favorite clothes directly in chat. Get feedback and style tips!',
          targetOffset: Offset(itemWidth * 3.5, screenHeight - bottomNavHeight / 2 - 10),
          targetSize: const Size(70, 70),
          alignment: Alignment.topCenter,
        ),
        OnboardingStep(
          id: 'profile',
          title: 'Your Profile',
          description: 'Manage your account, settings, and view your statistics. Customize your wardrobe experience here.',
          targetOffset: Offset(itemWidth * 4.5, screenHeight - bottomNavHeight / 2 - 10),
          targetSize: const Size(70, 70),
          alignment: Alignment.topCenter,
        ),
      ];
      
      if (mounted) {
        onboardingProvider.startOnboarding(steps);
      }
    });
  }

  Future<void> _handleOnboardingNext(OnboardingProvider onboardingProvider, AuthProvider authProvider) async {
    onboardingProvider.nextStep();
    
    // If onboarding is complete, save status
    if (!onboardingProvider.isOnboardingActive && authProvider.user != null) {
      await OnboardingService.completeOnboarding(authProvider.user!.uid);
    }
  }

  Future<void> _handleOnboardingSkip(OnboardingProvider onboardingProvider, AuthProvider authProvider) async {
    onboardingProvider.skipOnboarding();
    
    if (authProvider.user != null) {
      await OnboardingService.skipOnboarding(authProvider.user!.uid);
    }
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
    // Only update if user is authenticated
    if (authProvider.isAuthenticated && authProvider.user != null) {
      final isInForeground = state == AppLifecycleState.resumed;
      FCMService.updateAppState(authProvider.user!.uid, isInForeground).catchError((e) {
        // Silently handle errors (user might have signed out)
        debugPrint('Failed to update app state: $e');
      });

      if (isInForeground) {
        // Update last active when app comes to foreground
        FCMService.updateLastActive(authProvider.user!.uid).catchError((e) {
          // Silently handle errors (user might have signed out)
          debugPrint('Failed to update last active: $e');
        });
        // Start periodic updates
        _startPeriodicUpdates(authProvider.user!.uid);
      } else {
        // Stop periodic updates when app goes to background
        _stopPeriodicUpdates();
      }
    } else {
      // User is not authenticated, stop all updates
      _stopPeriodicUpdates();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final navigationProvider = Provider.of<NavigationProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final onboardingProvider = Provider.of<OnboardingProvider>(context);

    // Load unread counts when screen builds (only if authenticated)
    if (authProvider.isAuthenticated && authProvider.user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Double check authentication before loading
        if (authProvider.isAuthenticated && authProvider.user != null) {
          chatProvider.loadUnreadCounts(authProvider.user!.uid).catchError((e) {
            // Silently handle errors (user might have signed out)
            debugPrint('Failed to load unread counts: $e');
          });
        }
      });
    }

    if (!authProvider.isAuthenticated) {
      // Redirect to login screen if not authenticated
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      });
      // Show loading while redirecting
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
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

    return TooltipOverlay(
      step: onboardingProvider.currentStep,
      onNext: onboardingProvider.isOnboardingActive
          ? () => _handleOnboardingNext(onboardingProvider, authProvider)
          : null,
      onPrevious: onboardingProvider.isOnboardingActive && onboardingProvider.currentStepIndex > 0
          ? () => onboardingProvider.previousStep()
          : null,
      onSkip: onboardingProvider.isOnboardingActive
          ? () => _handleOnboardingSkip(onboardingProvider, authProvider)
          : null,
      hasMoreSteps: onboardingProvider.hasMoreSteps,
      hasPreviousSteps: onboardingProvider.currentStepIndex > 0,
      child: Scaffold(
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
          key: _bottomNavKey,
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
      ),
    );
  }
}
