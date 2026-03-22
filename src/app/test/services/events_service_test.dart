import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gocalgo/services/events_service.dart';
import 'package:gocalgo/services/api_client.dart';

void main() {
  group('EventsService', () {
    test('getEvents() returns parsed EventsResponse', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'events': [
              {
                'id': 'test-event-1',
                'name': 'Test Event',
                'eventType': 'event',
                'heading': 'Event',
                'imageUrl': 'https://example.com/img.png',
                'linkUrl': 'https://example.com/event',
                'start': '2026-04-01T10:00:00.000',
                'end': '2026-04-01T17:00:00.000',
                'isUtcTime': false,
                'hasSpawns': true,
                'hasResearchTasks': false,
                'buffs': [],
                'featuredPokemon': [],
                'promoCodes': [],
              }
            ],
            'lastUpdated': '2026-03-21T12:00:00Z',
            'cacheHit': true,
          }),
          200,
        );
      });

      final apiClient = ApiClient(httpClient: mockClient, baseUrl: 'http://test.local');
      final service = EventsService(apiClient: apiClient);
      final response = await service.getEvents();

      expect(response.events, hasLength(1));
      expect(response.events.first.name, 'Test Event');
      expect(response.events.first.hasSpawns, true);
      expect(response.cacheHit, true);
    });

    group('active and upcoming filtering', () {
      late EventsService service;

      setUp(() {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'events': [
                {
                  'id': 'active-event',
                  'name': 'Active Event',
                  'eventType': 'event',
                  'heading': 'Active',
                  'imageUrl': 'https://example.com/img.png',
                  'linkUrl': 'https://example.com/event',
                  'start': '2026-03-20T10:00:00.000',
                  'end': '2026-03-22T17:00:00.000',
                  'isUtcTime': false,
                  'hasSpawns': false,
                  'hasResearchTasks': false,
                  'buffs': [],
                  'featuredPokemon': [],
                  'promoCodes': [],
                },
                {
                  'id': 'upcoming-event',
                  'name': 'Upcoming Event',
                  'eventType': 'community-day',
                  'heading': 'Upcoming',
                  'imageUrl': 'https://example.com/img.png',
                  'linkUrl': 'https://example.com/event',
                  'start': '2026-04-01T10:00:00.000',
                  'end': '2026-04-01T17:00:00.000',
                  'isUtcTime': false,
                  'hasSpawns': true,
                  'hasResearchTasks': false,
                  'buffs': [],
                  'featuredPokemon': [],
                  'promoCodes': [],
                },
                {
                  'id': 'past-event',
                  'name': 'Past Event',
                  'eventType': 'raid-hour',
                  'heading': 'Past',
                  'imageUrl': 'https://example.com/img.png',
                  'linkUrl': 'https://example.com/event',
                  'start': '2026-03-10T10:00:00.000',
                  'end': '2026-03-10T11:00:00.000',
                  'isUtcTime': false,
                  'hasSpawns': false,
                  'hasResearchTasks': false,
                  'buffs': [],
                  'featuredPokemon': [],
                  'promoCodes': [],
                },
              ],
              'lastUpdated': '2026-03-21T12:00:00Z',
              'cacheHit': false,
            }),
            200,
          );
        });

        final apiClient =
            ApiClient(httpClient: mockClient, baseUrl: 'http://test.local');
        service = EventsService(apiClient: apiClient);
      });

      final now = DateTime(2026, 3, 21, 12, 0);

      test('getActiveEvents() returns only currently active events', () async {
        final active = await service.getActiveEvents(now: now);
        expect(active, hasLength(1));
        expect(active.first.id, 'active-event');
      });

      test('getUpcomingEvents() returns only future events', () async {
        final upcoming = await service.getUpcomingEvents(now: now);
        expect(upcoming, hasLength(1));
        expect(upcoming.first.id, 'upcoming-event');
      });
    });
  });
}
