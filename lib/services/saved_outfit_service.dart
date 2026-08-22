import '../config/api_config.dart';
import '../models/saved_outfit.dart';
import 'laravel_api_client.dart';

class SavedOutfitService {
  static List<dynamic> _listFromData(dynamic data) {
    if (data is List) return data;
    if (data is Map && data['data'] is List) return data['data'] as List;
    return const [];
  }

  static Future<List<SavedOutfit>> getSavedOutfits({int perPage = 50}) async {
    final uri = Uri.parse(ApiConfig.savedOutfits).replace(
      queryParameters: {'per_page': '$perPage'},
    );
    final body = await LaravelApiClient.getJson(uri.toString());
    final data = LaravelApiClient.extractData(body);
    return _listFromData(data)
        .whereType<Map>()
        .map((e) => SavedOutfit.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<SavedOutfit> create({
    required String name,
    required Map<String, String?> slots,
  }) async {
    final body = await LaravelApiClient.postJson(ApiConfig.savedOutfits, {
      'name': name,
      'slots': slots,
    });
    final data = LaravelApiClient.extractData(body);
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid saved outfit response');
    }
    return SavedOutfit.fromJson(data);
  }

  static Future<SavedOutfit> update({
    required String outfitId,
    String? name,
    Map<String, String?>? slots,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (slots != null) payload['slots'] = slots;

    final body = await LaravelApiClient.putJson(
      ApiConfig.savedOutfit(outfitId),
      payload,
    );
    final data = LaravelApiClient.extractData(body);
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid saved outfit response');
    }
    return SavedOutfit.fromJson(data);
  }

  static Future<void> delete(String outfitId) async {
    await LaravelApiClient.deleteJson(ApiConfig.savedOutfit(outfitId));
  }
}
