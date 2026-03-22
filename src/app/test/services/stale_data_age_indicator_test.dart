import 'package:flutter_test/flutter_test.dart';
import 'package:gocalgo/models/event_dto.dart';
import 'package:gocalgo/models/event_type.dart';
import 'package:gocalgo/providers/events_provider.dart';

/// Verifies acceptance criterion for story US-GCG-26:
/// "Visual indicator when data is stale (older than 1 hour)"
///
/// Tests that [EventsState] correctly identifies data as stale when the
/// [lastUpdated] timestamp is more than 1 hour old, independent of whether
/// the data came from cache.
void main() {
  EventDto _sampleEvent() => EventDto(
        id: 'ev-1',
        name: 'Community Day',
        eventType: EventType.communityDay,
        heading: 'Community Day',
        imageUrl: 'https://example.com/ev-1.png',
        linkUrl: 'https://example.com/ev-1',
        start: DateTime(2026, 3, 21, 10),
        end: DateTime(2026, 3, 21, 17),
        isUtcTime: false,
        hasSpawns: false,
        hasResearchTasks: false,
        buffs: const [],
        featuredPokemon: const [],
        promoCodes: const [],
      );

  group('US-GCG-26 — Visual indicator when data is stale (older than 1 hour)',
      () {
    test('data updated less than 1 hour ago is not stale by age', () {
      final now = DateTime(2026, 3, 21, 12, 0);
      final lastUpdated = DateTime(2026, 3, 21, 11, 30); // 30 min ago

      final state = EventsState(
        events: [_sampleEvent()],
        isStale: false,
        lastUpdated: lastUpdated,
      );

      expect(state.isStaleByAge(now: now), isFalse,
          reason: 'Data updated 30 minutes ago should not be stale');
      expect(state.shouldShowStaleBanner(now: now), isFalse);
    });

    test('data updated exactly 1 hour ago is considered stale', () {
      final now = DateTime(2026, 3, 21, 12, 0);
      final lastUpdated = DateTime(2026, 3, 21, 11, 0); // exactly 1 hour

      final state = EventsState(
        events: [_sampleEvent()],
        isStale: false,
        lastUpdated: lastUpdated,
      );

      expect(state.isStaleByAge(now: now), isTrue,
          reason: 'Data exactly 1 hour old should be considered stale');
      expect(state.shouldShowStaleBanner(now: now), isTrue);
    });

    test('data updated more than 1 hour ago is stale by age', () {
      final now = DateTime(2026, 3, 21, 14, 0);
      final lastUpdated = DateTime(2026, 3, 21, 12, 0); // 2 hours ago

      final state = EventsState(
        events: [_sampleEvent()],
        isStale: false,
        lastUpdated: lastUpdated,
      );

      expect(state.isStaleByAge(now: now), isTrue,
          reason: 'Data updated 2 hours ago should be stale');
      expect(state.shouldShowStaleBanner(now: now), isTrue);
    });

    test('data with null lastUpdated is not stale by age', () {
      final now = DateTime(2026, 3, 21, 12, 0);

      final state = EventsState(
        events: [_sampleEvent()],
        isStale: false,
        lastUpdated: null,
      );

      expect(state.isStaleByAge(now: now), isFalse,
          reason: 'Cannot determine age without a timestamp');
    });

    test('cache-hit data is always shown as stale regardless of age', () {
      final now = DateTime(2026, 3, 21, 12, 0);
      final lastUpdated = DateTime(2026, 3, 21, 11, 59); // only 1 min ago

      final state = EventsState(
        events: [_sampleEvent()],
        isStale: true, // came from cache
        lastUpdated: lastUpdated,
      );

      expect(state.isStaleByAge(now: now), isFalse,
          reason: 'Age alone is under threshold');
      expect(state.shouldShowStaleBanner(now: now), isTrue,
          reason: 'Cache-hit flag alone triggers the banner');
    });

    test('banner shows when data is old even if not from cache', () {
      final now = DateTime(2026, 3, 21, 15, 0);
      final lastUpdated = DateTime(2026, 3, 21, 12, 0); // 3 hours ago

      final state = EventsState(
        events: [_sampleEvent()],
        isStale: false, // fresh API call, but server data is old
        lastUpdated: lastUpdated,
      );

      expect(state.shouldShowStaleBanner(now: now), isTrue,
          reason: 'Age-based staleness triggers the banner even without '
              'cacheHit, since the server data may be outdated');
    });

    test('staleThreshold constant is 1 hour', () {
      expect(EventsState.staleThreshold, const Duration(hours: 1));
    });

    test('data updated 59 minutes ago is not stale', () {
      final now = DateTime(2026, 3, 21, 12, 0);
      final lastUpdated = DateTime(2026, 3, 21, 11, 1); // 59 min ago

      final state = EventsState(
        events: [_sampleEvent()],
        isStale: false,
        lastUpdated: lastUpdated,
      );

      expect(state.isStaleByAge(now: now), isFalse);
      expect(state.shouldShowStaleBanner(now: now), isFalse);
    });
  });
}
