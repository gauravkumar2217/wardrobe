import 'package:flutter/foundation.dart';

/// Navigation provider for managing main navigation tab index
class NavigationProvider with ChangeNotifier {
  int _currentIndex = 0;
  int _tryOnRefreshNonce = 0;

  int get currentIndex => _currentIndex;

  /// Bumped when try-on should reload avatar data (e.g. after avatar replacement).
  int get tryOnRefreshNonce => _tryOnRefreshNonce;

  void setCurrentIndex(int index) {
    if (_currentIndex == index) {
      notifyListeners();
      return;
    }
    _currentIndex = index;
    notifyListeners();
  }

  /// Switch to Home tab and notify even if already on Home (e.g. pop overlays).
  void goHomeTab() {
    _currentIndex = 0;
    notifyListeners();
  }

  void navigateToHome() {
    setCurrentIndex(0);
  }

  void navigateToWardrobes() {
    setCurrentIndex(1);
  }

  void navigateToTryOn() {
    _tryOnRefreshNonce++;
    setCurrentIndex(2);
  }

  void navigateToCommunity() {
    setCurrentIndex(3);
  }

  void navigateToProfile() {
    setCurrentIndex(4);
  }
}

