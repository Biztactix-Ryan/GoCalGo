import 'package:flutter_test/flutter_test.dart';
import 'package:gocalgo/models/buff.dart';
import 'package:gocalgo/models/buff_category.dart';
import 'package:gocalgo/models/event_dto.dart';
import 'package:gocalgo/models/event_type.dart';
import 'package:gocalgo/models/pokemon.dart';
import 'package:gocalgo/models/pokemon_role.dart';
import 'package:gocalgo/services/event_time_display.dart';

/// Comprehensive edge-case tests for event models, timezone logic, and
/// buff/bonus mapping — filling gaps in the existing unit test suite.
void main() {
  // ── EventDto — unknown and edge-case event types ──

  group('EventDto — unknown event types', () {
    Map<String, dynamic> _baseJson({String eventType = 'event'}) => {
          'id': 'edge-1',
          'name': 'Edge Case Event',
          'eventType': eventType,
          'heading': 'Edge',
          'imageUrl': 'https://example.com/img.png',
          'linkUrl': 'https://example.com/evt',
          'start': '2026-05-01T10:00:00.000',
          'end': '2026-05-01T17:00:00.000',
          'isUtcTime': false,
          'hasSpawns': false,
          'hasResearchTasks': false,
          'buffs': <dynamic>[],
          'featuredPokemon': <dynamic>[],
          'promoCodes': <dynamic>[],
        };

    test('fromJson() maps unknown eventType string to EventType.other', () {
      final dto = EventDto.fromJson(_baseJson(eventType: 'mega-evolution-event'));

      expect(dto.eventType, EventType.other);
    });

    test('toJson() serialises EventType.other back to "other"', () {
      final dto = EventDto.fromJson(_baseJson(eventType: 'never-seen-before'));
      final json = dto.toJson();

      expect(json['eventType'], 'other');
    });

    test('round-trip through unknown type loses original string', () {
      final dto = EventDto.fromJson(_baseJson(eventType: 'wild-area-event'));
      final restored = EventDto.fromJson(dto.toJson());

      expect(restored.eventType, EventType.other);
    });

    test('every known EventType value round-trips through EventDto', () {
      for (final type in EventType.values) {
        final dto = EventDto.fromJson(_baseJson(eventType: type.toJson()));
        expect(dto.eventType, type,
            reason: '${type.value} should survive fromJson');

        final reJson = dto.toJson();
        expect(reJson['eventType'], type.toJson(),
            reason: '${type.value} should survive toJson');
      }
    });
  });

  // ── EventDto — UTC timestamp parsing ──

  group('EventDto — UTC timestamp parsing', () {
    Map<String, dynamic> _baseJson({String? start, String? end}) => {
          'id': 'utc-parse-1',
          'name': 'UTC Parse Test',
          'eventType': 'pokemon-go-fest',
          'heading': 'GO Fest',
          'imageUrl': '',
          'linkUrl': '',
          'start': start,
          'end': end,
          'isUtcTime': true,
          'hasSpawns': false,
          'hasResearchTasks': false,
          'buffs': <dynamic>[],
          'featuredPokemon': <dynamic>[],
          'promoCodes': <dynamic>[],
        };

    test('Z-suffix timestamp parses as UTC DateTime', () {
      final dto = EventDto.fromJson(
        _baseJson(start: '2026-06-07T10:00:00.000Z'),
      );

      expect(dto.start, isNotNull);
      expect(dto.start!.isUtc, isTrue);
      expect(dto.start!.hour, 10);
    });

    test('timestamp without Z parses as local DateTime', () {
      final dto = EventDto.fromJson(
        _baseJson(start: '2026-06-07T10:00:00.000'),
      );

      expect(dto.start, isNotNull);
      expect(dto.start!.isUtc, isFalse);
    });

    test('toJson serialises UTC DateTime with Z suffix', () {
      final dto = EventDto(
        id: 'utc-ser',
        name: 'UTC Serialise',
        eventType: EventType.pokemonGoFest,
        heading: 'Fest',
        imageUrl: '',
        linkUrl: '',
        start: DateTime.utc(2026, 6, 7, 10, 0),
        end: DateTime.utc(2026, 6, 7, 18, 0),
        isUtcTime: true,
        hasSpawns: false,
        hasResearchTasks: false,
        buffs: const [],
        featuredPokemon: const [],
        promoCodes: const [],
      );

      final json = dto.toJson();

      expect((json['start'] as String).endsWith('Z'), isTrue);
      expect((json['end'] as String).endsWith('Z'), isTrue);
    });

    test('local DateTime toJson does NOT end with Z', () {
      final dto = EventDto(
        id: 'local-ser',
        name: 'Local Serialise',
        eventType: EventType.communityDay,
        heading: 'CD',
        imageUrl: '',
        linkUrl: '',
        start: DateTime(2026, 3, 15, 14, 0),
        end: DateTime(2026, 3, 15, 17, 0),
        isUtcTime: false,
        hasSpawns: false,
        hasResearchTasks: false,
        buffs: const [],
        featuredPokemon: const [],
        promoCodes: const [],
      );

      final json = dto.toJson();

      expect((json['start'] as String).endsWith('Z'), isFalse);
    });
  });

  // ── EventDto — multiple nested collections ──

  group('EventDto — rich nested data', () {
    test('fromJson parses multiple buffs with different categories', () {
      final json = {
        'id': 'multi-buff',
        'name': 'Multi-buff Event',
        'eventType': 'community-day',
        'heading': 'Community Day',
        'imageUrl': '',
        'linkUrl': '',
        'isUtcTime': false,
        'hasSpawns': true,
        'hasResearchTasks': true,
        'buffs': [
          {'text': '3× Catch XP', 'category': 'multiplier', 'multiplier': 3.0, 'resource': 'XP'},
          {'text': '2× Catch Stardust', 'category': 'multiplier', 'multiplier': 2.0, 'resource': 'Stardust'},
          {'text': 'Longer lure duration', 'category': 'duration'},
          {'text': 'Increased shiny rate', 'category': 'probability'},
          {'text': 'Special trades available', 'category': 'trade'},
        ],
        'featuredPokemon': [
          {'name': 'Charmander', 'imageUrl': '', 'canBeShiny': true, 'role': 'spawn'},
          {'name': 'Charizard', 'imageUrl': '', 'canBeShiny': true, 'role': 'raid-boss'},
          {'name': 'Charmeleon', 'imageUrl': '', 'canBeShiny': false, 'role': 'research-reward'},
        ],
        'promoCodes': ['CDAY1', 'CDAY2', 'CDAY3'],
      };

      final dto = EventDto.fromJson(json);

      expect(dto.buffs, hasLength(5));
      expect(dto.buffs[0].category, BuffCategory.multiplier);
      expect(dto.buffs[2].category, BuffCategory.duration);
      expect(dto.buffs[3].category, BuffCategory.probability);
      expect(dto.buffs[4].category, BuffCategory.trade);

      expect(dto.featuredPokemon, hasLength(3));
      expect(dto.featuredPokemon[0].role, PokemonRole.spawn);
      expect(dto.featuredPokemon[1].role, PokemonRole.raidBoss);
      expect(dto.featuredPokemon[2].role, PokemonRole.researchReward);
      expect(dto.featuredPokemon[2].canBeShiny, isFalse);

      expect(dto.promoCodes, ['CDAY1', 'CDAY2', 'CDAY3']);
    });

    test('round-trip preserves all nested collection data', () {
      final original = EventDto(
        id: 'rt-nested',
        name: 'Round Trip Nested',
        eventType: EventType.communityDay,
        heading: 'CD',
        imageUrl: '',
        linkUrl: '',
        start: DateTime(2026, 4, 1, 14, 0),
        end: DateTime(2026, 4, 1, 17, 0),
        isUtcTime: false,
        hasSpawns: true,
        hasResearchTasks: true,
        buffs: const [
          Buff(text: '3× XP', category: BuffCategory.multiplier, multiplier: 3.0, resource: 'XP'),
          Buff(text: 'Longer lures', category: BuffCategory.duration),
        ],
        featuredPokemon: const [
          Pokemon(name: 'Pikachu', imageUrl: '', canBeShiny: true, role: PokemonRole.spotlight),
        ],
        promoCodes: const ['CODE1'],
      );

      final restored = EventDto.fromJson(original.toJson());

      expect(restored.buffs, hasLength(2));
      expect(restored.buffs[0].text, '3× XP');
      expect(restored.buffs[0].multiplier, 3.0);
      expect(restored.buffs[1].text, 'Longer lures');
      expect(restored.buffs[1].multiplier, isNull);

      expect(restored.featuredPokemon, hasLength(1));
      expect(restored.featuredPokemon.first.name, 'Pikachu');
      expect(restored.featuredPokemon.first.role, PokemonRole.spotlight);

      expect(restored.promoCodes, ['CODE1']);
    });
  });

  // ── Buff — integer and edge-case multiplier coercion ──

  group('Buff — multiplier edge cases', () {
    test('integer multiplier from JSON is coerced to double', () {
      final json = {
        'text': '3× Catch XP',
        'category': 'multiplier',
        'multiplier': 3, // int, not double
        'resource': 'XP',
      };

      final buff = Buff.fromJson(json);

      expect(buff.multiplier, isA<double>());
      expect(buff.multiplier, 3.0);
    });

    test('fractional multiplier is preserved', () {
      final json = {
        'text': '1.5× Hatch distance',
        'category': 'multiplier',
        'multiplier': 1.5,
      };

      final buff = Buff.fromJson(json);

      expect(buff.multiplier, 1.5);
    });

    test('zero multiplier is valid', () {
      final json = {
        'text': 'No candy cost for trade',
        'category': 'trade',
        'multiplier': 0,
      };

      final buff = Buff.fromJson(json);

      expect(buff.multiplier, 0.0);
    });

    test('buff with unknown category defaults to other', () {
      final json = {
        'text': 'New mysterious bonus',
        'category': 'quantum-entanglement',
      };

      final buff = Buff.fromJson(json);

      expect(buff.category, BuffCategory.other);
    });

    test('buff round-trip preserves unknown-category-as-other', () {
      final json = {
        'text': 'Futuristic bonus',
        'category': 'time-travel',
      };

      final buff = Buff.fromJson(json);
      final restored = Buff.fromJson(buff.toJson());

      expect(restored.category, BuffCategory.other);
      expect(restored.text, 'Futuristic bonus');
    });
  });

  // ── Combined model parsing + timezone display pipeline ──

  group('Full pipeline: JSON → EventDto → EventTimeDisplay', () {
    test('UTC GO Fest event: JSON parse → local display conversion', () {
      final json = {
        'id': 'gofest-2026',
        'name': 'GO Fest 2026',
        'eventType': 'pokemon-go-fest',
        'heading': 'GO Fest',
        'imageUrl': '',
        'linkUrl': '',
        'start': '2026-06-07T10:00:00.000Z',
        'end': '2026-06-07T18:00:00.000Z',
        'isUtcTime': true,
        'hasSpawns': true,
        'hasResearchTasks': true,
        'buffs': [
          {'text': '2× Incense duration', 'category': 'duration', 'multiplier': 2},
        ],
        'featuredPokemon': <dynamic>[],
        'promoCodes': <dynamic>[],
      };

      final dto = EventDto.fromJson(json);
      final localStart = EventTimeDisplay.localStart(dto);
      final localEnd = EventTimeDisplay.localEnd(dto);

      expect(dto.eventType, EventType.pokemonGoFest);
      expect(dto.buffs.first.multiplier, 2.0);

      expect(localStart, isNotNull);
      expect(localStart!.isUtc, isFalse);
      expect(localStart, equals(DateTime.utc(2026, 6, 7, 10).toLocal()));
      expect(localEnd, equals(DateTime.utc(2026, 6, 7, 18).toLocal()));
    });

    test('local Community Day: JSON parse → wall-clock preserved', () {
      final json = {
        'id': 'cd-mar-2026',
        'name': 'Community Day: March',
        'eventType': 'community-day',
        'heading': 'Community Day',
        'imageUrl': '',
        'linkUrl': '',
        'start': '2026-03-21T14:00:00.000',
        'end': '2026-03-21T17:00:00.000',
        'isUtcTime': false,
        'hasSpawns': true,
        'hasResearchTasks': false,
        'buffs': [
          {'text': '3× Catch XP', 'category': 'multiplier', 'multiplier': 3.0, 'resource': 'XP'},
          {'text': '2× Catch Stardust', 'category': 'multiplier', 'multiplier': 2.0, 'resource': 'Stardust'},
          {'text': 'Longer lure modules', 'category': 'duration'},
        ],
        'featuredPokemon': [
          {'name': 'Bulbasaur', 'imageUrl': '', 'canBeShiny': true, 'role': 'spawn'},
        ],
        'promoCodes': <dynamic>[],
      };

      final dto = EventDto.fromJson(json);
      final localStart = EventTimeDisplay.localStart(dto);
      final localEnd = EventTimeDisplay.localEnd(dto);
      final range = EventTimeDisplay.formatTimeRange(dto);

      expect(dto.eventType, EventType.communityDay);
      expect(dto.buffs, hasLength(3));
      expect(dto.featuredPokemon.first.canBeShiny, isTrue);

      expect(localStart!.hour, 14);
      expect(localEnd!.hour, 17);
      expect(range, '2:00 PM – 5:00 PM');
    });

    test('event with null times: display gracefully degrades', () {
      final json = {
        'id': 'tbd-event',
        'name': 'Dates TBD Season',
        'eventType': 'season',
        'heading': 'Season',
        'imageUrl': '',
        'linkUrl': '',
        'start': null,
        'end': null,
        'isUtcTime': false,
        'hasSpawns': false,
        'hasResearchTasks': false,
        'buffs': <dynamic>[],
        'featuredPokemon': <dynamic>[],
        'promoCodes': <dynamic>[],
      };

      final dto = EventDto.fromJson(json);

      expect(EventTimeDisplay.localStart(dto), isNull);
      expect(EventTimeDisplay.localEnd(dto), isNull);
      expect(EventTimeDisplay.formatTimeRange(dto), 'Time TBD');
      expect(EventTimeDisplay.formatDate(dto), 'Date TBD');
    });
  });

  // ── isUtcTime=true with non-UTC DateTime (re-wrapping logic) ──

  group('EventTimeDisplay — _toDisplayTime re-wrapping', () {
    EventDto _makeEvent({
      DateTime? start,
      DateTime? end,
      required bool isUtcTime,
    }) =>
        EventDto(
          id: 'rewrap-test',
          name: 'Rewrap Test',
          eventType: EventType.event,
          heading: 'Test',
          imageUrl: '',
          linkUrl: '',
          start: start,
          end: end,
          isUtcTime: isUtcTime,
          hasSpawns: false,
          hasResearchTasks: false,
          buffs: const [],
          featuredPokemon: const [],
          promoCodes: const [],
        );

    test('isUtcTime=true with local DateTime re-interprets as UTC then converts', () {
      // Simulates a parsed timestamp without Z that the API flags as UTC.
      // _toDisplayTime wraps it in DateTime.utc(...) then calls toLocal().
      final nonUtcDateTime = DateTime(2026, 6, 7, 10, 0); // not .isUtc
      final event = _makeEvent(start: nonUtcDateTime, isUtcTime: true);

      final display = EventTimeDisplay.localStart(event)!;

      // Should be equivalent to treating 10:00 as UTC and converting.
      final expectedUtc = DateTime.utc(2026, 6, 7, 10, 0);
      expect(display, equals(expectedUtc.toLocal()));
      expect(display.isUtc, isFalse);
    });

    test('isUtcTime=true with actual UTC DateTime converts directly', () {
      final utcDateTime = DateTime.utc(2026, 6, 7, 10, 0);
      final event = _makeEvent(start: utcDateTime, isUtcTime: true);

      final display = EventTimeDisplay.localStart(event)!;

      expect(display, equals(utcDateTime.toLocal()));
      expect(display.isUtc, isFalse);
    });

    test('both paths produce identical result for same hour/minute', () {
      final local = DateTime(2026, 6, 7, 10, 0);
      final utc = DateTime.utc(2026, 6, 7, 10, 0);

      final eventLocal = _makeEvent(start: local, isUtcTime: true);
      final eventUtc = _makeEvent(start: utc, isUtcTime: true);

      final displayLocal = EventTimeDisplay.localStart(eventLocal)!;
      final displayUtc = EventTimeDisplay.localStart(eventUtc)!;

      expect(displayLocal, equals(displayUtc));
    });
  });

  // ── DST boundary + model parsing combined tests ──

  group('DST boundaries — full JSON parse pipeline', () {
    test('UTC event during US spring-forward gap parses and converts', () {
      // 07:30 UTC on March 8 2026 maps to the 2:30 AM gap in US Eastern.
      final json = {
        'id': 'dst-gap',
        'name': 'DST Gap Event',
        'eventType': 'event',
        'heading': 'Event',
        'imageUrl': '',
        'linkUrl': '',
        'start': '2026-03-08T07:30:00.000Z',
        'end': '2026-03-08T12:00:00.000Z',
        'isUtcTime': true,
        'hasSpawns': false,
        'hasResearchTasks': false,
        'buffs': <dynamic>[],
        'featuredPokemon': <dynamic>[],
        'promoCodes': <dynamic>[],
      };

      final dto = EventDto.fromJson(json);
      final local = EventTimeDisplay.localStart(dto)!;
      final expected = DateTime.utc(2026, 3, 8, 7, 30).toLocal();

      expect(local, equals(expected));
      expect(local.isUtc, isFalse);
    });

    test('local event on US fall-back day preserves wall-clock via JSON', () {
      final json = {
        'id': 'dst-fallback',
        'name': 'Fall-back Spotlight',
        'eventType': 'spotlight-hour',
        'heading': 'Spotlight Hour',
        'imageUrl': '',
        'linkUrl': '',
        'start': '2026-11-01T18:00:00.000',
        'end': '2026-11-01T19:00:00.000',
        'isUtcTime': false,
        'hasSpawns': true,
        'hasResearchTasks': false,
        'buffs': [
          {'text': '2× Transfer Candy', 'category': 'multiplier', 'multiplier': 2, 'resource': 'Candy'},
        ],
        'featuredPokemon': [
          {'name': 'Gastly', 'imageUrl': '', 'canBeShiny': true, 'role': 'spotlight'},
        ],
        'promoCodes': <dynamic>[],
      };

      final dto = EventDto.fromJson(json);
      final localStart = EventTimeDisplay.localStart(dto)!;
      final localEnd = EventTimeDisplay.localEnd(dto)!;

      expect(localStart.hour, 18);
      expect(localEnd.hour, 19);
      expect(dto.eventType, EventType.spotlightHour);
      expect(dto.buffs.first.multiplier, 2.0);
      expect(dto.featuredPokemon.first.role, PokemonRole.spotlight);
      expect(
        EventTimeDisplay.formatTimeRange(dto),
        '6:00 PM – 7:00 PM',
      );
    });

    test('multi-day season event spanning DST transition', () {
      // Season runs March 1 – June 1, crossing spring-forward on March 8.
      final json = {
        'id': 'season-spring',
        'name': 'Season of Discovery',
        'eventType': 'season',
        'heading': 'Season',
        'imageUrl': '',
        'linkUrl': '',
        'start': '2026-03-01T10:00:00.000',
        'end': '2026-06-01T10:00:00.000',
        'isUtcTime': false,
        'hasSpawns': true,
        'hasResearchTasks': true,
        'buffs': [
          {'text': 'Increased wild spawns', 'category': 'spawn'},
          {'text': 'Weather boost extended', 'category': 'weather'},
        ],
        'featuredPokemon': <dynamic>[],
        'promoCodes': <dynamic>[],
      };

      final dto = EventDto.fromJson(json);
      final localStart = EventTimeDisplay.localStart(dto)!;
      final localEnd = EventTimeDisplay.localEnd(dto)!;

      // Wall-clock preserved across DST boundary.
      expect(localStart.hour, 10);
      expect(localStart.month, 3);
      expect(localStart.day, 1);
      expect(localEnd.hour, 10);
      expect(localEnd.month, 6);
      expect(localEnd.day, 1);

      expect(dto.buffs[0].category, BuffCategory.spawn);
      expect(dto.buffs[1].category, BuffCategory.weather);
    });
  });

  // ── EventDto — boolean field edge cases ──

  group('EventDto — boolean fields', () {
    Map<String, dynamic> _json({
      required bool isUtcTime,
      required bool hasSpawns,
      required bool hasResearchTasks,
    }) =>
        {
          'id': 'bool-test',
          'name': 'Bool Test',
          'eventType': 'event',
          'heading': 'Test',
          'imageUrl': '',
          'linkUrl': '',
          'isUtcTime': isUtcTime,
          'hasSpawns': hasSpawns,
          'hasResearchTasks': hasResearchTasks,
          'buffs': <dynamic>[],
          'featuredPokemon': <dynamic>[],
          'promoCodes': <dynamic>[],
        };

    test('all boolean combinations parse and round-trip', () {
      for (final utc in [true, false]) {
        for (final spawns in [true, false]) {
          for (final research in [true, false]) {
            final dto = EventDto.fromJson(_json(
              isUtcTime: utc,
              hasSpawns: spawns,
              hasResearchTasks: research,
            ));

            expect(dto.isUtcTime, utc);
            expect(dto.hasSpawns, spawns);
            expect(dto.hasResearchTasks, research);

            final reJson = dto.toJson();
            expect(reJson['isUtcTime'], utc);
            expect(reJson['hasSpawns'], spawns);
            expect(reJson['hasResearchTasks'], research);
          }
        }
      }
    });
  });

  // ── Buff category mapping completeness ──

  group('Buff — category mapping through EventDto', () {
    test('all BuffCategory values survive EventDto round-trip', () {
      for (final cat in BuffCategory.values) {
        final json = {
          'id': 'cat-${cat.value}',
          'name': 'Category Test',
          'eventType': 'event',
          'heading': 'Test',
          'imageUrl': '',
          'linkUrl': '',
          'isUtcTime': false,
          'hasSpawns': false,
          'hasResearchTasks': false,
          'buffs': [
            {'text': 'Test buff', 'category': cat.toJson()},
          ],
          'featuredPokemon': <dynamic>[],
          'promoCodes': <dynamic>[],
        };

        final dto = EventDto.fromJson(json);
        expect(dto.buffs.first.category, cat,
            reason: '${cat.value} should parse correctly');

        final restored = EventDto.fromJson(dto.toJson());
        expect(restored.buffs.first.category, cat,
            reason: '${cat.value} should round-trip');
      }
    });
  });
}
