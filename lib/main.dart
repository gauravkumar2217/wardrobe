import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/auth/splash_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/cloth_provider.dart';
import 'providers/wardrobe_provider.dart';
import 'providers/friend_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/navigation_provider.dart';
import 'providers/filter_provider.dart';
import 'providers/onboarding_provider.dart';
import 'providers/scheduler_provider.dart';
import 'services/fcm_service.dart';
import 'services/tag_list_service.dart';
import 'services/ai_detection_service.dart';
import 'services/local_notification_service.dart';
import 'services/update_service.dart';

// Global navigator key for navigation from notifications
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Background message handler for FCM
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Handling background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase first (critical)
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    debugPrint('✅ Firebase initialized successfully');

    // Initialize AI detection service
    await AiDetectionService.initialize();
    debugPrint('✅ AI Detection Service initialized');
  } catch (e) {
    debugPrint('❌ Firebase initialization failed: $e');
  }

  // Initialize App Check
  try {
    if (kDebugMode) {
      FirebaseAppCheck.instance
          .activate(
        androidProvider: AndroidProvider.debug,
        appleProvider: AppleProvider.debug,
      )
          .then((_) async {
        debugPrint('✅ App Check initialized in DEBUG mode');

        // Verify App Check token is working
        // Wait a moment for App Check to fully initialize
        Future.delayed(const Duration(seconds: 2), () async {
          try {
            final tokenResult = await FirebaseAppCheck.instance.getToken();
            if (tokenResult != null) {
              // tokenResult is already a String (the token itself)
              final tokenString = tokenResult;
              debugPrint('');
              debugPrint(
                  '═══════════════════════════════════════════════════════');
              debugPrint('✅ APP CHECK DEBUG TOKEN VERIFIED');
              debugPrint(
                  '═══════════════════════════════════════════════════════');
              debugPrint('');
              debugPrint('Current token: $tokenString');
              debugPrint('');
              debugPrint(
                  'Expected token: BECB928B-A405-40BC-B0AA-A2EBC581AB97');
              debugPrint('');
              if (tokenString
                  .contains('BECB928B-A405-40BC-B0AA-A2EBC581AB97')) {
                debugPrint(
                    '✅ Token matches! App Check is configured correctly.');
              } else {
                debugPrint(
                    '⚠️ Token mismatch. Make sure the debug token is added in Firebase Console.');
                debugPrint(
                    '   Go to: Firebase Console → App Check → Your App → Manage debug tokens');
              }
              debugPrint('');
              debugPrint(
                  '═══════════════════════════════════════════════════════');
              debugPrint('');
            } else {
              debugPrint('⚠️ App Check token is null');
              debugPrint(
                  '   Make sure debug token BECB928B-A405-40BC-B0AA-A2EBC581AB97 is added in Firebase Console');
            }
          } catch (tokenError) {
            debugPrint('⚠️ Failed to get App Check debug token: $tokenError');
            debugPrint('');
            debugPrint(
                '═══════════════════════════════════════════════════════');
            debugPrint('🔍 ALTERNATIVE: Check Android Logcat for debug token');
            debugPrint(
                '═══════════════════════════════════════════════════════');
            debugPrint('');
            debugPrint('To find the debug token:');
            debugPrint('1. Open Android Studio Logcat');
            debugPrint('2. Filter by: "AppCheck" or "DebugAppCheckProvider"');
            debugPrint('3. Look for a line containing "Debug token:"');
            debugPrint('4. Copy the token value');
            debugPrint('5. Go to Firebase Console → App Check → Your App');
            debugPrint('6. Click "Manage debug tokens" → "Add debug token"');
            debugPrint('7. Paste the token and save');
            debugPrint('');
            debugPrint(
                '═══════════════════════════════════════════════════════');
            debugPrint('');

            // Try one more time after a longer delay
            Future.delayed(const Duration(seconds: 5), () async {
              try {
                final retryToken = await FirebaseAppCheck.instance.getToken();
                if (retryToken != null) {
                  debugPrint('');
                  debugPrint('✅ App Check debug token (retry):');
                  debugPrint(retryToken);
                  debugPrint('');
                }
              } catch (e) {
                debugPrint('Retry also failed: $e');
              }
            });
          }
        });
      }).catchError((e) {
        debugPrint('⚠️ App Check debug initialization failed: $e');
      });
    } else {
      FirebaseAppCheck.instance
          .activate(
        androidProvider: AndroidProvider.playIntegrity,
        appleProvider: AppleProvider.appAttest,
      )
          .then((_) {
        debugPrint('✅ App Check initialized in RELEASE mode');
      }).catchError((e) {
        debugPrint('❌ App Check initialization failed: $e');
      });
    }
  } catch (e) {
    debugPrint('App Check setup error: $e');
  }

  // Initialize FCM Service
  try {
    await FCMService.initialize();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('FCM Service initialization failed: $e');
  }

  // Initialize Local Notification Service
  try {
    await LocalNotificationService.initialize();
    debugPrint('✅ Local Notification Service initialized');
  } catch (e) {
    debugPrint('❌ Local Notification Service initialization failed: $e');
  }

  // Fetch tag lists in background
  TagListService.fetchTagLists().catchError((e) {
    debugPrint('Failed to fetch tag lists: $e');
    return TagListService.getCachedTagLists(); // Return default on error
  });

  // Start the app
  runApp(const WardrobeApp());
}

class WardrobeApp extends StatelessWidget {
  const WardrobeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ClothProvider()),
        ChangeNotifierProvider(create: (_) => WardrobeProvider()),
        ChangeNotifierProvider(create: (_) => FriendProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => FilterProvider()),
        ChangeNotifierProvider(create: (_) => OnboardingProvider()),
        ChangeNotifierProvider(create: (_) => SchedulerProvider()),
      ],
      child: UpdateService.buildUpgrader(
        child: MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Wardrobe',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF7C3AED),
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
