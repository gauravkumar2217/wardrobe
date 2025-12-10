import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:palette_generator/palette_generator.dart';
import 'tag_list_service.dart';

/// Service for AI-powered cloth detection
/// Uses ML Kit (FREE) for cloth type, Palette Generator (FREE) for colors
class AiDetectionService {
  static ImageLabeler? _imageLabeler;

  /// Initialize ML Kit Image Labeler
  static Future<void> initialize() async {
    try {
      final options = ImageLabelerOptions(
        confidenceThreshold: 0.5,
      );
      _imageLabeler = ImageLabeler(options: options);
      debugPrint('✅ ML Kit Image Labeler initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize ML Kit: $e');
    }
  }

  /// Detect cloth type from image using ML Kit
  static Future<String?> detectClothType(File imageFile) async {
    try {
      if (_imageLabeler == null) {
        await initialize();
      }

      final inputImage = InputImage.fromFile(imageFile);
      final labels = await _imageLabeler!.processImage(inputImage);

      if (labels.isEmpty) {
        return null;
      }

      // Get the most confident label
      final topLabel = labels.first;
      debugPrint('🏷️ ML Kit detected: ${topLabel.label} (${topLabel.confidence})');

      // Map ML Kit labels to our cloth types
      final detectedType = _mapLabelToClothType(topLabel.label);
      
      return detectedType;
    } catch (e) {
      debugPrint('❌ Error detecting cloth type: $e');
      return null;
    }
  }

  /// Map ML Kit labels to our cloth type list
  static String _mapLabelToClothType(String label) {
    final lowerLabel = label.toLowerCase();
    final tags = TagListService.getCachedTagLists();
    
    // Try to find exact match first
    for (final type in tags.clothTypes) {
      if (lowerLabel.contains(type.toLowerCase()) || 
          type.toLowerCase().contains(lowerLabel)) {
        return type;
      }
    }

    // Common mappings
    final mappings = {
      'shirt': 'Shirt',
      't-shirt': 'T-Shirt',
      'tshirt': 'T-Shirt',
      'dress': 'Dress',
      'jeans': 'Jeans',
      'pants': 'Pants',
      'trouser': 'Trouser',
      'skirt': 'Skirt',
      'shorts': 'Shorts',
      'jacket': 'Jacket',
      'coat': 'Coat',
      'sweater': 'Sweater',
      'blouse': 'Blouse',
      'top': 'Top',
      'jumpsuit': 'Jumpsuit',
      'suit': 'Suit',
      'blazer': 'Blazer',
      'kurta': 'Kurta',
      'saree': 'Saree',
      'lehenga': 'Lehenga',
      'anarkali': 'Anarkali',
      'sherwani': 'Sherwani',
      // Filter out non-clothing labels
      'fun': null, // Skip generic labels
      'person': null,
      'people': null,
      'human': null,
      'face': null,
      'smile': null,
    };

    for (final entry in mappings.entries) {
      if (lowerLabel.contains(entry.key)) {
        if (entry.value != null) {
          return entry.value!;
        } else {
          // Skip this label - it's not a clothing item
          return '';
        }
      }
    }

    // If not found and not filtered, capitalize and return the label
    // But only if it seems like a clothing-related term
    final clothingKeywords = ['wear', 'cloth', 'apparel', 'garment', 'outfit'];
    final seemsLikeClothing = clothingKeywords.any((keyword) => lowerLabel.contains(keyword));
    
    if (seemsLikeClothing || lowerLabel.length > 3) {
      return label.split(' ').map((word) => 
        word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1).toLowerCase()
      ).join(' ');
    }
    
