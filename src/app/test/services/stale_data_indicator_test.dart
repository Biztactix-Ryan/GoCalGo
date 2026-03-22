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
/// "App indicates when data may be stale due to offline mode"
///
/// Tests that [CachedEventsService] marks responses with [cacheHit] = true
/// when falling back to locally cached data, and preserves the original
/// [lastUpdated] timestamp so the UI can display a staleness indicator.
void main() {
  group('US-GCG-9 — App indicates when data may be stale due to offline mode',
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

    test('fresh API response preserves original cacheHit value (false)',
        () async {
      final cache = InMemoryEventCache();
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode(_buildResponse(
            events: [_event(id: 'ev-1', name: 'Community Day')],
            lastUpdated: '2026-03-21T12:00:00Z',
            cacheHit: false,
          )),
          200,
        );
      });

      final service = _buildService(client: client, cache: cache);
      final result = await service.getEvents();

      expect(result.cacheHit, isFalse,
          reason: 'Fresh API data should not be marked as stale');
    });

    test('cached fallback response has cacheHit=true indicating stale data',
        () async {
      final cache = InMemoryEventCache();

      // Sync online first.
      final onlineClient = MockClient((request) async {
        return http.Response(
          jsonEncode(_buildResponse(
            events: [_event(id: 'ev-1', name: 'Raid Hour')],
            lastUpdated: '2026-03-21T12:00:00Z',
            cacheHit: false,
          )),
          200,
        );
      });

      final onlineService = _buildService(client: onlineClient, cache: cache);
      final freshResult = await onlineService.getEvents();
      expect(freshResult.cacheHit, isFalse);

      // Go offline — server error.
      final offlineClient = MockClient((request) async {
        return http.Response('Service Unavailable', 503);
      });

      final offlineService =
          _buildService(client: offlineClient, cache: cache);
      final staleResult = await offlineService.getEvents();

      expect(staleResult.cacheHit, isTrue,
          reason: 'Cached fallback must set cacheHit=true so UI can show '
              'a stale-data indicator');
      expect(staleResult.events, hasLength(1));
      expect(staleResult.events.first.name, 'Raid Hour');
    });

    test(
        'cached fallback response preserves lastUpdated from the original sync',
        () async {
      final cache = InMemoryEventCache();
      const syncTimestamp = '2026-03-21T08:00:00Z';

      final onlineClient = MockClient((request) async {
        return http.Response(
          jsonEncode(_buildResponse(
            events: [_event(id: 'ev-1', name: 'Spotlight Hour')],
            lastUpdated: syncTimestamp,
            cacheHit: false,
          )),
          200,
        );
      });

      final onlineService = _buildService(client: onlineClient, cache: cache);
      await onlineService.getEvents();

      // Go offline.
      final offlineClient = MockClient((request) async {
        throw const SocketException('No internet connection');
      });

      final offlineService =
          _buildService(client: offlineClient, cache: cache);
      final result = await offlineService.getEvents();

      expect(result.lastUpdated, DateTime.parse(syncTimestamp),
          reason: 'lastUpdated should reflect when data was last synced, '
              'allowing the UI to show how old the data is');
      expect(result.cacheHit, isTrue);
    });

    test('cacheHit resets to false when connectivity is restored', () async {
      final cache = InMemoryEventCache();

      // Online sync.
      final onlineClient = MockClient((request) async {
        return http.Response(
          jsonEncode(_buildResponse(
            events: [_event(id: 'ev-1', name: 'GO Battle Day')],
            lastUpdated: '2026-03-21T12:00:00Z',
            cacheHit: false,
          )),
          200,
        );
      });

      final onlineService = _buildService(client: onlineClient, cache: cache);
      await onlineService.getEvents();

      // Offline — stale.
      final offlineClient = MockClient((request) async {
        throw const SocketException('Network unreachable');
      });

      final offlineService =
          _buildService(client: offlineClient, cache: cache);
      final staleResult = await offlineService.getEvents();
      expect(staleResult.cacheHit, isTrue);

      // Back online with fresh data.
      final refreshClient = MockClient((request) async {
        return http.Response(
          jsonEncode(_buildResponse(
            events: [_event(id: 'ev-1', name: 'GO Battle Day')],
            lastUpdated: '2026-03-21T14:00:00Z',
            cacheHit: false,
          )),
          200,
        );
      });

      final refreshService =
          _buildService(client: refreshClient, cache: cache);
      final freshResult = await refreshService.getEvents();

      expect(freshResult.cacheHit, isFalse,
          reason: 'After a successful refresh, data should no longer be '
              'marked as stale');
      expect(freshResult.lastUpdated, DateTime.parse('2026-03-21T14:00:00Z'));
    });

    test('stale indicator works with SocketException (network down)', () async {
      final cache = InMemoryEventCache();

      final onlineClient = MockClient((request) async {
        return http.Response(
          jsonEncode(_buildResponse(
            events: [_event(id: 'ev-1', name: 'Raid Hour')],
            lastUpdated: '2026-03-21T10:00:00Z',
            cacheHit: false,
          )),
          200,
        );
      });

      final onlineService = _buildService(client: onlineClient, cache: cache);
      await onlineService.getEvents();

      final offlineClient = MockClient((request) async {
        throw const SocketException('Connection refused');
      });

      final offlineService =
          _buildService(client: offlineClient, cache: cache);
      final result = await offlineService.getEvents();

      expect(result.cacheHit, isTrue);
      expect(result.events.first.name, 'Raid Hour');
    });

    test('even if original API response had cacheHit=true, '
        'offline fallback still returns cacheHit=true', () async {
      final cache = InMemoryEventCache();

      // API itself returns cacheHit=true (server-side cache).
      final onlineClient = MockClient((request) async {
        return http.Response(
          jsonEncode(_buildResponse(
            events: [_event(id: 'ev-1', name: 'Event')],
            lastUpdated: '2026-03-21T10:00:00Z',
            cacheHit: true,
          )),
          200,
        );
      });

      final onlineService = _buildService(client: onlineClient, cache: cache);
      final onlineResult = await onlineService.getEvents();
      expect(onlineResult.cacheHit, isTrue);

      // Offline fallback.
      final offlineClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final offlineService =
          _buildService(client: offlineClient, cache: cache);
      final offlineResult = await offlineService.getEvents();

      expect(offlineResult.cacheHit, isTrue,
          reason: 'Offline fallback always indicates stale data');
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
