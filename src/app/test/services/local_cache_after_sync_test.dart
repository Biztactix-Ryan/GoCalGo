import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gocalgo/models/events_response.dart';
import 'package:gocalgo/services/api_client.dart';
import 'package:gocalgo/services/cached_events_service.dart';
import 'package:gocalgo/services/event_cache.dart';
import 'package:gocalgo/services/events_service.dart';

/// Verifies acceptance criterion for story US-GCG-9:
/// "Event data is cached locally on the device after each API sync"
///
/// Tests that [CachedEventsService] persists event data to the local
/// [EventCache] every time a successful API response is received.
void main() {
  group('US-GCG-9 — Event data is cached locally after each API sync', () {
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

    CachedEventsService _createService({
      required MockClient mockClient,
      required InMemoryEventCache cache,
    }) {
      final apiClient =
          ApiClient(httpClient: mockClient, baseUrl: 'http://test.local');
      final remote = EventsService(apiClient: apiClient);
      return CachedEventsService(remote: remote, cache: cache);
    }

    test('cache is populated after a successful getEvents() call', () async {
      final cache = InMemoryEventCache();
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode(_buildResponse(
            events: [_event(id: 'ev-1', name: 'Community Day')],
            lastUpdated: '2026-03-21T12:00:00Z',
          )),
          200,
        );
      });

      final service = _createService(mockClient: mockClient, cache: cache);

      // Cache starts empty.
      expect(await cache.get(), isNull);

      await service.getEvents();

      // Cache now holds the synced data.
      final cached = await cache.get();
      expect(cached, isNotNull);
      expect(cached!.events, hasLength(1));
      expect(cached.events.first.id, 'ev-1');
      expect(cached.events.first.name, 'Community Day');
    });

    test('cache is updated on every subsequent sync', () async {
      final cache = InMemoryEventCache();
      var callCount = 0;

      final mockClient = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          return http.Response(
            jsonEncode(_buildResponse(
              events: [_event(id: 'ev-1', name: 'Event 1')],
              lastUpdated: '2026-03-21T12:00:00Z',
            )),
            200,
          );
        }
        return http.Response(
          jsonEncode(_buildResponse(
            events: [
              _event(id: 'ev-1', name: 'Event 1'),
              _event(id: 'ev-2', name: 'Event 2'),
            ],
            lastUpdated: '2026-03-21T14:00:00Z',
          )),
          200,
        );
      });

      final service = _createService(mockClient: mockClient, cache: cache);

      await service.getEvents();
      var cached = await cache.get();
      expect(cached!.events, hasLength(1));

      // Second sync updates the cache.
      await service.getEvents();
      cached = await cache.get();
      expect(cached!.events, hasLength(2));
      expect(cached.lastUpdated, DateTime.utc(2026, 3, 21, 14, 0));
    });

    test('cached data preserves all event fields', () async {
      final cache = InMemoryEventCache();
      final mockClient = MockClient((request) async {
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
            cacheHit: true,
          )),
          200,
        );
      });

      final service = _createService(mockClient: mockClient, cache: cache);
      await service.getEvents();

      final cached = await cache.get();
      expect(cached, isNotNull);

      final event = cached!.events.first;
      expect(event.id, 'cd-march');
      expect(event.name, 'March Community Day');
      expect(event.hasSpawns, true);
      expect(event.hasResearchTasks, true);
      expect(event.buffs, hasLength(1));
      expect(event.buffs.first.text, '3× Catch Stardust');
      expect(event.featuredPokemon, hasLength(1));
      expect(event.featuredPokemon.first.name, 'Bellsprout');
      expect(event.promoCodes, ['POKEMON2026']);
      expect(cached.cacheHit, true);
    });

    test('getActiveEvents() also caches the full response', () async {
      final cache = InMemoryEventCache();
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode(_buildResponse(
            events: [
              _event(id: 'active-1', name: 'Active Event'),
              _event(
                id: 'future-1',
                name: 'Future Event',
                start: '2026-04-01T10:00:00.000',
                end: '2026-04-01T17:00:00.000',
              ),
            ],
            lastUpdated: '2026-03-21T12:00:00Z',
          )),
          200,
        );
      });

      final service = _createService(mockClient: mockClient, cache: cache);

      // getActiveEvents filters, but cache should have the full response.
      final active = await service.getActiveEvents(now: now);
      expect(active, hasLength(1));
      expect(active.first.id, 'active-1');

      final cached = await cache.get();
      expect(cached!.events, hasLength(2),
          reason: 'Cache stores the full response, not just active events');
    });

    test('getCachedEvents() returns cached data without network call',
        () async {
      final cache = InMemoryEventCache();
      var apiCallCount = 0;

      final mockClient = MockClient((request) async {
        apiCallCount++;
        return http.Response(
          jsonEncode(_buildResponse(
            events: [_event(id: 'ev-1', name: 'Cached Event')],
            lastUpdated: '2026-03-21T12:00:00Z',
          )),
          200,
        );
      });

      final service = _createService(mockClient: mockClient, cache: cache);

      // Sync once to populate cache.
      await service.getEvents();
      expect(apiCallCount, 1);

      // getCachedEvents reads from cache, no network call.
      final cached = await service.getCachedEvents();
      expect(apiCallCount, 1, reason: 'No additional API call should be made');
      expect(cached, isNotNull);
      expect(cached!.events.first.name, 'Cached Event');
    });

    test('cache survives API errors on subsequent syncs', () async {
      final cache = InMemoryEventCache();
      var callCount = 0;

      final mockClient = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          return http.Response(
            jsonEncode(_buildResponse(
              events: [_event(id: 'ev-1', name: 'Event 1')],
              lastUpdated: '2026-03-21T12:00:00Z',
            )),
            200,
          );
        }
        // Second call fails.
        return http.Response('Internal Server Error', 500);
      });

      final service = _createService(mockClient: mockClient, cache: cache);

      // First sync succeeds and populates cache.
      await service.getEvents();

      // Second sync fails — getEvents falls back to cache.
      final fallback = await service.getEvents();
      expect(fallback.events, hasLength(1));
      expect(fallback.events.first.id, 'ev-1',
          reason: 'Should return cached data when API fails');
    });

    test('cache is empty before first sync', () async {
      final cache = InMemoryEventCache();
      expect(await cache.get(), isNull);
    });

    test('cache.clear() removes all cached data', () async {
      final cache = InMemoryEventCache();
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode(_buildResponse(
            events: [_event(id: 'ev-1', name: 'Event 1')],
            lastUpdated: '2026-03-21T12:00:00Z',
          )),
          200,
        );
      });

      final service = _createService(mockClient: mockClient, cache: cache);
      await service.getEvents();
      expect(await cache.get(), isNotNull);

      await cache.clear();
      expect(await cache.get(), isNull);
    });
  });
}

/// Simple in-memory [EventCache] implementation for testing.
///
/// The real implementation (US-GCG-9-6) will use SQLite for persistence
/// across app restarts.
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
