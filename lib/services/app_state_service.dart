import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Service to track app lifecycle state (foreground/background)
class AppStateService {
  static final AppStateService _instance = AppStateService._internal();
  factory AppStateService() => _instance;
  AppStateService._internal();

  AppLifecycleState _currentState = AppLifecycleState.resumed;
  final List<Function(AppLifecycleState)> _listeners = [];

  AppLifecycleState get currentState => _currentState;
  bool get isInForeground => _currentState == AppLifecycleState.resumed;
  bool get isInBackground =>
      _currentState == AppLifecycleState.paused ||
      _currentState == AppLifecycleState.inactive ||
      _currentState == AppLifecycleState.detached;

  void updateState(AppLifecycleState newState) {
    if (_currentState != newState) {
      _currentState = newState;
      if (kDebugMode) {
        debugPrint('App state changed: $_currentState');
      }
      // Notify all listeners
      for (var listener in _listeners) {
        listener(newState);
      }
    }
  }

  void addListener(Function(AppLifecycleState) listener) {
    _listeners.add(listener);
  }

  void removeListener(Function(AppLifecycleState) listener) {
    _listeners.remove(listener);
  }
}
