import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/avatar.dart';

/// Widget for displaying 2D transparent PNG avatar
class Avatar2DDisplayWidget extends StatelessWidget {
  final Avatar? avatar;
  final double width;
  final double height;
  final BoxFit fit;
  final Color? backgroundColor;

  const Avatar2DDisplayWidget({
    super.key,
    this.avatar,
    this.width = 300,
    this.height = 600,
    this.fit = BoxFit.contain,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    if (avatar == null || !avatar!.isGenerated) {
      return _buildPlaceholder();
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: CachedNetworkImage(
        imageUrl: avatar!.avatarImageUrl!,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
        errorWidget: (context, url, error) => _buildPlaceholder(),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_outline,
            size: width * 0.3,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Avatar not ready',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Create your avatar first',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
