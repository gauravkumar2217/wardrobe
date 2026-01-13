import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/user_service.dart';
import 'login_screen.dart';
import 'eula_acceptance_screen.dart';
import 'profile_setup_screen.dart';
import '../main_navigation.dart';

/// Splash screen that checks auth status
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.initialize();

    if (!mounted) return;

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    if (authProvider.isAuthenticated) {
      final user = authProvider.user;
      if (user != null) {
        // Check EULA acceptance first
        final hasAcceptedEula = await UserService.hasAcceptedEula(user.uid);
        
        if (!hasAcceptedEula) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const EulaAcceptanceScreen()),
          );
          return;
        }

        // EULA accepted - check profile completion
        final profile = authProvider.userProfile;
        if (profile != null && profile.isComplete) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainNavigation()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
          );
        }
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFFA855F7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
    );
  }
}

