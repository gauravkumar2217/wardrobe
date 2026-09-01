import '../config/api_config.dart';
import '../models/cloth.dart';

/// Resolves wardrobe image paths to absolute URLs for CachedNetworkImage.
class ClothImageUrl {
  ClothImageUrl._();

  static String get _assetBase {
    final api = ApiConfig.baseUrl.trim();
    if (api.endsWith('/api')) {
      return api.substring(0, api.length - 4);
    }
    return api;
  }

  static String resolve(String? raw) {
    if (raw == null) return '';
    final url = raw.trim();
    if (url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('//')) return 'https:$url';
    if (url.startsWith('/')) return '$_assetBase$url';
    if (url.startsWith('upload-users/')) return '$_assetBase/$url';
    return '$_assetBase/upload-users/$url';
  }

  static String forCloth(Cloth cloth) {
    final processed = cloth.processedImageUrl?.trim();
    if (cloth.hasProcessedImage && processed != null && processed.isNotEmpty) {
      return resolve(processed);
    }
    return resolve(cloth.imageUrl);
  }
}
