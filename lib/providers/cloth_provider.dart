import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/cloth.dart';
import '../services/cloth_service.dart';

/// Cloth provider for managing clothes state
class WearHistoryInfo {
  final String summary;
  final bool isWornToday;
  final int totalCount;
  final DateTime? lastWornAt;

  const WearHistoryInfo({
    required this.summary,
    required this.isWornToday,
    required this.totalCount,
    required this.lastWornAt,
  });
}

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
  /// Set skipFinalNotify to true to skip the final notifyListeners() call
  /// (useful when you need to refresh counts before notifying)
  Future<void> loadClothes({
    required String userId,
    String? wardrobeId,
    bool skipFinalNotify = false,
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
      if (!skipFinalNotify) {
        notifyListeners();
      }
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

  /// Get cloth by ID
  Future<Cloth?> getClothById({
    required String userId,
    required String wardrobeId,
    required String clothId,
  }) async {
    try {
      return await ClothService.getCloth(
        userId: userId,
        wardrobeId: wardrobeId,
        clothId: clothId,
      );
    } catch (e) {
      debugPrint('Error getting cloth: $e');
      return null;
    }
  }

  /// Add cloth
  Future<String?> addCloth({
    required String userId,
    required String wardrobeId,
    required File imageFile,
    required String season,
    required String placement,
    PlacementDetails? placementDetails,
    required ColorTags colorTags,
    required String clothType,
    required String category,
    required List<String> occasions,
    String visibility = 'private',
    String itemKind = 'cloth',
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
        placementDetails: placementDetails,
        colorTags: colorTags,
        clothType: clothType,
        category: category,
        occasions: occasions,
        visibility: visibility,
        itemKind: itemKind,
        aiDetected: aiDetected,
      );

      _errorMessage = null;

      // Refresh clothes list to include the new cloth
      await loadClothes(userId: userId, wardrobeId: wardrobeId);

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

  /// Move cloth to a different wardrobe
  Future<void> moveClothToWardrobe({
    required String userId,
    required String oldWardrobeId,
    required String newWardrobeId,
    required String clothId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await ClothService.moveClothToWardrobe(
        userId: userId,
        oldWardrobeId: oldWardrobeId,
        newWardrobeId: newWardrobeId,
        clothId: clothId,
      );

      // Remove from local list if it exists
      _clothes.removeWhere((c) => c.id == clothId);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to move cloth: ${e.toString()}';
      debugPrint('Error moving cloth: $e');
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

  /// Toggle worn status (mark/unmark) for today
  Future<DateTime?> toggleWornStatus({
    required String userId,
    required String wardrobeId,
    required Cloth cloth,
  }) async {
    final now = DateTime.now();
    final isWornToday = cloth.wornAt != null && _isSameDay(cloth.wornAt!, now);

    try {
      DateTime? newWornAt;
      if (isWornToday) {
        newWornAt = await ClothService.unmarkWornToday(
          userId: userId,
          wardrobeId: wardrobeId,
          clothId: cloth.id,
        );
      } else {
        await ClothService.markAsWornToday(
          userId: userId,
          wardrobeId: wardrobeId,
          clothId: cloth.id,
        );
        newWornAt = now;
      }

      // Update placement based on worn status
      final newPlacement = newWornAt != null ? 'OutWardrobe' : 'InWardrobe';
      _updateClothLocally(
        cloth.id,
        wornAt: newWornAt,
        clearWornAt: newWornAt == null, // Explicitly clear if null
        placement: newPlacement,
      );
      _errorMessage = null;
      notifyListeners();
      return newWornAt;
    } catch (e) {
      _errorMessage = 'Failed to update worn status: ${e.toString()}';
      notifyListeners();
      rethrow;
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

      // Get actual like count from Firestore
      final actualCount = await getLikeCount(
        ownerId: ownerId,
        wardrobeId: wardrobeId,
        clothId: clothId,
      );

      _updateClothLocally(
        clothId,
        likesCount: actualCount,
      );
      notifyListeners();
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

      // Get actual like count from Firestore
      final actualCount = await getLikeCount(
        ownerId: ownerId,
        wardrobeId: wardrobeId,
        clothId: clothId,
      );

      _updateClothLocally(
        clothId,
        likesCount: actualCount,
      );
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to unlike cloth: ${e.toString()}';
      notifyListeners();
    }
  }

  /// Check if cloth is liked by user
  Future<bool> isLiked({
    required String userId,
    required String ownerId,
    required String wardrobeId,
    required String clothId,
  }) async {
    try {
      return await ClothService.hasLiked(
        userId: userId,
        ownerId: ownerId,
        wardrobeId: wardrobeId,
        clothId: clothId,
      );
    } catch (e) {
      debugPrint('Failed to check like status: $e');
      return false;
    }
  }

  /// Get actual like count from Firestore
  Future<int> getLikeCount({
    required String ownerId,
    required String wardrobeId,
    required String clothId,
  }) async {
    try {
      return await ClothService.getLikeCount(
        ownerId: ownerId,
        wardrobeId: wardrobeId,
        clothId: clothId,
      );
    } catch (e) {
      debugPrint('Failed to get like count: $e');
      return 0;
    }
  }

  /// Get actual comment count from Firestore
  Future<int> getCommentCount({
    required String ownerId,
    required String wardrobeId,
    required String clothId,
  }) async {
    try {
      return await ClothService.getCommentCount(
        ownerId: ownerId,
        wardrobeId: wardrobeId,
        clothId: clothId,
      );
    } catch (e) {
      debugPrint('Failed to get comment count: $e');
      return 0;
    }
  }

  /// Toggle like status
  Future<void> toggleLike({
    required String userId,
    required String ownerId,
    required String wardrobeId,
    required String clothId,
  }) async {
    try {
      // Check if user has currently liked the cloth (check Firestore directly)
      final isCurrentlyLiked = await isLiked(
        userId: userId,
        ownerId: ownerId,
        wardrobeId: wardrobeId,
        clothId: clothId,
      );

      if (isCurrentlyLiked) {
        await unlikeCloth(
          userId: userId,
          ownerId: ownerId,
          wardrobeId: wardrobeId,
          clothId: clothId,
        );
      } else {
        await likeCloth(
          userId: userId,
          ownerId: ownerId,
          wardrobeId: wardrobeId,
          clothId: clothId,
        );
      }

      // likeCloth/unlikeCloth already update the count, so we just notify listeners
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to toggle like: ${e.toString()}';
      notifyListeners();
      rethrow; // Re-throw so UI can handle the error
    }
  }

  /// Get wear history info for cloth
  Future<WearHistoryInfo> getWearHistoryInfo({
    required String userId,
    required String wardrobeId,
    required String clothId,
  }) async {
    try {
      final history = await ClothService.getWearHistory(
        userId: userId,
        wardrobeId: wardrobeId,
        clothId: clothId,
      );

      if (history.isEmpty) {
        return const WearHistoryInfo(
          summary: 'Never worn',
          isWornToday: false,
          totalCount: 0,
          lastWornAt: null,
        );
      }

      final count = history.length;
      final lastWorn = history.first.wornAt;
      final now = DateTime.now();
      final normalizedNow = DateTime(now.year, now.month, now.day);
      final normalizedLast =
          DateTime(lastWorn.year, lastWorn.month, lastWorn.day);
      final daysSince = normalizedNow.difference(normalizedLast).inDays;
      final isToday = daysSince == 0;

      String summary;
      if (isToday) {
        summary =
            'Worn $count ${count == 1 ? 'time' : 'times'}, last worn today';
      } else if (daysSince == 1) {
        summary =
            'Worn $count ${count == 1 ? 'time' : 'times'}, last worn yesterday';
      } else {
        summary =
            'Worn $count ${count == 1 ? 'time' : 'times'}, last worn $daysSince days ago';
      }

      return WearHistoryInfo(
        summary: summary,
        isWornToday: isToday,
        totalCount: count,
        lastWornAt: lastWorn,
      );
    } catch (e) {
      debugPrint('Failed to get wear history: $e');
      return const WearHistoryInfo(
        summary: 'Wear history unavailable',
        isWornToday: false,
        totalCount: 0,
        lastWornAt: null,
      );
    }
  }

  /// Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _updateClothLocally(
    String clothId, {
    DateTime? wornAt,
    bool clearWornAt = false, // Flag to explicitly clear wornAt
    String? placement,
    int? likesCount,
    int? commentsCount,
  }) {
    final index = _clothes.indexWhere((cloth) => cloth.id == clothId);
    if (index == -1) return;

    final oldCloth = _clothes[index];

    // Handle wornAt: if clearWornAt is true, set to null;
    // if wornAt is provided (not null), use it; otherwise keep existing
    final updatedWornAt =
        clearWornAt ? null : (wornAt != null ? wornAt : oldCloth.wornAt);

    // Create updated cloth - need to handle null wornAt explicitly
    final updated = Cloth(
      id: oldCloth.id,
      ownerId: oldCloth.ownerId,
      wardrobeId: oldCloth.wardrobeId,
      imageUrl: oldCloth.imageUrl,
      season: oldCloth.season,
      placement: placement ?? oldCloth.placement,
      placementDetails: oldCloth.placementDetails,
      colorTags: oldCloth.colorTags,
      clothType: oldCloth.clothType,
      category: oldCloth.category,
      itemKind: oldCloth.itemKind,
      occasions: oldCloth.occasions,
      aiDetected: oldCloth.aiDetected,
      createdAt: oldCloth.createdAt,
      updatedAt: DateTime.now(),
      wornAt: updatedWornAt, // This can be null now
      visibility: oldCloth.visibility,
      sharedWith: oldCloth.sharedWith,
      likesCount: likesCount ?? oldCloth.likesCount,
      commentsCount: commentsCount ?? oldCloth.commentsCount,
    );
    _clothes[index] = updated;
  }

  /// Update cloth locally (public method for UI to refresh counts)
  /// Set batchUpdate to true to avoid calling notifyListeners() (caller will handle it)
  void updateClothLocally({
    required String clothId,
    int? likesCount,
    int? commentsCount,
    bool batchUpdate = false,
  }) {
    _updateClothLocally(
      clothId,
      likesCount: likesCount,
      commentsCount: commentsCount,
    );
    if (!batchUpdate) {
      notifyListeners();
    }
  }

  /// Notify listeners (public method for batch updates)
  void notifyListenersUpdate() {
    notifyListeners();
  }
}
