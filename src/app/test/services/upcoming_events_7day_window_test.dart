import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gocalgo/services/events_service.dart';
import 'package:gocalgo/services/api_client.dart';

/// Helper to build a minimal event JSON map.
Map<String, dynamic> _event(String id, String name, String start, String end) =>
    {
      'id': id,
      'name': name,
      'eventType': 'event',
      'heading': name,
      'imageUrl': 'https://example.com/img.png',
      'linkUrl': 'https://example.com/$id',
      'start': start,
      'end': end,
      'isUtcTime': false,
      'hasSpawns': false,
      'hasResearchTasks': false,
      'buffs': <dynamic>[],
      'featuredPokemon': <dynamic>[],
      'promoCodes': <String>[],
    };

void main() {
  // Fixed "now" for all tests: 2026-03-21 12:00
  final now = DateTime(2026, 3, 21, 12, 0);

  group('Upcoming events 7-day window', () {
    late EventsService service;

    setUp(() {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'events': [
              // Past event — ended before now
              _event('past', 'Past Event',
                  '2026-03-10T10:00:00.000', '2026-03-10T11:00:00.000'),
              // Active event — started before now, ends after now
              _event('active', 'Active Event',
                  '2026-03-20T10:00:00.000', '2026-03-22T17:00:00.000'),
              // Upcoming within 7 days — starts day 2 from now
              _event('upcoming-2d', 'Community Day',
                  '2026-03-23T14:00:00.000', '2026-03-23T17:00:00.000'),
              // Upcoming within 7 days — starts day 6 from now
              _event('upcoming-6d', 'Raid Hour',
                  '2026-03-27T18:00:00.000', '2026-03-27T19:00:00.000'),
              // Upcoming exactly at 7-day boundary
              _event('upcoming-7d', 'Spotlight Hour',
                  '2026-03-28T12:00:00.000', '2026-03-28T13:00:00.000'),
              // Upcoming beyond 7 days — starts day 14 from now
              _event('upcoming-14d', 'Go Fest',
                  '2026-04-04T10:00:00.000', '2026-04-05T20:00:00.000'),
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

    test('returns only events starting within 7 days', () async {
      final upcoming = await service.getUpcomingEvents(now: now, days: 7);
      final ids = upcoming.map((e) => e.id).toList();

      expect(ids, contains('upcoming-2d'));
      expect(ids, contains('upcoming-6d'));
      expect(ids, contains('upcoming-7d'));
      expect(ids, isNot(contains('past')));
      expect(ids, isNot(contains('active')));
      expect(ids, isNot(contains('upcoming-14d')));
    });

    test('excludes events starting beyond 7 days', () async {
      final upcoming = await service.getUpcomingEvents(now: now, days: 7);

      expect(upcoming.every((e) =>
          e.start != null &&
          e.start!.isAfter(now) &&
          !e.start!.isAfter(now.add(const Duration(days: 7)))), isTrue);
    });

    test('excludes past and currently active events', () async {
      final upcoming = await service.getUpcomingEvents(now: now, days: 7);
      final ids = upcoming.map((e) => e.id).toSet();

      expect(ids, isNot(contains('past')));
      expect(ids, isNot(contains('active')));
    });

    test('without days parameter returns all future events', () async {
      final all = await service.getUpcomingEvents(now: now);
      final ids = all.map((e) => e.id).toList();

      expect(ids, contains('upcoming-2d'));
      expect(ids, contains('upcoming-6d'));
      expect(ids, contains('upcoming-7d'));
      expect(ids, contains('upcoming-14d'));
      expect(ids, isNot(contains('past')));
      expect(ids, isNot(contains('active')));
    });

    test('returns events in API order', () async {
      final upcoming = await service.getUpcomingEvents(now: now, days: 7);

      expect(upcoming, hasLength(3));
      expect(upcoming[0].id, 'upcoming-2d');
      expect(upcoming[1].id, 'upcoming-6d');
      expect(upcoming[2].id, 'upcoming-7d');
    });
  });
}
