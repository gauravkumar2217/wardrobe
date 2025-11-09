import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/cloth.dart';
import '../services/cloth_service.dart';

class ClothProvider with ChangeNotifier {
  List<Cloth> _clothes = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Cloth> get clothes => _clothes;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Load clothes for a wardrobe
  Future<void> loadClothes(String userId, String wardrobeId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _clothes = await ClothService.getClothes(userId, wardrobeId);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load clothes: ${e.toString()}';
      if (kDebugMode) {
        print('Error loading clothes: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Watch clothes for real-time updates
  void watchClothes(String userId, String wardrobeId) {
    ClothService.watchClothes(userId, wardrobeId).listen((clothes) {
      _clothes = clothes;
      _errorMessage = null;
      notifyListeners();
    }).onError((error) {
      _errorMessage = 'Failed to watch clothes: ${error.toString()}';
      notifyListeners();
    });
  }

  /// Add cloth to wardrobe
  Future<String?> addCloth(
    String userId,
    String wardrobeId,
    File? imageFile,
    String type,
    String color,
    List<String> occasions, // Changed to support multiple occasions
    String season,
  ) async {
    if (kDebugMode) {
      debugPrint('ClothProvider: Starting addCloth');
      debugPrint('ClothProvider: User ID: $userId, Wardrobe ID: $wardrobeId');
      debugPrint('ClothProvider: Type: $type, Color: $color, Occasions: $occasions, Season: $season');
      debugPrint('ClothProvider: Image file: ${imageFile?.path ?? "null"}');
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (kDebugMode) {
        debugPrint('ClothProvider: Calling ClothService.addCloth');
      }

      final clothId = await ClothService.addCloth(
        userId,
        wardrobeId,
        imageFile,
        type,
        color,
        occasions,
        season,
      );

      if (kDebugMode) {
        debugPrint('ClothProvider: ClothService.addCloth returned: $clothId');
      }

      _errorMessage = null;
      _isLoading = false;
      notifyListeners();

      return clothId;
    } catch (e, stackTrace) {
      _errorMessage = 'Failed to add cloth: ${e.toString()}';
      _isLoading = false;
      if (kDebugMode) {
        debugPrint('ClothProvider: Error adding cloth: $_errorMessage');
        debugPrint('ClothProvider: Stack trace: $stackTrace');
      }
      notifyListeners();
      return null;
    }
  }

  /// Delete cloth
  Future<void> deleteCloth(
    String userId,
    String wardrobeId,
    String clothId,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await ClothService.deleteCloth(userId, wardrobeId, clothId);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to delete cloth: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Mark cloth as worn
  Future<void> markAsWorn(
    String userId,
    String wardrobeId,
    String clothId,
  ) async {
    try {
      await ClothService.markAsWorn(userId, wardrobeId, clothId);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to mark as worn: ${e.toString()}';
      notifyListeners();
    }
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

