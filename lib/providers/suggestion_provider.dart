import 'package:flutter/foundation.dart';
import '../models/suggestion.dart';
import '../models/wardrobe.dart';
import '../services/suggestion_service.dart';

class SuggestionProvider with ChangeNotifier {
  Suggestion? _todaySuggestion;
  List<Suggestion> _history = [];
  bool _isLoading = false;
  String? _errorMessage;

  Suggestion? get todaySuggestion => _todaySuggestion;
  List<Suggestion> get history => _history;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Generate a new suggestion
  Future<Suggestion?> generateSuggestion(
    String userId,
    String wardrobeId,
    Wardrobe wardrobe, {
    String? occasion,
    int maxItems = 3,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final suggestion = await SuggestionService.generateSuggestion(
        userId,
        wardrobeId,
        wardrobe,
        occasion: occasion,
        maxItems: maxItems,
      );

      _todaySuggestion = suggestion;
      _errorMessage = null;
      _isLoading = false;
      notifyListeners();

      return suggestion;
    } catch (e) {
      _errorMessage = 'Failed to generate suggestion: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Load today's suggestion
  Future<void> loadTodaySuggestion(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _todaySuggestion = await SuggestionService.getTodaySuggestion(userId);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load suggestion: ${e.toString()}';
      if (kDebugMode) {
        print('Error loading suggestion: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load suggestion history
  Future<void> loadHistory(String userId, {int limit = 30}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _history = await SuggestionService.getSuggestionHistory(userId, limit: limit);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load history: ${e.toString()}';
      if (kDebugMode) {
        print('Error loading history: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Watch today's suggestion for real-time updates
  void watchTodaySuggestion(String userId) {
    SuggestionService.watchTodaySuggestion(userId).listen((suggestion) {
      _todaySuggestion = suggestion;
      _errorMessage = null;
      notifyListeners();
    }).onError((error) {
      _errorMessage = 'Failed to watch suggestion: ${error.toString()}';
      notifyListeners();
    });
  }

  /// Mark suggestion as viewed
  Future<void> markAsViewed(String userId, String suggestionId) async {
    try {
      await SuggestionService.markAsViewed(userId, suggestionId);
      if (_todaySuggestion?.id == suggestionId) {
        _todaySuggestion = _todaySuggestion?.copyWith(viewed: true);
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to mark as viewed: ${e.toString()}';
      notifyListeners();
    }
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

