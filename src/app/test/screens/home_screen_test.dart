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
import 'package:gocalgo/widgets/empty_state.dart';

/// Widget tests for HomeScreen — the hero screen showing today's active events.
///
/// These tests demonstrate the established widget test pattern for screens that
/// depend on Riverpod providers:
///   1. Override async providers with pre-loaded data via ProviderScope.
///   2. Wrap the screen in MaterialApp with the app theme.
///   3. Use testWidgets + WidgetTester to drive interactions.
///   4. Assert on widget presence, text content, and structure.

// ---------------------------------------------------------------------------
// Test fixtures
// ---------------------------------------------------------------------------

final _now = DateTime.now();

EventDto _makeEvent({
  String id = 'evt-1',
  String name = 'Community Day: Bulbasaur',
  EventType type = EventType.communityDay,
  String heading = 'Catch Bulbasaur everywhere!',
  List<Buff> buffs = const [],
}) =>
    EventDto(
      id: id,
      name: name,
      eventType: type,
      heading: heading,
      imageUrl: '',
      linkUrl: '',
      start: _now.subtract(const Duration(hours: 1)),
      end: _now.add(const Duration(hours: 3)),
      isUtcTime: false,
      hasSpawns: true,
      hasResearchTasks: false,
      buffs: buffs,
      featuredPokemon: const [],
      promoCodes: const [],
    );

final _sampleEvents = [
  _makeEvent(),
  _makeEvent(
    id: 'evt-2',
    name: 'Spotlight Hour: Pikachu',
    type: EventType.spotlightHour,
    heading: 'Pikachu appears more often!',
    buffs: [
      const Buff(
        text: '2× Transfer Candy',
        category: BuffCategory.multiplier,
        multiplier: 2.0,
        resource: 'Candy',
      ),
    ],
  ),
];

// ---------------------------------------------------------------------------
// Builder helpers
// ---------------------------------------------------------------------------

/// Builds a [HomeScreen] wrapped in [ProviderScope] with overridden providers.
///
/// This is the canonical pattern for widget-testing Riverpod screens:
/// override the async provider to return pre-loaded data so the test does not
/// depend on real services, databases, or network.
Widget _buildHomeScreen({
  List<EventDto> events = const [],
  Set<String> flaggedIds = const {},
  bool isError = false,
}) {
  return ProviderScope(
    overrides: [
      activeEventsProvider.overrideWith(() => _FakeEventsNotifier(
            events: events,
            isError: isError,
          )),
      flaggedIdsProvider.overrideWith(() => _FakeFlaggedIdsNotifier(flaggedIds)),
      connectivityProvider.overrideWith(() => _FakeConnectivityNotifier()),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: const HomeScreen(),
    ),
  );
}

// ---------------------------------------------------------------------------
// Fake notifiers for provider overrides
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
      lastUpdated: DateTime.now(),
    );
  }

  @override
  Future<void> refresh() async {
    state = AsyncData(EventsState(
      events: events,
      lastUpdated: DateTime.now(),
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
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('HomeScreen', () {
    testWidgets('renders app bar with GoCalGo title', (tester) async {
      await tester.pumpWidget(_buildHomeScreen(events: _sampleEvents));
      await tester.pumpAndSettle();

      expect(find.text('GoCalGo'), findsOneWidget);
    });

    testWidgets('displays event cards when data is loaded', (tester) async {
      await tester.pumpWidget(_buildHomeScreen(events: _sampleEvents));
      await tester.pumpAndSettle();

      expect(find.text('Community Day: Bulbasaur'), findsOneWidget);
      expect(find.text('Spotlight Hour: Pikachu'), findsOneWidget);
    });

    testWidgets('shows empty state when no events exist', (tester) async {
      await tester.pumpWidget(_buildHomeScreen(events: []));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      // No event cards should be present
      expect(find.text('Community Day: Bulbasaur'), findsNothing);
    });

    testWidgets('shows error state on provider failure', (tester) async {
      await tester.pumpWidget(_buildHomeScreen(isError: true));
      await tester.pumpAndSettle();

      expect(find.text('Failed to load events'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('flag toggle button is present in app bar', (tester) async {
      await tester.pumpWidget(_buildHomeScreen(events: _sampleEvents));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.flag_outlined), findsWidgets);
    });

    testWidgets('event card shows buff chips', (tester) async {
      await tester.pumpWidget(_buildHomeScreen(events: _sampleEvents));
      await tester.pumpAndSettle();

      expect(find.text('2× Transfer Candy'), findsOneWidget);
    });

    testWidgets('event type badges are displayed on cards', (tester) async {
      await tester.pumpWidget(_buildHomeScreen(events: _sampleEvents));
      await tester.pumpAndSettle();

      // Type labels appear in both filter bar chips and card badges,
      // so we just verify they are present (at least one each).
      expect(find.text('Community Day'), findsWidgets);
      expect(find.text('Spotlight Hour'), findsWidgets);
    });

    testWidgets('tapping flag filter toggles flagged-only mode', (tester) async {
      await tester.pumpWidget(_buildHomeScreen(
        events: _sampleEvents,
        flaggedIds: {'evt-1'},
      ));
      await tester.pumpAndSettle();

      // Both events visible initially
      expect(find.text('Community Day: Bulbasaur'), findsOneWidget);
      expect(find.text('Spotlight Hour: Pikachu'), findsOneWidget);

      // Tap the flag filter in the app bar (use tooltip to target precisely)
      await tester.tap(find.byTooltip('Show flagged only'));
      await tester.pumpAndSettle();

      // Only flagged event should remain
      expect(find.text('Community Day: Bulbasaur'), findsOneWidget);
      expect(find.text('Spotlight Hour: Pikachu'), findsNothing);
    });
  });
}
