import 'package:flutter/material.dart';
import '../models/event_type.dart';

/// Visual styling for each event type — colour, icon, and display label.
///
/// Ensures every event type is visually distinct on the daily calendar view
/// (acceptance criterion US-GCG-7 AC-3).
class EventTypeStyle {
  final Color color;
  final IconData icon;
  final String label;

  const EventTypeStyle._({
    required this.color,
    required this.icon,
    required this.label,
  });

  /// Returns the visual style for the given [eventType].
  static EventTypeStyle of(EventType eventType) {
    return _styles[eventType]!;
  }

  static const _styles = <EventType, EventTypeStyle>{
    EventType.communityDay: EventTypeStyle._(
      color: Color(0xFF43A047),
      icon: Icons.groups,
      label: 'Community Day',
    ),
    EventType.spotlightHour: EventTypeStyle._(
      color: Color(0xFFFFC107),
      icon: Icons.flashlight_on,
      label: 'Spotlight Hour',
    ),
    EventType.raidHour: EventTypeStyle._(
      color: Color(0xFFE53935),
      icon: Icons.local_fire_department,
      label: 'Raid Hour',
    ),
    EventType.raidDay: EventTypeStyle._(
      color: Color(0xFFD32F2F),
      icon: Icons.whatshot,
      label: 'Raid Day',
    ),
    EventType.event: EventTypeStyle._(
      color: Color(0xFF1E88E5),
      icon: Icons.event,
      label: 'Event',
    ),
    EventType.goBattleLeague: EventTypeStyle._(
      color: Color(0xFF8E24AA),
      icon: Icons.sports_kabaddi,
      label: 'GO Battle League',
    ),
    EventType.goRocket: EventTypeStyle._(
      color: Color(0xFF37474F),
      icon: Icons.rocket_launch,
      label: 'Team GO Rocket',
    ),
    EventType.research: EventTypeStyle._(
      color: Color(0xFF00897B),
      icon: Icons.science,
      label: 'Research',
    ),
    EventType.pokemonGoFest: EventTypeStyle._(
      color: Color(0xFFFF6F00),
      icon: Icons.celebration,
      label: 'Pokémon GO Fest',
    ),
    EventType.safariZone: EventTypeStyle._(
      color: Color(0xFF2E7D32),
      icon: Icons.park,
      label: 'Safari Zone',
    ),
    EventType.season: EventTypeStyle._(
      color: Color(0xFF5C6BC0),
      icon: Icons.calendar_month,
      label: 'Season',
    ),
    EventType.other: EventTypeStyle._(
      color: Color(0xFF757575),
      icon: Icons.more_horiz,
      label: 'Other',
    ),
  };
}
