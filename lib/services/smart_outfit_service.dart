import 'dart:math';
import '../models/outfit.dart';
import '../models/cloth.dart';
import '../models/wardrobe.dart';
import 'cloth_service.dart';

/// Smart Outfit Service for AI-powered outfit combinations
class SmartOutfitService {
  // Weather API key (OpenWeatherMap) - can be configured later
  // static const String? _weatherApiKey = null;

  /// Generate smart outfit combinations
  static Future<List<Outfit>> generateSmartOutfits(
    String userId,
    String wardrobeId,
    Wardrobe wardrobe, {
    String? occasion,
    int maxOutfits = 5,
  }) async {
    try {
      final clothes = await ClothService.getClothes(userId, wardrobeId);
      
      if (clothes.isEmpty) {
        throw Exception('No clothes available');
      }

      // Filter by season
      var filteredClothes = clothes.where((cloth) {
        return cloth.season == wardrobe.season || 
               cloth.season == 'All-season' ||
               wardrobe.season == 'All-season';
      }).toList();

      if (filteredClothes.isEmpty) {
        filteredClothes = clothes;
      }

      // Filter by occasion if specified
      if (occasion != null && occasion.isNotEmpty) {
        filteredClothes = filteredClothes.where((cloth) {
          return cloth.occasion == occasion || cloth.occasion == 'Other';
        }).toList();
      }

      // Get weather data
      final weather = await _getCurrentWeather();

      // Categorize clothes
      final tops = filteredClothes.where((c) => 
        _isTop(c.type)
      ).toList();
      final bottoms = filteredClothes.where((c) => 
        _isBottom(c.type)
      ).toList();
      final accessories = filteredClothes.where((c) => 
        _isAccessory(c.type)
      ).toList();

      // Generate outfit combinations
      final outfits = <Outfit>[];
      final random = Random();

      for (int i = 0; i < maxOutfits && i < 20; i++) {
        if (tops.isEmpty || bottoms.isEmpty) break;

        // Pick random top and bottom
        final top = tops[random.nextInt(tops.length)];
        final bottom = bottoms[random.nextInt(bottoms.length)];

        // Check color compatibility
        if (!_areColorsCompatible(top.color, bottom.color)) {
          continue;
        }

        // Build outfit
        final clothIds = [top.id, bottom.id];
        
        // Add accessory if available
        if (accessories.isNotEmpty && random.nextBool()) {
          final accessory = accessories[random.nextInt(accessories.length)];
          if (_isAccessoryCompatible(accessory, top, bottom)) {
            clothIds.add(accessory.id);
          }
        }

        // Calculate confidence score
        double confidence = 0.7;
        confidence += _getColorMatchScore(top.color, bottom.color) * 0.2;
        confidence += _getWeatherMatchScore(top, bottom, weather) * 0.1;

        final outfit = Outfit(
          id: DateTime.now().millisecondsSinceEpoch.toString() + i.toString(),
          wardrobeId: wardrobeId,
          clothIds: clothIds,
          occasion: occasion ?? top.occasion,
          weather: weather,
          confidence: confidence.clamp(0.0, 1.0),
          createdAt: DateTime.now(),
        );

        outfits.add(outfit);
      }

      // Sort by confidence
      outfits.sort((a, b) => b.confidence.compareTo(a.confidence));

      return outfits.take(maxOutfits).toList();
    } catch (e) {
      throw Exception('Failed to generate smart outfits: $e');
    }
  }

  /// Check if clothing type is a top
  static bool _isTop(String type) {
    return ['Shirt', 'T-Shirt', 'Blouse', 'Sweater', 'Jacket'].contains(type);
  }

  /// Check if clothing type is a bottom
  static bool _isBottom(String type) {
    return ['Pants', 'Jeans', 'Shorts', 'Skirt'].contains(type);
  }

  /// Check if clothing type is an accessory
  static bool _isAccessory(String type) {
    return ['Jacket'].contains(type); // Can be extended
  }

  /// Check if colors are compatible
  static bool _areColorsCompatible(String color1, String color2) {
    final c1 = color1.toLowerCase();
    final c2 = color2.toLowerCase();

    // Neutral colors go with everything
    if (_isNeutral(c1) || _isNeutral(c2)) return true;

    // Same color
    if (c1 == c2) return true;

    // Complementary colors
    final complementary = {
      'red': ['green', 'blue'],
      'blue': ['orange', 'red'],
      'yellow': ['purple', 'blue'],
      'green': ['red', 'pink'],
    };

    for (final entry in complementary.entries) {
      if (c1.contains(entry.key) && entry.value.any((c) => c2.contains(c))) {
        return true;
      }
      if (c2.contains(entry.key) && entry.value.any((c) => c1.contains(c))) {
        return true;
      }
    }

    return false;
  }

  /// Check if color is neutral
  static bool _isNeutral(String color) {
    final neutral = ['black', 'white', 'grey', 'gray', 'beige', 'brown', 'navy'];
    return neutral.any((n) => color.contains(n));
  }

  /// Get color match score
  static double _getColorMatchScore(String color1, String color2) {
    if (_areColorsCompatible(color1, color2)) {
      return 1.0;
    }
    return 0.5;
  }

  /// Check if accessory is compatible with outfit
  static bool _isAccessoryCompatible(Cloth accessory, Cloth top, Cloth bottom) {
    // Simple compatibility check
    return _areColorsCompatible(accessory.color, top.color) ||
           _areColorsCompatible(accessory.color, bottom.color);
  }

  /// Get weather match score
  static double _getWeatherMatchScore(Cloth top, Cloth bottom, String? weather) {
    if (weather == null) return 0.5;

    // Simple weather matching (can be enhanced)
    final isWarm = weather.toLowerCase().contains('sunny') ||
                    weather.toLowerCase().contains('warm');
    final isCold = weather.toLowerCase().contains('cold') ||
                   weather.toLowerCase().contains('snow');

    if (isWarm && (top.type == 'T-Shirt' || bottom.type == 'Shorts')) {
      return 1.0;
    }
    if (isCold && (top.type == 'Sweater' || top.type == 'Jacket')) {
      return 1.0;
    }

    return 0.5;
  }

  /// Get current weather (simplified - can integrate with weather API)
  static Future<String?> _getCurrentWeather() async {
    // Placeholder - can integrate with OpenWeatherMap API
    // For now, return null to skip weather-based matching
    return null;
    
    /* Example integration:
    if (_weatherApiKey == null) return null;
    
    try {
      final response = await http.get(
        Uri.parse('https://api.openweathermap.org/data/2.5/weather?q=London&appid=$_weatherApiKey'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final temp = data['main']['temp'] - 273.15; // Convert to Celsius
        final condition = data['weather'][0]['main'];
        return '$condition, ${temp.toStringAsFixed(0)}°C';
      }
    } catch (e) {
      // Fail silently
    }
    
    return null;
    */
  }
}

