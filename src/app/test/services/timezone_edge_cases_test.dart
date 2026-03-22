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
      id: 'tz-edge-test',
      name: 'Timezone Edge Case',
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
  // ── Northern hemisphere DST — US spring-forward (March 8, 2026) ──

  group('DST — US spring-forward edge cases', () {
    test('UTC event in spring-forward gap converts to valid local time', () {
      // 2:30 AM EST doesn't exist (clocks skip 2→3 AM). UTC 07:30 maps
      // to this gap moment. Dart's toLocal() must resolve it.
      final utcTime = DateTime.utc(2026, 3, 8, 7, 30);
      final event = _makeEvent(start: utcTime, isUtcTime: true);

      final local = EventTimeDisplay.localStart(event)!;
      final expected = utcTime.toLocal();

      expect(local, isNotNull);
      expect(local.isUtc, isFalse);
      expect(local, equals(expected));
      expect(local.hour, isNonNegative);
      expect(local.hour, lessThan(24));
    });

    test('local-time event at gap hour (2:30 AM) preserves wall-clock', () {
      // 2:30 AM is skipped in US Eastern, but local-time events display as-is.
      final event = _makeEvent(
        start: DateTime(2026, 3, 8, 2, 30),
        end: DateTime(2026, 3, 8, 5, 0),
        isUtcTime: false,
      );

      final displayStart = EventTimeDisplay.localStart(event)!;
      final displayEnd = EventTimeDisplay.localEnd(event)!;

      expect(displayStart.hour, equals(2));
      expect(displayStart.minute, equals(30));
      expect(displayEnd.hour, equals(5));
    });

    test('UTC events straddling spring-forward boundary convert correctly', () {
      // Event starts before spring-forward (UTC 06:00 = 1 AM EST) and ends
      // after (UTC 09:00 = 5 AM EDT). Both must convert via toLocal().
      final utcStart = DateTime.utc(2026, 3, 8, 6, 0);
      final utcEnd = DateTime.utc(2026, 3, 8, 9, 0);
      final event = _makeEvent(start: utcStart, end: utcEnd, isUtcTime: true);

      final localStart = EventTimeDisplay.localStart(event)!;
      final localEnd = EventTimeDisplay.localEnd(event)!;

      expect(localStart, equals(utcStart.toLocal()));
      expect(localEnd, equals(utcEnd.toLocal()));
      // The 3-hour UTC span should still be 3 hours in local.
      expect(localEnd.difference(localStart).inHours, equals(3));
    });
  });

  // ── Northern hemisphere DST — US fall-back (November 1, 2026) ──

  group('DST — US fall-back edge cases', () {
    test('UTC events in ambiguous hour remain distinct after conversion', () {
      // 1:30 AM occurs twice on fall-back day.
      // UTC 05:30 = 1:30 AM EDT (before), UTC 06:30 = 1:30 AM EST (after).
      final utcBefore = DateTime.utc(2026, 11, 1, 5, 30);
      final utcAfter = DateTime.utc(2026, 11, 1, 6, 30);

      final evBefore = _makeEvent(start: utcBefore, isUtcTime: true);
      final evAfter = _makeEvent(start: utcAfter, isUtcTime: true);

      final localBefore = EventTimeDisplay.localStart(evBefore)!;
      final localAfter = EventTimeDisplay.localStart(evAfter)!;

      // Both convert correctly via toLocal().
      expect(localBefore, equals(utcBefore.toLocal()));
      expect(localAfter, equals(utcAfter.toLocal()));
      // They must be 1 hour apart (the UTC instants differ by 1 hour).
      expect(localAfter.difference(localBefore).inMinutes, equals(60));
    });

    test('local-time event in ambiguous hour preserves wall-clock', () {
      // Local-time event at 1:30 AM on fall-back day — ambiguous but preserved.
      final event = _makeEvent(
        start: DateTime(2026, 11, 1, 1, 30),
        end: DateTime(2026, 11, 1, 5, 0),
        isUtcTime: false,
      );

      final displayStart = EventTimeDisplay.localStart(event)!;

      expect(displayStart.hour, equals(1));
      expect(displayStart.minute, equals(30));
      expect(displayStart.day, equals(1));
      expect(displayStart.month, equals(11));
    });

    test('multi-day event spanning fall-back preserves wall-clock both sides', () {
      final event = _makeEvent(
        start: DateTime(2026, 10, 30, 10, 0),
        end: DateTime(2026, 11, 3, 20, 0),
        isUtcTime: false,
      );

      final displayStart = EventTimeDisplay.localStart(event)!;
      final displayEnd = EventTimeDisplay.localEnd(event)!;

      expect(displayStart.hour, equals(10));
      expect(displayStart.month, equals(10));
      expect(displayStart.day, equals(30));
      expect(displayEnd.hour, equals(20));
      expect(displayEnd.month, equals(11));
      expect(displayEnd.day, equals(3));
    });
  });

  // ── Southern hemisphere DST — Australia AEDT→AEST (April 5, 2026) ──

  group('DST — Australian fall-back (April 5, 2026)', () {
    test('UTC event at Australian fall-back moment converts correctly', () {
      // AEDT→AEST at 3:00 AM local = UTC 16:00 April 4.
      // Clocks go back, so 2:00 AM occurs twice.
      final utcTime = DateTime.utc(2026, 4, 4, 16, 0);
      final event = _makeEvent(start: utcTime, isUtcTime: true);

      final local = EventTimeDisplay.localStart(event)!;

      expect(local, isNotNull);
      expect(local.isUtc, isFalse);
      expect(local, equals(utcTime.toLocal()));
    });

    test('UTC events before and after Australian fall-back are distinct', () {
      // UTC 15:30 April 4 = 2:30 AM AEDT (before fall-back)
      // UTC 16:30 April 4 = 2:30 AM AEST (after fall-back)
      final utcBefore = DateTime.utc(2026, 4, 4, 15, 30);
      final utcAfter = DateTime.utc(2026, 4, 4, 16, 30);

      final evBefore = _makeEvent(start: utcBefore, isUtcTime: true);
      final evAfter = _makeEvent(start: utcAfter, isUtcTime: true);

      final localBefore = EventTimeDisplay.localStart(evBefore)!;
      final localAfter = EventTimeDisplay.localStart(evAfter)!;

      expect(localBefore, equals(utcBefore.toLocal()));
      expect(localAfter, equals(utcAfter.toLocal()));
      expect(localAfter.difference(localBefore).inMinutes, equals(60));
    });

    test('local-time event on Australian fall-back day preserves wall-clock', () {
      // Community Day at 2:00 PM on April 5 — unaffected by DST.
      final event = _makeEvent(
        start: DateTime(2026, 4, 5, 14, 0),
        end: DateTime(2026, 4, 5, 17, 0),
        isUtcTime: false,
      );

      final displayStart = EventTimeDisplay.localStart(event)!;
      final displayEnd = EventTimeDisplay.localEnd(event)!;

      expect(displayStart.hour, equals(14));
      expect(displayEnd.hour, equals(17));
      expect(displayStart.day, equals(5));
      expect(displayStart.month, equals(4));
    });

    test('formatTimeRange for local event on Australian fall-back day', () {
      final event = _makeEvent(
        start: DateTime(2026, 4, 5, 14, 0),
        end: DateTime(2026, 4, 5, 17, 0),
        isUtcTime: false,
      );

      expect(EventTimeDisplay.formatTimeRange(event), equals('2:00 PM – 5:00 PM'));
    });
  });

  // ── Southern hemisphere DST — Australia AEST→AEDT (October 4, 2026) ──

  group('DST — Australian spring-forward (October 4, 2026)', () {
    test('UTC event at Australian spring-forward moment converts correctly', () {
      // AEST→AEDT at 2:00 AM local = UTC 16:00 Oct 3.
      // 2:00 AM–3:00 AM local is skipped.
      final utcTime = DateTime.utc(2026, 10, 3, 16, 0);
      final event = _makeEvent(start: utcTime, isUtcTime: true);

      final local = EventTimeDisplay.localStart(event)!;

      expect(local, isNotNull);
      expect(local.isUtc, isFalse);
      expect(local, equals(utcTime.toLocal()));
    });

    test('local-time event at skipped hour on AU spring-forward preserves wall-clock', () {
      // 2:30 AM is skipped in Australia on Oct 4. Local-time event stores as-is.
      final event = _makeEvent(
        start: DateTime(2026, 10, 4, 2, 30),
        end: DateTime(2026, 10, 4, 5, 0),
        isUtcTime: false,
      );

      final displayStart = EventTimeDisplay.localStart(event)!;

      expect(displayStart.hour, equals(2));
      expect(displayStart.minute, equals(30));
      expect(displayStart.day, equals(4));
      expect(displayStart.month, equals(10));
    });

    test('multi-day event spanning Australian spring-forward preserves wall-clock', () {
      // Event Oct 2–6, crossing spring-forward on Oct 4.
      final event = _makeEvent(
        start: DateTime(2026, 10, 2, 10, 0),
        end: DateTime(2026, 10, 6, 20, 0),
        isUtcTime: false,
      );

      final displayStart = EventTimeDisplay.localStart(event)!;
      final displayEnd = EventTimeDisplay.localEnd(event)!;

      expect(displayStart.hour, equals(10));
      expect(displayStart.day, equals(2));
      expect(displayEnd.hour, equals(20));
      expect(displayEnd.day, equals(6));
    });
  });

  // ── Southern hemisphere DST — Brazil ──

  group('DST — Brazilian transitions', () {
    test('UTC event at Brazilian fall-back moment converts correctly', () {
      // BRST→BRT: Feb 15, 2026 at midnight local = UTC 02:00.
      final utcTime = DateTime.utc(2026, 2, 15, 2, 0);
      final event = _makeEvent(start: utcTime, isUtcTime: true);

      final local = EventTimeDisplay.localStart(event)!;

      expect(local, isNotNull);
      expect(local.isUtc, isFalse);
      expect(local, equals(utcTime.toLocal()));
    });

    test('UTC event at Brazilian spring-forward moment converts correctly', () {
      // BRT→BRST: Nov 1, 2026 at midnight local = UTC 03:00.
      final utcTime = DateTime.utc(2026, 11, 1, 3, 0);
      final event = _makeEvent(start: utcTime, isUtcTime: true);

      final local = EventTimeDisplay.localStart(event)!;

      expect(local, isNotNull);
      expect(local.isUtc, isFalse);
      expect(local, equals(utcTime.toLocal()));
    });

    test('local-time event on Brazilian DST day preserves wall-clock', () {
      // Community Day at 2:00 PM on Nov 1 (Brazilian spring-forward day).
      final event = _makeEvent(
        start: DateTime(2026, 11, 1, 14, 0),
        end: DateTime(2026, 11, 1, 17, 0),
        isUtcTime: false,
      );

      final displayStart = EventTimeDisplay.localStart(event)!;
      final displayEnd = EventTimeDisplay.localEnd(event)!;

      expect(displayStart.hour, equals(14));
      expect(displayEnd.hour, equals(17));
      expect(displayStart.day, equals(1));
      expect(displayStart.month, equals(11));
    });

    test('local-time midnight event on Brazilian spring-forward preserves hour zero', () {
      // Midnight is skipped to 1:00 AM in Brazil on Nov 1, but local-time events
      // preserve the wall-clock.
      final event = _makeEvent(
        start: DateTime(2026, 11, 1, 0, 0),
        end: DateTime(2026, 11, 1, 3, 0),
        isUtcTime: false,
      );

      final displayStart = EventTimeDisplay.localStart(event)!;

      expect(displayStart.hour, equals(0));
      expect(displayStart.minute, equals(0));
      expect(displayStart.day, equals(1));
    });
  });

  // ── Date boundary crossing + DST combined edge cases ──

  group('Date boundary crossing during DST transitions', () {
    test('UTC midnight event on US spring-forward day converts correctly', () {
      // Midnight UTC on March 8 (US spring-forward day).
      final utcMidnight = DateTime.utc(2026, 3, 8, 0, 0);
      final event = _makeEvent(start: utcMidnight, isUtcTime: true);

      final local = EventTimeDisplay.localStart(event)!;
      final expected = utcMidnight.toLocal();

      expect(local.year, equals(expected.year));
      expect(local.month, equals(expected.month));
      expect(local.day, equals(expected.day));
      expect(local.hour, equals(expected.hour));
    });

    test('UTC event crossing date boundary on AU fall-back day', () {
      // Event from UTC 20:00 April 4 to UTC 04:00 April 5.
      // In Australia this crosses the fall-back boundary.
      final utcStart = DateTime.utc(2026, 4, 4, 20, 0);
      final utcEnd = DateTime.utc(2026, 4, 5, 4, 0);
      final event = _makeEvent(start: utcStart, end: utcEnd, isUtcTime: true);

      final localStart = EventTimeDisplay.localStart(event)!;
      final localEnd = EventTimeDisplay.localEnd(event)!;

      expect(localStart, equals(utcStart.toLocal()));
      expect(localEnd, equals(utcEnd.toLocal()));
    });

    test('local event crossing month boundary on DST transition month', () {
      // March 31 – April 5, crossing Australian fall-back on April 5.
      final event = _makeEvent(
        start: DateTime(2026, 3, 31, 10, 0),
        end: DateTime(2026, 4, 5, 17, 0),
        isUtcTime: false,
      );

      final result = EventTimeDisplay.formatTimeRange(event);

      expect(result, contains('Mar 31'));
      expect(result, contains('Apr 5'));
    });

    test('formatDate for UTC event near midnight on DST day shows local date', () {
      // 11:59 PM UTC on March 7 (day before US spring-forward).
      // In UTC+ timezones this is already March 8.
      final utcTime = DateTime.utc(2026, 3, 7, 23, 59);
      final event = _makeEvent(start: utcTime, isUtcTime: true);

      final expectedLocal = utcTime.toLocal();
      final result = EventTimeDisplay.formatDate(event);

      expect(result, equals(
        '${_monthAbbr(expectedLocal.month)} ${expectedLocal.day}',
      ));
    });
  });

  // ── Local-time vs UTC interaction edge cases ──

  group('Local-time vs UTC interaction', () {
    test('same wall-clock time: local event unchanged, UTC event shifted', () {
      // Both events at 2:00 PM on the same day.
      // Local: must always show 2:00 PM.
      // UTC: shows 2:00 PM only if device is at UTC+0.
      final time = DateTime(2026, 6, 15, 14, 0);
      final utcTime = DateTime.utc(2026, 6, 15, 14, 0);

      final localEvent = _makeEvent(start: time, isUtcTime: false);
      final utcEvent = _makeEvent(start: utcTime, isUtcTime: true);

      final localDisplay = EventTimeDisplay.localStart(localEvent)!;
      final utcDisplay = EventTimeDisplay.localStart(utcEvent)!;

      // Local event: always 2:00 PM.
      expect(localDisplay.hour, equals(14));
      expect(localDisplay.minute, equals(0));

      // UTC event: equals toLocal() which shifts by device offset.
      expect(utcDisplay, equals(utcTime.toLocal()));

      // They are only equal if device is at UTC+0.
      final offset = DateTime.now().timeZoneOffset;
      if (offset == Duration.zero) {
        expect(localDisplay.hour, equals(utcDisplay.hour));
      }
    });

    test('formatTimeRange differs between local and UTC for same raw time', () {
      // Community Day (local) and GO Fest (UTC) both "14:00–17:00".
      final localEvent = _makeEvent(
        start: DateTime(2026, 6, 15, 14, 0),
        end: DateTime(2026, 6, 15, 17, 0),
        isUtcTime: false,
      );
      final utcEvent = _makeEvent(
        start: DateTime.utc(2026, 6, 15, 14, 0),
        end: DateTime.utc(2026, 6, 15, 17, 0),
        isUtcTime: true,
      );

      final localRange = EventTimeDisplay.formatTimeRange(localEvent);
      final utcRange = EventTimeDisplay.formatTimeRange(utcEvent);

      // Local event: always "2:00 PM – 5:00 PM".
      expect(localRange, equals('2:00 PM – 5:00 PM'));

      // UTC event: may differ if device is not at UTC+0.
      final offset = DateTime.now().timeZoneOffset;
      if (offset != Duration.zero) {
        expect(utcRange, isNot(equals(localRange)));
      }
    });

    test('JSON roundtrip: UTC event with Z suffix converts differently than local', () {
      final utcJson = {
        'id': 'utc-event',
        'name': 'GO Fest',
        'eventType': 'pokemon-go-fest',
        'heading': 'GO Fest',
        'imageUrl': '',
        'linkUrl': '',
        'start': '2026-06-07T14:00:00.000Z',
        'end': '2026-06-07T17:00:00.000Z',
        'isUtcTime': true,
        'hasSpawns': false,
        'hasResearchTasks': false,
        'buffs': <dynamic>[],
        'featuredPokemon': <dynamic>[],
        'promoCodes': <dynamic>[],
      };

      final localJson = {
        'id': 'local-event',
        'name': 'Community Day',
        'eventType': 'community-day',
        'heading': 'CD',
        'imageUrl': '',
        'linkUrl': '',
        'start': '2026-06-07T14:00:00.000',
        'end': '2026-06-07T17:00:00.000',
        'isUtcTime': false,
        'hasSpawns': false,
        'hasResearchTasks': false,
        'buffs': <dynamic>[],
        'featuredPokemon': <dynamic>[],
        'promoCodes': <dynamic>[],
      };

      final utcEvent = EventDto.fromJson(utcJson);
      final localEvent = EventDto.fromJson(localJson);

      final utcDisplay = EventTimeDisplay.localStart(utcEvent)!;
      final localDisplay = EventTimeDisplay.localStart(localEvent)!;

      // Local event: always 2:00 PM.
      expect(localDisplay.hour, equals(14));

      // UTC event: shifted by device offset.
      expect(utcDisplay, equals(DateTime.parse('2026-06-07T14:00:00.000Z').toLocal()));
    });
  });

  // ── Extreme timezone offset edge cases ──

  group('Extreme timezone offsets', () {
    test('UTC event near day boundary converts correctly regardless of offset', () {
      // Events at 23:00, 00:00, 00:30, 01:00 UTC — cover cases where large
      // positive or negative offsets shift to different dates.
      final utcTimes = [
        DateTime.utc(2026, 6, 15, 23, 0),
        DateTime.utc(2026, 6, 16, 0, 0),
        DateTime.utc(2026, 6, 16, 0, 30),
        DateTime.utc(2026, 6, 16, 1, 0),
      ];

      for (final utcTime in utcTimes) {
        final event = _makeEvent(start: utcTime, isUtcTime: true);
        final local = EventTimeDisplay.localStart(event)!;
        final expected = utcTime.toLocal();

        expect(local, equals(expected),
            reason: 'UTC ${utcTime.toIso8601String()} should convert correctly');
        expect(local.isUtc, isFalse);
      }
    });

    test('formatDate handles UTC events that cross date line for any offset', () {
      // Dec 31 at various UTC hours — could be Dec 31 or Jan 1 depending on offset.
      final utcTimes = [
        DateTime.utc(2026, 12, 31, 0, 0),
        DateTime.utc(2026, 12, 31, 12, 0),
        DateTime.utc(2026, 12, 31, 23, 59),
      ];

      for (final utcTime in utcTimes) {
        final event = _makeEvent(start: utcTime, isUtcTime: true);
        final expectedLocal = utcTime.toLocal();
        final result = EventTimeDisplay.formatDate(event);

        expect(result, equals(
          '${_monthAbbr(expectedLocal.month)} ${expectedLocal.day}',
        ), reason: 'UTC ${utcTime.toIso8601String()} should show local date');
      }
    });

    test('UTC event at year boundary converts correctly for all offsets', () {
      // Dec 31 23:00 UTC → in UTC+2 this is Jan 1 01:00.
      final utcTime = DateTime.utc(2026, 12, 31, 23, 0);
      final event = _makeEvent(start: utcTime, isUtcTime: true);

      final local = EventTimeDisplay.localStart(event)!;
      final expected = utcTime.toLocal();

      expect(local.year, equals(expected.year));
      expect(local.month, equals(expected.month));
      expect(local.day, equals(expected.day));
      expect(local.hour, equals(expected.hour));
    });
  });
}
