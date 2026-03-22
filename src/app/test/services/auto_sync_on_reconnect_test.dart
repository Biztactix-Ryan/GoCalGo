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

/// Verifies acceptance criterion for story US-GCG-9:
/// "Data syncs automatically when network connectivity is restored"
///
/// Tests that [CachedEventsService] fetches fresh data from the API on the
/// first successful call after a period of offline fallback, updating the
/// local cache with the latest response.
void main() {
  group('US-GCG-9 — Data syncs automatically when connectivity is restored',
      () {
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
      String eventType = 'event',
      String? start,
      String? end,
    }) {
      return {
        'id': id,
        'name': name,
        'eventType': eventType,
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
      final api = ApiClient(httpClient: client, baseUrl: 'http://test.local');
      final remote = EventsService(apiClient: api);
      return CachedEventsService(remote: remote, cache: cache);
    }

    test(
        'getEvents() fetches fresh data from API after offline period, '
        'replacing stale cache', () async {
      final cache = InMemoryEventCache();
      int requestCount = 0;

      // Phase 1: Online — populate cache with initial data.
      final initialClient = MockClient((request) async {
        requestCount++;
        return http.Response(
          jsonEncode(_buildResponse(
            events: [_event(id: 'ev-1', name: 'Community Day')],
            lastUpdated: '2026-03-21T10:00:00Z',
          )),
          200,
        );
      });

      var service = _buildService(client: initialClient, cache: cache);
      final initial = await service.getEvents();
      expect(initial.events, hasLength(1));
      expect(initial.events.first.name, 'Community Day');
      expect(initial.cacheHit, isFalse);
      expect(requestCount, 1);

      // Phase 2: Offline — falls back to stale cache.
      final offlineClient = MockClient((request) async {
        throw const SocketException('No internet connection');
      });

      service = _buildService(client: offlineClient, cache: cache);
      final offline = await service.getEvents();
      expect(offline.events, hasLength(1));
      expect(offline.events.first.name, 'Community Day');
      expect(offline.cacheHit, isTrue);

      // Phase 3: Back online — fresh data is fetched and cache is updated.
      final reconnectClient = MockClient((request) async {
        requestCount++;
        return http.Response(
          jsonEncode(_buildResponse(
            events: [
              _event(id: 'ev-1', name: 'Community Day'),
              _event(id: 'ev-2', name: 'Raid Hour'),
            ],
            lastUpdated: '2026-03-21T14:00:00Z',
          )),
          200,
        );
      });

      service = _buildService(client: reconnectClient, cache: cache);
      final reconnected = await service.getEvents();
      expect(reconnected.events, hasLength(2));
      expect(reconnected.events.last.name, 'Raid Hour');
      expect(reconnected.cacheHit, isFalse);
      expect(requestCount, 2);
    });

    test('cache is updated with fresh data after reconnect', () async {
      final cache = InMemoryEventCache();

      // Online: seed cache.
      final seedClient = MockClient((request) async {
        return http.Response(
          jsonEncode(_buildResponse(
            events: [_event(id: 'ev-1', name: 'Old Event')],
            lastUpdated: '2026-03-21T08:00:00Z',
          )),
          200,
        );
      });

      var service = _buildService(client: seedClient, cache: cache);
      await service.getEvents();

      // Offline period (skipped — cache already populated).

      // Reconnect with updated data.
      final freshClient = MockClient((request) async {
        return http.Response(
          jsonEncode(_buildResponse(
            events: [_event(id: 'ev-1', name: 'Updated Event')],
            lastUpdated: '2026-03-21T15:00:00Z',
          )),
          200,
        );
      });

      service = _buildService(client: freshClient, cache: cache);
      await service.getEvents();

      // Verify the cache itself was updated — read directly.
      final cached = await cache.get();
      expect(cached, isNotNull);
      expect(cached!.events.first.name, 'Updated Event');
      expect(cached.lastUpdated, DateTime.utc(2026, 3, 21, 15, 0));
    });

    test('lastUpdated timestamp advances after reconnect sync', () async {
      final cache = InMemoryEventCache();

      // Seed with old timestamp.
      final oldClient = MockClient((request) async {
        return http.Response(
          jsonEncode(_buildResponse(
            events: [_event(id: 'ev-1', name: 'Event')],
            lastUpdated: '2026-03-21T06:00:00Z',
          )),
          200,
        );
      });

      var service = _buildService(client: oldClient, cache: cache);
      await service.getEvents();

      // Go offline.
      final offlineClient = MockClient((request) async {
        throw const SocketException('No internet connection');
      });

      service = _buildService(client: offlineClient, cache: cache);
      final stale = await service.getEvents();
      expect(stale.lastUpdated, DateTime.utc(2026, 3, 21, 6, 0));
      expect(stale.cacheHit, isTrue);

      // Reconnect with newer timestamp.
      final freshClient = MockClient((request) async {
        return http.Response(
          jsonEncode(_buildResponse(
            events: [_event(id: 'ev-1', name: 'Event')],
            lastUpdated: '2026-03-21T18:00:00Z',
          )),
          200,
        );
      });

      service = _buildService(client: freshClient, cache: cache);
      final fresh = await service.getEvents();
      expect(fresh.lastUpdated, DateTime.utc(2026, 3, 21, 18, 0));
      expect(fresh.cacheHit, isFalse);
    });

    test('cacheHit is false after successful reconnect sync', () async {
      final cache = InMemoryEventCache();

      // Seed cache.
      final seedClient = MockClient((request) async {
        return http.Response(
          jsonEncode(_buildResponse(
            events: [_event(id: 'ev-1', name: 'Event')],
            lastUpdated: '2026-03-21T10:00:00Z',
          )),
          200,
        );
      });

      var service = _buildService(client: seedClient, cache: cache);
      await service.getEvents();

      // Offline — cacheHit should be true.
      final offlineClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      service = _buildService(client: offlineClient, cache: cache);
      final offline = await service.getEvents();
      expect(offline.cacheHit, isTrue);

      // Reconnect — cacheHit should be false.
      final onlineClient = MockClient((request) async {
        return http.Response(
          jsonEncode(_buildResponse(
            events: [_event(id: 'ev-1', name: 'Event')],
            lastUpdated: '2026-03-21T16:00:00Z',
          )),
          200,
        );
      });

      service = _buildService(client: onlineClient, cache: cache);
      final fresh = await service.getEvents();
      expect(fresh.cacheHit, isFalse);
    });

    test('getActiveEvents() returns fresh active events after reconnect',
        () async {
      final cache = InMemoryEventCache();
      final now = DateTime(2026, 3, 21, 14, 0);

      // Seed with one active event.
      final seedClient = MockClient((request) async {
        return http.Response(
          jsonEncode(_buildResponse(
            events: [
              _event(
                id: 'ev-1',
                name: 'Morning Event',
                start: '2026-03-21T08:00:00.000',
                end: '2026-03-21T12:00:00.000',
              ),
            ],
            lastUpdated: '2026-03-21T07:00:00Z',
          )),
          200,
        );
      });

      var service = _buildService(client: seedClient, cache: cache);
      await service.getEvents();

      // Offline — morning event is no longer active at 14:00.
      final offlineClient = MockClient((request) async {
        throw const SocketException('No internet connection');
      });

      service = _buildService(client: offlineClient, cache: cache);
      final offlineActive = await service.getActiveEvents(now: now);
      expect(offlineActive, isEmpty);

      // Reconnect — server now has an afternoon event.
      final freshClient = MockClient((request) async {
        return http.Response(
          jsonEncode(_buildResponse(
            events: [
              _event(
                id: 'ev-2',
                name: 'Afternoon Raid Hour',
                start: '2026-03-21T13:00:00.000',
                end: '2026-03-21T19:00:00.000',
              ),
            ],
            lastUpdated: '2026-03-21T13:00:00Z',
          )),
          200,
        );
      });

      service = _buildService(client: freshClient, cache: cache);
      final freshActive = await service.getActiveEvents(now: now);
      expect(freshActive, hasLength(1));
      expect(freshActive.first.id, 'ev-2');
      expect(freshActive.first.name, 'Afternoon Raid Hour');
    });

    test('multiple offline-to-online cycles all sync correctly', () async {
      final cache = InMemoryEventCache();

      for (var cycle = 1; cycle <= 3; cycle++) {
        // Online: return data specific to this cycle.
        final onlineClient = MockClient((request) async {
          return http.Response(
            jsonEncode(_buildResponse(
              events: [_event(id: 'ev-$cycle', name: 'Event $cycle')],
              lastUpdated: '2026-03-21T${10 + cycle}:00:00Z',
            )),
            200,
          );
        });

        var service = _buildService(client: onlineClient, cache: cache);
        final result = await service.getEvents();
        expect(result.events, hasLength(1));
        expect(result.events.first.id, 'ev-$cycle');
        expect(result.cacheHit, isFalse);

        // Offline: should return the data from this cycle.
        final offlineClient = MockClient((request) async {
          throw const SocketException('No internet connection');
        });

        service = _buildService(client: offlineClient, cache: cache);
        final offline = await service.getEvents();
        expect(offline.events.first.id, 'ev-$cycle');
        expect(offline.cacheHit, isTrue);
      }

      // Final cache state should have the last cycle's data.
      final cached = await cache.get();
      expect(cached!.events.first.id, 'ev-3');
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
