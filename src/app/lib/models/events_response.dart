import 'event_dto.dart';

/// API response envelope wrapping event data.
class EventsResponse {
  final List<EventDto> events;
  final DateTime lastUpdated;
  final bool cacheHit;

  const EventsResponse({
    required this.events,
    required this.lastUpdated,
    required this.cacheHit,
  });

  factory EventsResponse.fromJson(Map<String, dynamic> json) =>
      EventsResponse(
        events: (json['events'] as List<dynamic>)
            .map((e) => EventDto.fromJson(e as Map<String, dynamic>))
            .toList(),
        lastUpdated: DateTime.parse(json['lastUpdated'] as String),
        cacheHit: json['cacheHit'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'events': events.map((e) => e.toJson()).toList(),
        'lastUpdated': lastUpdated.toIso8601String(),
        'cacheHit': cacheHit,
      };
}
