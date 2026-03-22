import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gocalgo/services/events_service.dart';
import 'package:gocalgo/services/api_client.dart';
import 'package:gocalgo/models/buff_category.dart';
import 'package:gocalgo/models/event_type.dart';

/// Verifies acceptance criterion for story US-GCG-7:
/// "Today's active events are displayed with buff/bonus details"
///
/// Tests that the Flutter EventsService correctly fetches, filters, and
/// parses active events that include buff/bonus information.
void main() {
  group("Active events with buff/bonus details", () {
    late EventsService service;

    final now = DateTime(2026, 3, 21, 14, 0);

    setUp(() {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'events': [
              {
                'id': 'community-day-bulbasaur',
                'name': 'Community Day: Bulbasaur',
                'eventType': 'community-day',
                'heading': 'Catch Bulbasaur!',
                'imageUrl': 'https://example.com/bulbasaur.png',
                'linkUrl': 'https://example.com/community-day',
                'start': '2026-03-21T11:00:00.000',
                'end': '2026-03-21T17:00:00.000',
                'isUtcTime': false,
                'hasSpawns': true,
                'hasResearchTasks': true,
                'buffs': [
                  {
                    'text': '2\u00d7 Catch Stardust',
                    'iconUrl': 'https://example.com/stardust.png',
                    'category': 'multiplier',
                    'multiplier': 2.0,
                    'resource': 'Stardust',
                  },
                  {
                    'text': '3-hour Incense',
                    'iconUrl': 'https://example.com/incense.png',
                    'category': 'duration',
                    'resource': 'Incense',
                  },
                  {
                    'text': 'Increased Shiny rate',
                    'category': 'probability',
                  },
                ],
                'featuredPokemon': [],
                'promoCodes': [],
              },
              {
                'id': 'spotlight-hour',
                'name': 'Spotlight Hour: Pikachu',
                'eventType': 'spotlight-hour',
                'heading': 'Spotlight!',
                'imageUrl': 'https://example.com/pikachu.png',
                'linkUrl': 'https://example.com/spotlight',
                'start': '2026-03-21T18:00:00.000',
                'end': '2026-03-21T19:00:00.000',
                'isUtcTime': false,
                'hasSpawns': true,
                'hasResearchTasks': false,
                'buffs': [
                  {
                    'text': '2\u00d7 Transfer Candy',
                    'iconUrl': 'https://example.com/candy.png',
                    'category': 'multiplier',
                    'multiplier': 2.0,
                    'resource': 'Candy',
                  },
                ],
                'featuredPokemon': [],
                'promoCodes': [],
              },
              {
                'id': 'past-raid-hour',
                'name': 'Raid Hour (Past)',
                'eventType': 'raid-hour',
                'heading': 'Raid!',
                'imageUrl': 'https://example.com/raid.png',
                'linkUrl': 'https://example.com/raid',
                'start': '2026-03-20T18:00:00.000',
                'end': '2026-03-20T19:00:00.000',
                'isUtcTime': false,
                'hasSpawns': false,
                'hasResearchTasks': false,
                'buffs': [
                  {
                    'text': 'Extra Raid Pass',
                    'category': 'other',
                    'disclaimer': 'Up to 5 free passes',
                  },
                ],
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

    test('getActiveEvents returns only currently active events', () async {
      final active = await service.getActiveEvents(now: now);

      expect(active, hasLength(1));
      expect(active.first.id, 'community-day-bulbasaur');
    });

    test('active event includes buff list with correct count', () async {
      final active = await service.getActiveEvents(now: now);
      final event = active.first;

      expect(event.buffs, hasLength(3));
    });

    test('buff text is parsed correctly', () async {
      final active = await service.getActiveEvents(now: now);
      final buffs = active.first.buffs;

      expect(buffs[0].text, '2\u00d7 Catch Stardust');
      expect(buffs[1].text, '3-hour Incense');
      expect(buffs[2].text, 'Increased Shiny rate');
    });

    test('buff categories are parsed correctly', () async {
      final active = await service.getActiveEvents(now: now);
      final buffs = active.first.buffs;

      expect(buffs[0].category, BuffCategory.multiplier);
      expect(buffs[1].category, BuffCategory.duration);
      expect(buffs[2].category, BuffCategory.probability);
    });

    test('buff multiplier values are parsed correctly', () async {
      final active = await service.getActiveEvents(now: now);
      final buffs = active.first.buffs;

      expect(buffs[0].multiplier, 2.0);
      expect(buffs[1].multiplier, isNull);
      expect(buffs[2].multiplier, isNull);
    });

    test('buff resource names are parsed correctly', () async {
      final active = await service.getActiveEvents(now: now);
      final buffs = active.first.buffs;

      expect(buffs[0].resource, 'Stardust');
      expect(buffs[1].resource, 'Incense');
      expect(buffs[2].resource, isNull);
    });

    test('buff icon URLs are parsed correctly', () async {
      final active = await service.getActiveEvents(now: now);
      final buffs = active.first.buffs;

      expect(buffs[0].iconUrl, 'https://example.com/stardust.png');
      expect(buffs[1].iconUrl, 'https://example.com/incense.png');
      expect(buffs[2].iconUrl, isNull);
    });

    test('active event preserves event type and metadata', () async {
      final active = await service.getActiveEvents(now: now);
      final event = active.first;

      expect(event.name, 'Community Day: Bulbasaur');
      expect(event.eventType, EventType.communityDay);
      expect(event.hasSpawns, true);
      expect(event.hasResearchTasks, true);
    });

    test('past events with buffs are excluded from active list', () async {
      final active = await service.getActiveEvents(now: now);

      expect(active.map((e) => e.id), isNot(contains('past-raid-hour')));
    });

    test('upcoming events with buffs are excluded from active list', () async {
      final active = await service.getActiveEvents(now: now);

      expect(active.map((e) => e.id), isNot(contains('spotlight-hour')));
    });

    test('event with no buffs is still returned if active', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'events': [
              {
                'id': 'no-buff-event',
                'name': 'Season Change',
                'eventType': 'season',
                'heading': 'New Season',
                'imageUrl': 'https://example.com/season.png',
                'linkUrl': 'https://example.com/season',
                'start': '2026-03-01T00:00:00.000',
                'end': '2026-06-01T00:00:00.000',
                'isUtcTime': false,
                'hasSpawns': false,
                'hasResearchTasks': false,
                'buffs': [],
                'featuredPokemon': [],
                'promoCodes': [],
              }
            ],
            'lastUpdated': '2026-03-21T12:00:00Z',
            'cacheHit': false,
          }),
          200,
        );
      });

      final apiClient =
          ApiClient(httpClient: mockClient, baseUrl: 'http://test.local');
      final svc = EventsService(apiClient: apiClient);
      final active = await svc.getActiveEvents(now: now);

      expect(active, hasLength(1));
      expect(active.first.buffs, isEmpty);
    });
  });
}
