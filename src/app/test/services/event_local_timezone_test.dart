import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gocalgo/services/events_service.dart';
import 'package:gocalgo/services/api_client.dart';
import 'package:gocalgo/services/event_time_display.dart';

/// Verifies acceptance criterion for story US-GCG-7:
/// "Events show start and end times in the user's local timezone"
///
/// Tests the full pipeline: API response → EventsService → EventTimeDisplay,
/// ensuring both UTC and local-time events display correct local times.
void main() {
  group('Events show start and end times in local timezone', () {
    late EventsService service;

    final now = DateTime(2026, 6, 7, 12, 0);

    /// Builds a mock service returning the given event list.
    EventsService _buildService(List<Map<String, dynamic>> events) {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'events': events,
            'lastUpdated': '2026-06-07T10:00:00Z',
            'cacheHit': false,
          }),
          200,
        );
      });
      final apiClient =
          ApiClient(httpClient: mockClient, baseUrl: 'http://test.local');
      return EventsService(apiClient: apiClient);
    }

    final utcEvent = {
      'id': 'go-fest-global',
      'name': 'GO Fest 2026 Global',
      'eventType': 'pokemon-go-fest',
      'heading': 'GO Fest!',
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

    final localTimeEvent = {
      'id': 'community-day-bulbasaur',
      'name': 'Community Day: Bulbasaur',
      'eventType': 'community-day',
      'heading': 'Catch Bulbasaur!',
      'imageUrl': 'https://example.com/bulbasaur.png',
      'linkUrl': 'https://example.com/community-day',
      'start': '2026-06-07T14:00:00.000',
      'end': '2026-06-07T17:00:00.000',
      'isUtcTime': false,
      'hasSpawns': true,
      'hasResearchTasks': true,
      'buffs': <dynamic>[],
      'featuredPokemon': <dynamic>[],
      'promoCodes': <dynamic>[],
    };

    setUp(() {
      service = _buildService([utcEvent, localTimeEvent]);
    });

    test('UTC event start time is converted to local timezone', () async {
      final events = await service.getActiveEvents(now: now);
      final goFest = events.firstWhere((e) => e.id == 'go-fest-global');

      final displayStart = EventTimeDisplay.localStart(goFest);

      expect(displayStart, isNotNull);
      expect(displayStart!.isUtc, isFalse);
      final expectedLocal = DateTime.utc(2026, 6, 7, 10, 0).toLocal();
      expect(displayStart, equals(expectedLocal));
    });

    test('UTC event end time is converted to local timezone', () async {
      final events = await service.getActiveEvents(now: now);
      final goFest = events.firstWhere((e) => e.id == 'go-fest-global');

      final displayEnd = EventTimeDisplay.localEnd(goFest);

      expect(displayEnd, isNotNull);
      expect(displayEnd!.isUtc, isFalse);
      final expectedLocal = DateTime.utc(2026, 6, 7, 18, 0).toLocal();
      expect(displayEnd, equals(expectedLocal));
    });

    test('UTC event time range is formatted using local times', () async {
      final events = await service.getActiveEvents(now: now);
      final goFest = events.firstWhere((e) => e.id == 'go-fest-global');

      final range = EventTimeDisplay.formatTimeRange(goFest);
      final expectedStart = DateTime.utc(2026, 6, 7, 10, 0).toLocal();
      final expectedEnd = DateTime.utc(2026, 6, 7, 18, 0).toLocal();

      // The range must contain the local-converted hours, not the raw UTC hours.
      final startHour12 =
          expectedStart.hour % 12 == 0 ? 12 : expectedStart.hour % 12;
      final endHour12 =
          expectedEnd.hour % 12 == 0 ? 12 : expectedEnd.hour % 12;

      expect(range, contains('$startHour12:00'));
      expect(range, contains('$endHour12:00'));
      expect(range, isNot(equals('Time TBD')));
    });

    test('local-time event start preserves wall-clock time', () async {
      final response = await service.getEvents();
      final cd =
          response.events.firstWhere((e) => e.id == 'community-day-bulbasaur');

      final displayStart = EventTimeDisplay.localStart(cd);

      expect(displayStart, isNotNull);
      expect(displayStart!.hour, equals(14));
      expect(displayStart.minute, equals(0));
    });

    test('local-time event end preserves wall-clock time', () async {
      final response = await service.getEvents();
      final cd =
          response.events.firstWhere((e) => e.id == 'community-day-bulbasaur');

      final displayEnd = EventTimeDisplay.localEnd(cd);

      expect(displayEnd, isNotNull);
      expect(displayEnd!.hour, equals(17));
      expect(displayEnd.minute, equals(0));
    });

    test('local-time event formats as wall-clock time range', () async {
      final response = await service.getEvents();
      final cd =
          response.events.firstWhere((e) => e.id == 'community-day-bulbasaur');

      final range = EventTimeDisplay.formatTimeRange(cd);

      expect(range, equals('2:00 PM – 5:00 PM'));
    });

    test('UTC event date reflects local timezone, not UTC date', () async {
      final events = await service.getActiveEvents(now: now);
      final goFest = events.firstWhere((e) => e.id == 'go-fest-global');

      final date = EventTimeDisplay.formatDate(goFest);
      final expectedLocal = DateTime.utc(2026, 6, 7, 10, 0).toLocal();

      expect(date, contains('${expectedLocal.day}'));
      expect(date, isNot(equals('Date TBD')));
    });

    test('both event types display times through the same pipeline', () async {
      final events = await service.getActiveEvents(now: now);

      // Both events should be active and have displayable time ranges.
      for (final event in events) {
        final start = EventTimeDisplay.localStart(event);
        final end = EventTimeDisplay.localEnd(event);
        final range = EventTimeDisplay.formatTimeRange(event);

        expect(start, isNotNull, reason: '${event.id} should have a start');
        expect(end, isNotNull, reason: '${event.id} should have an end');
        expect(range, isNot(equals('Time TBD')),
            reason: '${event.id} should have a displayable range');
      }
    });

    test('UTC event near midnight converts to correct local date', () async {
      // Event at 23:00 UTC — in UTC+ timezones this crosses to the next day.
      final lateUtcEvent = {
        ...utcEvent,
        'id': 'late-utc-raid',
        'start': '2026-06-07T23:00:00.000Z',
        'end': '2026-06-08T01:00:00.000Z',
      };
      final svc = _buildService([lateUtcEvent]);
      final events = await svc.getEvents();
      final event = events.events.first;

      final displayStart = EventTimeDisplay.localStart(event)!;
      final displayEnd = EventTimeDisplay.localEnd(event)!;
      final expectedStart = DateTime.utc(2026, 6, 7, 23, 0).toLocal();
      final expectedEnd = DateTime.utc(2026, 6, 8, 1, 0).toLocal();

      expect(displayStart, equals(expectedStart));
      expect(displayEnd, equals(expectedEnd));
      // Date shown should be the local date, not the UTC date.
      expect(displayStart.day, equals(expectedStart.day));
    });

    test('multi-day local-time event preserves wall-clock on both days',
        () async {
      final multiDayEvent = {
        ...localTimeEvent,
        'id': 'season-event',
        'name': 'Season of Discovery',
        'eventType': 'season',
        'start': '2026-06-01T00:00:00.000',
        'end': '2026-09-01T00:00:00.000',
      };
      final svc = _buildService([multiDayEvent]);
      final events = await svc.getEvents();
      final event = events.events.first;

      final displayStart = EventTimeDisplay.localStart(event)!;
      final displayEnd = EventTimeDisplay.localEnd(event)!;

      expect(displayStart.month, equals(6));
      expect(displayStart.day, equals(1));
      expect(displayStart.hour, equals(0));
      expect(displayEnd.month, equals(9));
      expect(displayEnd.day, equals(1));
      expect(displayEnd.hour, equals(0));
    });

    test('event with only start time shows Starts prefix in local time',
        () async {
      final startOnlyEvent = {
        ...localTimeEvent,
        'id': 'start-only',
        'end': null,
      };
      final svc = _buildService([startOnlyEvent]);
      final events = await svc.getEvents();
      final event = events.events.first;

      final range = EventTimeDisplay.formatTimeRange(event);

      expect(range, equals('Starts 2:00 PM'));
    });

    test('event with only end time shows Ends prefix in local time', () async {
      final endOnlyEvent = {
        ...localTimeEvent,
        'id': 'end-only',
        'start': null,
        'end': '2026-06-07T17:00:00.000',
      };
      final svc = _buildService([endOnlyEvent]);
      final events = await svc.getEvents();
      final event = events.events.first;

      final range = EventTimeDisplay.formatTimeRange(event);

      expect(range, equals('Ends 5:00 PM'));
    });
  });
}
