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
        // Check BOTH EULA acceptance and profile completion
        final hasAcceptedEula = await UserService.hasAcceptedEula(user.uid);
        final profile = authProvider.userProfile;
        final hasCompleteProfile = profile != null && profile.isComplete;
        
        // Decision logic:
        // 1. Both done → go to main app
        // 2. EULA done, profile not → show profile setup
        // 3. EULA not, profile done → show EULA
        // 4. Neither → show EULA first
        
        if (hasAcceptedEula && hasCompleteProfile) {
          // Both done - go directly to main app
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainNavigation()),
          );
        } else if (hasAcceptedEula && !hasCompleteProfile) {
          // EULA accepted but profile incomplete - show profile setup only
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
          );
        } else if (!hasAcceptedEula && hasCompleteProfile) {
          // Profile complete but EULA not accepted - show EULA only
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const EulaAcceptanceScreen()),
          );
        } else {
          // Neither - show EULA first (it will navigate to profile setup after acceptance)
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const EulaAcceptanceScreen()),
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

