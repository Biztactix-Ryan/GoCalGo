import 'package:flutter_test/flutter_test.dart';
import 'package:gocalgo/models/buff.dart';
import 'package:gocalgo/models/buff_category.dart';

/// Unit tests for Buff model JSON serialisation and optional field handling.
void main() {
  group('Buff', () {
    test('fromJson() parses all fields', () {
      final json = {
        'text': '2× Catch Stardust',
        'iconUrl': 'https://example.com/stardust.png',
        'category': 'multiplier',
        'multiplier': 2.0,
        'resource': 'Stardust',
        'disclaimer': 'With Star Piece active',
      };

      final buff = Buff.fromJson(json);

      expect(buff.text, '2× Catch Stardust');
      expect(buff.iconUrl, 'https://example.com/stardust.png');
      expect(buff.category, BuffCategory.multiplier);
      expect(buff.multiplier, 2.0);
      expect(buff.resource, 'Stardust');
      expect(buff.disclaimer, 'With Star Piece active');
    });

    test('fromJson() handles null optional fields', () {
      final json = {
        'text': 'Increased spawns',
        'category': 'spawn',
      };

      final buff = Buff.fromJson(json);

      expect(buff.text, 'Increased spawns');
      expect(buff.iconUrl, isNull);
      expect(buff.category, BuffCategory.spawn);
      expect(buff.multiplier, isNull);
      expect(buff.resource, isNull);
      expect(buff.disclaimer, isNull);
    });

    test('toJson() omits null optional fields', () {
      final buff = Buff(text: 'Longer lures', category: BuffCategory.duration);
      final json = buff.toJson();

      expect(json['text'], 'Longer lures');
      expect(json['category'], 'duration');
      expect(json.containsKey('iconUrl'), false);
      expect(json.containsKey('multiplier'), false);
      expect(json.containsKey('resource'), false);
      expect(json.containsKey('disclaimer'), false);
    });

    test('toJson() round-trips with all fields', () {
      final original = Buff(
        text: '3× Catch XP',
        iconUrl: 'https://example.com/xp.png',
        category: BuffCategory.multiplier,
        multiplier: 3.0,
        resource: 'XP',
        disclaimer: 'Event hours only',
      );

      final roundTripped = Buff.fromJson(original.toJson());

      expect(roundTripped.text, original.text);
      expect(roundTripped.iconUrl, original.iconUrl);
      expect(roundTripped.category, original.category);
      expect(roundTripped.multiplier, original.multiplier);
      expect(roundTripped.resource, original.resource);
      expect(roundTripped.disclaimer, original.disclaimer);
    });
  });

  group('BuffCategory', () {
    test('fromJson() maps known values', () {
      expect(BuffCategory.fromJson('multiplier'), BuffCategory.multiplier);
      expect(BuffCategory.fromJson('duration'), BuffCategory.duration);
      expect(BuffCategory.fromJson('spawn'), BuffCategory.spawn);
      expect(BuffCategory.fromJson('probability'), BuffCategory.probability);
      expect(BuffCategory.fromJson('trade'), BuffCategory.trade);
      expect(BuffCategory.fromJson('weather'), BuffCategory.weather);
    });

    test('fromJson() falls back to other for unknown values', () {
      expect(BuffCategory.fromJson('unknown-category'), BuffCategory.other);
    });

    test('toJson() round-trips all values', () {
      for (final category in BuffCategory.values) {
        expect(BuffCategory.fromJson(category.toJson()), category);
      }
    });
  });
}
