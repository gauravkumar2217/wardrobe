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
      
      // Refresh counts for all wardrobes
      await _refreshAllWardrobeCounts(userId);
      
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load wardrobes: ${e.toString()}';
      debugPrint('Error loading wardrobes: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh counts for all wardrobes
  Future<void> _refreshAllWardrobeCounts(String userId) async {
    try {
      // Fetch counts for all wardrobes in parallel
      final futures = _wardrobes.map((wardrobe) async {
        try {
          final count = await WardrobeService.getClothesCount(
            userId: userId,
            wardrobeId: wardrobe.id,
          );
          return {'wardrobeId': wardrobe.id, 'count': count};
        } catch (e) {
          debugPrint('Failed to get count for wardrobe ${wardrobe.id}: $e');
          return {'wardrobeId': wardrobe.id, 'count': 0};
        }
      });

      final results = await Future.wait(futures);

      // Update wardrobes with actual counts
      for (var result in results) {
        final wardrobeId = result['wardrobeId'] as String;
        final count = result['count'] as int;
        
        final index = _wardrobes.indexWhere((w) => w.id == wardrobeId);
        if (index != -1) {
          _wardrobes[index] = _wardrobes[index].copyWith(totalItems: count);
          
          // Update selected wardrobe if it's the same
          if (_selectedWardrobe?.id == wardrobeId) {
            _selectedWardrobe = _wardrobes[index];
          }
        }
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to refresh wardrobe counts: $e');
    }
  }

  /// Watch wardrobes for real-time updates
  void watchWardrobes(String userId) {
    WardrobeService.watchUserWardrobes(userId).listen((wardrobes) async {
      _wardrobes = wardrobes;
      _errorMessage = null;
      
      // Refresh counts for all wardrobes
      await _refreshAllWardrobeCounts(userId);
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

  /// Get wardrobe by ID
  Wardrobe? getWardrobeById(String wardrobeId) {
    try {
      return _wardrobes.firstWhere((w) => w.id == wardrobeId);
    } catch (e) {
      return null;
    }
  }

  /// Refresh wardrobe count (update totalItems from actual clothes count)
  Future<void> refreshWardrobeCount({
    required String userId,
    required String wardrobeId,
  }) async {
    try {
      final count = await WardrobeService.getClothesCount(
        userId: userId,
        wardrobeId: wardrobeId,
      );
      
      // Update the wardrobe in the list
      final index = _wardrobes.indexWhere((w) => w.id == wardrobeId);
      if (index != -1) {
        _wardrobes[index] = _wardrobes[index].copyWith(totalItems: count);
        
        // Update selected wardrobe if it's the same
        if (_selectedWardrobe?.id == wardrobeId) {
          _selectedWardrobe = _wardrobes[index];
        }
        
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to refresh wardrobe count: $e');
    }
  }

  /// Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
