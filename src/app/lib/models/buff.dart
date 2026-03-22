import 'buff_category.dart';

/// Unified representation of a buff or bonus, normalised from ScrapedDuck's various shapes.
class Buff {
  final String text;
  final String? iconUrl;
  final BuffCategory category;
  final double? multiplier;
  final String? resource;
  final String? disclaimer;

  const Buff({
    required this.text,
    this.iconUrl,
    required this.category,
    this.multiplier,
    this.resource,
    this.disclaimer,
  });

  factory Buff.fromJson(Map<String, dynamic> json) => Buff(
        text: json['text'] as String,
        iconUrl: json['iconUrl'] as String?,
        category: BuffCategory.fromJson(json['category'] as String),
        multiplier: (json['multiplier'] as num?)?.toDouble(),
        resource: json['resource'] as String?,
        disclaimer: json['disclaimer'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'text': text,
        if (iconUrl != null) 'iconUrl': iconUrl,
        'category': category.toJson(),
        if (multiplier != null) 'multiplier': multiplier,
        if (resource != null) 'resource': resource,
        if (disclaimer != null) 'disclaimer': disclaimer,
      };
}
