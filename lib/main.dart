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
import 'services/fcm_service.dart';
import 'services/tag_list_service.dart';

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
  } catch (e) {
    debugPrint('❌ Firebase initialization failed: $e');
  }

  // Initialize App Check
  try {
    if (kDebugMode) {
      FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.debug,
        appleProvider: AppleProvider.debug,
      ).then((_) async {
        debugPrint('✅ App Check initialized in DEBUG mode');
        
        // Get and print debug token for Firebase Console
        // Wait a moment for App Check to fully initialize
        Future.delayed(const Duration(seconds: 2), () async {
          try {
            final tokenResult = await FirebaseAppCheck.instance.getToken();
            if (tokenResult != null) {
              // tokenResult is already a String (the token itself)
              final tokenString = tokenResult;
              debugPrint('');
              debugPrint('═══════════════════════════════════════════════════════');
              debugPrint('🔑 APP CHECK DEBUG TOKEN (Copy this to Firebase Console)');
              debugPrint('═══════════════════════════════════════════════════════');
              debugPrint('');
              debugPrint(tokenString);
              debugPrint('');
              debugPrint('📋 Instructions:');
              debugPrint('1. Go to Firebase Console → App Check');
              debugPrint('2. Click on your Android app');
              debugPrint('3. Click "Manage debug tokens"');
              debugPrint('4. Click "Add debug token"');
              debugPrint('5. Paste the token above');
              debugPrint('6. Click "Save"');
              debugPrint('');
              debugPrint('═══════════════════════════════════════════════════════');
              debugPrint('');
              debugPrint('💡 Note: Debug token may also appear in Android Logcat');
              debugPrint('   Filter by "AppCheck" or "DebugAppCheckProvider"');
              debugPrint('');
            } else {
              debugPrint('⚠️ App Check token is null');
              debugPrint('   Check Android Logcat for debug token');
            }
          } catch (tokenError) {
            debugPrint('⚠️ Failed to get App Check debug token: $tokenError');
            debugPrint('   Check Android Logcat for debug token');
            debugPrint('   Filter by "AppCheck" or "DebugAppCheckProvider"');
          }
        });
      }).catchError((e) {
        debugPrint('⚠️ App Check debug initialization failed: $e');
      });
    } else {
      FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.playIntegrity,
        appleProvider: AppleProvider.appAttest,
      ).then((_) {
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
      ],
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
    );
  }
}
