/// Normalised event categories mapping ScrapedDuck's 32 event types into logical groups.
enum EventType {
  communityDay('community-day'),
  spotlightHour('spotlight-hour'),
  raidHour('raid-hour'),
  raidDay('raid-day'),
  event('event'),
  goBattleLeague('go-battle-league'),
  goRocket('go-rocket'),
  research('research'),
  pokemonGoFest('pokemon-go-fest'),
  safariZone('safari-zone'),
  season('season'),
  other('other');

  const EventType(this.value);
  final String value;

  static EventType fromJson(String json) =>
      EventType.values.firstWhere(
        (e) => e.value == json,
        orElse: () => EventType.other,
      );

  String toJson() => value;
}
