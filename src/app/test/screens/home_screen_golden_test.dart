import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gocalgo/config/theme.dart';
import 'package:gocalgo/models/buff.dart';
import 'package:gocalgo/models/buff_category.dart';
import 'package:gocalgo/models/event_dto.dart';
import 'package:gocalgo/models/event_type.dart';
import 'package:gocalgo/providers/events_provider.dart';
import 'package:gocalgo/screens/home_screen.dart';

/// Golden tests for the [HomeScreen] — the daily view showing today's events.
///
/// Captures full-screen snapshots of the daily view in key states:
/// - Populated with events
/// - Empty (no events)
/// - With flagged events
///
/// To update goldens after intentional visual changes:
///   flutter test --update-goldens test/screens/home_screen_golden_test.dart

// ---------------------------------------------------------------------------
// Test fixtures
// ---------------------------------------------------------------------------

final _now = DateTime(2026, 3, 21, 15, 0); // fixed time for determinism

final _sampleEvents = [
  EventDto(
    id: 'evt-1',
    name: 'Community Day: Bulbasaur',
    eventType: EventType.communityDay,
    heading: 'Catch Bulbasaur everywhere!',
    imageUrl: '',
    linkUrl: '',
    start: _now.subtract(const Duration(hours: 1)),
    end: _now.add(const Duration(hours: 3)),
    isUtcTime: false,
    hasSpawns: true,
    hasResearchTasks: false,
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
  ),
  EventDto(
    id: 'evt-2',
    name: 'Spotlight Hour: Pikachu',
    eventType: EventType.spotlightHour,
    heading: 'Pikachu appears more often!',
    imageUrl: '',
    linkUrl: '',
    start: _now.subtract(const Duration(minutes: 30)),
    end: _now.add(const Duration(minutes: 30)),
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
  ),
];

// ---------------------------------------------------------------------------
// Fake notifiers (same pattern as home_screen_test.dart)
// ---------------------------------------------------------------------------

class _FakeEventsNotifier extends EventsNotifier {
  _FakeEventsNotifier({this.events = const [], this.isError = false});
  final List<EventDto> events;
  final bool isError;

  @override
  Future<EventsState> build() async {
    if (isError) throw Exception('Network error');
    return EventsState(
      events: events,
      lastUpdated: _now,
    );
  }

  @override
  Future<void> refresh() async {
    state = AsyncData(EventsState(
      events: events,
      lastUpdated: _now,
    ));
  }
}

class _FakeFlaggedIdsNotifier extends FlaggedIdsNotifier {
  _FakeFlaggedIdsNotifier(this._ids);
  final Set<String> _ids;

  @override
  Future<Set<String>> build() async => _ids;

  @override
  Future<void> toggle(String id) async {
    final current = state.valueOrNull ?? {};
    if (current.contains(id)) {
      state = AsyncData({...current}..remove(id));
    } else {
      state = AsyncData({...current, id});
    }
  }
}

class _FakeConnectivityNotifier extends ConnectivityNotifier {
  @override
  Stream<bool> build() => Stream.value(true);
}

// ---------------------------------------------------------------------------
// Builder
// ---------------------------------------------------------------------------

Widget _buildHomeScreen({
  List<EventDto> events = const [],
  Set<String> flaggedIds = const {},
  bool isError = false,
}) {
  return ProviderScope(
    overrides: [
      activeEventsProvider.overrideWith(
        () => _FakeEventsNotifier(events: events, isError: isError),
      ),
      flaggedIdsProvider.overrideWith(() => _FakeFlaggedIdsNotifier(flaggedIds)),
      connectivityProvider.overrideWith(() => _FakeConnectivityNotifier()),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    ),
  );
}

// ---------------------------------------------------------------------------
// Golden tests
// ---------------------------------------------------------------------------

void main() {
  group('HomeScreen (daily view) golden tests', () {
    testWidgets('daily view with events', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildHomeScreen(events: _sampleEvents));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(HomeScreen),
        matchesGoldenFile('goldens/home_screen_with_events.png'),
      );
    });

    testWidgets('daily view empty state', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildHomeScreen(events: []));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(HomeScreen),
        matchesGoldenFile('goldens/home_screen_empty.png'),
      );
    });

    testWidgets('daily view with flagged event', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildHomeScreen(
        events: _sampleEvents,
        flaggedIds: {'evt-1'},
      ));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(HomeScreen),
        matchesGoldenFile('goldens/home_screen_flagged.png'),
      );
    });
  });
}
