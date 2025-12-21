import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
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
import 'services/schedule_notification_worker.dart';

import 'utils/navigator_key.dart' show navigatorKey;

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

  // Initialize Schedule Notification Worker
  try {
    await ScheduleNotificationWorker.initialize();
    debugPrint('✅ Schedule Notification Worker initialized');
  } catch (e) {
    debugPrint('❌ Schedule Notification Worker initialization failed: $e');
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
