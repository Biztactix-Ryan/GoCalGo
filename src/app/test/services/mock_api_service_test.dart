import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gocalgo/models/event_type.dart';
import 'package:gocalgo/services/api_client.dart';
import 'package:gocalgo/services/cached_events_service.dart';
import 'package:gocalgo/services/events_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../helpers/helpers.dart';

/// Verifies acceptance criterion for story US-GCG-31:
/// "Mock API service created for testing without backend"
///
/// Tests that [MockEventsService] can fully replace the real
/// [EventsService] in tests without any HTTP or backend dependency.
void main() {
  group('MockEventsService', () {
    test('returns default event when no configuration provided', () async {
      final mock = MockEventsService();
      final response = await mock.getEvents();

      expect(response.events, hasLength(1));
      expect(response.events.first.id, 'test-event-1');
      expect(response.cacheHit, false);
    });

    test('returns configured events', () async {
      final mock = MockEventsService(
        events: [
          TestData.communityDay(),
          TestData.spotlightHour(),
          TestData.raidHour(),
        ],
      );

      final response = await mock.getEvents();
      expect(response.events, hasLength(3));
      expect(response.events[0].eventType, EventType.communityDay);
      expect(response.events[1].eventType, EventType.spotlightHour);
      expect(response.events[2].eventType, EventType.raidHour);
    });

    test('getActiveEvents filters to currently active events', () async {
      final now = DateTime(2026, 3, 21, 15, 0);
      final mock = MockEventsService(
        events: [
          TestData.event(
            id: 'active',
            name: 'Active Event',
            start: DateTime(2026, 3, 21, 10, 0),
            end: DateTime(2026, 3, 21, 20, 0),
          ),
          TestData.event(
            id: 'future',
            name: 'Future Event',
            start: DateTime(2026, 4, 1, 10, 0),
            end: DateTime(2026, 4, 1, 17, 0),
          ),
          TestData.event(
            id: 'past',
            name: 'Past Event',
            start: DateTime(2026, 3, 10, 10, 0),
            end: DateTime(2026, 3, 10, 11, 0),
          ),
        ],
      );

      final active = await mock.getActiveEvents(now: now);
      expect(active, hasLength(1));
      expect(active.first.id, 'active');
    });

    test('getUpcomingEvents filters to future events within window', () async {
      final now = DateTime(2026, 3, 21, 12, 0);
      final mock = MockEventsService(
        events: [
          TestData.event(
            id: 'soon',
            name: 'Soon Event',
            start: DateTime(2026, 3, 25, 10, 0),
            end: DateTime(2026, 3, 25, 17, 0),
          ),
          TestData.event(
            id: 'far',
            name: 'Far Event',
            start: DateTime(2026, 5, 1, 10, 0),
            end: DateTime(2026, 5, 1, 17, 0),
          ),
        ],
      );

      final upcoming = await mock.getUpcomingEvents(now: now, days: 7);
      expect(upcoming, hasLength(1));
      expect(upcoming.first.id, 'soon');
    });

    test('simulateError causes getEvents to throw', () async {
      final mock = MockEventsService(simulateError: true);

      expect(
        () => mock.getEvents(),
        throwsA(isA<MockApiException>()),
      );
    });

    test('simulateError causes getActiveEvents to throw', () async {
      final mock = MockEventsService(simulateError: true);

      expect(
        () => mock.getActiveEvents(),
        throwsA(isA<MockApiException>()),
      );
    });

    test('tracks call counts', () async {
      final mock = MockEventsService();

      await mock.getEvents();
      await mock.getEvents();
      await mock.getActiveEvents();
      await mock.getUpcomingEvents();

      expect(mock.getEventsCallCount, 2);
      expect(mock.getActiveEventsCallCount, 1);
      expect(mock.getUpcomingEventsCallCount, 1);
    });

    test('events can be changed between calls', () async {
      final mock = MockEventsService(
        events: [TestData.event(id: 'first')],
      );

      final r1 = await mock.getEvents();
      expect(r1.events.first.id, 'first');

      mock.events = [TestData.event(id: 'second')];
      final r2 = await mock.getEvents();
      expect(r2.events.first.id, 'second');
    });

    test('can toggle error simulation mid-test', () async {
      final mock = MockEventsService();

      // Works initially.
      final response = await mock.getEvents();
      expect(response.events, hasLength(1));

      // Simulate failure.
      mock.simulateError = true;
      expect(() => mock.getEvents(), throwsA(isA<MockApiException>()));

      // Recover.
      mock.simulateError = false;
      final recovered = await mock.getEvents();
      expect(recovered.events, hasLength(1));
    });
  });

  group('Mock infrastructure integrates with CachedEventsService', () {
    test('TestData + InMemoryEventCache work with CachedEventsService',
        () async {
      // Use TestData.responseJson() to build a MockClient response.
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode(TestData.responseJson(
            events: [TestData.communityDay().toJson()],
          )),
          200,
        );
      });

      final apiClient =
          ApiClient(httpClient: mockClient, baseUrl: 'http://test.local');
      final remote = EventsService(apiClient: apiClient);
      final cache = InMemoryEventCache();
      final service = CachedEventsService(remote: remote, cache: cache);

      // Populate cache.
      final response = await service.getEvents();
      expect(response.events, hasLength(1));
      expect(response.events.first.eventType, EventType.communityDay);

      // Verify cache was populated via InMemoryEventCache.
      final cached = await cache.get();
      expect(cached, isNotNull);
      expect(cached!.events.first.name, response.events.first.name);
    });
  });

  group('InMemoryEventCache', () {
    test('stores and retrieves responses', () async {
      final cache = InMemoryEventCache();
      final response = TestData.response();

      await cache.put(response);
      final retrieved = await cache.get();

      expect(retrieved, isNotNull);
      expect(retrieved!.events, hasLength(1));
    });

    test('returns null when empty', () async {
      final cache = InMemoryEventCache();
      expect(await cache.get(), isNull);
    });

    test('clear removes cached data', () async {
      final cache = InMemoryEventCache();
      await cache.put(TestData.response());
      await cache.clear();
      expect(await cache.get(), isNull);
    });
  });

  group('InMemoryFlagStore', () {
    test('flags and unflags events', () async {
      final store = InMemoryFlagStore();

      await store.flag('ev-1');
      expect(await store.isFlagged('ev-1'), true);

      await store.unflag('ev-1');
      expect(await store.isFlagged('ev-1'), false);
    });

    test('returns all flagged IDs', () async {
      final store = InMemoryFlagStore();
      await store.flag('ev-1');
      await store.flag('ev-2');

      final ids = await store.flaggedIds();
      expect(ids, containsAll(['ev-1', 'ev-2']));
    });

    test('clearAll removes all flags', () async {
      final store = InMemoryFlagStore();
      await store.flag('ev-1');
      await store.flag('ev-2');
      await store.clearAll();
      expect(await store.flaggedIds(), isEmpty);
    });
  });

  group('InMemoryOnboardingStore', () {
    test('starts incomplete', () async {
      final store = InMemoryOnboardingStore();
      expect(await store.hasCompletedOnboarding(), false);
    });

    test('marks and resets onboarding', () async {
      final store = InMemoryOnboardingStore();

      await store.markOnboardingComplete();
      expect(await store.hasCompletedOnboarding(), true);

      await store.resetOnboarding();
      expect(await store.hasCompletedOnboarding(), false);
    });
  });

  group('TestData factories', () {
    test('event() creates a valid EventDto', () {
      final event = TestData.event();
      expect(event.id, 'test-event-1');
      expect(event.name, 'Test Event');
    });

    test('communityDay() includes buffs and featured Pokemon', () {
      final cd = TestData.communityDay();
      expect(cd.eventType, EventType.communityDay);
      expect(cd.hasSpawns, true);
      expect(cd.buffs, isNotEmpty);
      expect(cd.featuredPokemon, isNotEmpty);
    });

    test('response() wraps events in an EventsResponse', () {
      final response = TestData.response(
        events: [TestData.communityDay(), TestData.raidHour()],
      );
      expect(response.events, hasLength(2));
      expect(response.cacheHit, false);
    });

    test('eventJson() produces valid JSON for MockClient responses', () {
      final json = TestData.eventJson(
        id: 'json-test',
        name: 'JSON Event',
        start: '2026-04-01T10:00:00.000',
      );
      expect(json['id'], 'json-test');
      expect(json['start'], '2026-04-01T10:00:00.000');
      expect(json['buffs'], isEmpty);
    });
  });
}
