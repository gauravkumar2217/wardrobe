import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/cloth.dart';
import '../services/cloth_service.dart';

/// Cloth provider for managing clothes state
class ClothProvider with ChangeNotifier {
  List<Cloth> _clothes = [];
  String? _selectedWardrobeId;
  bool _isLoading = false;
  String? _errorMessage;

  List<Cloth> get clothes => _clothes;
  String? get selectedWardrobeId => _selectedWardrobeId;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Set selected wardrobe filter
  void setSelectedWardrobe(String? wardrobeId) {
    _selectedWardrobeId = wardrobeId;
    notifyListeners();
  }

  /// Load clothes for a wardrobe
  Future<void> loadClothes({
    required String userId,
    String? wardrobeId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (wardrobeId != null) {
        _clothes = await ClothService.getClothes(
          userId: userId,
          wardrobeId: wardrobeId,
        );
      } else {
        _clothes = await ClothService.getAllUserClothes(userId);
      }
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load clothes: ${e.toString()}';
      debugPrint('Error loading clothes: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Watch clothes for real-time updates
  void watchClothes({
    required String userId,
    String? wardrobeId,
  }) {
    Stream<List<Cloth>> stream;
    
    if (wardrobeId != null) {
      stream = ClothService.watchClothes(
        userId: userId,
        wardrobeId: wardrobeId,
      );
    } else {
      stream = ClothService.watchAllUserClothes(userId);
    }

    stream.listen((clothes) {
      _clothes = clothes;
      _errorMessage = null;
      notifyListeners();
    }).onError((error) {
      _errorMessage = 'Failed to watch clothes: ${error.toString()}';
      notifyListeners();
    });
  }

  /// Add cloth
  Future<String?> addCloth({
    required String userId,
    required String wardrobeId,
    required File imageFile,
    required String season,
    required String placement,
    required ColorTags colorTags,
    required String clothType,
    required String category,
    required List<String> occasions,
    String visibility = 'private',
    AiDetected? aiDetected,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final clothId = await ClothService.addCloth(
        userId: userId,
        wardrobeId: wardrobeId,
        imageFile: imageFile,
        season: season,
        placement: placement,
        colorTags: colorTags,
        clothType: clothType,
        category: category,
        occasions: occasions,
        visibility: visibility,
        aiDetected: aiDetected,
      );

      _errorMessage = null;
      return clothId;
    } catch (e) {
      _errorMessage = 'Failed to add cloth: ${e.toString()}';
      debugPrint('Error adding cloth: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update cloth
  Future<void> updateCloth({
    required String userId,
    required String wardrobeId,
    required String clothId,
    Map<String, dynamic>? updates,
    Cloth? cloth,
    File? newImageFile,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await ClothService.updateCloth(
        userId: userId,
        wardrobeId: wardrobeId,
        clothId: clothId,
        updates: updates,
        cloth: cloth,
        newImageFile: newImageFile,
      );
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to update cloth: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Delete cloth
  Future<void> deleteCloth({
    required String userId,
    required String wardrobeId,
    required String clothId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await ClothService.deleteCloth(
        userId: userId,
        wardrobeId: wardrobeId,
        clothId: clothId,
      );
      _clothes.removeWhere((c) => c.id == clothId);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to delete cloth: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Mark cloth as worn today
  Future<void> markAsWornToday({
    required String userId,
    required String wardrobeId,
    required String clothId,
  }) async {
    try {
      await ClothService.markAsWornToday(
        userId: userId,
        wardrobeId: wardrobeId,
        clothId: clothId,
      );
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to mark as worn: ${e.toString()}';
      notifyListeners();
    }
  }

  /// Like cloth
  Future<void> likeCloth({
    required String userId,
    required String ownerId,
    required String wardrobeId,
    required String clothId,
  }) async {
    try {
      await ClothService.likeCloth(
        userId: userId,
        ownerId: ownerId,
        wardrobeId: wardrobeId,
        clothId: clothId,
      );
    } catch (e) {
      _errorMessage = 'Failed to like cloth: ${e.toString()}';
      notifyListeners();
    }
  }

  /// Unlike cloth
  Future<void> unlikeCloth({
    required String userId,
    required String ownerId,
    required String wardrobeId,
    required String clothId,
  }) async {
    try {
      await ClothService.unlikeCloth(
        userId: userId,
        ownerId: ownerId,
        wardrobeId: wardrobeId,
        clothId: clothId,
      );
    } catch (e) {
      _errorMessage = 'Failed to unlike cloth: ${e.toString()}';
      notifyListeners();
    }
  }

  /// Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
