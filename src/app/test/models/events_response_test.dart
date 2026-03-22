import 'package:flutter_test/flutter_test.dart';
import 'package:gocalgo/models/events_response.dart';
import 'package:gocalgo/models/event_dto.dart';
import 'package:gocalgo/models/event_type.dart';

/// Unit tests for EventsResponse model JSON serialisation.
void main() {
  group('EventsResponse', () {
    test('fromJson() parses response with events', () {
      final json = {
        'events': [
          {
            'id': 'evt-1',
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
        'lastUpdated': '2026-03-21T12:00:00.000Z',
        'cacheHit': true,
      };

      final response = EventsResponse.fromJson(json);

      expect(response.events, hasLength(1));
      expect(response.events.first.id, 'evt-1');
      expect(response.lastUpdated, DateTime.utc(2026, 3, 21, 12));
      expect(response.cacheHit, true);
    });

    test('fromJson() handles empty events list', () {
      final json = {
        'events': [],
        'lastUpdated': '2026-03-21T00:00:00.000Z',
        'cacheHit': false,
      };

      final response = EventsResponse.fromJson(json);

      expect(response.events, isEmpty);
      expect(response.cacheHit, false);
    });

    test('toJson() round-trips correctly', () {
      final original = EventsResponse(
        events: [
          EventDto(
            id: 'evt-2',
            name: 'Round Trip Event',
            eventType: EventType.raidHour,
            heading: 'Raid Hour',
            imageUrl: 'https://example.com/raid.png',
            linkUrl: 'https://example.com/raid',
            start: DateTime(2026, 4, 2, 18, 0),
            end: DateTime(2026, 4, 2, 19, 0),
            isUtcTime: false,
            hasSpawns: false,
            hasResearchTasks: false,
            buffs: [],
            featuredPokemon: [],
            promoCodes: [],
          ),
        ],
        lastUpdated: DateTime.utc(2026, 3, 21, 15, 30),
        cacheHit: false,
      );

      final reJson = original.toJson();
      final restored = EventsResponse.fromJson(reJson);

      expect(restored.events, hasLength(1));
      expect(restored.events.first.id, 'evt-2');
      expect(restored.events.first.eventType, EventType.raidHour);
      expect(restored.cacheHit, false);
    });
  });

  group('EventType', () {
    test('fromJson() maps known values', () {
      expect(EventType.fromJson('community-day'), EventType.communityDay);
      expect(EventType.fromJson('spotlight-hour'), EventType.spotlightHour);
      expect(EventType.fromJson('raid-hour'), EventType.raidHour);
      expect(EventType.fromJson('go-battle-league'), EventType.goBattleLeague);
      expect(EventType.fromJson('pokemon-go-fest'), EventType.pokemonGoFest);
      expect(EventType.fromJson('safari-zone'), EventType.safariZone);
      expect(EventType.fromJson('season'), EventType.season);
    });

    test('fromJson() falls back to other for unknown values', () {
      expect(EventType.fromJson('unknown-type'), EventType.other);
    });

    test('toJson() round-trips all values', () {
      for (final type in EventType.values) {
        expect(EventType.fromJson(type.toJson()), type);
      }
    });
  });
}
