import 'package:flutter/material.dart';
import '../models/suggestion.dart';
import '../models/cloth.dart';

class SuggestionCard extends StatelessWidget {
  final Suggestion suggestion;
  final List<Cloth> clothes;
  final VoidCallback? onTap;
  final VoidCallback? onMarkAsWorn;

  const SuggestionCard({
    super.key,
    required this.suggestion,
    required this.clothes,
    this.onTap,
    this.onMarkAsWorn,
  });

  @override
  Widget build(BuildContext context) {
    // Get the suggested clothes
    final suggestedClothes = clothes.where((cloth) {
      return suggestion.clothIds.contains(cloth.id);
    }).toList();

    if (suggestedClothes.isEmpty) {
      return const SizedBox.shrink();
    }

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
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.lightbulb_outline,
                      color: Color(0xFF7C3AED),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Today\'s Suggestion',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (suggestion.reason != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            suggestion.reason!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!suggestion.viewed)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF7C3AED),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Clothes Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.75,
                ),
                itemCount: suggestedClothes.length,
                itemBuilder: (context, index) {
                  final cloth = suggestedClothes[index];
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

              // Action Button
              if (onMarkAsWorn != null)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onMarkAsWorn,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Mark All as Worn'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF7C3AED),
                      side: const BorderSide(color: Color(0xFF7C3AED)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

