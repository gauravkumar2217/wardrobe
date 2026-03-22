import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/cloth.dart';

/// Widget for displaying rendered try-on outfit
class TryOnRendererWidget extends StatelessWidget {
  final String? renderedImageUrl;
  final List<Cloth>? clothingItems;
  final String viewAngle;
  final double width;
  final double height;
  final bool showComparison;
  final VoidCallback? onSave;
  final VoidCallback? onShare;

  const TryOnRendererWidget({
    super.key,
    this.renderedImageUrl,
    this.clothingItems,
    this.viewAngle = 'front',
    this.width = 300,
    this.height = 600,
    this.showComparison = false,
    this.onSave,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          // Rendered image
          if (renderedImageUrl != null)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: renderedImageUrl!,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.error, size: 64, color: Colors.red),
                    ),
                  ),
                ),
              ),
            )
          else
            // Placeholder
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.checkroom, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    'No outfit rendered',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

          // Action buttons overlay
          if (renderedImageUrl != null)
            Positioned(
              bottom: 16,
              right: 16,
              child: Row(
                children: [
                  if (onSave != null)
                    FloatingActionButton.small(
                      heroTag: 'save',
                      onPressed: onSave,
                      child: const Icon(Icons.save),
                    ),
                  const SizedBox(width: 8),
                  if (onShare != null)
                    FloatingActionButton.small(
                      heroTag: 'share',
                      onPressed: onShare,
                      child: const Icon(Icons.share),
                    ),
                ],
              ),
            ),

          // Clothing items list overlay (if provided)
          if (clothingItems != null && clothingItems!.isNotEmpty)
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Items:',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...clothingItems!.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            '• ${item.clothType}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        )),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Comparison view widget for side-by-side outfit comparison
class OutfitComparisonWidget extends StatelessWidget {
  final String? outfit1Url;
  final String? outfit2Url;
  final String outfit1Label;
  final String outfit2Label;

  const OutfitComparisonWidget({
    super.key,
    this.outfit1Url,
    this.outfit2Url,
    required this.outfit1Label,
    required this.outfit2Label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Outfit 1
        Expanded(
          child: Column(
            children: [
              Text(
                outfit1Label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TryOnRendererWidget(
                  renderedImageUrl: outfit1Url,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Outfit 2
        Expanded(
          child: Column(
            children: [
              Text(
                outfit2Label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TryOnRendererWidget(
                  renderedImageUrl: outfit2Url,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
