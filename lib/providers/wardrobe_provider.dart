import 'package:flutter/foundation.dart';
import '../models/wardrobe.dart';
import '../services/wardrobe_service.dart';

class WardrobeProvider with ChangeNotifier {
  List<Wardrobe> _wardrobes = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Wardrobe> get wardrobes => _wardrobes;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasReachedLimit => _wardrobes.length >= 2;

  /// Load wardrobes for a user
  Future<void> loadWardrobes(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _wardrobes = await WardrobeService.getUserWardrobes(userId);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load wardrobes: ${e.toString()}';
      if (kDebugMode) {
        print('Error loading wardrobes: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Watch wardrobes for real-time updates
  void watchWardrobes(String userId) {
    WardrobeService.watchUserWardrobes(userId).listen((wardrobes) {
      _wardrobes = wardrobes;
      _errorMessage = null;
      notifyListeners();
    }).onError((error) {
      _errorMessage = 'Failed to watch wardrobes: ${error.toString()}';
      notifyListeners();
    });
  }

  /// Create a new wardrobe
  Future<String?> createWardrobe(
    String userId,
    String title,
    String location,
    String season,
  ) async {
    if (hasReachedLimit) {
      _errorMessage = 'Maximum 2 wardrobes allowed on free plan';
      notifyListeners();
      return null;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final wardrobeId = await WardrobeService.createWardrobe(
        userId,
        title,
        location,
        season,
      );

      _errorMessage = null;
      _isLoading = false;
      notifyListeners();

      return wardrobeId;
    } catch (e) {
      _errorMessage = 'Failed to create wardrobe: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Update a wardrobe
  Future<void> updateWardrobe(
    String userId,
    String wardrobeId,
    Map<String, dynamic> updates,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await WardrobeService.updateWardrobe(userId, wardrobeId, updates);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to update wardrobe: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Delete a wardrobe
  Future<void> deleteWardrobe(String userId, String wardrobeId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await WardrobeService.deleteWardrobe(userId, wardrobeId);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to delete wardrobe: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

