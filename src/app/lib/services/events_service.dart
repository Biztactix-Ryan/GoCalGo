import '../models/event_dto.dart';
import '../models/events_response.dart';
import 'api_client.dart';

/// Service for fetching event data from the backend.
class EventsService {
  final ApiClient _apiClient;

  EventsService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  /// Fetches all current and upcoming events.
  Future<EventsResponse> getEvents() async {
    final json = await _apiClient.get('/events') as Map<String, dynamic>;
    return EventsResponse.fromJson(json);
  }

  /// Returns events that are currently active (started and not yet ended).
  Future<List<EventDto>> getActiveEvents({DateTime? now}) async {
    final response = await getEvents();
    final timestamp = now ?? DateTime.now();
    return response.events.where((e) {
      if (e.start == null) return false;
      final started = !e.start!.isAfter(timestamp);
      final notEnded = e.end == null || e.end!.isAfter(timestamp);
      return started && notEnded;
    }).toList();
  }

  /// Returns events that have not yet started.
  ///
  /// When [days] is provided, only events starting within that many days
  /// from [now] are included (defaults to all future events).
  Future<List<EventDto>> getUpcomingEvents({DateTime? now, int? days}) async {
    final response = await getEvents();
    final timestamp = now ?? DateTime.now();
    final cutoff = days != null ? timestamp.add(Duration(days: days)) : null;
    return response.events.where((e) {
      if (e.start == null) return true;
      if (!e.start!.isAfter(timestamp)) return false;
      if (cutoff != null && e.start!.isAfter(cutoff)) return false;
      return true;
    }).toList();
  }

  void dispose() {
    _apiClient.dispose();
  }
}
