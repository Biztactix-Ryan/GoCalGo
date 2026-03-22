import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/event_dto.dart';
import '../services/cached_events_service.dart';
import '../services/events_service.dart';
import '../services/flag_store.dart';
import '../services/sqlite_event_cache.dart';
import '../services/sqlite_flag_store.dart';
import '../services/ttl_event_cache.dart';

/// Current events data with offline/stale metadata.
class EventsState {
  final List<EventDto> events;
  final bool isStale;
  final DateTime? lastUpdated;

  /// Age threshold after which data is considered stale (1 hour).
  static const staleThreshold = Duration(hours: 1);

  const EventsState({
    required this.events,
    this.isStale = false,
    this.lastUpdated,
  });

  /// Whether the data is older than [staleThreshold].
  bool isStaleByAge({DateTime? now}) {
    if (lastUpdated == null) return false;
    final timestamp = now ?? DateTime.now();
    return timestamp.difference(lastUpdated!) >= staleThreshold;
  }

  /// Whether the stale-data banner should be shown — true if data came from
  /// cache OR is older than the staleness threshold.
  bool shouldShowStaleBanner({DateTime? now}) => isStale || isStaleByAge(now: now);
}

/// Singleton flag store for persisting user-flagged events.
final flagStoreProvider = Provider<FlagStore>((ref) {
  final store = SqliteFlagStore();
  ref.onDispose(store.close);
  return store;
});

/// Singleton event cache with 6-hour TTL.
final eventCacheProvider = Provider<TtlEventCache>((ref) {
  return TtlEventCache(
    inner: SqliteEventCache(),
    ttl: const Duration(hours: 6),
  );
});

/// Singleton cached events service.
final cachedEventsServiceProvider = Provider<CachedEventsService>((ref) {
  final cache = ref.watch(eventCacheProvider);
  final remote = EventsService();
  ref.onDispose(remote.dispose);
  return CachedEventsService(remote: remote, cache: cache);
});

/// Offline-first events provider.
///
/// 1. Returns cached data immediately (marked stale).
/// 2. Fetches fresh data from the API in the background.
/// 3. Re-syncs automatically when network connectivity is restored.
final activeEventsProvider =
    AsyncNotifierProvider.autoDispose<EventsNotifier, EventsState>(
  EventsNotifier.new,
);

class EventsNotifier extends AutoDisposeAsyncNotifier<EventsState> {
  late CachedEventsService _service;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  Future<EventsState> build() async {
    _service = ref.read(cachedEventsServiceProvider);

    ref.onDispose(() {
      _connectivitySub?.cancel();
    });

    _startConnectivityMonitoring();

    // Load from local cache first.
    final cached = await _service.getCachedEvents();
    if (cached != null) {
      // Fire-and-forget background API refresh.
      unawaited(_refreshFromApi());
      return EventsState(
        events: _filterActive(cached.events),
        isStale: true,
        lastUpdated: cached.lastUpdated,
      );
    }

    // No cache — must fetch from API (blocking).
    final response = await _service.getEvents();
    return EventsState(
      events: _filterActive(response.events),
      isStale: response.cacheHit,
      lastUpdated: response.lastUpdated,
    );
  }

  /// Force refresh from the API. Used by pull-to-refresh.
  Future<void> refresh() async {
    try {
      final response = await _service.getEvents();
      state = AsyncData(EventsState(
        events: _filterActive(response.events),
        isStale: response.cacheHit,
        lastUpdated: response.lastUpdated,
      ));
    } catch (e, st) {
      if (!state.hasValue) {
        state = AsyncError(e, st);
      }
    }
  }

  Future<void> _refreshFromApi() async {
    try {
      final response = await _service.getEvents();
      state = AsyncData(EventsState(
        events: _filterActive(response.events),
        isStale: response.cacheHit,
        lastUpdated: response.lastUpdated,
      ));
    } catch (_) {
      // Keep showing cached data.
    }
  }

  void _startConnectivityMonitoring() {
    bool wasOffline = false;
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (isOnline && wasOffline) {
        _refreshFromApi();
      }
      wasOffline = !isOnline;
    });
  }
}

