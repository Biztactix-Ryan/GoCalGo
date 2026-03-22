/// Describes a Pokemon's role within an event context.
enum PokemonRole {
  spawn('spawn'),
  shiny('shiny'),
  spotlight('spotlight'),
  raidBoss('raid-boss'),
  researchReward('research-reward'),
  researchBreakthrough('research-breakthrough');

  const PokemonRole(this.value);
  final String value;

  static PokemonRole fromJson(String json) =>
      PokemonRole.values.firstWhere(
        (e) => e.value == json,
        orElse: () => PokemonRole.spawn,
      );

  String toJson() => value;
}
