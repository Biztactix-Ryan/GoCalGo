import 'package:flutter_test/flutter_test.dart';
import 'package:gocalgo/models/pokemon.dart';
import 'package:gocalgo/models/pokemon_role.dart';

/// Unit tests for Pokemon model and PokemonRole enum.
void main() {
  group('Pokemon', () {
    test('fromJson() parses all fields', () {
      final json = {
        'name': 'Pikachu',
        'imageUrl': 'https://example.com/pikachu.png',
        'canBeShiny': true,
        'role': 'spotlight',
      };

      final pokemon = Pokemon.fromJson(json);

      expect(pokemon.name, 'Pikachu');
      expect(pokemon.imageUrl, 'https://example.com/pikachu.png');
      expect(pokemon.canBeShiny, true);
      expect(pokemon.role, PokemonRole.spotlight);
    });

    test('fromJson() with canBeShiny false', () {
      final json = {
        'name': 'Mewtwo',
        'imageUrl': 'https://example.com/mewtwo.png',
        'canBeShiny': false,
        'role': 'raid-boss',
      };

      final pokemon = Pokemon.fromJson(json);

      expect(pokemon.canBeShiny, false);
      expect(pokemon.role, PokemonRole.raidBoss);
    });

    test('toJson() round-trips correctly', () {
      final original = Pokemon(
        name: 'Bulbasaur',
        imageUrl: 'https://example.com/bulbasaur.png',
        canBeShiny: true,
        role: PokemonRole.researchReward,
      );

      final roundTripped = Pokemon.fromJson(original.toJson());

      expect(roundTripped.name, original.name);
      expect(roundTripped.imageUrl, original.imageUrl);
      expect(roundTripped.canBeShiny, original.canBeShiny);
      expect(roundTripped.role, original.role);
    });
  });

  group('PokemonRole', () {
    test('fromJson() maps known values', () {
      expect(PokemonRole.fromJson('spawn'), PokemonRole.spawn);
      expect(PokemonRole.fromJson('shiny'), PokemonRole.shiny);
      expect(PokemonRole.fromJson('spotlight'), PokemonRole.spotlight);
      expect(PokemonRole.fromJson('raid-boss'), PokemonRole.raidBoss);
      expect(PokemonRole.fromJson('research-reward'), PokemonRole.researchReward);
      expect(PokemonRole.fromJson('research-breakthrough'), PokemonRole.researchBreakthrough);
    });

    test('fromJson() falls back to spawn for unknown values', () {
      expect(PokemonRole.fromJson('unknown-role'), PokemonRole.spawn);
    });

    test('toJson() round-trips all values', () {
      for (final role in PokemonRole.values) {
        expect(PokemonRole.fromJson(role.toJson()), role);
      }
    });
  });
}
