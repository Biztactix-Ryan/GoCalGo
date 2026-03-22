import 'package:flutter_test/flutter_test.dart';
import 'package:gocalgo/models/event_dto.dart';
import 'package:gocalgo/models/event_type.dart';
import 'package:gocalgo/models/buff.dart';
import 'package:gocalgo/models/buff_category.dart';
import 'package:gocalgo/models/pokemon.dart';
import 'package:gocalgo/models/pokemon_role.dart';

/// Unit tests for EventDto model JSON serialisation round-trip and edge cases.
void main() {
  final fullJson = {
    'id': 'evt-001',
    'name': 'Community Day: Charmander',
    'eventType': 'community-day',
    'heading': 'Community Day',
    'imageUrl': 'https://example.com/charmander.png',
    'linkUrl': 'https://example.com/event/evt-001',
    'start': '2026-04-01T11:00:00.000',
    'end': '2026-04-01T14:00:00.000',
    'isUtcTime': false,
    'hasSpawns': true,
    'hasResearchTasks': true,
    'buffs': [
      {
        'text': '3× Catch XP',
        'iconUrl': 'https://example.com/xp.png',
        'category': 'multiplier',
        'multiplier': 3.0,
        'resource': 'XP',
        'disclaimer': 'During event hours only',
      }
    ],
    'featuredPokemon': [
      {
        'name': 'Charmander',
        'imageUrl': 'https://example.com/charmander-sprite.png',
        'canBeShiny': true,
        'role': 'spawn',
      }
    ],
    'promoCodes': ['CDAY2026'],
  };

  group('EventDto', () {
    test('fromJson() parses all fields correctly', () {
      final dto = EventDto.fromJson(fullJson);

      expect(dto.id, 'evt-001');
      expect(dto.name, 'Community Day: Charmander');
      expect(dto.eventType, EventType.communityDay);
      expect(dto.heading, 'Community Day');
      expect(dto.imageUrl, 'https://example.com/charmander.png');
      expect(dto.linkUrl, 'https://example.com/event/evt-001');
      expect(dto.start, DateTime.parse('2026-04-01T11:00:00.000'));
      expect(dto.end, DateTime.parse('2026-04-01T14:00:00.000'));
      expect(dto.isUtcTime, false);
      expect(dto.hasSpawns, true);
      expect(dto.hasResearchTasks, true);
      expect(dto.buffs, hasLength(1));
      expect(dto.buffs.first.text, '3× Catch XP');
      expect(dto.featuredPokemon, hasLength(1));
      expect(dto.featuredPokemon.first.name, 'Charmander');
      expect(dto.promoCodes, ['CDAY2026']);
    });

    test('fromJson() handles null start and end', () {
      final json = Map<String, dynamic>.from(fullJson)
        ..['start'] = null
        ..['end'] = null;

      final dto = EventDto.fromJson(json);

      expect(dto.start, isNull);
      expect(dto.end, isNull);
    });

    test('fromJson() handles empty nested lists', () {
      final json = Map<String, dynamic>.from(fullJson)
        ..['buffs'] = []
        ..['featuredPokemon'] = []
        ..['promoCodes'] = [];

      final dto = EventDto.fromJson(json);

      expect(dto.buffs, isEmpty);
      expect(dto.featuredPokemon, isEmpty);
      expect(dto.promoCodes, isEmpty);
    });

    test('toJson() round-trips back to equivalent JSON', () {
      final dto = EventDto.fromJson(fullJson);
      final reJson = dto.toJson();

      expect(reJson['id'], fullJson['id']);
      expect(reJson['name'], fullJson['name']);
      expect(reJson['eventType'], fullJson['eventType']);
      expect(reJson['isUtcTime'], fullJson['isUtcTime']);
      expect(reJson['hasSpawns'], fullJson['hasSpawns']);
      expect(reJson['hasResearchTasks'], fullJson['hasResearchTasks']);
      expect((reJson['buffs'] as List), hasLength(1));
      expect((reJson['featuredPokemon'] as List), hasLength(1));
      expect(reJson['promoCodes'], fullJson['promoCodes']);
    });

    test('toJson() omits start and end when null', () {
      final json = Map<String, dynamic>.from(fullJson)
        ..['start'] = null
        ..['end'] = null;

      final dto = EventDto.fromJson(json);
      final reJson = dto.toJson();

      expect(reJson.containsKey('start'), false);
      expect(reJson.containsKey('end'), false);
    });
  });
}
