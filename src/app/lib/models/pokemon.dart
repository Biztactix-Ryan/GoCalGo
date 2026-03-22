import 'pokemon_role.dart';

/// A featured Pokemon within an event context.
class Pokemon {
  final String name;
  final String imageUrl;
  final bool canBeShiny;
  final PokemonRole role;

  const Pokemon({
    required this.name,
    required this.imageUrl,
    required this.canBeShiny,
    required this.role,
  });

  factory Pokemon.fromJson(Map<String, dynamic> json) => Pokemon(
        name: json['name'] as String,
        imageUrl: json['imageUrl'] as String,
        canBeShiny: json['canBeShiny'] as bool,
        role: PokemonRole.fromJson(json['role'] as String),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'imageUrl': imageUrl,
        'canBeShiny': canBeShiny,
        'role': role.toJson(),
      };
}
