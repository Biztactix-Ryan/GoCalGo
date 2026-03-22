/// Categorises the type of buff/bonus effect.
enum BuffCategory {
  multiplier('multiplier'),
  duration('duration'),
  spawn('spawn'),
  probability('probability'),
  trade('trade'),
  weather('weather'),
  other('other');

  const BuffCategory(this.value);
  final String value;

  static BuffCategory fromJson(String json) =>
      BuffCategory.values.firstWhere(
        (e) => e.value == json,
        orElse: () => BuffCategory.other,
      );

  String toJson() => value;
}
