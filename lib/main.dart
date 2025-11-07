import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'providers/wardrobe_provider.dart';
import 'providers/cloth_provider.dart';
import 'providers/suggestion_provider.dart';
import 'providers/chat_provider.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env file
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Warning: Could not load .env file: $e');
    debugPrint('Make sure .env file exists in the root directory');
  }

  try {
    // Initialize Firebase with platform-specific options
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    // Use Play Integrity for production builds, debug provider for development
    // Disable App Check in debug mode to avoid authentication errors
    if (kReleaseMode) {
      try {
        await FirebaseAppCheck.instance.activate(
          androidProvider: AndroidProvider.playIntegrity,
          appleProvider: AppleProvider.appAttest,
        );
      } catch (e) {
        debugPrint('Firebase App Check initialization failed: $e');
      }
    }

    // Initialize notification service
    try {
      await NotificationService.initialize();
      await NotificationService.requestPermissions();
    } catch (e) {
      debugPrint('Notification service initialization failed: $e');
    }
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
    // Continue anyway - Firebase might work later
  }

  runApp(const WardrobeApp());
}

class WardrobeApp extends StatelessWidget {
  const WardrobeApp({super.key});

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
      ),
    );
  }
}
