import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gocalgo/models/events_response.dart';
import 'package:gocalgo/services/api_client.dart';
import 'package:gocalgo/services/cached_events_service.dart';
import 'package:gocalgo/services/event_cache.dart';
import 'package:gocalgo/services/events_service.dart';
import 'package:gocalgo/services/ttl_event_cache.dart';

/// Verifies acceptance criterion for story US-GCG-9:
/// "Local cache is cleared and refreshed on a reasonable schedule"
///
/// Tests that cached event data expires after a configurable TTL and is
/// automatically replaced with fresh API data on the next fetch.
void main() {
  group('US-GCG-9 — Local cache is cleared and refreshed on a reasonable schedule', () {
    late DateTime _now;

    setUp(() {
      _now = DateTime(2026, 3, 21, 14, 0);
    });

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
      required EventCache cache,
    }) {
      final apiClient =
          ApiClient(httpClient: mockClient, baseUrl: 'http://test.local');
      final remote = EventsService(apiClient: apiClient);
      return CachedEventsService(remote: remote, cache: cache);
    }

    // --- TtlEventCache unit tests ---

    group('TtlEventCache expiration behaviour', () {
      test('returns cached data before TTL expires', () async {
        final inner = InMemoryEventCache();
        final ttlCache = TtlEventCache(
          inner: inner,
          ttl: const Duration(hours: 6),
          clock: () => _now,
        );

        final response = EventsResponse(
          events: [],
          lastUpdated: _now,
          cacheHit: false,
        );

        await ttlCache.put(response);

        // Advance clock by 5 hours 59 minutes — still within TTL.
        _now = _now.add(const Duration(hours: 5, minutes: 59));
        final cached = await ttlCache.get();
        expect(cached, isNotNull, reason: 'Cache should still be valid before TTL');
        expect(ttlCache.isExpired, isFalse);
      });

      test('returns null after TTL expires', () async {
        final inner = InMemoryEventCache();
        final ttlCache = TtlEventCache(
          inner: inner,
          ttl: const Duration(hours: 6),
          clock: () => _now,
        );

        final response = EventsResponse(
          events: [],
          lastUpdated: _now,
          cacheHit: false,
        );

        await ttlCache.put(response);

        // Advance clock past TTL.
        _now = _now.add(const Duration(hours: 6));
        final cached = await ttlCache.get();
        expect(cached, isNull, reason: 'Cache should expire after TTL');
        expect(ttlCache.isExpired, isTrue);
      });

      test('clears inner cache when TTL expires', () async {
        final inner = InMemoryEventCache();
        final ttlCache = TtlEventCache(
          inner: inner,
          ttl: const Duration(hours: 1),
          clock: () => _now,
        );

        final response = EventsResponse(
          events: [],
          lastUpdated: _now,
          cacheHit: false,
        );

        await ttlCache.put(response);
        expect(await inner.get(), isNotNull);

        // Expire and trigger get.
        _now = _now.add(const Duration(hours: 1));
        await ttlCache.get();

        // Inner cache should also be cleared.
        expect(await inner.get(), isNull,
            reason: 'Stale data should be purged from inner cache');
      });

      test('put resets the TTL timer', () async {
        final inner = InMemoryEventCache();
        final ttlCache = TtlEventCache(
          inner: inner,
          ttl: const Duration(hours: 2),
          clock: () => _now,
        );

        final response = EventsResponse(
          events: [],
          lastUpdated: _now,
          cacheHit: false,
        );

        await ttlCache.put(response);

        // Advance 1h 50m — almost expired.
        _now = _now.add(const Duration(hours: 1, minutes: 50));
        expect(await ttlCache.get(), isNotNull);

        // Re-put resets the timer.
        await ttlCache.put(response);

        // Another 1h 50m from the new put — still valid.
        _now = _now.add(const Duration(hours: 1, minutes: 50));
        expect(await ttlCache.get(), isNotNull,
            reason: 'TTL should reset after put');
      });

      test('clear removes data and resets timestamp', () async {
        final inner = InMemoryEventCache();
        final ttlCache = TtlEventCache(
          inner: inner,
          ttl: const Duration(hours: 6),
          clock: () => _now,
        );

        final response = EventsResponse(
          events: [],
          lastUpdated: _now,
          cacheHit: false,
        );

        await ttlCache.put(response);
        await ttlCache.clear();

        expect(await ttlCache.get(), isNull);
        expect(ttlCache.isExpired, isTrue);
      });

      test('get returns null when cache has never been populated', () async {
        final inner = InMemoryEventCache();
        final ttlCache = TtlEventCache(
          inner: inner,
          ttl: const Duration(hours: 6),
          clock: () => _now,
        );

        expect(await ttlCache.get(), isNull);
        expect(ttlCache.isExpired, isTrue);
      });
    });

    // --- Integration: CachedEventsService + TtlEventCache ---

    group('CachedEventsService refreshes data after cache expires', () {
      test('fetches fresh data from API when cache has expired', () async {
        final inner = InMemoryEventCache();
        final ttlCache = TtlEventCache(
          inner: inner,
          ttl: const Duration(hours: 6),
          clock: () => _now,
        );

        var callCount = 0;
        final mockClient = MockClient((request) async {
          callCount++;
          return http.Response(
            jsonEncode(_buildResponse(
              events: [_event(id: 'ev-$callCount', name: 'Event $callCount')],
              lastUpdated: _now.toUtc().toIso8601String(),
            )),
            200,
          );
        });

        final service = _createService(mockClient: mockClient, cache: ttlCache);

        // Initial sync.
        final first = await service.getEvents();
        expect(first.events.first.id, 'ev-1');
        expect(callCount, 1);

        // Expire the cache.
        _now = _now.add(const Duration(hours: 7));

        // Next getEvents hits the API again (cache expired).
        final second = await service.getEvents();
        expect(second.events.first.id, 'ev-2');
        expect(callCount, 2);
      });

      test('serves cached data without API call when cache is still valid', () async {
        final inner = InMemoryEventCache();
        final ttlCache = TtlEventCache(
          inner: inner,
          ttl: const Duration(hours: 6),
          clock: () => _now,
        );

        var callCount = 0;
        final mockClient = MockClient((request) async {
          callCount++;
          return http.Response(
            jsonEncode(_buildResponse(
              events: [_event(id: 'ev-1', name: 'Community Day')],
              lastUpdated: '2026-03-21T12:00:00Z',
            )),
            200,
          );
        });

        final service = _createService(mockClient: mockClient, cache: ttlCache);

        // Initial sync.
        await service.getEvents();
        expect(callCount, 1);

        // Advance 3 hours — still within TTL.
        _now = _now.add(const Duration(hours: 3));

        // getCachedEvents returns data without hitting the API.
        final cached = await service.getCachedEvents();
        expect(cached, isNotNull);
        expect(cached!.events.first.id, 'ev-1');
        expect(callCount, 1, reason: 'Should not make additional API call');
      });

      test('expired cache causes fallback-free fresh fetch', () async {
        final inner = InMemoryEventCache();
        final ttlCache = TtlEventCache(
          inner: inner,
          ttl: const Duration(hours: 6),
          clock: () => _now,
        );

        var callCount = 0;
        final mockClient = MockClient((request) async {
          callCount++;
          return http.Response(
            jsonEncode(_buildResponse(
              events: [
                _event(id: 'ev-$callCount', name: 'Event $callCount'),
              ],
              lastUpdated: _now.toUtc().toIso8601String(),
            )),
            200,
          );
        });

        final service = _createService(mockClient: mockClient, cache: ttlCache);

        // Initial sync.
        await service.getEvents();

        // Expire.
        _now = _now.add(const Duration(hours: 6, minutes: 1));

        // Cache should report expired.
        expect(await service.getCachedEvents(), isNull,
            reason: 'Expired cache should return null');

        // getEvents() should fetch fresh data.
        final fresh = await service.getEvents();
        expect(fresh.cacheHit, isFalse);
        expect(fresh.events.first.name, 'Event 2');
      });

      test('multiple TTL cycles: cache expires, refreshes, expires again', () async {
        final inner = InMemoryEventCache();
        final ttlCache = TtlEventCache(
          inner: inner,
          ttl: const Duration(hours: 1),
          clock: () => _now,
        );

        var callCount = 0;
        final mockClient = MockClient((request) async {
          callCount++;
          return http.Response(
            jsonEncode(_buildResponse(
              events: [_event(id: 'ev-$callCount', name: 'Cycle $callCount')],
              lastUpdated: _now.toUtc().toIso8601String(),
            )),
            200,
          );
        });

        final service = _createService(mockClient: mockClient, cache: ttlCache);

        // Cycle 1: fetch and cache.
        await service.getEvents();
        expect(callCount, 1);

        // Expire cycle 1.
        _now = _now.add(const Duration(hours: 1, minutes: 1));

        // Cycle 2: fetch fresh.
        final second = await service.getEvents();
        expect(callCount, 2);
        expect(second.events.first.name, 'Cycle 2');

        // Expire cycle 2.
        _now = _now.add(const Duration(hours: 1, minutes: 1));

        // Cycle 3: fetch fresh again.
        final third = await service.getEvents();
        expect(callCount, 3);
        expect(third.events.first.name, 'Cycle 3');
      });

      test('each sync resets TTL even if cache had not yet expired', () async {
        final inner = InMemoryEventCache();
        final ttlCache = TtlEventCache(
          inner: inner,
          ttl: const Duration(hours: 6),
          clock: () => _now,
        );

        var callCount = 0;
        final mockClient = MockClient((request) async {
          callCount++;
          return http.Response(
            jsonEncode(_buildResponse(
              events: [_event(id: 'ev-$callCount', name: 'Event $callCount')],
              lastUpdated: _now.toUtc().toIso8601String(),
            )),
            200,
          );
        });

        final service = _createService(mockClient: mockClient, cache: ttlCache);

        // Initial sync at T+0.
        await service.getEvents();

        // Sync again at T+5h (within TTL) — this resets the timer.
        _now = _now.add(const Duration(hours: 5));
        await service.getEvents();

        // At T+10h (5h after second sync) — cache should still be valid.
        _now = _now.add(const Duration(hours: 5));
        final cached = await service.getCachedEvents();
        expect(cached, isNotNull,
            reason: 'TTL resets on each sync, so 5h after second put is still valid');

        // At T+11h01m (6h01m after second sync) — cache should expire.
        _now = _now.add(const Duration(hours: 1, minutes: 1));
        final expired = await service.getCachedEvents();
        expect(expired, isNull, reason: 'Cache should expire 6h after last sync');
      });
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
