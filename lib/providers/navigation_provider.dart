import 'package:flutter/foundation.dart';

/// Navigation provider for managing main navigation tab index
class NavigationProvider with ChangeNotifier {
  int _currentIndex = 0;

  int get currentIndex => _currentIndex;

  void setCurrentIndex(int index) {
    if (_currentIndex != index) {
      _currentIndex = index;
      notifyListeners();
    }
  }

  void navigateToHome() {
    setCurrentIndex(0);
  }

  void navigateToWardrobes() {
    setCurrentIndex(1);
  }

  void navigateToFriends() {
    setCurrentIndex(2);
  }

  void navigateToChats() {
    setCurrentIndex(3);
  }

  void navigateToProfile() {
    setCurrentIndex(4);
  }
}

