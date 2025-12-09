import 'package:flutter/material.dart';

/// Onboarding step definition
class OnboardingStep {
  final String id;
  final String title;
  final String description;
  final GlobalKey? targetKey; // Key to the widget to highlight
  final Offset? targetOffset; // Alternative: manual position
  final Size? targetSize; // Size of the target widget
  final Alignment alignment; // Where to show the tooltip relative to target

  OnboardingStep({
    required this.id,
    required this.title,
    required this.description,
    this.targetKey,
    this.targetOffset,
    this.targetSize,
    this.alignment = Alignment.bottomCenter,
  });
}

/// Provider for managing onboarding state
class OnboardingProvider with ChangeNotifier {
  bool _isOnboardingActive = false;
  int _currentStepIndex = 0;
  List<OnboardingStep> _steps = [];
  bool _isSkipped = false;

  bool get isOnboardingActive => _isOnboardingActive;
  int get currentStepIndex => _currentStepIndex;
  OnboardingStep? get currentStep => 
      _currentStepIndex < _steps.length ? _steps[_currentStepIndex] : null;
  int get totalSteps => _steps.length;
  bool get isSkipped => _isSkipped;
  bool get hasMoreSteps => _currentStepIndex < _steps.length - 1;

  /// Start onboarding with a list of steps
  void startOnboarding(List<OnboardingStep> steps) {
    _steps = steps;
    _currentStepIndex = 0;
    _isOnboardingActive = true;
    _isSkipped = false;
    notifyListeners();
  }

  /// Move to next step
  void nextStep() {
    if (_currentStepIndex < _steps.length - 1) {
      _currentStepIndex++;
      notifyListeners();
    } else {
      completeOnboarding();
    }
  }

  /// Move to previous step
  void previousStep() {
    if (_currentStepIndex > 0) {
      _currentStepIndex--;
      notifyListeners();
    }
  }

  /// Skip onboarding
  void skipOnboarding() {
    _isSkipped = true;
    _isOnboardingActive = false;
    notifyListeners();
  }

  /// Complete onboarding
  void completeOnboarding() {
    _isOnboardingActive = false;
    _currentStepIndex = 0;
    _steps = [];
    notifyListeners();
  }

  /// Reset onboarding (for testing or re-showing)
  void reset() {
    _isOnboardingActive = false;
    _currentStepIndex = 0;
    _steps = [];
    _isSkipped = false;
    notifyListeners();
  }
}

