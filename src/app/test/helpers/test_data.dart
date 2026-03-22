import 'package:gocalgo/models/buff.dart';
import 'package:gocalgo/models/buff_category.dart';
import 'package:gocalgo/models/event_dto.dart';
import 'package:gocalgo/models/event_type.dart';
import 'package:gocalgo/models/events_response.dart';
import 'package:gocalgo/models/pokemon.dart';
import 'package:gocalgo/models/pokemon_role.dart';

/// Factory helpers for creating sample domain objects in tests.
///
/// All methods return sensible defaults that can be selectively overridden,
/// eliminating boilerplate JSON maps scattered across test files.
class TestData {
  TestData._();

  /// Creates a sample [EventDto] with all required fields populated.
  ///
  /// Override any field to customise the event for a specific test scenario.
  static EventDto event({
    String id = 'test-event-1',
    String name = 'Test Event',
    EventType eventType = EventType.event,
    String heading = 'Test Heading',
    String imageUrl = 'https://example.com/img.png',
    String linkUrl = 'https://example.com/event',
    DateTime? start,
    DateTime? end,
    bool isUtcTime = false,
    bool hasSpawns = false,
    bool hasResearchTasks = false,
    List<Buff> buffs = const [],
    List<Pokemon> featuredPokemon = const [],
    List<String> promoCodes = const [],
  }) {
    return EventDto(
      id: id,
      name: name,
      eventType: eventType,
      heading: heading,
      imageUrl: imageUrl,
      linkUrl: linkUrl,
      start: start,
      end: end,
      isUtcTime: isUtcTime,
      hasSpawns: hasSpawns,
      hasResearchTasks: hasResearchTasks,
      buffs: buffs,
      featuredPokemon: featuredPokemon,
      promoCodes: promoCodes,
    );
  }

  /// Creates a sample [EventsResponse] wrapping the given [events].
  static EventsResponse response({
    List<EventDto>? events,
    DateTime? lastUpdated,
    bool cacheHit = false,
  }) {
    return EventsResponse(
      events: events ?? [TestData.event()],
      lastUpdated: lastUpdated ?? DateTime(2026, 3, 21, 12, 0),
      cacheHit: cacheHit,
    );
  }

  /// A Community Day event with spawns, buffs, and featured Pokemon.
  static EventDto communityDay({
    String id = 'cd-test',
    String name = 'Community Day: Bulbasaur',
    DateTime? start,
    DateTime? end,
  }) {
    return event(
      id: id,
      name: name,
      eventType: EventType.communityDay,
      heading: 'Community Day',
      start: start ?? DateTime(2026, 3, 21, 14, 0),
      end: end ?? DateTime(2026, 3, 21, 17, 0),
      hasSpawns: true,
      hasResearchTasks: true,
      buffs: [
        const Buff(
          text: '3× Catch Stardust',
          category: BuffCategory.multiplier,
          multiplier: 3.0,
          resource: 'Stardust',
        ),
      ],
      featuredPokemon: [
        const Pokemon(
          name: 'Bulbasaur',
          imageUrl: 'https://example.com/bulbasaur.png',
          canBeShiny: true,
          role: PokemonRole.spawn,
        ),
      ],
    );
  }

  /// A Spotlight Hour event.
  static EventDto spotlightHour({
    String id = 'sh-test',
    String name = 'Spotlight Hour: Pikachu',
    DateTime? start,
    DateTime? end,
  }) {
    return event(
      id: id,
      name: name,
      eventType: EventType.spotlightHour,
      heading: 'Spotlight Hour',
      start: start ?? DateTime(2026, 3, 25, 18, 0),
      end: end ?? DateTime(2026, 3, 25, 19, 0),
      hasSpawns: true,
      buffs: [
        const Buff(
          text: '2× Transfer Candy',
          category: BuffCategory.multiplier,
          multiplier: 2.0,
          resource: 'Candy',
        ),
      ],
    );
  }

  /// A Raid Hour event.
  static EventDto raidHour({
    String id = 'rh-test',
    String name = 'Raid Hour',
    DateTime? start,
    DateTime? end,
  }) {
    return event(
      id: id,
      name: name,
      eventType: EventType.raidHour,
      heading: 'Raid Hour',
      start: start ?? DateTime(2026, 3, 26, 18, 0),
      end: end ?? DateTime(2026, 3, 26, 19, 0),
    );
  }

  /// Returns a JSON map for an event, useful when tests need raw JSON
  /// (e.g. for MockClient HTTP responses).
  static Map<String, dynamic> eventJson({
    String id = 'test-event-1',
    String name = 'Test Event',
    String eventType = 'event',
    String heading = 'Test Heading',
    String? start,
    String? end,
    bool isUtcTime = false,
    bool hasSpawns = false,
    bool hasResearchTasks = false,
    List<Map<String, dynamic>> buffs = const [],
    List<Map<String, dynamic>> featuredPokemon = const [],
    List<String> promoCodes = const [],
  }) {
    return {
      'id': id,
      'name': name,
      'eventType': eventType,
      'heading': heading,
      'imageUrl': 'https://example.com/$id.png',
      'linkUrl': 'https://example.com/$id',
      if (start != null) 'start': start,
      if (end != null) 'end': end,
      'isUtcTime': isUtcTime,
      'hasSpawns': hasSpawns,
      'hasResearchTasks': hasResearchTasks,
      'buffs': buffs,
      'featuredPokemon': featuredPokemon,
      'promoCodes': promoCodes,
    };
  }

  /// Returns a JSON map for an [EventsResponse], useful for MockClient
  /// HTTP responses.
  static Map<String, dynamic> responseJson({
    List<Map<String, dynamic>>? events,
    String lastUpdated = '2026-03-21T12:00:00Z',
    bool cacheHit = false,
  }) {
    return {
      'events': events ?? [eventJson()],
      'lastUpdated': lastUpdated,
      'cacheHit': cacheHit,
    };
  }
}
