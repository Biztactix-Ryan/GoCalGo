import 'package:test/test.dart';
import 'package:gocalgo/models/event_dto.dart';
import 'package:gocalgo/models/event_type.dart';
import 'package:gocalgo/services/event_day_grouping.dart';

/// Helper to build a minimal EventDto for grouping tests.
EventDto _event(String id, String name, {String? start, String? end}) =>
    EventDto(
      id: id,
      name: name,
      eventType: EventType.event,
      heading: name,
      imageUrl: 'https://example.com/img.png',
      linkUrl: 'https://example.com/$id',
      start: start != null ? DateTime.parse(start) : null,
      end: end != null ? DateTime.parse(end) : null,
      isUtcTime: false,
      hasSpawns: false,
      hasResearchTasks: false,
      buffs: const [],
      featuredPokemon: const [],
      promoCodes: const [],
    );

void main() {
  group('groupEventsByDay', () {
    test('groups events by their start date with formatted headers', () {
      final events = [
        _event('e1', 'Community Day',
            start: '2026-03-23T14:00:00.000',
            end: '2026-03-23T17:00:00.000'),
        _event('e2', 'Raid Hour',
            start: '2026-03-23T18:00:00.000',
            end: '2026-03-23T19:00:00.000'),
        _event('e3', 'Spotlight Hour',
            start: '2026-03-25T18:00:00.000',
            end: '2026-03-25T19:00:00.000'),
      ];

      final groups = groupEventsByDay(events);

      expect(groups, hasLength(2));
      expect(groups[0].header, 'Mon, Mar 23');
      expect(groups[0].events.map((e) => e.id), ['e1', 'e2']);
      expect(groups[1].header, 'Wed, Mar 25');
      expect(groups[1].events.map((e) => e.id), ['e3']);
    });

    test('returns groups sorted chronologically', () {
      final events = [
        // Deliberately out of order
        _event('e2', 'Later Event',
            start: '2026-03-27T10:00:00.000',
            end: '2026-03-27T11:00:00.000'),
        _event('e1', 'Earlier Event',
            start: '2026-03-22T10:00:00.000',
            end: '2026-03-22T11:00:00.000'),
      ];

      final groups = groupEventsByDay(events);

      expect(groups, hasLength(2));
      expect(groups[0].header, 'Sun, Mar 22');
      expect(groups[1].header, 'Fri, Mar 27');
    });

    test('preserves event order within each day group', () {
      final events = [
        _event('morning', 'Morning Raid',
            start: '2026-03-23T09:00:00.000',
            end: '2026-03-23T10:00:00.000'),
        _event('afternoon', 'Afternoon Walk',
            start: '2026-03-23T14:00:00.000',
            end: '2026-03-23T15:00:00.000'),
        _event('evening', 'Evening Battle',
            start: '2026-03-23T19:00:00.000',
            end: '2026-03-23T20:00:00.000'),
      ];

      final groups = groupEventsByDay(events);

      expect(groups, hasLength(1));
      expect(groups[0].events.map((e) => e.id),
          ['morning', 'afternoon', 'evening']);
    });

    test('places events with no start date into a "Date TBD" group', () {
      final events = [
        _event('dated', 'Known Event',
            start: '2026-03-23T14:00:00.000',
            end: '2026-03-23T17:00:00.000'),
        _event('undated', 'Mystery Event'),
      ];

      final groups = groupEventsByDay(events);

      expect(groups, hasLength(2));
      expect(groups[0].header, 'Mon, Mar 23');
      expect(groups[0].events.map((e) => e.id), ['dated']);
      expect(groups[1].header, 'Date TBD');
      expect(groups[1].events.map((e) => e.id), ['undated']);
    });

    test('returns empty list for empty input', () {
      expect(groupEventsByDay([]), isEmpty);
    });

    test('each group date is midnight of that calendar day', () {
      final events = [
        _event('e1', 'Event',
            start: '2026-03-23T14:30:00.000',
            end: '2026-03-23T17:00:00.000'),
      ];

      final groups = groupEventsByDay(events);

      expect(groups[0].date, DateTime(2026, 3, 23));
      expect(groups[0].date.hour, 0);
      expect(groups[0].date.minute, 0);
    });

    test('handles single-event days and multi-event days together', () {
      final events = [
        _event('solo', 'Solo Event',
            start: '2026-03-22T10:00:00.000',
            end: '2026-03-22T11:00:00.000'),
        _event('duo-1', 'Duo First',
            start: '2026-03-24T10:00:00.000',
            end: '2026-03-24T11:00:00.000'),
        _event('duo-2', 'Duo Second',
            start: '2026-03-24T14:00:00.000',
            end: '2026-03-24T15:00:00.000'),
      ];

      final groups = groupEventsByDay(events);

      expect(groups, hasLength(2));
      expect(groups[0].events, hasLength(1));
      expect(groups[1].events, hasLength(2));
    });
  });
}
