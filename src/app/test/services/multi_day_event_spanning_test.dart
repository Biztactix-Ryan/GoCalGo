import 'package:test/test.dart';
import 'package:gocalgo/models/event_dto.dart';
import 'package:gocalgo/models/event_type.dart';
import 'package:gocalgo/services/event_day_grouping.dart';
import 'package:gocalgo/services/event_time_display.dart';

/// Helper to build an EventDto for multi-day spanning tests.
EventDto _event(
  String id,
  String name, {
  required DateTime start,
  required DateTime end,
  bool isUtcTime = false,
  EventType eventType = EventType.event,
}) =>
    EventDto(
      id: id,
      name: name,
      eventType: eventType,
      heading: name,
      imageUrl: 'https://example.com/img.png',
      linkUrl: 'https://example.com/$id',
      start: start,
      end: end,
      isUtcTime: isUtcTime,
      hasSpawns: false,
      hasResearchTasks: false,
      buffs: const [],
      featuredPokemon: const [],
      promoCodes: const [],
    );

/// Simulates active-event filtering: event is active if start <= now <= end.
bool _isActive(EventDto event, DateTime now) {
  if (event.start == null) return false;
  final started = !event.start!.isAfter(now);
  final notEnded = event.end == null || event.end!.isAfter(now);
  return started && notEnded;
}

