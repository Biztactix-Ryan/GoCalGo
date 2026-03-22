import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gocalgo/services/events_service.dart';
import 'package:gocalgo/services/api_client.dart';

/// Verifies acceptance criterion for story US-GCG-7:
/// "Pull-to-refresh updates event data from the API"
///
/// Tests that successive calls to EventsService.getActiveEvents() hit the
/// API each time and return the latest data — the behaviour required for
/// pull-to-refresh to surface updated events.
void main() {
  group('Pull-to-refresh updates event data', () {
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
      String eventType = 'general',
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

    test('each call fetches fresh data from the API', () async {
      var callCount = 0;

      final mockClient = MockClient((request) async {
        callCount++;
        return http.Response(
          jsonEncode(_buildResponse(
            events: [_event(id: 'ev-1', name: 'Event 1')],
            lastUpdated: '2026-03-21T12:00:00Z',
          )),
          200,
        );
      });

      final apiClient =
          ApiClient(httpClient: mockClient, baseUrl: 'http://test.local');
      final service = EventsService(apiClient: apiClient);

      await service.getActiveEvents(now: now);
      await service.getActiveEvents(now: now);

      expect(callCount, 2,
          reason: 'Each call should hit the API — no client-side caching');
    });

    test('refreshed data reflects newly added events', () async {
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
        // Second call returns an additional event (simulating server-side update).
        return http.Response(
          jsonEncode(_buildResponse(
            events: [
              _event(id: 'ev-1', name: 'Event 1'),
              _event(id: 'ev-2', name: 'Event 2'),
            ],
            lastUpdated: '2026-03-21T14:05:00Z',
          )),
          200,
        );
      });

      final apiClient =
          ApiClient(httpClient: mockClient, baseUrl: 'http://test.local');
      final service = EventsService(apiClient: apiClient);

      final first = await service.getActiveEvents(now: now);
      expect(first, hasLength(1));
      expect(first.first.id, 'ev-1');

      final refreshed = await service.getActiveEvents(now: now);
      expect(refreshed, hasLength(2));
      expect(refreshed.map((e) => e.id), containsAll(['ev-1', 'ev-2']));
    });

    test('refreshed data reflects removed events', () async {
      var callCount = 0;

      final mockClient = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          return http.Response(
            jsonEncode(_buildResponse(
              events: [
                _event(id: 'ev-1', name: 'Event 1'),
                _event(id: 'ev-2', name: 'Event 2'),
              ],
              lastUpdated: '2026-03-21T12:00:00Z',
            )),
            200,
          );
        }
        // Event ended / was removed server-side.
        return http.Response(
          jsonEncode(_buildResponse(
            events: [_event(id: 'ev-1', name: 'Event 1')],
            lastUpdated: '2026-03-21T14:10:00Z',
          )),
          200,
        );
      });

      final apiClient =
          ApiClient(httpClient: mockClient, baseUrl: 'http://test.local');
      final service = EventsService(apiClient: apiClient);

      final first = await service.getActiveEvents(now: now);
      expect(first, hasLength(2));

      final refreshed = await service.getActiveEvents(now: now);
      expect(refreshed, hasLength(1));
      expect(refreshed.first.id, 'ev-1');
    });

    test('refreshed data reflects updated event details', () async {
      var callCount = 0;

      final mockClient = MockClient((request) async {
        callCount++;
        if (callCount == 1) {
          return http.Response(
            jsonEncode(_buildResponse(
              events: [_event(id: 'ev-1', name: 'Original Name')],
              lastUpdated: '2026-03-21T12:00:00Z',
            )),
            200,
          );
        }
        return http.Response(
          jsonEncode(_buildResponse(
            events: [_event(id: 'ev-1', name: 'Updated Name')],
            lastUpdated: '2026-03-21T14:15:00Z',
          )),
          200,
        );
      });

      final apiClient =
          ApiClient(httpClient: mockClient, baseUrl: 'http://test.local');
      final service = EventsService(apiClient: apiClient);

      final first = await service.getActiveEvents(now: now);
      expect(first.first.name, 'Original Name');

      final refreshed = await service.getActiveEvents(now: now);
      expect(refreshed.first.name, 'Updated Name');
    });

    test('refresh updates lastUpdated timestamp', () async {
      var callCount = 0;

      final mockClient = MockClient((request) async {
        callCount++;
        return http.Response(
          jsonEncode(_buildResponse(
            events: [_event(id: 'ev-1', name: 'Event 1')],
            lastUpdated: callCount == 1
                ? '2026-03-21T12:00:00Z'
                : '2026-03-21T14:30:00Z',
          )),
          200,
        );
      });

      final apiClient =
          ApiClient(httpClient: mockClient, baseUrl: 'http://test.local');
      final service = EventsService(apiClient: apiClient);

      final first = await service.getEvents();
      expect(first.lastUpdated, DateTime.utc(2026, 3, 21, 12, 0));

      final refreshed = await service.getEvents();
      expect(refreshed.lastUpdated, DateTime.utc(2026, 3, 21, 14, 30));
      expect(refreshed.lastUpdated.isAfter(first.lastUpdated), isTrue);
    });

    test('refresh after API error still fetches fresh data on retry',
        () async {
      var callCount = 0;

      final mockClient = MockClient((request) async {
        callCount++;
        if (callCount == 2) {
          return http.Response('Internal Server Error', 500);
        }
        return http.Response(
          jsonEncode(_buildResponse(
            events: [_event(id: 'ev-1', name: 'Event 1')],
            lastUpdated: '2026-03-21T12:00:00Z',
          )),
          200,
        );
      });

      final apiClient =
          ApiClient(httpClient: mockClient, baseUrl: 'http://test.local');
      final service = EventsService(apiClient: apiClient);

      // First call succeeds.
      final first = await service.getActiveEvents(now: now);
      expect(first, hasLength(1));

      // Second call fails.
      expect(
        () => service.getActiveEvents(now: now),
        throwsA(isA<ApiException>()),
      );

      // Third call succeeds — refresh recovers after transient failure.
      final recovered = await service.getActiveEvents(now: now);
      expect(recovered, hasLength(1));
      expect(callCount, 3);
    });
  });
}
