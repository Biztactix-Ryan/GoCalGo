import '../models/events_response.dart';
import 'event_cache.dart';

/// Wraps an [EventCache] with time-based expiration.
///
/// After [ttl] has elapsed since the last [put], [get] returns `null` —
/// forcing [CachedEventsService] to fetch fresh data from the API.
/// The stale entry is automatically cleared on expiration.
class TtlEventCache implements EventCache {
  final EventCache _inner;
  final Duration ttl;
  final DateTime Function() _clock;
  DateTime? _storedAt;

  TtlEventCache({
    required EventCache inner,
    required this.ttl,
    DateTime Function()? clock,
  })  : _inner = inner,
        _clock = clock ?? DateTime.now;

  /// Store [response] and record the insertion time.
  @override
  Future<void> put(EventsResponse response) async {
    _storedAt = _clock();
    await _inner.put(response);
  }

  /// Returns the cached response only if within the TTL window.
  /// Returns `null` (and clears the stale entry) if expired.
  @override
  Future<EventsResponse?> get() async {
    if (_storedAt == null) return null;
    if (_clock().difference(_storedAt!) >= ttl) {
      await clear();
      return null;
    }
    return _inner.get();
  }

  /// Remove all cached data and reset the insertion timestamp.
  @override
  Future<void> clear() async {
    _storedAt = null;
    await _inner.clear();
  }

  /// Whether the cache entry has expired (exposed for testing/diagnostics).
  bool get isExpired {
    if (_storedAt == null) return true;
    return _clock().difference(_storedAt!) >= ttl;
  }
}
