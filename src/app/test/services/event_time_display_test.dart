import 'package:flutter_test/flutter_test.dart';
import 'package:gocalgo/models/event_dto.dart';
import 'package:gocalgo/models/event_type.dart';
import 'package:gocalgo/services/event_time_display.dart';

/// Helper to build an [EventDto] with only the fields relevant to time display.
EventDto _makeEvent({
  DateTime? start,
  DateTime? end,
  required bool isUtcTime,
}) =>
    EventDto(
      id: 'test-event',
      name: 'Test Event',
      eventType: EventType.event,
      heading: 'Test',
      imageUrl: '',
      linkUrl: '',
      start: start,
      end: end,
      isUtcTime: isUtcTime,
      hasSpawns: false,
      hasResearchTasks: false,
      buffs: const [],
      featuredPokemon: const [],
      promoCodes: const [],
    );

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _monthAbbr(int month) => _months[month - 1];

void main() {
  group('EventTimeDisplay — UTC events converted to local', () {
    test('localStart converts UTC DateTime to local timezone', () {
      final utcStart = DateTime.utc(2026, 3, 21, 18, 0); // 6:00 PM UTC
      final event = _makeEvent(
        start: utcStart,
        end: DateTime.utc(2026, 3, 21, 21, 0),
        isUtcTime: true,
      );

      final localStart = EventTimeDisplay.localStart(event);

      expect(localStart, isNotNull);
      // The converted time must not be in UTC — it should be local.
      expect(localStart!.isUtc, isFalse);
      // The local time should equal the UTC time converted via toLocal().
      expect(localStart, equals(utcStart.toLocal()));
    });

    test('localEnd converts UTC DateTime to local timezone', () {
      final utcEnd = DateTime.utc(2026, 3, 21, 21, 0); // 9:00 PM UTC
      final event = _makeEvent(
        start: DateTime.utc(2026, 3, 21, 18, 0),
        end: utcEnd,
        isUtcTime: true,
      );

      final localEnd = EventTimeDisplay.localEnd(event);

      expect(localEnd, isNotNull);
      expect(localEnd!.isUtc, isFalse);
      expect(localEnd, equals(utcEnd.toLocal()));
    });

    test('UTC conversion changes hour based on device offset', () {
      final utcTime = DateTime.utc(2026, 7, 15, 12, 0); // noon UTC
      final event = _makeEvent(start: utcTime, isUtcTime: true);

      final local = EventTimeDisplay.localStart(event)!;
      final expectedOffset = DateTime.now().timeZoneOffset;

      // The local time should differ from UTC by the device's offset.
      expect(local.difference(utcTime), equals(expectedOffset));
    });
  });

  group('EventTimeDisplay — local-time events displayed as-is', () {
    test('localStart returns same wall-clock time for local events', () {
      // Community Day: 2:00 PM local time everywhere.
      final localTime = DateTime(2026, 3, 21, 14, 0);
      final event = _makeEvent(
        start: localTime,
        end: DateTime(2026, 3, 21, 17, 0),
        isUtcTime: false,
      );

      final displayStart = EventTimeDisplay.localStart(event);

      expect(displayStart, isNotNull);
      // Wall-clock time must be preserved — no conversion.
      expect(displayStart!.hour, equals(14));
      expect(displayStart.minute, equals(0));
      expect(displayStart.year, equals(2026));
      expect(displayStart.month, equals(3));
      expect(displayStart.day, equals(21));
    });

    test('localEnd returns same wall-clock time for local events', () {
      final localEnd = DateTime(2026, 3, 21, 17, 0);
      final event = _makeEvent(
        start: DateTime(2026, 3, 21, 14, 0),
        end: localEnd,
        isUtcTime: false,
      );

      final displayEnd = EventTimeDisplay.localEnd(event);

      expect(displayEnd, isNotNull);
      expect(displayEnd!.hour, equals(17));
      expect(displayEnd.minute, equals(0));
    });
  });

  group('EventTimeDisplay — local-time events are timezone-immune', () {
    test('local-time event hour is NOT shifted by device timezone offset', () {
      // Community Day at 2:00 PM — must show 2:00 PM regardless of timezone.
      final localTime = DateTime(2026, 3, 21, 14, 0);
      final event = _makeEvent(
        start: localTime,
        end: DateTime(2026, 3, 21, 17, 0),
        isUtcTime: false,
      );

      final displayStart = EventTimeDisplay.localStart(event);
      final displayEnd = EventTimeDisplay.localEnd(event);

      // Unlike UTC events, local-time events must NOT differ by device offset.
      expect(displayStart!.hour, equals(localTime.hour));
      expect(displayStart.minute, equals(localTime.minute));
      expect(displayEnd!.hour, equals(17));
      expect(displayEnd.minute, equals(0));
    });

    test('local-time midnight event preserves hour zero', () {
      // Edge case: midnight local time must not wrap to previous/next day.
      final midnight = DateTime(2026, 3, 22, 0, 0);
      final event = _makeEvent(start: midnight, isUtcTime: false);

      final display = EventTimeDisplay.localStart(event);

      expect(display!.hour, equals(0));
      expect(display.day, equals(22));
      expect(display.month, equals(3));
    });

    test('local-time late-night event preserves hour 23', () {
      final lateNight = DateTime(2026, 3, 21, 23, 59);
      final event = _makeEvent(start: lateNight, isUtcTime: false);

      final display = EventTimeDisplay.localStart(event);

      expect(display!.hour, equals(23));
      expect(display.minute, equals(59));
      expect(display.day, equals(21));
    });

    test('multiple local-time event types all preserve wall-clock time', () {
      // Community Day, Spotlight Hour, Raid Hour — all use local time.
      final times = [
        DateTime(2026, 4, 11, 14, 0),  // Community Day 2 PM
        DateTime(2026, 4, 14, 18, 0),  // Spotlight Hour 6 PM
        DateTime(2026, 4, 15, 18, 0),  // Raid Hour 6 PM
      ];

      for (final time in times) {
        final event = _makeEvent(start: time, isUtcTime: false);
        final display = EventTimeDisplay.localStart(event);
        expect(display!.hour, equals(time.hour),
            reason: 'Wall-clock time should be preserved for ${time.hour}:00');
        expect(display.minute, equals(time.minute));
      }
    });

    test('formatTimeRange shows correct wall-clock for local-time event', () {
      // Spotlight Hour: 6:00 PM – 7:00 PM local.
      final event = _makeEvent(
        start: DateTime(2026, 4, 14, 18, 0),
        end: DateTime(2026, 4, 14, 19, 0),
        isUtcTime: false,
      );

      expect(
        EventTimeDisplay.formatTimeRange(event),
        equals('6:00 PM – 7:00 PM'),
      );
    });
  });

  group('EventTimeDisplay — null time handling', () {
    test('localStart returns null when start is null', () {
      final event = _makeEvent(isUtcTime: true);
      expect(EventTimeDisplay.localStart(event), isNull);
    });

    test('localEnd returns null when end is null', () {
      final event = _makeEvent(isUtcTime: false);
      expect(EventTimeDisplay.localEnd(event), isNull);
    });
  });

  group('EventTimeDisplay.formatTimeRange', () {
    test('shows time range for same-day event', () {
      final event = _makeEvent(
        start: DateTime(2026, 3, 21, 14, 0),
        end: DateTime(2026, 3, 21, 17, 0),
        isUtcTime: false,
      );

      final result = EventTimeDisplay.formatTimeRange(event);

      expect(result, equals('2:00 PM – 5:00 PM'));
    });

    test('shows date+time range for multi-day event', () {
      final event = _makeEvent(
        start: DateTime(2026, 3, 21, 10, 0),
        end: DateTime(2026, 3, 23, 20, 0),
        isUtcTime: false,
      );

      final result = EventTimeDisplay.formatTimeRange(event);

      expect(result, equals('Mar 21, 10:00 AM – Mar 23, 8:00 PM'));
    });

    test('returns Time TBD when both start and end are null', () {
      final event = _makeEvent(isUtcTime: false);
      expect(EventTimeDisplay.formatTimeRange(event), equals('Time TBD'));
    });

    test('returns Starts prefix when only start is set', () {
      final event = _makeEvent(
        start: DateTime(2026, 3, 21, 14, 0),
        isUtcTime: false,
      );

      expect(
        EventTimeDisplay.formatTimeRange(event),
        equals('Starts 2:00 PM'),
      );
    });

    test('returns Ends prefix when only end is set', () {
      final event = _makeEvent(
        end: DateTime(2026, 3, 21, 17, 0),
        isUtcTime: false,
      );

      expect(
        EventTimeDisplay.formatTimeRange(event),
        equals('Ends 5:00 PM'),
      );
    });
  });

  group('EventTimeDisplay.formatDate', () {
    test('formats date from local start time', () {
      final event = _makeEvent(
        start: DateTime(2026, 3, 21, 14, 0),
        isUtcTime: false,
      );

      expect(EventTimeDisplay.formatDate(event), equals('Mar 21'));
    });

    test('returns Date TBD when start is null', () {
      final event = _makeEvent(isUtcTime: false);
      expect(EventTimeDisplay.formatDate(event), equals('Date TBD'));
    });

    test('formats date using converted local time for UTC events', () {
      // Midnight UTC on Mar 22 — in UTC+X timezones this is still Mar 22,
      // but in UTC-X timezones this becomes Mar 21.
      final utcTime = DateTime.utc(2026, 3, 22, 0, 0);
      final event = _makeEvent(start: utcTime, isUtcTime: true);

      final expectedLocal = utcTime.toLocal();
      final result = EventTimeDisplay.formatDate(event);

      // The displayed date should match the local conversion, not the UTC date.
      expect(result, contains('Mar'));
      expect(result, contains('${expectedLocal.day}'));
    });
  });

  group('EventTimeDisplay — fixed UTC events convert to local display', () {
    test('formatTimeRange shows local times for same-day UTC event', () {
      // GO Fest 10:00–18:00 UTC — should display converted local times.
      final utcStart = DateTime.utc(2026, 6, 7, 10, 0);
      final utcEnd = DateTime.utc(2026, 6, 7, 18, 0);
      final event = _makeEvent(
        start: utcStart,
        end: utcEnd,
        isUtcTime: true,
      );

      final result = EventTimeDisplay.formatTimeRange(event);
      final expectedStart = utcStart.toLocal();
      final expectedEnd = utcEnd.toLocal();

      // The formatted string should use the local-converted times, not UTC.
      if (expectedStart.day == expectedEnd.day) {
        expect(result, contains('–'));
        // Verify the start hour appears in the output.
        final startHour = expectedStart.hour % 12 == 0 ? 12 : expectedStart.hour % 12;
        expect(result, contains('$startHour:00'));
      } else {
        // If timezone offset pushes them to different days, date format is used.
        expect(result, contains('–'));
      }
    });

    test('formatTimeRange for UTC event crossing date boundary shows dates', () {
      // Event from 22:00 UTC to 04:00 UTC next day — in UTC+ zones this
      // may land on different local dates.
      final utcStart = DateTime.utc(2026, 6, 7, 22, 0);
      final utcEnd = DateTime.utc(2026, 6, 8, 4, 0);
      final event = _makeEvent(
        start: utcStart,
        end: utcEnd,
        isUtcTime: true,
      );

      final localStart = utcStart.toLocal();
      final localEnd = utcEnd.toLocal();
      final result = EventTimeDisplay.formatTimeRange(event);

      if (localStart.day != localEnd.day) {
        // Multi-day format includes month and day.
        expect(result, contains('Jun'));
      }
      // Either way, the result should not be "Time TBD".
      expect(result, isNot(equals('Time TBD')));
    });

    test('formatDate for UTC midnight event shows correct local date', () {
      // Midnight UTC on Mar 22 — negative-offset timezones shift to Mar 21.
      final utcMidnight = DateTime.utc(2026, 3, 22, 0, 0);
      final event = _makeEvent(start: utcMidnight, isUtcTime: true);

      final expectedLocal = utcMidnight.toLocal();
      final result = EventTimeDisplay.formatDate(event);

      expect(result, equals('${_monthAbbr(expectedLocal.month)} ${expectedLocal.day}'));
    });

    test('multiple fixed-UTC events all convert consistently', () {
      // GO Fest, Safari Zone, and global raid events all use fixed UTC times.
      final utcTimes = [
        DateTime.utc(2026, 6, 7, 10, 0),   // GO Fest morning
        DateTime.utc(2026, 6, 7, 14, 0),   // GO Fest afternoon
        DateTime.utc(2026, 8, 22, 9, 0),   // Safari Zone
        DateTime.utc(2026, 12, 31, 23, 0), // New Year's Eve event
      ];

      for (final utcTime in utcTimes) {
        final event = _makeEvent(start: utcTime, isUtcTime: true);
        final local = EventTimeDisplay.localStart(event);

        expect(local, isNotNull,
            reason: 'UTC ${utcTime.toIso8601String()} should produce a non-null local time');
        expect(local!.isUtc, isFalse,
            reason: 'Converted time should not be UTC');
        expect(local, equals(utcTime.toLocal()),
            reason: 'Should match Dart toLocal() for ${utcTime.toIso8601String()}');
      }
    });

    test('UTC event end-of-year boundary converts correctly', () {
      // Dec 31 23:00 UTC → in UTC+ zones this becomes Jan 1 of the next year.
      final utcTime = DateTime.utc(2026, 12, 31, 23, 0);
      final event = _makeEvent(start: utcTime, isUtcTime: true);

      final local = EventTimeDisplay.localStart(event)!;
      final expectedLocal = utcTime.toLocal();

      expect(local.year, equals(expectedLocal.year));
      expect(local.month, equals(expectedLocal.month));
      expect(local.day, equals(expectedLocal.day));
      expect(local.hour, equals(expectedLocal.hour));
    });

    test('formatTimeRange for UTC event uses local times not raw UTC', () {
      // Verify that formatTimeRange does NOT just display the raw UTC hours.
      final utcStart = DateTime.utc(2026, 7, 15, 0, 0);  // midnight UTC
      final utcEnd = DateTime.utc(2026, 7, 15, 6, 0);    // 6 AM UTC
      final event = _makeEvent(
        start: utcStart,
        end: utcEnd,
        isUtcTime: true,
      );

      final result = EventTimeDisplay.formatTimeRange(event);
      final expectedLocalStart = utcStart.toLocal();
      final expectedLocalEnd = utcEnd.toLocal();

      // The formatted range must reflect local-converted hours.
      final startHour = expectedLocalStart.hour % 12 == 0
          ? 12
          : expectedLocalStart.hour % 12;
      final endHour = expectedLocalEnd.hour % 12 == 0
          ? 12
          : expectedLocalEnd.hour % 12;

      if (expectedLocalStart.day == expectedLocalEnd.day) {
        expect(result, contains('$startHour:00'));
        expect(result, contains('$endHour:00'));
      } else {
        // Multi-day format — still should contain the hours.
        expect(result, contains('$startHour:00'));
        expect(result, contains('$endHour:00'));
      }
    });
  });

  group('EventTimeDisplay — DST transition edge cases', () {
    // US Spring-forward: clocks skip 2:00 AM → 3:00 AM on second Sunday of March.
    // 2026 spring-forward: March 8, 2026 at 2:00 AM EST → 3:00 AM EDT.

    test('local-time event on spring-forward day preserves wall-clock time', () {
      // Community Day at 2:00 PM on DST transition day — must still show 2:00 PM.
      final event = _makeEvent(
        start: DateTime(2026, 3, 8, 14, 0),
        end: DateTime(2026, 3, 8, 17, 0),
        isUtcTime: false,
      );

      final displayStart = EventTimeDisplay.localStart(event)!;
      final displayEnd = EventTimeDisplay.localEnd(event)!;

      expect(displayStart.hour, equals(14));
      expect(displayStart.day, equals(8));
      expect(displayEnd.hour, equals(17));
      expect(displayEnd.day, equals(8));
    });

    test('local-time multi-day event spanning spring-forward preserves wall-clock', () {
      // Event runs Mar 7–10, crossing the spring-forward boundary on Mar 8.
      // Wall-clock times must be identical on both sides of the transition.
      final event = _makeEvent(
        start: DateTime(2026, 3, 7, 10, 0),
        end: DateTime(2026, 3, 10, 20, 0),
        isUtcTime: false,
      );

      final displayStart = EventTimeDisplay.localStart(event)!;
      final displayEnd = EventTimeDisplay.localEnd(event)!;

      // The start and end hours should be unchanged — DST doesn't affect display.
      expect(displayStart.hour, equals(10));
      expect(displayStart.day, equals(7));
      expect(displayEnd.hour, equals(20));
      expect(displayEnd.day, equals(10));
    });

    test('UTC event during spring-forward gap converts to valid local time', () {
      // 2:30 AM EST doesn't exist on spring-forward day (skips to 3:00 AM EDT).
      // UTC 7:30 AM = 2:30 AM EST, but after spring-forward = 3:30 AM EDT.
      // Dart's toLocal() handles this — result should be a valid local time.
      final utcTime = DateTime.utc(2026, 3, 8, 7, 30);
      final event = _makeEvent(start: utcTime, isUtcTime: true);

      final local = EventTimeDisplay.localStart(event)!;
      final expected = utcTime.toLocal();

      expect(local, isNotNull);
      expect(local.isUtc, isFalse);
      expect(local, equals(expected));
      // The result must be a valid local time (Dart resolves the gap).
      expect(local.hour, isNonNegative);
      expect(local.hour, lessThan(24));
    });

    // US Fall-back: clocks repeat 1:00 AM–2:00 AM on first Sunday of November.
    // 2026 fall-back: November 1, 2026 at 2:00 AM EDT → 1:00 AM EST.

    test('local-time event on fall-back day preserves wall-clock time', () {
      // Spotlight Hour at 6:00 PM on fall-back day — unaffected by DST.
      final event = _makeEvent(
        start: DateTime(2026, 11, 1, 18, 0),
        end: DateTime(2026, 11, 1, 19, 0),
        isUtcTime: false,
      );

      final displayStart = EventTimeDisplay.localStart(event)!;
      final displayEnd = EventTimeDisplay.localEnd(event)!;

      expect(displayStart.hour, equals(18));
      expect(displayEnd.hour, equals(19));
      expect(displayStart.day, equals(1));
    });

    test('UTC event during fall-back ambiguous hour converts correctly', () {
      // 1:30 AM occurs twice on fall-back day. UTC 6:30 AM = 1:30 AM EST (after
      // fall-back). Dart's toLocal() picks the unambiguous mapping from UTC.
      final utcTime = DateTime.utc(2026, 11, 1, 6, 30);
      final event = _makeEvent(start: utcTime, isUtcTime: true);

      final local = EventTimeDisplay.localStart(event)!;
      final expected = utcTime.toLocal();

      expect(local, isNotNull);
      expect(local.isUtc, isFalse);
      expect(local, equals(expected));
    });

    test('multi-day event spanning fall-back preserves wall-clock on both sides', () {
      // Event Oct 31 – Nov 3, crossing fall-back on Nov 1.
      final event = _makeEvent(
        start: DateTime(2026, 10, 31, 10, 0),
        end: DateTime(2026, 11, 3, 20, 0),
        isUtcTime: false,
      );

      final displayStart = EventTimeDisplay.localStart(event)!;
      final displayEnd = EventTimeDisplay.localEnd(event)!;

      expect(displayStart.hour, equals(10));
      expect(displayStart.month, equals(10));
      expect(displayStart.day, equals(31));
      expect(displayEnd.hour, equals(20));
      expect(displayEnd.month, equals(11));
      expect(displayEnd.day, equals(3));
    });

    test('formatTimeRange for local-time event on DST day shows correct times', () {
      // Community Day 2:00–5:00 PM on spring-forward day.
      final event = _makeEvent(
        start: DateTime(2026, 3, 8, 14, 0),
        end: DateTime(2026, 3, 8, 17, 0),
        isUtcTime: false,
      );

      expect(
        EventTimeDisplay.formatTimeRange(event),
        equals('2:00 PM – 5:00 PM'),
      );
    });
  });

  group('EventTimeDisplay — date boundary crossing edge cases', () {
    test('event ending exactly at midnight shows correct date range', () {
      // Event from 6 PM to midnight — crosses the day boundary.
      final event = _makeEvent(
        start: DateTime(2026, 3, 21, 18, 0),
        end: DateTime(2026, 3, 22, 0, 0),
        isUtcTime: false,
      );

      final result = EventTimeDisplay.formatTimeRange(event);

      // Different days → multi-day format.
      expect(result, contains('Mar 21'));
      expect(result, contains('Mar 22'));
      expect(result, contains('12:00 AM'));
    });

    test('event starting before midnight ending after shows multi-day format', () {
      // Raid event 10 PM – 2 AM next day.
      final event = _makeEvent(
        start: DateTime(2026, 3, 21, 22, 0),
        end: DateTime(2026, 3, 22, 2, 0),
        isUtcTime: false,
      );

      final result = EventTimeDisplay.formatTimeRange(event);

      expect(result, contains('Mar 21'));
      expect(result, contains('Mar 22'));
      expect(result, contains('10:00 PM'));
      expect(result, contains('2:00 AM'));
    });

    test('event crossing month boundary shows correct months', () {
      // Event spanning March 31 to April 1.
      final event = _makeEvent(
        start: DateTime(2026, 3, 31, 10, 0),
        end: DateTime(2026, 4, 1, 20, 0),
        isUtcTime: false,
      );

      final result = EventTimeDisplay.formatTimeRange(event);

      expect(result, contains('Mar 31'));
      expect(result, contains('Apr 1'));
    });

    test('event crossing year boundary shows correct dates', () {
      // New Year's Eve event Dec 31 – Jan 1.
      final event = _makeEvent(
        start: DateTime(2026, 12, 31, 22, 0),
        end: DateTime(2027, 1, 1, 2, 0),
        isUtcTime: false,
      );

      final result = EventTimeDisplay.formatTimeRange(event);

      expect(result, contains('Dec 31'));
      expect(result, contains('Jan 1'));
    });

    test('UTC event at midnight crossing date line converts to correct local date', () {
      // Midnight UTC on Jan 1 — in negative offsets this is still Dec 31.
      final utcMidnight = DateTime.utc(2027, 1, 1, 0, 0);
      final event = _makeEvent(start: utcMidnight, isUtcTime: true);

      final local = EventTimeDisplay.localStart(event)!;
      final expected = utcMidnight.toLocal();

      expect(local.year, equals(expected.year));
      expect(local.month, equals(expected.month));
      expect(local.day, equals(expected.day));
      expect(local.hour, equals(expected.hour));
    });

    test('formatDate for UTC event near midnight shows local date', () {
      // 11:59 PM UTC — in UTC+ timezones this is already the next day.
      final utcTime = DateTime.utc(2026, 6, 30, 23, 59);
      final event = _makeEvent(start: utcTime, isUtcTime: true);

      final expectedLocal = utcTime.toLocal();
      final result = EventTimeDisplay.formatDate(event);

      expect(result, equals(
        '${_monthAbbr(expectedLocal.month)} ${expectedLocal.day}',
      ));
    });

    test('local-time event at exactly midnight preserves date and hour zero', () {
      // Event starts exactly at midnight — must not drift to previous day.
      final event = _makeEvent(
        start: DateTime(2026, 4, 1, 0, 0),
        end: DateTime(2026, 4, 1, 8, 0),
        isUtcTime: false,
      );

      final displayStart = EventTimeDisplay.localStart(event)!;

      expect(displayStart.year, equals(2026));
      expect(displayStart.month, equals(4));
      expect(displayStart.day, equals(1));
      expect(displayStart.hour, equals(0));
      expect(displayStart.minute, equals(0));
    });

    test('local-time event at 23:59:59 preserves correct day', () {
      // Event ending at 23:59:59 — must not round to next day.
      final event = _makeEvent(
        start: DateTime(2026, 3, 31, 20, 0),
        end: DateTime(2026, 3, 31, 23, 59, 59),
        isUtcTime: false,
      );

      final displayEnd = EventTimeDisplay.localEnd(event)!;

      expect(displayEnd.day, equals(31));
      expect(displayEnd.month, equals(3));
      expect(displayEnd.hour, equals(23));
      expect(displayEnd.minute, equals(59));
    });

    test('UTC event spanning Feb 28–Mar 1 in leap year converts correctly', () {
      // 2028 is a leap year — Feb 29 exists.
      final utcStart = DateTime.utc(2028, 2, 28, 22, 0);
      final utcEnd = DateTime.utc(2028, 3, 1, 6, 0);
      final event = _makeEvent(
        start: utcStart,
        end: utcEnd,
        isUtcTime: true,
      );

      final localStart = EventTimeDisplay.localStart(event)!;
      final localEnd = EventTimeDisplay.localEnd(event)!;

      expect(localStart, equals(utcStart.toLocal()));
      expect(localEnd, equals(utcEnd.toLocal()));
    });
  });

  group('EventTimeDisplay — JSON roundtrip preserves timezone behavior', () {
    test('UTC event parsed from JSON converts to local on display', () {
      // Simulate an API response with a UTC timestamp (Z suffix).
      final json = {
        'id': 'go-fest-2026',
        'name': 'GO Fest 2026 Global',
        'eventType': 'pokemon-go-fest',
        'heading': 'GO Fest',
        'imageUrl': 'https://example.com/gofest.png',
        'linkUrl': 'https://example.com/gofest',
        'start': '2026-06-07T10:00:00.000Z',
        'end': '2026-06-07T18:00:00.000Z',
        'isUtcTime': true,
        'hasSpawns': true,
        'hasResearchTasks': true,
        'buffs': <dynamic>[],
        'featuredPokemon': <dynamic>[],
        'promoCodes': <dynamic>[],
      };

      final event = EventDto.fromJson(json);
      final localStart = EventTimeDisplay.localStart(event);

      expect(localStart, isNotNull);
      expect(localStart!.isUtc, isFalse);

      // Should equal the parsed UTC time converted to local.
      final expectedUtc = DateTime.parse('2026-06-07T10:00:00.000Z');
      expect(localStart, equals(expectedUtc.toLocal()));
    });

    test('local-time event parsed from JSON keeps wall-clock time', () {
      // Simulate an API response with a local timestamp (no Z suffix).
      final json = {
        'id': 'community-day-mar-2026',
        'name': 'Community Day: March 2026',
        'eventType': 'community-day',
        'heading': 'Community Day',
        'imageUrl': 'https://example.com/cd.png',
        'linkUrl': 'https://example.com/cd',
        'start': '2026-03-15T14:00:00.000',
        'end': '2026-03-15T17:00:00.000',
        'isUtcTime': false,
        'hasSpawns': true,
        'hasResearchTasks': false,
        'buffs': <dynamic>[],
        'featuredPokemon': <dynamic>[],
        'promoCodes': <dynamic>[],
      };

      final event = EventDto.fromJson(json);
      final localStart = EventTimeDisplay.localStart(event);

      expect(localStart, isNotNull);
      // Wall-clock time must be 2:00 PM regardless of device timezone.
      expect(localStart!.hour, equals(14));
      expect(localStart.minute, equals(0));
    });
  });
}