    // Return empty string for non-clothing labels
    return '';
  }

  /// Detect colors from image using Palette Generator
  static Future<List<String>> detectColors(File imageFile) async {
    try {
      final paletteGenerator = await PaletteGenerator.fromImageProvider(
        FileImage(imageFile),
        maximumColorCount: 5,
      );

      final colors = <String>[];
      final existingColors = TagListService.getCachedTagLists().commonColors;

      // Process dominant color
      if (paletteGenerator.dominantColor != null) {
        final colorName = _colorToName(paletteGenerator.dominantColor!.color);
        if (!colors.contains(colorName)) {
          colors.add(colorName);
        }
      }

      // Process vibrant color
      if (paletteGenerator.vibrantColor != null) {
        final colorName = _colorToName(paletteGenerator.vibrantColor!.color);
        if (!colors.contains(colorName)) {
          colors.add(colorName);
        }
      }

      // Process muted color
      if (paletteGenerator.mutedColor != null) {
        final colorName = _colorToName(paletteGenerator.mutedColor!.color);
        if (!colors.contains(colorName)) {
          colors.add(colorName);
        }
      }

      // Process light vibrant color
      if (paletteGenerator.lightVibrantColor != null) {
        final colorName = _colorToName(paletteGenerator.lightVibrantColor!.color);
        if (!colors.contains(colorName)) {
          colors.add(colorName);
        }
      }

      // Process dark vibrant color
      if (paletteGenerator.darkVibrantColor != null) {
        final colorName = _colorToName(paletteGenerator.darkVibrantColor!.color);
        if (!colors.contains(colorName)) {
          colors.add(colorName);
        }
      }

      // Match detected colors with existing list or add new ones
      final matchedColors = <String>[];
      for (final detectedColor in colors) {
        // Try to find close match in existing colors
        String? matchedColor;
        for (final existingColor in existingColors) {
          if (_colorsMatch(detectedColor, existingColor)) {
            matchedColor = existingColor;
            break;
          }
        }
        
        if (matchedColor != null) {
          if (!matchedColors.contains(matchedColor)) {
            matchedColors.add(matchedColor);
          }
        } else {
          // New color not in list - add it
          if (!matchedColors.contains(detectedColor)) {
            matchedColors.add(detectedColor);
          }
        }
      }

      debugPrint('🎨 Detected colors: $matchedColors');
      return matchedColors;
    } catch (e) {
      debugPrint('❌ Error detecting colors: $e');
      return [];
    }
  }

  /// Convert Color to color name
  static String _colorToName(Color color) {
    final r = color.red;
    final g = color.green;
    final b = color.blue;

    // Simple color name mapping based on RGB values
    if (r > 200 && g < 100 && b < 100) return 'Red';
    if (r < 100 && g < 100 && b > 200) return 'Blue';
    if (r < 100 && g > 200 && b < 100) return 'Green';
    if (r < 50 && g < 50 && b < 50) return 'Black';
    if (r > 240 && g > 240 && b > 240) return 'White';
    if (r > 200 && g > 200 && b < 100) return 'Yellow';
    if (r > 200 && g < 150 && b > 150) return 'Pink';
    if (r > 200 && g < 150 && b < 100) return 'Orange';
    if (r < 150 && g < 100 && b > 200) return 'Purple';
    if (r > 150 && g < 100 && b < 50) return 'Brown';
    if (r > 100 && r < 150 && g > 100 && g < 150 && b > 100 && b < 150) return 'Grey';
    if (r < 50 && g < 50 && b > 150 && b < 200) return 'Navy';
    if (r > 100 && r < 150 && g < 50 && b < 50) return 'Maroon';
    if (r > 200 && g > 200 && b > 150 && b < 200) return 'Beige';
    if (r > 240 && g > 240 && b > 200 && b < 240) return 'Cream';
    if (r > 200 && g > 150 && b < 50) return 'Gold';
    if (r > 180 && g > 180 && b > 180) return 'Silver';
    if (r < 50 && g > 150 && b > 150) return 'Turquoise';
    if (r > 200 && g < 100 && b < 100) return 'Coral';
    if (r > 150 && g > 100 && b > 200) return 'Lavender';
    if (r < 50 && g > 100 && b > 100) return 'Teal';
    if (r > 100 && r < 150 && g < 50 && b < 50) return 'Burgundy';
    if (r > 200 && g < 50 && b > 200) return 'Magenta';
    if (r < 50 && g > 200 && b > 200) return 'Cyan';
    if (r > 100 && r < 150 && g > 150 && b < 100) return 'Olive';
    if (r > 150 && r < 200 && g > 150 && g < 200 && b < 100) return 'Khaki';
    if (r < 100 && g < 50 && b > 150) return 'Indigo';
    if (r > 100 && r < 150 && g < 100 && b > 150) return 'Violet';
    if (r > 250 && g > 200 && b < 150) return 'Peach';
    if (r < 100 && g > 200 && b > 150) return 'Mint';

    // If no match, create a descriptive name
    final brightness = (r + g + b) / 3;
    if (brightness < 85) return 'Dark';
    if (brightness > 170) return 'Light';
    
    // Return RGB-based name
    return 'RGB($r,$g,$b)';
  }

  /// Check if two color names match (fuzzy matching)
  static bool _colorsMatch(String color1, String color2) {
    final c1 = color1.toLowerCase().trim();
    final c2 = color2.toLowerCase().trim();
    
    if (c1 == c2) return true;
    if (c1.contains(c2) || c2.contains(c1)) return true;
    
    // Check for common variations
    final variations = {
      'grey': ['gray', 'grey'],
      'navy': ['navy blue', 'navy'],
      'maroon': ['maroon', 'burgundy'],
    };
    
    for (final entry in variations.entries) {
      if ((c1.contains(entry.key) && entry.value.any((v) => c2.contains(v))) ||
          (c2.contains(entry.key) && entry.value.any((v) => c1.contains(v)))) {
        return true;
      }
    }
    
    return false;
  }

  /// Detect season from image (optional - using simple heuristics)
  /// Since TFLite requires a trained model, we'll use color-based heuristics
  static Future<String?> detectSeason(File imageFile) async {
    try {
      // Use color palette to infer season
      final paletteGenerator = await PaletteGenerator.fromImageProvider(
        FileImage(imageFile),
        maximumColorCount: 3,
      );

      // Analyze colors to determine season
      final colors = <Color>[];
      if (paletteGenerator.dominantColor != null) {
        colors.add(paletteGenerator.dominantColor!.color);
      }
      if (paletteGenerator.vibrantColor != null) {
        colors.add(paletteGenerator.vibrantColor!.color);
      }
      if (paletteGenerator.mutedColor != null) {
        colors.add(paletteGenerator.mutedColor!.color);
      }
      if (paletteGenerator.lightVibrantColor != null) {
        colors.add(paletteGenerator.lightVibrantColor!.color);
      }
      if (paletteGenerator.darkVibrantColor != null) {
        colors.add(paletteGenerator.darkVibrantColor!.color);
      }

      // Calculate average brightness and saturation
      double totalBrightness = 0;
      double totalSaturation = 0;
      
      for (final color in colors) {
        final hsl = HSLColor.fromColor(color);
        totalBrightness += hsl.lightness;
        totalSaturation += hsl.saturation;
      }
      
      final avgBrightness = totalBrightness / colors.length;
      final avgSaturation = totalSaturation / colors.length;

      // Determine season based on color characteristics
      final tags = TagListService.getCachedTagLists();
      
      if (avgBrightness > 0.7 && avgSaturation > 0.5) {
        // Bright and saturated - likely Summer
        return tags.seasons.contains('Summer') ? 'Summer' : tags.seasons.first;
      } else if (avgBrightness < 0.4) {
        // Dark colors - likely Winter
        return tags.seasons.contains('Winter') ? 'Winter' : tags.seasons.first;
      } else if (avgSaturation < 0.3) {
        // Muted colors - likely Fall
        return tags.seasons.contains('Fall') ? 'Fall' : tags.seasons.first;
      } else {
        // Balanced - likely Spring or All Season
        if (tags.seasons.contains('Spring')) {
          return 'Spring';
        } else if (tags.seasons.contains('All Season')) {
          return 'All Season';
        } else {
          return tags.seasons.first;
        }
      }
    } catch (e) {
      debugPrint('❌ Error detecting season: $e');
      return null;
    }
  }

  /// Dispose resources
  static Future<void> dispose() async {
    await _imageLabeler?.close();
    _imageLabeler = null;
  }
}

