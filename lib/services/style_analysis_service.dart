import '../models/cloth.dart';
import 'cloth_service.dart';
import 'wardrobe_service.dart';

class StyleProfile {
  final Map<String, int> typeDistribution;
  final Map<String, int> colorDistribution;
  final Map<String, int> occasionDistribution;
  final double consistencyScore;
  final List<String> wardrobeGaps;

  StyleProfile({
    required this.typeDistribution,
    required this.colorDistribution,
    required this.occasionDistribution,
    this.consistencyScore = 0.0,
    this.wardrobeGaps = const [],
  });
}

class StyleAnalysisService {
  /// Generate style profile for user
  static Future<StyleProfile> generateStyleProfile(String userId) async {
    final wardrobes = await WardrobeService.getUserWardrobes(userId);
    
    final typeCounts = <String, int>{};
    final colorCounts = <String, int>{};
    final occasionCounts = <String, int>{};
    int totalClothes = 0;

    for (final wardrobe in wardrobes) {
      final clothes = await ClothService.getClothes(userId, wardrobe.id);
      totalClothes += clothes.length;

      for (final cloth in clothes) {
        typeCounts[cloth.type] = (typeCounts[cloth.type] ?? 0) + 1;
        colorCounts[cloth.color] = (colorCounts[cloth.color] ?? 0) + 1;
        // Count all occasions for each cloth
        for (final occasion in cloth.occasions) {
          occasionCounts[occasion] = (occasionCounts[occasion] ?? 0) + 1;
        }
      }
    }

    // Calculate consistency score (diversity metric)
    final consistencyScore = _calculateConsistencyScore(
      typeCounts,
      colorCounts,
      totalClothes,
    );

    // Identify wardrobe gaps
    final gaps = _identifyWardrobeGaps(typeCounts, colorCounts, occasionCounts);

    return StyleProfile(
      typeDistribution: typeCounts,
      colorDistribution: colorCounts,
      occasionDistribution: occasionCounts,
      consistencyScore: consistencyScore,
      wardrobeGaps: gaps,
    );
  }

  /// Calculate style consistency score (0-1)
  static double _calculateConsistencyScore(
    Map<String, int> typeCounts,
    Map<String, int> colorCounts,
    int totalClothes,
  ) {
    if (totalClothes == 0) return 0.0;

    // Calculate diversity (higher diversity = lower consistency)
    final typeDiversity = typeCounts.length / Cloth.types.length;
    final colorDiversity = colorCounts.length / 10.0; // Assume ~10 common colors

    // Consistency is inverse of diversity
    final consistency = 1.0 - ((typeDiversity + colorDiversity) / 2.0);
    return consistency.clamp(0.0, 1.0);
  }

  /// Identify missing items in wardrobe
  static List<String> _identifyWardrobeGaps(
    Map<String, int> typeCounts,
    Map<String, int> colorCounts,
    Map<String, int> occasionCounts,
  ) {
    final gaps = <String>[];

    // Check for missing essential types
    final essentialTypes = ['Shirt', 'Pants', 'T-Shirt'];
    for (final type in essentialTypes) {
      if (!typeCounts.containsKey(type) || typeCounts[type] == 0) {
        gaps.add('Missing: $type');
      }
    }

    // Check for missing neutral colors
    final neutralColors = ['Black', 'White', 'Grey', 'Navy'];
    final hasNeutral = neutralColors.any((color) => 
      colorCounts.keys.any((c) => c.toLowerCase().contains(color.toLowerCase()))
    );
    if (!hasNeutral) {
      gaps.add('Missing neutral colors');
    }

    // Check for missing occasions
    final essentialOccasions = ['Casual', 'Formal'];
    for (final occasion in essentialOccasions) {
      if (!occasionCounts.containsKey(occasion) || occasionCounts[occasion] == 0) {
        gaps.add('Missing: $occasion clothes');
      }
    }

    return gaps;
  }
}

