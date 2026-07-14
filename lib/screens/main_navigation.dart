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
import '../widgets/premium/wardrobe_top_header.dart';
import '../utils/main_shell_navigation.dart';
import 'home/wardrobe_home_screen.dart';
import 'wardrobe/wardrobe_list_screen.dart';
import 'changing_room/changing_room_screen.dart';
import 'community/community_screen.dart';
import 'assistant/ai_assistant_screen.dart';
import 'profile/profile_screen.dart';
import 'notifications/notifications_screen.dart';
import 'profile/settings_screen.dart';
import 'auth/login_screen.dart';

/// Main navigation screen with bottom navigation bar
class MainNavigation extends StatefulWidget {
  final bool justCompletedProfileSetup;

  const MainNavigation({
    super.key,
    this.justCompletedProfileSetup = false,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _contentNavigatorKey =
      GlobalKey<NavigatorState>();
  final List<Widget> _screens = [
    const WardrobeHomeScreen(),
    const WardrobeListScreen(),
    const ChangingRoomScreen(),
    const CommunityScreen(),
    const AiAssistantScreen(),
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
      _checkOnboardingStatus(
          justCompletedProfileSetup: widget.justCompletedProfileSetup);
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

  Future<void> _checkOnboardingStatus(
      {bool justCompletedProfileSetup = false}) async {
    if (_hasCheckedOnboarding) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final onboardingProvider =
        Provider.of<OnboardingProvider>(context, listen: false);

    if (authProvider.user == null) return;

    _hasCheckedOnboarding = true;

    // Check if user has completed onboarding
    final hasCompleted = await OnboardingService.hasCompletedOnboarding(
      authProvider.user!.uid,
    );

    if (!hasCompleted && mounted) {
      // If user just completed profile setup, wait longer before starting onboarding
      // This gives them time to see the app and get comfortable
      final delayDuration = justCompletedProfileSetup
          ? const Duration(seconds: 5) // 5 seconds for new users
          : const Duration(
              milliseconds: 1500); // 1.5 seconds for returning users

      await Future.delayed(delayDuration);

      if (mounted) {
        _startOnboarding(onboardingProvider, context);
      }
    }
  }

  /// Restart onboarding (called from settings)
  Future<void> restartOnboarding() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final onboardingProvider =
        Provider.of<OnboardingProvider>(context, listen: false);

    if (authProvider.user == null) return;

    // Reset the check flag so it can check again
    _hasCheckedOnboarding = false;

    // Wait a bit for UI to be ready
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      _startOnboarding(onboardingProvider, context);
    }
  }

  void _startOnboarding(
      OnboardingProvider onboardingProvider, BuildContext context) {
    // Wait a bit more for the bottom navigation bar to be fully rendered
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;

      final navContext = this.context;
      if (!mounted) return;

      final screenWidth = MediaQuery.of(navContext).size.width;
      final screenHeight = MediaQuery.of(navContext).size.height;
      final safeAreaBottom = MediaQuery.of(navContext).padding.bottom;

      // Try to get actual bottom navigation bar position
      Offset? getBottomNavItemPosition(int index) {
        if (_bottomNavKey.currentContext == null) return null;

        try {
          final renderBox =
              _bottomNavKey.currentContext!.findRenderObject() as RenderBox?;
          if (renderBox == null || !renderBox.attached) return null;

          // Get the bottom nav bar's global position
          final navBarPosition = renderBox.localToGlobal(Offset.zero);

          // BottomNavigationBar with 5 items: each item takes screenWidth / 5
          // Icon is typically centered in each item
          final itemWidth = screenWidth / 5;
          final iconX = itemWidth * (index + 0.5); // Center of each item

          // Icon Y position: typically in the upper portion of the nav bar
          // BottomNavigationBar icons are usually positioned about 10-14px from top of nav bar
          // Account for the icon size (typically 24px) and padding
          final iconY = navBarPosition.dy + 14.0;

          return Offset(iconX, iconY);
        } catch (e) {
          debugPrint('Error getting bottom nav position: $e');
          return null;
        }
      }

      // Responsive target size for icon highlighting (half of previous size)
      final targetSize = (screenWidth * 0.06).clamp(24.0, 32.0);

      // Calculate positions - try to use actual positions, fallback to calculated
      final List<OnboardingStep> steps = [];

      for (int i = 0; i < 5; i++) {
        final actualPosition = getBottomNavItemPosition(i);
        Offset targetOffset;

        if (actualPosition != null) {
          // Use actual position from bottom nav bar, adjusted left 5px and top 5px
          targetOffset =
              Offset(actualPosition.dx - 5.0, actualPosition.dy - 5.0);
        } else {
          // Fallback to calculated position, adjusted left 5px and top 5px
          final itemWidth = screenWidth / 5;
          final iconX = itemWidth * (i + 0.5);
          // Estimate Y position: screen height - safe area - nav bar height/2
          final estimatedNavBarHeight = 60.0 + safeAreaBottom;
          final iconY = screenHeight - estimatedNavBarHeight + 12.0;
          targetOffset = Offset(iconX - 5.0, iconY - 5.0);
        }

        // Create step based on index
        OnboardingStep step;
        switch (i) {
          case 0:
            step = OnboardingStep(
              id: 'home',
              title: 'Welcome to Wardrobe!',
              description:
                  'Home — tap Clothes for the swipe feed, or open wardrobes, changing room, scheduler, friends, chats, and more.',
              targetOffset: targetOffset,
              targetSize: Size(targetSize, targetSize),
              alignment: Alignment.topCenter,
            );
            break;
          case 1:
            step = OnboardingStep(
              id: 'wardrobes',
              title: 'Organize Your Wardrobes',
              description:
                  'Create different wardrobes to organize your clothes by location or category. Tap here to manage your wardrobes.',
              targetOffset: targetOffset,
              targetSize: Size(targetSize, targetSize),
              alignment: Alignment.topCenter,
            );
            break;
          case 2:
            step = OnboardingStep(
              id: 'tryon',
              title: 'Virtual Try-On',
              description:
                  'Tap TRY-ON to open the changing room. Try wardrobe items on your avatar with AI.',
              targetOffset: targetOffset,
              targetSize: Size(targetSize, targetSize),
              alignment: Alignment.topCenter,
            );
            break;
          case 3:
            step = OnboardingStep(
              id: 'chat',
              title: 'Chat & Share',
              description:
                  'Message your friends and share your favorite clothes directly in chat. Get feedback and style tips!',
              targetOffset: targetOffset,
              targetSize: Size(targetSize, targetSize),
              alignment: Alignment.topCenter,
            );
            break;
          case 4:
            step = OnboardingStep(
              id: 'assistant',
              title: 'AI Assistant',
              description:
                  'Ask Wardrobe for outfit ideas, planning, and AI-powered recommendations.',
              targetOffset: targetOffset,
              targetSize: Size(targetSize, targetSize),
              alignment: Alignment.topCenter,
            );
            break;
          default:
            continue;
        }
        steps.add(step);
      }

      if (mounted && steps.isNotEmpty) {
        onboardingProvider.startOnboarding(steps);
      }
    });
  }

  Future<void> _handleOnboardingNext(
      OnboardingProvider onboardingProvider, AuthProvider authProvider) async {
    onboardingProvider.nextStep();

    // If onboarding is complete, save status
    if (!onboardingProvider.isOnboardingActive && authProvider.user != null) {
      await OnboardingService.completeOnboarding(authProvider.user!.uid);
    }
  }

  Future<void> _handleOnboardingSkip(
      OnboardingProvider onboardingProvider, AuthProvider authProvider) async {
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
      FCMService.updateAppState(authProvider.user!.uid, isInForeground)
          .catchError((e) {
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

    // Check if restart was requested
    if (onboardingProvider.shouldRestart && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          onboardingProvider.clearRestartRequest();
          _hasCheckedOnboarding = false;
          _checkOnboardingStatus();
        }
      });
    }

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
      onPrevious: onboardingProvider.isOnboardingActive &&
              onboardingProvider.currentStepIndex > 0
          ? () => onboardingProvider.previousStep()
          : null,
      onSkip: onboardingProvider.isOnboardingActive
          ? () => _handleOnboardingSkip(onboardingProvider, authProvider)
          : null,
      hasMoreSteps: onboardingProvider.hasMoreSteps,
      hasPreviousSteps: onboardingProvider.currentStepIndex > 0,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (!mounted) return;
          handleMainShellBackButton(context);
        },
        child: Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.only(
                    top: WardrobeTopHeader.contentTopInset(context),
                  ),
                  child: Navigator(
                    key: _contentNavigatorKey,
                    onGenerateRoute: (_) => MaterialPageRoute<void>(
                      builder: (_) => IndexedStack(
                        index: navigationProvider.currentIndex,
                        children: _screens,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: WardrobeTopHeader(
                  onProfilePressed: () {
                    _contentNavigatorKey.currentState?.push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ProfileScreen(),
                      ),
                    );
                  },
                  onNotificationsPressed: () {
                    _contentNavigatorKey.currentState?.push(
                      MaterialPageRoute<void>(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    );
                  },
                  onSettingsPressed: () {
                    _contentNavigatorKey.currentState?.push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SettingsScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          bottomNavigationBar: _PremiumBottomNavBar(
            bottomNavKey: _bottomNavKey,
            currentIndex: navigationProvider.currentIndex,
            unreadCount: chatProvider.totalUnreadCount,
            onSelectIndex: (index) {
              // Pop any pushed routes in the content area (e.g. Profile).
              _contentNavigatorKey.currentState
                  ?.popUntil((route) => route.isFirst);

              // Home: clear filters and always show hub.
              if (index == 0) {
                final filterProvider =
                    Provider.of<FilterProvider>(context, listen: false);
                final wardrobeProvider =
                    Provider.of<WardrobeProvider>(context, listen: false);
                filterProvider.clearFilters();
                wardrobeProvider.setSelectedWardrobe(null);
                navigationProvider.goHomeTab();
                return;
              }

              navigationProvider.setCurrentIndex(index);
            },
          ),
        ),
      ),
    );
  }
}

