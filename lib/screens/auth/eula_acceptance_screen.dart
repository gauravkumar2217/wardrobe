import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/legal_content_service.dart';
import '../../services/user_service.dart';
import '../../providers/auth_provider.dart';
import '../../constants/app_constants.dart';
import 'profile_setup_screen.dart';
import '../main_navigation.dart';

/// EULA Acceptance screen - required before completing profile setup
class EulaAcceptanceScreen extends StatefulWidget {
  const EulaAcceptanceScreen({super.key});

  @override
  State<EulaAcceptanceScreen> createState() => _EulaAcceptanceScreenState();
}

class _EulaAcceptanceScreenState extends State<EulaAcceptanceScreen> {
  bool _hasAcceptedEula = false;
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();

  Future<void> _acceptAndContinue() async {
    if (!_hasAcceptedEula) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must accept the Terms & Conditions to continue'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      if (user == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not found. Please sign in again.')),
          );
        }
        return;
      }

      // Record EULA acceptance
      final version = UserService.getCurrentEulaVersion();
      await UserService.recordEulaAcceptance(
        userId: user.uid,
        version: version,
      );

      if (mounted) {
        // Refresh profile to get latest data
        await authProvider.refreshProfile();
        final profile = authProvider.userProfile;
        
        // Check if profile is already complete
        if (profile != null && profile.isComplete) {
          // Profile is complete - go directly to main app
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainNavigation()),
          );
        } else {
          // Profile not complete - navigate to profile setup
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save acceptance: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Scrollable terms content
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Terms & Conditions',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Last Updated: ${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Terms content
                    SelectableText(
                      LegalContentService.getTermsAndConditions(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 14,
                            height: 1.6,
                          ),
                    ),
                    const SizedBox(height: 24),
                    // Zero tolerance policy highlight
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        border: Border.all(color: Colors.red[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  color: Colors.red[700], size: 24),
                              const SizedBox(width: 8),
                              Text(
                                'Zero Tolerance Policy',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[900],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${AppConstants.appName} has a ZERO TOLERANCE policy for objectionable content and abusive users. Any user who posts objectionable content, harasses other users, or engages in abusive behavior will have their content removed immediately and may be permanently banned from the platform.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.red[900],
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'By accepting these Terms & Conditions, you acknowledge that you understand this policy and agree to comply with all community guidelines.',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.red[900],
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            // Acceptance checkbox and button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Checkbox
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _hasAcceptedEula,
                        onChanged: (value) {
                          setState(() {
                            _hasAcceptedEula = value ?? false;
                          });
                        },
                        activeColor: const Color(0xFF7C3AED),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _hasAcceptedEula = !_hasAcceptedEula;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[800],
                                  height: 1.5,
                                ),
                                children: [
                                  const TextSpan(
                                    text:
                                        'I have read and agree to the Terms & Conditions and understand that there is ',
                                  ),
                                  TextSpan(
                                    text: 'zero tolerance for objectionable content or abusive users',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red[700],
                                    ),
                                  ),
                                  const TextSpan(text: '.'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Continue button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _acceptAndContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        disabledBackgroundColor: Colors.grey[300],
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Accept & Continue',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
