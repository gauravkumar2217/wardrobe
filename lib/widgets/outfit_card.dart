import 'package:flutter/material.dart';
import '../models/outfit.dart';
import '../models/cloth.dart';

class OutfitCard extends StatelessWidget {
  final Outfit outfit;
  final List<Cloth> clothes;
  final VoidCallback? onTap;
  final Function(int)? onRate;

  const OutfitCard({
    super.key,
    required this.outfit,
    required this.clothes,
    this.onTap,
    this.onRate,
  });

  @override
  Widget build(BuildContext context) {
    final outfitClothes = clothes.where((cloth) {
      return outfit.clothIds.contains(cloth.id);
    }).toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with confidence
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Outfit Suggestion',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getConfidenceColor(outfit.confidence).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${(outfit.confidence * 100).toStringAsFixed(0)}% match',
                      style: TextStyle(
                        fontSize: 10,
                        color: _getConfidenceColor(outfit.confidence),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Clothes grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: outfitClothes.length > 2 ? 3 : outfitClothes.length,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.75,
                ),
                itemCount: outfitClothes.length,
                itemBuilder: (context, index) {
                  final cloth = outfitClothes[index];
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.grey[300]!,
                        width: 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: cloth.imageUrl.isNotEmpty
                          ? Image.network(
                              cloth.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[200],
                                  child: const Icon(
                                    Icons.checkroom,
                                    size: 24,
                                    color: Colors.grey,
                                  ),
                                );
                              },
                            )
                          : Container(
                              color: Colors.grey[200],
                              child: const Icon(
                                Icons.checkroom,
                                size: 24,
                                color: Colors.grey,
                              ),
                            ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 12),

              // Metadata
              if (outfit.occasion != null || outfit.weather != null) ...[
                Wrap(
                  spacing: 8,
                  children: [
                    if (outfit.occasion != null)
                      Chip(
                        label: Text(
                          outfit.occasion!,
                          style: const TextStyle(fontSize: 10),
                        ),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    if (outfit.weather != null)
                      Chip(
                        label: Text(
                          outfit.weather!,
                          style: const TextStyle(fontSize: 10),
                        ),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // Rating
              if (onRate != null)
                Row(
                  children: [
                    const Text(
                      'Rate: ',
                      style: TextStyle(fontSize: 12),
                    ),
                    ...List.generate(5, (index) {
                      return IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          outfit.userRating != null && index < outfit.userRating!
                              ? Icons.star
                              : Icons.star_border,
                          size: 16,
                          color: Colors.amber,
                        ),
                        onPressed: () => onRate!(index + 1),
                      );
                    }),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green;
    if (confidence >= 0.6) return Colors.orange;
    return Colors.red;
  }
}

