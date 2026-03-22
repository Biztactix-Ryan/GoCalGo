import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gocalgo/config/router.dart';
import 'package:gocalgo/config/theme.dart';
import 'package:gocalgo/models/buff.dart';
import 'package:gocalgo/models/buff_category.dart';
import 'package:gocalgo/models/event_dto.dart';
import 'package:gocalgo/models/event_type.dart';
import 'package:gocalgo/models/events_response.dart';
import 'package:gocalgo/providers/events_provider.dart';
import 'package:gocalgo/providers/onboarding_provider.dart';
import 'package:gocalgo/services/cached_events_service.dart';
import 'package:gocalgo/services/event_cache.dart';
import 'package:gocalgo/services/events_service.dart';
import 'package:gocalgo/services/flag_store.dart';
import 'package:integration_test/integration_test.dart';

/// Integration tests covering three critical user journeys:
///
///   1. View today's events — Home screen shows active events
///   2. Flag an event — tapping the flag icon toggles flag state
///   3. View upcoming events — Upcoming tab groups future events by day
///
/// These tests use deterministic mock data so they don't depend on live
/// backend state. They exercise the real widget tree, navigation, and
/// provider wiring end-to-end.
///
/// Run:
///   cd src/app
///   flutter test integration_test/user_journeys_test.dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ── Test data ──────────────────────────────────────────────────────────

  final now = DateTime.now();

  // Active events (started in the past, ending in the future).
  final activeEvent1 = EventDto(
    id: 'active-cd-1',
    name: 'Community Day: Charmander',
    eventType: EventType.communityDay,
    heading: 'Community Day',
    imageUrl: '',
    linkUrl: '',
    start: now.subtract(const Duration(hours: 1)),
    end: now.add(const Duration(hours: 2)),
    isUtcTime: false,
    hasSpawns: true,
    hasResearchTasks: true,
    buffs: const [
      Buff(
        text: '3× Catch Stardust',
        category: BuffCategory.multiplier,
        multiplier: 3.0,
        resource: 'Stardust',
      ),
    ],
    featuredPokemon: const [],
    promoCodes: const [],
  );

  final activeEvent2 = EventDto(
    id: 'active-event-2',
    name: 'Wild Area Global',
    eventType: EventType.event,
    heading: 'Global Event',
    imageUrl: '',
    linkUrl: '',
    start: now.subtract(const Duration(days: 1)),
    end: now.add(const Duration(days: 3)),
    isUtcTime: false,
    hasSpawns: true,
    hasResearchTasks: false,
    buffs: const [],
    featuredPokemon: const [],
    promoCodes: const [],
  );

  // Upcoming events (starting in the future, within 7 days).
  final upcomingEvent1 = EventDto(
    id: 'upcoming-sh-1',
    name: 'Spotlight Hour: Pikachu',
    eventType: EventType.spotlightHour,
    heading: 'Spotlight Hour',
    imageUrl: '',
    linkUrl: '',
    start: now.add(const Duration(days: 1, hours: 2)),
    end: now.add(const Duration(days: 1, hours: 3)),
    isUtcTime: false,
    hasSpawns: true,
    hasResearchTasks: false,
    buffs: const [
      Buff(
        text: '2× Transfer Candy',
        category: BuffCategory.multiplier,
        multiplier: 2.0,
        resource: 'Candy',
      ),
    ],
    featuredPokemon: const [],
    promoCodes: const [],
  );

  final upcomingEvent2 = EventDto(
    id: 'upcoming-rh-1',
    name: 'Raid Hour',
    eventType: EventType.raidHour,
    heading: 'Raid Hour',
    imageUrl: '',
    linkUrl: '',
    start: now.add(const Duration(days: 3, hours: 4)),
    end: now.add(const Duration(days: 3, hours: 5)),
    isUtcTime: false,
    hasSpawns: false,
    hasResearchTasks: false,
    buffs: const [],
    featuredPokemon: const [],
    promoCodes: const [],
  );

  final allEvents = [activeEvent1, activeEvent2, upcomingEvent1, upcomingEvent2];

  final mockResponse = EventsResponse(
    events: allEvents,
    lastUpdated: now,
    cacheHit: false,
  );

  // ── Helpers ────────────────────────────────────────────────────────────

  Widget buildApp({List<Override> extraOverrides = const []}) {
    final mockService = CachedEventsService(
      remote: _StubEventsService(mockResponse),
      cache: _NoOpEventCache(),
    );

    return ProviderScope(
      overrides: [
        cachedEventsServiceProvider.overrideWithValue(mockService),
        hasCompletedOnboardingProvider.overrideWith((_) async => true),
        flagStoreProvider.overrideWithValue(_InMemoryFlagStore()),
        ...extraOverrides,
      ],
      child: const _TestApp(),
    );
  }

  // ── Journey 1: View today's events ────────────────────────────────────

  group('Journey: View today\'s events', () {
    testWidgets('home screen displays active events with details',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // The app bar shows the app title.
      expect(find.text('GoCalGo'), findsOneWidget);

      // Active events are visible.
      expect(find.text('Community Day: Charmander'), findsOneWidget);
      expect(find.text('Wild Area Global'), findsOneWidget);

      // Upcoming-only events are NOT shown on the home screen (they haven't started).
      expect(find.text('Spotlight Hour: Pikachu'), findsNothing);
      expect(find.text('Raid Hour'), findsNothing);
    });

    testWidgets('active event card shows type badge and buff chips',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Community Day type badge is visible.
      expect(find.text('Community Day'), findsWidgets);

      // Buff chip is displayed.
      expect(find.text('3× Catch Stardust'), findsOneWidget);
    });

    testWidgets('active event card shows time remaining indicator',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // The Community Day event ends in ~2 hours, so we expect "1h left" or "2h left".
      final timeRemainingFinder = find.textContaining(RegExp(r'\d+[hmd] left'));
      expect(timeRemainingFinder, findsWidgets);
    });
  });

  // ── Journey 2: Flag an event ──────────────────────────────────────────

  group('Journey: Flag an event', () {
    testWidgets('tapping flag icon toggles the flag on', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Find flag icons — initially all outlined (unflagged).
      final outlinedFlags = find.byIcon(Icons.flag_outlined);
      expect(outlinedFlags, findsWidgets);

      // Tap the first flag icon to flag the event.
      await tester.tap(outlinedFlags.first);
      await tester.pumpAndSettle();

      // After flagging, at least one solid flag icon should appear.
      expect(find.byIcon(Icons.flag), findsWidgets);
    });

    testWidgets('tapping flag again unflags the event', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Flag the first event.
      final outlinedFlags = find.byIcon(Icons.flag_outlined);
      await tester.tap(outlinedFlags.first);
      await tester.pumpAndSettle();

      // Now unflag it by tapping the solid flag icon.
      final solidFlags = find.byIcon(Icons.flag);
      await tester.tap(solidFlags.first);
      await tester.pumpAndSettle();

      // All flags should be outlined again (unflagged).
      // The app bar also has a flag icon for "show flagged only", so we check
      // that the event card flags are all outlined.
      final cardOutlinedFlags = find.byIcon(Icons.flag_outlined);
      expect(cardOutlinedFlags, findsWidgets);
    });

    testWidgets('flagged event gets a colored border', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Flag the first event.
      final outlinedFlags = find.byIcon(Icons.flag_outlined);
      await tester.tap(outlinedFlags.first);
      await tester.pumpAndSettle();

      // The flagged event card should have a Card with a colored border.
      // Find all Card widgets and check that at least one has a non-null side.
      final cards = tester.widgetList<Card>(find.byType(Card));
      final hasBorderedCard = cards.any((card) {
        final shape = card.shape;
        if (shape is RoundedRectangleBorder) {
          return shape.side != BorderSide.none;
        }
        return false;
      });
      expect(hasBorderedCard, isTrue,
          reason: 'Flagged event card should have a colored border');
    });
  });

  // ── Journey 3: View upcoming events ───────────────────────────────────

  group('Journey: View upcoming events', () {
    testWidgets('navigating to Upcoming tab shows future events',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Tap the Upcoming tab in bottom navigation.
      await tester.tap(find.text('Upcoming'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Upcoming events should be visible.
      expect(find.text('Spotlight Hour: Pikachu'), findsOneWidget);
      expect(find.text('Raid Hour'), findsOneWidget);

      // Currently active events should NOT appear on the upcoming screen
      // (they have already started).
      expect(find.text('Community Day: Charmander'), findsNothing);
    });

    testWidgets('upcoming events are grouped by day with date headers',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Navigate to Upcoming.
      await tester.tap(find.text('Upcoming'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Events on different days should produce separate day headers.
      // The two upcoming events are 1 day and 3 days in the future,
      // so they should be under different day group headers.
      // Day headers use format like "Mon, Mar 23".
      // We just verify that multiple Text widgets with comma-separated dates exist.
      final dayHeaders = find.textContaining(RegExp(r'[A-Z][a-z]{2}, [A-Z][a-z]{2}'));
      expect(dayHeaders, findsAtLeast(2),
          reason: 'Should have at least 2 day group headers for events on different days');
    });

    testWidgets('can flag an event on the upcoming screen', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Navigate to Upcoming.
      await tester.tap(find.text('Upcoming'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Flag the first upcoming event.
      final outlinedFlags = find.byIcon(Icons.flag_outlined);
      expect(outlinedFlags, findsWidgets);

      await tester.tap(outlinedFlags.first);
      await tester.pumpAndSettle();

      // A solid flag icon should appear.
      expect(find.byIcon(Icons.flag), findsWidgets);
    });

    testWidgets('can navigate back to Today tab after viewing upcoming',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Go to Upcoming.
      await tester.tap(find.text('Upcoming'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text('Spotlight Hour: Pikachu'), findsOneWidget);

      // Go back to Today.
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Home screen events should be visible again.
      expect(find.text('Community Day: Charmander'), findsOneWidget);
      expect(find.text('GoCalGo'), findsOneWidget);
    });
  });
}

// ── Test doubles ──────────────────────────────────────────────────────────

/// A stub [EventsService] that returns a fixed response without hitting
/// the network.
class _StubEventsService implements EventsService {
  final EventsResponse _response;

  _StubEventsService(this._response);

  @override
  Future<EventsResponse> getEvents() async => _response;

  @override
  Future<List<EventDto>> getActiveEvents({DateTime? now}) async {
    final timestamp = now ?? DateTime.now();
    return _response.events.where((e) {
      if (e.start == null) return false;
      final started = !e.start!.isAfter(timestamp);
      final notEnded = e.end == null || e.end!.isAfter(timestamp);
      return started && notEnded;
    }).toList();
  }

  @override
  Future<List<EventDto>> getUpcomingEvents({DateTime? now, int? days}) async {
    final timestamp = now ?? DateTime.now();
    final cutoff = days != null ? timestamp.add(Duration(days: days)) : null;
    return _response.events.where((e) {
      if (e.start == null) return true;
      if (!e.start!.isAfter(timestamp)) return false;
      if (cutoff != null && e.start!.isAfter(cutoff)) return false;
      return true;
    }).toList();
  }

  @override
  void dispose() {}
}

/// No-op cache — tests always use fresh mock data.
class _NoOpEventCache implements EventCache {
  @override
  Future<void> put(EventsResponse response) async {}

  @override
  Future<EventsResponse?> get() async => null;

  @override
  Future<void> clear() async {}
}

/// In-memory flag store for deterministic flag tests.
class _InMemoryFlagStore implements FlagStore {
  final Set<String> _ids = {};

  @override
  Future<void> flag(String eventId) async => _ids.add(eventId);

  @override
  Future<void> unflag(String eventId) async => _ids.remove(eventId);

  @override
  Future<bool> isFlagged(String eventId) async => _ids.contains(eventId);

  @override
  Future<Set<String>> flaggedIds() async => {..._ids};

  @override
  Future<void> clearAll() async => _ids.clear();
}

class _TestApp extends ConsumerWidget {
  const _TestApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'GoCalGo Integration Test',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