/// Reactive connectivity state — true when device has network access.
///
/// Listens to [Connectivity] changes and emits the current online/offline
/// status. Used by [OfflineBanner] to show a dedicated offline indicator.
final connectivityProvider =
    StreamNotifierProvider.autoDispose<ConnectivityNotifier, bool>(
  ConnectivityNotifier.new,
);

class ConnectivityNotifier extends AutoDisposeStreamNotifier<bool> {
  @override
  Stream<bool> build() {
    return Connectivity().onConnectivityChanged.map(
          (results) => results.any((r) => r != ConnectivityResult.none),
        );
  }
}

/// Reactive set of flagged event IDs.
///
/// Loads from [FlagStore] on first access. UI calls [toggle] to flag/unflag;
/// the provider keeps in-memory state in sync with the persistent store.
final flaggedIdsProvider =
    AsyncNotifierProvider.autoDispose<FlaggedIdsNotifier, Set<String>>(
  FlaggedIdsNotifier.new,
);

class FlaggedIdsNotifier extends AutoDisposeAsyncNotifier<Set<String>> {
  late FlagStore _store;

  @override
  Future<Set<String>> build() async {
    _store = ref.read(flagStoreProvider);
    return _store.flaggedIds();
  }

  Future<void> toggle(String eventId) async {
    final current = state.valueOrNull ?? {};
    if (current.contains(eventId)) {
      await _store.unflag(eventId);
      state = AsyncData({...current}..remove(eventId));
    } else {
      await _store.flag(eventId);
      state = AsyncData({...current, eventId});
    }
  }
}

/// Offline-first provider for upcoming events (next 7 days).
///
/// Mirrors [activeEventsProvider] but filters for future events instead of
/// currently active ones, and groups them by day.
final upcomingEventsProvider =
    AsyncNotifierProvider.autoDispose<UpcomingEventsNotifier, EventsState>(
  UpcomingEventsNotifier.new,
);

class UpcomingEventsNotifier extends AutoDisposeAsyncNotifier<EventsState> {
  late CachedEventsService _service;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  Future<EventsState> build() async {
    _service = ref.read(cachedEventsServiceProvider);

    ref.onDispose(() {
      _connectivitySub?.cancel();
    });

    _startConnectivityMonitoring();

    final cached = await _service.getCachedEvents();
    if (cached != null) {
      unawaited(_refreshFromApi());
      return EventsState(
        events: _filterUpcoming(cached.events),
        isStale: true,
        lastUpdated: cached.lastUpdated,
      );
    }

    final response = await _service.getEvents();
    return EventsState(
      events: _filterUpcoming(response.events),
      isStale: response.cacheHit,
      lastUpdated: response.lastUpdated,
    );
  }

  Future<void> refresh() async {
    try {
      final response = await _service.getEvents();
      state = AsyncData(EventsState(
        events: _filterUpcoming(response.events),
        isStale: response.cacheHit,
        lastUpdated: response.lastUpdated,
      ));
    } catch (e, st) {
      if (!state.hasValue) {
        state = AsyncError(e, st);
      }
    }
  }

  Future<void> _refreshFromApi() async {
    try {
      final response = await _service.getEvents();
      state = AsyncData(EventsState(
        events: _filterUpcoming(response.events),
        isStale: response.cacheHit,
        lastUpdated: response.lastUpdated,
      ));
    } catch (_) {
      // Keep showing cached data.
    }
  }

  void _startConnectivityMonitoring() {
    bool wasOffline = false;
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (isOnline && wasOffline) {
        _refreshFromApi();
      }
      wasOffline = !isOnline;
    });
  }
}

List<EventDto> _filterUpcoming(List<EventDto> events, {DateTime? now}) {
  final timestamp = now ?? DateTime.now();
  final cutoff = timestamp.add(const Duration(days: 7));
  return events.where((e) {
    if (e.start == null) return true;
    if (!e.start!.isAfter(timestamp)) return false;
    if (e.start!.isAfter(cutoff)) return false;
    return true;
  }).toList();
}

List<EventDto> _filterActive(List<EventDto> events) {
  final now = DateTime.now();
  return events.where((e) {
    if (e.start == null) return false;
    final started = !e.start!.isAfter(now);
    final notEnded = e.end == null || e.end!.isAfter(now);
    return started && notEnded;
  }).toList();
}
