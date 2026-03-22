import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gocalgo/models/events_response.dart';
import 'package:gocalgo/services/api_client.dart';
import 'package:gocalgo/services/cached_events_service.dart';
import 'package:gocalgo/services/event_cache.dart';
import 'package:gocalgo/services/events_service.dart';

/// Verifies acceptance criterion for story US-GCG-26:
/// "Manual refresh option available"
///
/// Tests that [CachedEventsService] supports manual refresh by fetching fresh
/// data from the API on demand, updating the cache, and clearing stale flags —
/// the behaviour required for pull-to-refresh to work as a manual refresh
/// mechanism.
void main() {
  group('US-GCG-26 — Manual refresh option available', () {
    Map<String, dynamic> _buildResponse({
      required List<Map<String, dynamic>> events,
      required String lastUpdated,
      bool cacheHit = false,
    }) {
      return {
        'events': events,
        'lastUpdated': lastUpdated,
        'cacheHit': cacheHit,
      };
    }

    Map<String, dynamic> _event({
      required String id,
      required String name,
      String? start,
      String? end,
    }) {
      return {
        'id': id,
        'name': name,
        'eventType': 'event',
        'heading': name,
        'imageUrl': 'https://example.com/$id.png',
        'linkUrl': 'https://example.com/$id',
        'start': start ?? '2026-03-21T10:00:00.000',
        'end': end ?? '2026-03-21T20:00:00.000',
        'isUtcTime': false,
        'hasSpawns': false,
        'hasResearchTasks': false,
        'buffs': [],
        'featuredPokemon': [],
        'promoCodes': [],
      };
    }

    CachedEventsService _buildService({
      required MockClient client,
      required InMemoryEventCache cache,
    }) {
      final api =
          ApiClient(httpClient: client, baseUrl: 'http://test.local');
      final remote = EventsService(apiClient: api);
      return CachedEventsService(remote: remote, cache: cache);
    }

    test('manual refresh fetches fresh data and updates the cache', () async {
      final cache = InMemoryEventCache();
      var callCount = 0;

      final client = MockClient((request) async {
        callCount++;
        return http.Response(
          jsonEncode(_buildResponse(
            events: [_event(id: 'ev-$callCount', name: 'Event $callCount')],
            lastUpdated: '2026-03-21T${12 + callCount}:00:00Z',
          )),
          200,
        );
      });

      final service = _buildService(client: client, cache: cache);

      // Initial load populates cache.
      final first = await service.getEvents();
      expect(first.events, hasLength(1));
      expect(first.events.first.name, 'Event 1');

      // Manual refresh (second call) fetches fresh data.
      final refreshed = await service.getEvents();
      expect(refreshed.events, hasLength(1));
      expect(refreshed.events.first.name, 'Event 2',
          reason: 'Manual refresh should fetch new data from the API');
      expect(callCount, 2);

      // Cache should contain the refreshed data.
      final cached = await cache.get();
      expect(cached, isNotNull);
      expect(cached!.events.first.name, 'Event 2',
          reason: 'Cache should be updated after manual refresh');
    });

    test('manual refresh clears stale flag when API succeeds', () async {
      final cache = InMemoryEventCache();

      // Populate cache while online.
      final onlineClient = MockClient((request) async {
        return http.Response(
          jsonEncode(_buildResponse(
            events: [_event(id: 'ev-1', name: 'Raid Hour')],
            lastUpdated: '2026-03-21T08:00:00Z',
          )),
          200,
        );
      });

      final onlineService = _buildService(client: onlineClient, cache: cache);
      await onlineService.getEvents();

      // Go offline — get stale data.
      final offlineClient = MockClient((request) async {
        throw const SocketException('No internet');
      });

      final offlineService =
          _buildService(client: offlineClient, cache: cache);
      final staleResult = await offlineService.getEvents();
      expect(staleResult.cacheHit, isTrue,
          reason: 'Offline fallback should be marked stale');

      // Come back online — manual refresh clears stale flag.
      final refreshClient = MockClient((request) async {
        return http.Response(
          jsonEncode(_buildResponse(
            events: [_event(id: 'ev-1', name: 'Raid Hour')],
            lastUpdated: '2026-03-21T14:00:00Z',
          )),
          200,
        );
      });

      final refreshService =
          _buildService(client: refreshClient, cache: cache);
      final freshResult = await refreshService.getEvents();

      expect(freshResult.cacheHit, isFalse,
          reason: 'Manual refresh should clear the stale flag');
      expect(freshResult.lastUpdated, DateTime.utc(2026, 3, 21, 14, 0),
          reason: 'lastUpdated should reflect the fresh sync time');
    });

    test('manual refresh updates lastUpdated timestamp', () async {
      final cache = InMemoryEventCache();
      var callCount = 0;

      final client = MockClient((request) async {
        callCount++;
        final hour = callCount == 1 ? '08' : '15';
        return http.Response(
          jsonEncode(_buildResponse(
            events: [_event(id: 'ev-1', name: 'Community Day')],
            lastUpdated: '2026-03-21T$hour:00:00Z',
          )),
          200,
        );
      });

      final service = _buildService(client: client, cache: cache);

      final first = await service.getEvents();
      expect(first.lastUpdated, DateTime.utc(2026, 3, 21, 8, 0));

      final refreshed = await service.getEvents();
      expect(refreshed.lastUpdated, DateTime.utc(2026, 3, 21, 15, 0));
      expect(refreshed.lastUpdated.isAfter(first.lastUpdated), isTrue,
          reason: 'Manual refresh should advance the lastUpdated timestamp');
    });

    test('manual refresh while offline preserves cached data', () async {
      final cache = InMemoryEventCache();

      // Populate cache.
      final onlineClient = MockClient((request) async {
        return http.Response(
          jsonEncode(_buildResponse(
            events: [_event(id: 'ev-1', name: 'Spotlight Hour')],
            lastUpdated: '2026-03-21T10:00:00Z',
          )),
          200,
        );
      });

      final onlineService = _buildService(client: onlineClient, cache: cache);
      await onlineService.getEvents();

      // Attempt manual refresh while offline — should gracefully fall back.
      final offlineClient = MockClient((request) async {
        return http.Response('Service Unavailable', 503);
      });

      final offlineService =
          _buildService(client: offlineClient, cache: cache);
      final result = await offlineService.getEvents();

      expect(result.cacheHit, isTrue,
          reason: 'Failed refresh should fall back to cached data');
      expect(result.events, hasLength(1));
      expect(result.events.first.name, 'Spotlight Hour',
          reason: 'Cached data should be preserved on failed refresh');
    });

    test('manual refresh recovers after transient failure', () async {
      final cache = InMemoryEventCache();
      var callCount = 0;

      final client = MockClient((request) async {
        callCount++;
        if (callCount == 2) {
          return http.Response('Internal Server Error', 500);
        }
        return http.Response(
          jsonEncode(_buildResponse(
            events: [_event(id: 'ev-1', name: 'Event $callCount')],
            lastUpdated: '2026-03-21T12:00:00Z',
          )),
          200,
        );
      });

      final service = _buildService(client: client, cache: cache);

      // First call succeeds.
      final first = await service.getEvents();
      expect(first.events.first.name, 'Event 1');
      expect(first.cacheHit, isFalse);

      // Second call fails — falls back to cache.
      final fallback = await service.getEvents();
      expect(fallback.cacheHit, isTrue,
          reason: 'Failed refresh should fall back to cached data');

      // Third call succeeds — refresh recovers.
      final recovered = await service.getEvents();
      expect(recovered.events.first.name, 'Event 3');
      expect(recovered.cacheHit, isFalse,
          reason: 'Successful refresh after failure should clear stale flag');
    });

    test('consecutive manual refreshes always hit the API', () async {
      final cache = InMemoryEventCache();
      var callCount = 0;

      final client = MockClient((request) async {
        callCount++;
        return http.Response(
          jsonEncode(_buildResponse(
            events: [_event(id: 'ev-1', name: 'Event')],
            lastUpdated: '2026-03-21T12:00:00Z',
          )),
          200,
        );
      });

      final service = _buildService(client: client, cache: cache);

      await service.getEvents();
      await service.getEvents();
      await service.getEvents();

      expect(callCount, 3,
          reason: 'Each manual refresh must hit the API — '
              'no client-side request deduplication');
    });
  });
}

/// Simple in-memory [EventCache] implementation for testing.
class InMemoryEventCache implements EventCache {
  EventsResponse? _stored;

  @override
  Future<void> put(EventsResponse response) async {
    _stored = response;
  }

  @override
  Future<EventsResponse?> get() async => _stored;

  @override
  Future<void> clear() async {
    _stored = null;
  }
}
