import 'package:flutter/foundation.dart';

/// Filter provider for managing home screen filters
class FilterProvider with ChangeNotifier {
  List<String> _filterTypes = [];
  List<String> _filterOccasions = [];
  List<String> _filterSeasons = [];
  List<String> _filterColors = [];
  List<String> _filterPlacements = [];
  String? _selectedWardrobeId;

  // Getters for backward compatibility (single value)
  String? get filterType => _filterTypes.isNotEmpty ? _filterTypes.first : null;
  String? get filterOccasion => _filterOccasions.isNotEmpty ? _filterOccasions.first : null;
  String? get filterSeason => _filterSeasons.isNotEmpty ? _filterSeasons.first : null;
  String? get filterColor => _filterColors.isNotEmpty ? _filterColors.first : null;

  // Getters for multiple values
  List<String> get filterTypes => _filterTypes;
  List<String> get filterOccasions => _filterOccasions;
  List<String> get filterSeasons => _filterSeasons;
  List<String> get filterColors => _filterColors;
  List<String> get filterPlacements => _filterPlacements;
  String? get selectedWardrobeId => _selectedWardrobeId;

  bool get hasActiveFilter =>
      _filterTypes.isNotEmpty ||
      _filterOccasions.isNotEmpty ||
      _filterSeasons.isNotEmpty ||
      _filterColors.isNotEmpty ||
      _filterPlacements.isNotEmpty ||
      _selectedWardrobeId != null;

  void setFilter({
    String? type,
    String? occasion,
    String? season,
    String? color,
  }) {
    _filterTypes = type != null ? [type] : [];
    _filterOccasions = occasion != null ? [occasion] : [];
    _filterSeasons = season != null ? [season] : [];
    _filterColors = color != null ? [color] : [];
    notifyListeners();
  }

  void setMultipleFilters({
    List<String>? types,
    List<String>? occasions,
    List<String>? seasons,
    List<String>? colors,
    List<String>? placements,
    String? wardrobeId,
  }) {
    _filterTypes = types ?? [];
    _filterOccasions = occasions ?? [];
    _filterSeasons = seasons ?? [];
    _filterColors = colors ?? [];
    _filterPlacements = placements ?? [];
    _selectedWardrobeId = wardrobeId;
    notifyListeners();
  }

  void clearFilters() {
    _filterTypes = [];
    _filterOccasions = [];
    _filterSeasons = [];
    _filterColors = [];
    _filterPlacements = [];
    _selectedWardrobeId = null;
    notifyListeners();
  }
}

