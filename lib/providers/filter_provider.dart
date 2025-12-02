import 'package:flutter/foundation.dart';

/// Filter provider for managing home screen filters
class FilterProvider with ChangeNotifier {
  String? _filterType;
  String? _filterOccasion;
  String? _filterSeason;
  String? _filterColor;

  String? get filterType => _filterType;
  String? get filterOccasion => _filterOccasion;
  String? get filterSeason => _filterSeason;
  String? get filterColor => _filterColor;

  bool get hasActiveFilter =>
      _filterType != null ||
      _filterOccasion != null ||
      _filterSeason != null ||
      _filterColor != null;

  void setFilter({
    String? type,
    String? occasion,
    String? season,
    String? color,
  }) {
    _filterType = type;
    _filterOccasion = occasion;
    _filterSeason = season;
    _filterColor = color;
    notifyListeners();
  }

  void clearFilters() {
    _filterType = null;
    _filterOccasion = null;
    _filterSeason = null;
    _filterColor = null;
    notifyListeners();
  }
}