class _PremiumBottomNavBar extends StatelessWidget {
  final GlobalKey bottomNavKey;
  final int currentIndex;
  final int unreadCount;
  final ValueChanged<int> onSelectIndex;

  const _PremiumBottomNavBar({
    required this.bottomNavKey,
    required this.currentIndex,
    required this.unreadCount,
    required this.onSelectIndex,
  });

  @override
  Widget build(BuildContext context) {
    // Center TRY-ON action is implemented as a docked FAB over a Material 3 NavigationBar.
    const fabSize = 68.0; // match top header logo
    const navBarHeight = 80.0; // Material 3 NavigationBar default
    final safeBottom = MediaQuery.of(context).padding.bottom;
    return SizedBox(
      // Keep the bar as compact as possible; allow FAB to paint overflow above.
      height: navBarHeight + safeBottom,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.9),
                    width: 1.5,
                  ),
                ),
              ),
              child: NavigationBar(
                key: bottomNavKey,
                selectedIndex: currentIndex,
                onDestinationSelected: onSelectIndex,
                destinations: [
                  const NavigationDestination(
                    icon: Icon(Icons.home_rounded),
                    label: 'Home',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.inventory_2_rounded),
                    label: 'Wardrobe',
                  ),
                  const NavigationDestination(
                    // Spacer destination: the actual TRY-ON action is the docked FAB.
                    icon: SizedBox.shrink(),
                    selectedIcon: SizedBox.shrink(),
                    label: '',
                  ),
                  NavigationDestination(
                    icon: Badge(
                      isLabelVisible: unreadCount > 0,
                      label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
                      child: const Icon(Icons.people_alt_rounded),
                    ),
                    label: 'Community',
                  ),
              const NavigationDestination(
                icon: Icon(Icons.auto_awesome_rounded),
                label: 'Assistant',
              ),
                ],
              ),
            ),
          ),
          // Place the FAB so it straddles the bar top edge:
          // 40% above the bar (out), 60% inside.
          Positioned(
            // From the bottom of the bar: navBarHeight - (60% of fab size).
            // This makes 40% of the fab sit above the top border line.
            bottom: safeBottom + (navBarHeight - (fabSize * 0.6)),
            child: _TryOnFab(
              size: fabSize,
              selected: currentIndex == 2,
              onPressed: () => onSelectIndex(2),
            ),
          ),
        ],
      ),
    );
  }
}

class _TryOnFab extends StatelessWidget {
  final double size;
  final bool selected;
  final VoidCallback onPressed;

  const _TryOnFab({
    required this.size,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Try-On',
      child: Material(
        color: Colors.transparent,
        child: InkResponse(
          onTap: onPressed,
          radius: size / 2 + 6,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.primary,
                  scheme.primary.withValues(alpha: 0.82),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
              border: Border.all(
                color: scheme.onSurface.withValues(alpha: 0.10),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: scheme.onPrimary,
                  size: 26,
                ),
                const SizedBox(height: 2),
                Text(
                  'TRY-ON',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        fontSize: 9,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
