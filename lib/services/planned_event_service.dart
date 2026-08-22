import '../config/api_config.dart';
import '../models/planned_event.dart';
import 'laravel_api_client.dart';

class PlannedEventService {
  static List<dynamic> _listFromData(dynamic data) {
    if (data is List) return data;
    if (data is Map && data['data'] is List) return data['data'] as List;
    return const [];
  }

  static Future<List<PlannedEvent>> getEvents({
    String scope = 'upcoming',
    int perPage = 30,
  }) async {
    final uri = Uri.parse(ApiConfig.events).replace(
      queryParameters: {'scope': scope, 'per_page': '$perPage'},
    );
    final body = await LaravelApiClient.getJson(uri.toString());
    final data = LaravelApiClient.extractData(body);
    return _listFromData(data)
        .whereType<Map>()
        .map((e) => PlannedEvent.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<PlannedEvent> getEvent(String eventId) async {
    final body = await LaravelApiClient.getJson(ApiConfig.event(eventId));
    final data = LaravelApiClient.extractData(body);
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid event response');
    }
    return PlannedEvent.fromJson(data);
  }

  static Future<PlannedEvent> create({
    required String title,
    required String occasionTag,
    required DateTime eventAt,
    String? location,
    String? notes,
    int reminderHoursBefore = 24,
  }) async {
    final body = await LaravelApiClient.postJson(ApiConfig.events, {
      'title': title,
      'occasion_tag': occasionTag,
      'event_at': eventAt.toUtc().toIso8601String(),
      if (location != null && location.isNotEmpty) 'location': location,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'reminder_hours_before': reminderHoursBefore,
    });
    final data = LaravelApiClient.extractData(body);
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid event response');
    }
    return PlannedEvent.fromJson(data);
  }

  static Future<PlannedEvent> update({
    required String eventId,
    String? title,
    String? occasionTag,
    DateTime? eventAt,
    String? location,
    String? notes,
    int? reminderHoursBefore,
  }) async {
    final payload = <String, dynamic>{};
    if (title != null) payload['title'] = title;
    if (occasionTag != null) payload['occasion_tag'] = occasionTag;
    if (eventAt != null) payload['event_at'] = eventAt.toUtc().toIso8601String();
    if (location != null) payload['location'] = location;
    if (notes != null) payload['notes'] = notes;
    if (reminderHoursBefore != null) {
      payload['reminder_hours_before'] = reminderHoursBefore;
    }

    final body = await LaravelApiClient.putJson(
      ApiConfig.event(eventId),
      payload,
    );
    final data = LaravelApiClient.extractData(body);
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid event response');
    }
    return PlannedEvent.fromJson(data);
  }

  static Future<void> delete(String eventId) async {
    await LaravelApiClient.deleteJson(ApiConfig.event(eventId));
  }

  static Future<List<EventClothSuggestion>> getSuggestions(String eventId) async {
    final body =
        await LaravelApiClient.getJson(ApiConfig.eventSuggestions(eventId));
    final data = LaravelApiClient.extractData(body);
    return _listFromData(data)
        .whereType<Map>()
        .map((e) => EventClothSuggestion.fromJson(
            Map<String, dynamic>.from(e)))
        .toList();
  }
}