void main() {
  group('Multi-day events span correctly across days', () {
    // A 3-day season event: March 21 10:00 AM through March 23 8:00 PM.
    final multiDayEvent = _event(
      'season-1',
      'Season of Discovery',
      start: DateTime(2026, 3, 21, 10, 0),
      end: DateTime(2026, 3, 23, 20, 0),
      eventType: EventType.season,
    );

    group('active event filtering recognises mid-span days', () {
      test('event is active on its start day', () {
        final now = DateTime(2026, 3, 21, 12, 0);
        expect(_isActive(multiDayEvent, now), isTrue);
      });

      test('event is active on a middle day', () {
        final now = DateTime(2026, 3, 22, 15, 0);
        expect(_isActive(multiDayEvent, now), isTrue);
      });

      test('event is active on its end day before end time', () {
        final now = DateTime(2026, 3, 23, 19, 59);
        expect(_isActive(multiDayEvent, now), isTrue);
      });

      test('event is NOT active before it starts', () {
        final now = DateTime(2026, 3, 21, 9, 59);
        expect(_isActive(multiDayEvent, now), isFalse);
      });

      test('event is NOT active after it ends', () {
        final now = DateTime(2026, 3, 23, 20, 0);
        expect(_isActive(multiDayEvent, now), isFalse);
      });
    });

    group('day grouping places multi-day event in start-day group only', () {
      test('multi-day event appears once, grouped by its start date', () {
        final groups = groupEventsByDay([multiDayEvent]);

        expect(groups, hasLength(1));
        expect(groups[0].header, 'Sat, Mar 21');
        expect(groups[0].events, hasLength(1));
        expect(groups[0].events[0].id, 'season-1');
      });

      test('multi-day event does not duplicate into end-date group', () {
        final sameDayEvent = _event(
          'raid-hour',
          'Raid Hour',
          start: DateTime(2026, 3, 23, 18, 0),
          end: DateTime(2026, 3, 23, 19, 0),
        );

        final groups = groupEventsByDay([multiDayEvent, sameDayEvent]);

        // Two groups: Mar 21 (multi-day) and Mar 23 (raid hour).
        // The multi-day event should NOT also appear in the Mar 23 group.
        expect(groups, hasLength(2));
        expect(groups[0].header, 'Sat, Mar 21');
        expect(groups[0].events.map((e) => e.id), ['season-1']);
        expect(groups[1].header, 'Mon, Mar 23');
        expect(groups[1].events.map((e) => e.id), ['raid-hour']);
      });

      test('overlapping multi-day events each go to their own start day', () {
        final eventA = _event(
          'fest',
          'GO Fest',
          start: DateTime(2026, 3, 20, 10, 0),
          end: DateTime(2026, 3, 22, 20, 0),
        );
        final eventB = _event(
          'safari',
          'Safari Zone',
          start: DateTime(2026, 3, 21, 8, 0),
          end: DateTime(2026, 3, 24, 22, 0),
        );

        final groups = groupEventsByDay([eventA, eventB]);

        expect(groups, hasLength(2));
        expect(groups[0].header, 'Fri, Mar 20');
        expect(groups[0].events.map((e) => e.id), ['fest']);
        expect(groups[1].header, 'Sat, Mar 21');
        expect(groups[1].events.map((e) => e.id), ['safari']);
      });
    });

    group('time display formats multi-day ranges with dates', () {
      test('multi-day event shows date+time on both ends', () {
        final result = EventTimeDisplay.formatTimeRange(multiDayEvent);
        expect(result, equals('Mar 21, 10:00 AM – Mar 23, 8:00 PM'));
      });

      test('event spanning month boundary shows both months', () {
        final crossMonth = _event(
          'cross-month',
          'Cross Month Event',
          start: DateTime(2026, 3, 30, 10, 0),
          end: DateTime(2026, 4, 2, 18, 0),
        );

        final result = EventTimeDisplay.formatTimeRange(crossMonth);
        expect(result, equals('Mar 30, 10:00 AM – Apr 2, 6:00 PM'));
      });

      test('event spanning year boundary shows both dates', () {
        final crossYear = _event(
          'cross-year',
          'New Year Event',
          start: DateTime(2026, 12, 30, 10, 0),
          end: DateTime(2027, 1, 2, 18, 0),
        );

        final result = EventTimeDisplay.formatTimeRange(crossYear);
        expect(result, equals('Dec 30, 10:00 AM – Jan 2, 6:00 PM'));
      });

      test('same-day event does NOT show dates in time range', () {
        final sameDay = _event(
          'same-day',
          'Same Day',
          start: DateTime(2026, 3, 21, 14, 0),
          end: DateTime(2026, 3, 21, 17, 0),
        );

        final result = EventTimeDisplay.formatTimeRange(sameDay);
        expect(result, equals('2:00 PM – 5:00 PM'));
      });

      test('two-day event (overnight) shows dates', () {
        final overnight = _event(
          'overnight',
          'Overnight Raid',
          start: DateTime(2026, 3, 21, 22, 0),
          end: DateTime(2026, 3, 22, 2, 0),
        );

        final result = EventTimeDisplay.formatTimeRange(overnight);
        expect(result, equals('Mar 21, 10:00 PM – Mar 22, 2:00 AM'));
      });
    });

    group('multi-day event mixed with single-day events', () {
      test('active filter returns multi-day and single-day events together', () {
        final singleDay = _event(
          'cd',
          'Community Day',
          start: DateTime(2026, 3, 22, 14, 0),
          end: DateTime(2026, 3, 22, 17, 0),
        );
        final events = [multiDayEvent, singleDay];

        // At 3 PM on March 22, both events are active.
        final now = DateTime(2026, 3, 22, 15, 0);
        final active = events.where((e) => _isActive(e, now)).toList();

        expect(active, hasLength(2));
        expect(active.map((e) => e.id), containsAll(['season-1', 'cd']));
      });

      test('grouping keeps multi-day and single-day events in correct groups', () {
        final events = [
          multiDayEvent, // starts Mar 21
          _event('cd', 'Community Day',
              start: DateTime(2026, 3, 22, 14, 0),
              end: DateTime(2026, 3, 22, 17, 0)),
          _event('raid', 'Raid Hour',
              start: DateTime(2026, 3, 21, 18, 0),
              end: DateTime(2026, 3, 21, 19, 0)),
        ];

        final groups = groupEventsByDay(events);

        expect(groups, hasLength(2));
        // Mar 21: season event + raid hour
        expect(groups[0].header, 'Sat, Mar 21');
        expect(groups[0].events.map((e) => e.id),
            containsAll(['season-1', 'raid']));
        // Mar 22: community day only (multi-day event NOT duplicated here)
        expect(groups[1].header, 'Sun, Mar 22');
        expect(groups[1].events.map((e) => e.id), ['cd']);
      });
    });
  });
}
