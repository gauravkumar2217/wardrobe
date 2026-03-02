import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/body_profile.dart';
import '../models/cloth.dart';
import '../services/virtual_tryon_service.dart';

/// Widget to display user body with clothes overlaid
/// Uses RepaintBoundary for iOS GPU optimization
class BodyWithClothesWidget extends StatelessWidget {
  final BodyProfile? bodyProfile;
  final Cloth? shirt;
  final Cloth? pants;
  final Cloth? shoes;
  final Cloth? accessory;
  final double width;
  final double height;

  const BodyWithClothesWidget({
    super.key,
    this.bodyProfile,
    this.shirt,
    this.pants,
    this.shoes,
    this.accessory,
    this.width = 300,
    this.height = 600,
  });

  @override
  Widget build(BuildContext context) {
    // Use RepaintBoundary for GPU optimization (iOS Metal backend)
    return RepaintBoundary(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            // Body image (base layer)
            if (bodyProfile?.bodyImageUrl != null)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: bodyProfile!.bodyImageUrl!,
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
                        child: Icon(Icons.person, size: 64, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              )
            else
              // Placeholder if no body profile
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'No body profile',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),

            // Clothes overlay layers
            if (bodyProfile != null) ...[
              // Shirt layer
              if (shirt != null)
                _buildClothLayer(
                  cloth: shirt!,
                  bodyProfile: bodyProfile!,
                  itemType: 'shirt',
                ),

              // Pants layer
              if (pants != null)
                _buildClothLayer(
                  cloth: pants!,
                  bodyProfile: bodyProfile!,
                  itemType: 'pants',
                ),

              // Shoes layer
              if (shoes != null)
                _buildClothLayer(
                  cloth: shoes!,
                  bodyProfile: bodyProfile!,
                  itemType: 'shoes',
                ),

              // Accessory layer
              if (accessory != null)
                _buildClothLayer(
                  cloth: accessory!,
                  bodyProfile: bodyProfile!,
                  itemType: 'accessory',
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildClothLayer({
    required Cloth cloth,
    required BodyProfile bodyProfile,
    required String itemType,
  }) {
    // Calculate position and scale
    final position = VirtualTryOnService.calculateItemPosition(
      cloth: cloth,
      bodyProfile: bodyProfile,
      itemType: itemType,
    );

    final imageUrl = cloth.processedImageUrl ?? cloth.imageUrl;

    return Positioned(
      left: position['x']! * width,
      top: position['y']! * height,
      child: Transform.scale(
        scale: position['scale']!,
        child: Transform.rotate(
          angle: position['rotation']!,
          child: Opacity(
            opacity: 0.95, // Slight transparency for blending
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              width: width * 0.8,
              height: height * 0.3,
              fit: BoxFit.contain,
              placeholder: (context, url) => Container(
                width: width * 0.8,
                height: height * 0.3,
                color: Colors.transparent,
              ),
              errorWidget: (context, url, error) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}
