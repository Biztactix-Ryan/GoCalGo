import '../models/events_response.dart';

/// Abstract interface for local event data caching.
///
/// Implementations may use SQLite, shared preferences, or in-memory storage.
/// The [CachedEventsService] delegates persistence to this interface after
/// each successful API sync.
abstract class EventCache {
  /// Store [response] locally, replacing any previously cached data.
  Future<void> put(EventsResponse response);

  /// Retrieve the most recently cached response, or `null` if the cache
  /// is empty.
  Future<EventsResponse?> get();

  /// Remove all cached data.
  Future<void> clear();
}
