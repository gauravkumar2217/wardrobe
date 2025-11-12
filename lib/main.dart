import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'screens/suggestion_screen.dart';
import 'providers/wardrobe_provider.dart';
import 'providers/cloth_provider.dart';
import 'providers/suggestion_provider.dart';
import 'providers/chat_provider.dart';
import 'services/notification_service.dart';
import 'services/suggestion_service.dart';
import 'services/fcm_token_service.dart';
import 'services/notification_schedule_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'screens/about_screen.dart';
import 'screens/privacy_policy_screen.dart';
import 'screens/terms_conditions_screen.dart';

// Global navigator key for navigation from notifications
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Background message handler for FCM
// This must be a top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Handling background message: ${message.messageId}');
  debugPrint('Background message data: ${message.data}');
  debugPrint('Background message notification: ${message.notification?.title}');

  // Background messages are automatically shown as notifications
  // No need to manually show them here
  // The system will display the notification automatically
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase first (critical)
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    debugPrint('✅ Firebase initialized successfully');
  } catch (e) {
    debugPrint('❌ Firebase initialization failed: $e');
    // Continue anyway - app should still work
  }

  // Initialize App Check (non-blocking, only in release)
  if (kReleaseMode) {
    FirebaseAppCheck.instance
        .activate(
      androidProvider: AndroidProvider.playIntegrity,
      appleProvider: AppleProvider.appAttest,
    )
        .catchError((e) {
      debugPrint('Firebase App Check initialization failed: $e');
    });
  }

  // Start the app immediately - don't wait for services
  runApp(const WardrobeApp());

  // Initialize services in background (non-blocking)
  _initializeServicesInBackground();
}

/// Initialize services in background without blocking app startup
Future<void> _initializeServicesInBackground() async {
  try {
    // Initialize notification service with timeout
    await NotificationService.initialize().timeout(const Duration(seconds: 10),
        onTimeout: () {
      debugPrint('⚠️ Notification service initialization timed out');
    });
    NotificationService.setNavigatorKey(navigatorKey);

    // Request permissions (non-blocking)
    NotificationService.requestPermissions().catchError((e) {
      debugPrint('Failed to request notification permissions: $e');
      return false;
    });

    // Schedule daily notification (non-blocking)
    NotificationService.scheduleDailySuggestionNotification().catchError((e) {
      debugPrint('Failed to schedule daily notification: $e');
    });

    // Initialize FCM token service with timeout
    try {
      await FCMTokenService.initialize().timeout(const Duration(seconds: 10),
          onTimeout: () {
        debugPrint('⚠️ FCM token service initialization timed out');
      });

      // Set up background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Set up foreground message handler
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        debugPrint('Received foreground message: ${message.messageId}');
        if (message.notification != null) {
          await NotificationService.showNotification(
            title: message.notification!.title ?? 'Wardrobe',
            body: message.notification!.body ?? 'New notification',
            id: message.hashCode,
          );
        }
      });

      // Handle notification taps when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('Notification opened app: ${message.messageId}');
        if (message.data['type'] == 'daily_suggestion' &&
            navigatorKey.currentState != null) {
          navigatorKey.currentState!.pushNamed('/suggestions');
        }
      });

      // Check if app was opened from a notification (non-blocking)
      FirebaseMessaging.instance.getInitialMessage().then((initialMessage) {
        if (initialMessage != null) {
          debugPrint(
              'App opened from notification: ${initialMessage.messageId}');
          Future.delayed(const Duration(seconds: 2), () {
            if (initialMessage.data['type'] == 'daily_suggestion' &&
                navigatorKey.currentState != null) {
              navigatorKey.currentState!.pushNamed('/suggestions');
            }
          });
        }
      }).catchError((e) {
        debugPrint('Failed to get initial message: $e');
      });

      // Check if user is logged in and initialize user-specific services
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Save FCM token (non-blocking)
        FCMTokenService.saveTokenForCurrentUser().catchError((e) {
          debugPrint('Failed to save FCM token: $e');
        });

        // Auto-generate today's suggestion (non-blocking)
        SuggestionService.autoGenerateDailySuggestion(user.uid).catchError((e) {
          debugPrint('Failed to auto-generate suggestion: $e');
          return null;
        });

        // Reschedule all user notification schedules (non-blocking)
        NotificationScheduleService.rescheduleAllNotifications()
            .catchError((e) {
          debugPrint('Failed to reschedule notifications: $e');
        });
      }
    } catch (e) {
      debugPrint('FCM token service initialization failed: $e');
    }
  } catch (e) {
    debugPrint('Service initialization failed: $e');
    // App continues to work even if services fail
  }
}

class WardrobeApp extends StatefulWidget {
  const WardrobeApp({super.key});

  @override
  State<WardrobeApp> createState() => _WardrobeAppState();
}

class _WardrobeAppState extends State<WardrobeApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupAuthStateListener();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Listen to auth state changes to manage FCM tokens
  void _setupAuthStateListener() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user != null) {
        // User logged in - save FCM token
        try {
          await FCMTokenService.saveTokenForCurrentUser();
        } catch (e) {
          debugPrint('Failed to save FCM token on auth state change: $e');
        }
      } else {
        // User logged out - token is already deactivated in AuthService.signOut()
        // But we can also handle it here if needed
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    switch (state) {
      case AppLifecycleState.resumed:
        // App came to foreground - update last active and ensure token is active
        FCMTokenService.saveTokenForCurrentUser();
        FCMTokenService.updateLastActive();
        break;
      case AppLifecycleState.paused:
        // App went to background - update last active
        FCMTokenService.updateLastActive();
        break;
      case AppLifecycleState.inactive:
        // App is inactive - update last active
        FCMTokenService.updateLastActive();
        break;
      case AppLifecycleState.detached:
        // App is being terminated - update last active
        // Note: Actual app uninstall detection is not possible
        // Server-side cleanup is recommended for truly inactive tokens
        FCMTokenService.updateLastActive();
        break;
      case AppLifecycleState.hidden:
        // App is hidden - update last active
        FCMTokenService.updateLastActive();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WardrobeProvider()),
        ChangeNotifierProvider(create: (_) => ClothProvider()),
        ChangeNotifierProvider(create: (_) => SuggestionProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Wardrobe Chat',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF7C3AED),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          // Removed fontFamily: 'Inter' - font not configured in pubspec.yaml
        ),
        home: const SplashScreen(),
        routes: {
          '/suggestions': (context) => const SuggestionScreen(),
          '/about': (context) => const AboutScreen(),
          '/privacy': (context) => const PrivacyPolicyScreen(),
          '/terms': (context) => const TermsConditionsScreen(),
        },
      ),
    );
  }
}
