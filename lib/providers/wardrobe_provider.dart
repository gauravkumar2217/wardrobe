import 'package:flutter/foundation.dart';
import '../models/wardrobe.dart';
import '../services/wardrobe_service.dart';

/// Wardrobe provider for managing wardrobes state
class WardrobeProvider with ChangeNotifier {
  List<Wardrobe> _wardrobes = [];
  Wardrobe? _selectedWardrobe;
  bool _isLoading = false;
  String? _errorMessage;

  List<Wardrobe> get wardrobes => _wardrobes;
  Wardrobe? get selectedWardrobe => _selectedWardrobe;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Set selected wardrobe
  void setSelectedWardrobe(Wardrobe? wardrobe) {
    _selectedWardrobe = wardrobe;
    notifyListeners();
  }

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
      debugPrint('Error loading wardrobes: $e');
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

  /// Create wardrobe
  Future<String?> createWardrobe({
    required String userId,
    required String name,
    required String location,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final wardrobeId = await WardrobeService.createWardrobe(
        userId: userId,
        name: name,
        location: location,
      );

      _errorMessage = null;
      return wardrobeId;
    } catch (e) {
      _errorMessage = 'Failed to create wardrobe: ${e.toString()}';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update wardrobe
  Future<void> updateWardrobe({
    required String userId,
    required String wardrobeId,
    Map<String, dynamic>? updates,
    Wardrobe? wardrobe,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await WardrobeService.updateWardrobe(
        userId: userId,
        wardrobeId: wardrobeId,
        updates: updates,
        wardrobe: wardrobe,
      );
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to update wardrobe: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Delete wardrobe
  Future<void> deleteWardrobe({
    required String userId,
    required String wardrobeId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await WardrobeService.deleteWardrobe(
        userId: userId,
        wardrobeId: wardrobeId,
      );
      _wardrobes.removeWhere((w) => w.id == wardrobeId);
      if (_selectedWardrobe?.id == wardrobeId) {
        _selectedWardrobe = null;
      }
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to delete wardrobe: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
