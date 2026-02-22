import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/banner.dart' as models;

/// Widget to display a banner advertisement
class BannerWidget extends StatelessWidget {
  final models.Banner banner;
  final double? width;
  final double? height;
  final BoxFit fit;

  const BannerWidget({
    super.key,
    required this.banner,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    // Determine dimensions based on banner type
    double bannerWidth = width ?? MediaQuery.of(context).size.width;
    double bannerHeight = height ?? _getDefaultHeight(banner.type);

    return Container(
      width: bannerWidth,
      height: bannerHeight,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: banner.imageUrl,
          fit: fit,
          placeholder: (context, url) => Container(
            color: Colors.grey[200],
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: Colors.grey[200],
            child: const Icon(Icons.error_outline, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  double _getDefaultHeight(String type) {
    // Calculate height based on banner type and screen width
    // For 320x100 banners, maintain aspect ratio
    if (type == '320x100') {
      return 100;
    }
    // For full screen banners, use screen height
    if (type == '1080x1920') {
      return 1920; // Will be constrained by parent
    }
    return 100; // Default height
  }
}
