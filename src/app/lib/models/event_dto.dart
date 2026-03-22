import 'buff.dart';
import 'event_type.dart';
import 'pokemon.dart';

/// Primary DTO for a Pokemon GO event, with all data pre-shaped for display.
class EventDto {
  final String id;
  final String name;
  final EventType eventType;
  final String heading;
  final String imageUrl;
  final String linkUrl;
  final DateTime? start;
  final DateTime? end;
  final bool isUtcTime;
  final bool hasSpawns;
  final bool hasResearchTasks;
  final List<Buff> buffs;
  final List<Pokemon> featuredPokemon;
  final List<String> promoCodes;

  const EventDto({
    required this.id,
    required this.name,
    required this.eventType,
    required this.heading,
    required this.imageUrl,
    required this.linkUrl,
    this.start,
    this.end,
    required this.isUtcTime,
    required this.hasSpawns,
    required this.hasResearchTasks,
    required this.buffs,
    required this.featuredPokemon,
    required this.promoCodes,
  });

  factory EventDto.fromJson(Map<String, dynamic> json) => EventDto(
        id: json['id'] as String,
        name: json['name'] as String,
        eventType: EventType.fromJson(json['eventType'] as String),
        heading: json['heading'] as String,
        imageUrl: json['imageUrl'] as String,
        linkUrl: json['linkUrl'] as String,
        start: json['start'] != null
            ? DateTime.parse(json['start'] as String)
            : null,
        end: json['end'] != null
            ? DateTime.parse(json['end'] as String)
            : null,
        isUtcTime: json['isUtcTime'] as bool,
        hasSpawns: json['hasSpawns'] as bool,
        hasResearchTasks: json['hasResearchTasks'] as bool,
        buffs: (json['buffs'] as List<dynamic>)
            .map((e) => Buff.fromJson(e as Map<String, dynamic>))
            .toList(),
        featuredPokemon: (json['featuredPokemon'] as List<dynamic>)
            .map((e) => Pokemon.fromJson(e as Map<String, dynamic>))
            .toList(),
        promoCodes: (json['promoCodes'] as List<dynamic>)
            .map((e) => e as String)
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'eventType': eventType.toJson(),
        'heading': heading,
        'imageUrl': imageUrl,
        'linkUrl': linkUrl,
        if (start != null) 'start': start!.toIso8601String(),
        if (end != null) 'end': end!.toIso8601String(),
        'isUtcTime': isUtcTime,
        'hasSpawns': hasSpawns,
        'hasResearchTasks': hasResearchTasks,
        'buffs': buffs.map((e) => e.toJson()).toList(),
        'featuredPokemon': featuredPokemon.map((e) => e.toJson()).toList(),
        'promoCodes': promoCodes,
      };
}
