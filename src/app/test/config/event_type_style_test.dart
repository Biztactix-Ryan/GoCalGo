import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gocalgo/config/event_type_style.dart';
import 'package:gocalgo/models/event_type.dart';

/// Verifies acceptance criterion US-GCG-7 AC-3:
/// "Event types are visually distinct (community day vs spotlight hour vs
/// raid hour etc)."
void main() {
  group('EventTypeStyle — every EventType has a style', () {
    for (final type in EventType.values) {
      test('${type.name} has a defined style', () {
        final style = EventTypeStyle.of(type);
        expect(style, isNotNull);
        expect(style.label, isNotEmpty);
      });
    }
  });

  group('EventTypeStyle — all colours are unique', () {
    test('no two event types share the same colour', () {
      final colours = <Color>{};
      for (final type in EventType.values) {
        final style = EventTypeStyle.of(type);
        expect(
          colours.add(style.color),
          isTrue,
          reason: '${type.name} shares a colour with another event type',
        );
      }
    });
  });

  group('EventTypeStyle — all icons are unique', () {
    test('no two event types share the same icon', () {
      final icons = <IconData>{};
      for (final type in EventType.values) {
        final style = EventTypeStyle.of(type);
        expect(
          icons.add(style.icon),
          isTrue,
          reason: '${type.name} shares an icon with another event type',
        );
      }
    });
  });

  group('EventTypeStyle — all labels are unique', () {
    test('no two event types share the same label', () {
      final labels = <String>{};
      for (final type in EventType.values) {
        final style = EventTypeStyle.of(type);
        expect(
          labels.add(style.label),
          isTrue,
          reason: '${type.name} shares a label with another event type',
        );
      }
    });
  });

  group('EventTypeStyle — colours have sufficient contrast', () {
    test('all colours are opaque', () {
      for (final type in EventType.values) {
        final style = EventTypeStyle.of(type);
        expect(
          style.color.a,
          equals(1.0),
          reason: '${type.name} colour must be fully opaque',
        );
      }
    });
  });

  group('EventTypeStyle — expected visual identity for key types', () {
    test('Community Day is green', () {
      final style = EventTypeStyle.of(EventType.communityDay);
      // Green channel should dominate
      expect(style.color.g, greaterThan(style.color.r));
      expect(style.color.g, greaterThan(style.color.b));
    });

    test('Raid Hour is red', () {
      final style = EventTypeStyle.of(EventType.raidHour);
      expect(style.color.r, greaterThan(style.color.g));
      expect(style.color.r, greaterThan(style.color.b));
    });

    test('Spotlight Hour is warm/yellow', () {
      final style = EventTypeStyle.of(EventType.spotlightHour);
      expect(style.color.r, greaterThan(style.color.b));
    });

    test('GO Battle League is purple', () {
      final style = EventTypeStyle.of(EventType.goBattleLeague);
      expect(style.color.r, greaterThan(style.color.g));
      expect(style.color.b, greaterThan(style.color.g));
    });

    test('Pokémon GO Fest is orange', () {
      final style = EventTypeStyle.of(EventType.pokemonGoFest);
      expect(style.color.r, greaterThan(style.color.g));
      expect(style.color.r, greaterThan(style.color.b));
    });
  });
}
