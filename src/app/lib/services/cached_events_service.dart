import '../models/event_dto.dart';
import '../models/events_response.dart';
import 'api_client.dart';
import 'event_cache.dart';
import 'events_service.dart';

/// Wraps [EventsService] with local caching via [EventCache].
///
/// After each successful API sync the response is persisted locally so that
/// the app can display data when offline.
class CachedEventsService {
  final EventsService _remote;
  final EventCache _cache;

  CachedEventsService({
    required EventsService remote,
    required EventCache cache,
  })  : _remote = remote,
        _cache = cache;

  /// Fetches events from the API and caches the response locally.
  ///
  /// On network failure, falls back to the cached response if available.
  /// Throws if both the API call fails and no cached data exists.
  Future<EventsResponse> getEvents() async {
    try {
      final response = await _remote.getEvents();
      await _cache.put(response);
      return response;
    } on Exception {
      final cached = await _cache.get();
      if (cached != null) {
        return EventsResponse(
          events: cached.events,
          lastUpdated: cached.lastUpdated,
          cacheHit: true,
        );
      }
      rethrow;
    }
  }

  /// Returns currently active events, caching the underlying response.
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

  /// Returns the cached response without hitting the network.
  Future<EventsResponse?> getCachedEvents() => _cache.get();

  void dispose() {
    _remote.dispose();
  }
}
