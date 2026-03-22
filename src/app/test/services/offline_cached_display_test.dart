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
/// "App displays cached data when offline"
///
/// Tests that [CachedEventsService] returns previously cached data when the
/// network is unavailable, covering HTTP errors, socket exceptions, and the
/// [getActiveEvents] path.
void main() {
  group('US-GCG-9 — App displays cached data when offline', () {
    final now = DateTime(2026, 3, 21, 14, 0);

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

    /// Pre-populates [cache] by running a successful API sync.
    Future<CachedEventsService> _syncThenGoOffline({
      required InMemoryEventCache cache,
      required List<Map<String, dynamic>> events,
      required String lastUpdated,
      required MockClient offlineClient,
    }) async {
      // First, populate the cache with a successful online sync.
      final onlineClient = MockClient((request) async {
        return http.Response(
          jsonEncode(_buildResponse(
            events: events,
            lastUpdated: lastUpdated,
          )),
          200,
        );
      });

      final onlineApi =
          ApiClient(httpClient: onlineClient, baseUrl: 'http://test.local');
      final onlineRemote = EventsService(apiClient: onlineApi);
      final onlineService =
          CachedEventsService(remote: onlineRemote, cache: cache);

      await onlineService.getEvents();

      // Now create a new service that uses the offline client but the same cache.
      final offlineApi =
          ApiClient(httpClient: offlineClient, baseUrl: 'http://test.local');
      final offlineRemote = EventsService(apiClient: offlineApi);
      return CachedEventsService(remote: offlineRemote, cache: cache);
    }

    test('getEvents() returns cached data when API returns a server error',
        () async {
      final cache = InMemoryEventCache();

      final offlineClient = MockClient((request) async {
        return http.Response('Service Unavailable', 503);
      });

      final service = await _syncThenGoOffline(
        cache: cache,
        events: [
          _event(id: 'ev-1', name: 'Community Day'),
          _event(id: 'ev-2', name: 'Raid Hour'),
        ],
        lastUpdated: '2026-03-21T12:00:00Z',
        offlineClient: offlineClient,
      );

      // Service should fall back to cached data.
      final result = await service.getEvents();
      expect(result.events, hasLength(2));
      expect(result.events.first.id, 'ev-1');
      expect(result.events.last.id, 'ev-2');
    });

    test('getEvents() returns cached data when a SocketException occurs',
        () async {
      final cache = InMemoryEventCache();

      final offlineClient = MockClient((request) async {
        throw const SocketException('No internet connection');
      });

      final service = await _syncThenGoOffline(
        cache: cache,
        events: [_event(id: 'ev-1', name: 'Spotlight Hour')],
        lastUpdated: '2026-03-21T12:00:00Z',
        offlineClient: offlineClient,
      );

      final result = await service.getEvents();
      expect(result.events, hasLength(1));
      expect(result.events.first.name, 'Spotlight Hour');
    });

    test('getActiveEvents() returns cached active events when offline',
        () async {
      final cache = InMemoryEventCache();

      final offlineClient = MockClient((request) async {
        throw const SocketException('Network unreachable');
      });

      final service = await _syncThenGoOffline(
        cache: cache,
        events: [
          _event(
            id: 'active-1',
            name: 'Active Event',
            start: '2026-03-21T10:00:00.000',
            end: '2026-03-21T20:00:00.000',
          ),
          _event(
            id: 'future-1',
            name: 'Future Event',
            start: '2026-04-01T10:00:00.000',
            end: '2026-04-01T17:00:00.000',
          ),
        ],
        lastUpdated: '2026-03-21T12:00:00Z',
        offlineClient: offlineClient,
      );

      final active = await service.getActiveEvents(now: now);
      expect(active, hasLength(1));
      expect(active.first.id, 'active-1');
      expect(active.first.name, 'Active Event');
    });

    test('getEvents() throws when offline with no cached data', () async {
      final cache = InMemoryEventCache();

      final offlineClient = MockClient((request) async {
        throw const SocketException('No internet connection');
      });

      final apiClient =
          ApiClient(httpClient: offlineClient, baseUrl: 'http://test.local');
      final remote = EventsService(apiClient: apiClient);
      final service = CachedEventsService(remote: remote, cache: cache);

      expect(
        () => service.getEvents(),
        throwsA(isA<SocketException>()),
      );
    });

    test('cached data includes all event fields when served offline',
        () async {
      final cache = InMemoryEventCache();

      final offlineClient = MockClient((request) async {
        return http.Response('Service Unavailable', 503);
      });

      final onlineClient = MockClient((request) async {
        return http.Response(
          jsonEncode(_buildResponse(
            events: [
              {
                'id': 'cd-march',
                'name': 'March Community Day',
                'eventType': 'community-day',
                'heading': 'Featuring Bellsprout',
                'imageUrl': 'https://example.com/cd.png',
                'linkUrl': 'https://example.com/cd',
                'start': '2026-03-21T14:00:00.000',
                'end': '2026-03-21T17:00:00.000',
                'isUtcTime': false,
                'hasSpawns': true,
                'hasResearchTasks': true,
                'buffs': [
                  {
                    'text': '3× Catch Stardust',
                    'category': 'multiplier',
                    'multiplier': 3.0,
                    'resource': 'Stardust',
                  }
                ],
                'featuredPokemon': [
                  {
                    'name': 'Bellsprout',
                    'imageUrl': 'https://example.com/bellsprout.png',
                    'canBeShiny': true,
                    'role': 'spawn',
                  }
                ],
                'promoCodes': ['POKEMON2026'],
              }
            ],
            lastUpdated: '2026-03-21T12:00:00Z',
          )),
          200,
        );
      });

      // Populate cache online.
      final onlineApi =
          ApiClient(httpClient: onlineClient, baseUrl: 'http://test.local');
      final onlineRemote = EventsService(apiClient: onlineApi);
      final onlineService =
          CachedEventsService(remote: onlineRemote, cache: cache);
      await onlineService.getEvents();

      // Read from cache while offline.
      final offlineApi =
          ApiClient(httpClient: offlineClient, baseUrl: 'http://test.local');
      final offlineRemote = EventsService(apiClient: offlineApi);
      final offlineService =
          CachedEventsService(remote: offlineRemote, cache: cache);

      final result = await offlineService.getEvents();
      final event = result.events.first;
      expect(event.id, 'cd-march');
      expect(event.name, 'March Community Day');
      expect(event.hasSpawns, true);
      expect(event.hasResearchTasks, true);
      expect(event.buffs, hasLength(1));
      expect(event.buffs.first.text, '3× Catch Stardust');
      expect(event.featuredPokemon, hasLength(1));
      expect(event.featuredPokemon.first.name, 'Bellsprout');
      expect(event.promoCodes, ['POKEMON2026']);
    });

    test('multiple offline reads return consistent cached data', () async {
      final cache = InMemoryEventCache();

      final offlineClient = MockClient((request) async {
        throw const SocketException('No internet connection');
      });

      final service = await _syncThenGoOffline(
        cache: cache,
        events: [
          _event(id: 'ev-1', name: 'Event 1'),
          _event(id: 'ev-2', name: 'Event 2'),
        ],
        lastUpdated: '2026-03-21T12:00:00Z',
        offlineClient: offlineClient,
      );

      // Multiple offline reads should return the same data.
      final result1 = await service.getEvents();
      final result2 = await service.getEvents();
      final result3 = await service.getEvents();

      expect(result1.events, hasLength(2));
      expect(result2.events, hasLength(2));
      expect(result3.events, hasLength(2));
      expect(result1.events.first.id, result2.events.first.id);
      expect(result2.events.first.id, result3.events.first.id);
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
