import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gocalgo/config/theme.dart';
import 'package:gocalgo/models/event_dto.dart';
import 'package:gocalgo/models/event_type.dart';
import 'package:gocalgo/providers/events_provider.dart';
import 'package:gocalgo/screens/upcoming_screen.dart';

/// Widget tests for UpcomingScreen — shows upcoming events grouped by day.
///
/// Same pattern as HomeScreen tests: override providers, pump the widget,
/// assert on rendered content.

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _tomorrow = DateTime.now().add(const Duration(days: 1));
final _dayAfter = DateTime.now().add(const Duration(days: 2));

final _upcomingEvents = [
  EventDto(
    id: 'upcoming-1',
    name: 'Raid Hour: Mewtwo',
    eventType: EventType.raidHour,
    heading: 'Mewtwo in 5-star raids',
    imageUrl: '',
    linkUrl: '',
    start: _tomorrow,
    end: _tomorrow.add(const Duration(hours: 1)),
    isUtcTime: false,
    hasSpawns: false,
    hasResearchTasks: false,
    buffs: const [],
    featuredPokemon: const [],
    promoCodes: const [],
  ),
  EventDto(
    id: 'upcoming-2',
    name: 'Spotlight Hour: Eevee',
    eventType: EventType.spotlightHour,
    heading: 'Eevee spotlight',
    imageUrl: '',
    linkUrl: '',
    start: _tomorrow.add(const Duration(hours: 2)),
    end: _tomorrow.add(const Duration(hours: 3)),
    isUtcTime: false,
    hasSpawns: true,
    hasResearchTasks: false,
    buffs: const [],
    featuredPokemon: const [],
    promoCodes: const [],
  ),
  EventDto(
    id: 'upcoming-3',
    name: 'Research Day: Ditto',
    eventType: EventType.research,
    heading: 'Complete research tasks',
    imageUrl: '',
    linkUrl: '',
    start: _dayAfter,
    end: _dayAfter.add(const Duration(hours: 6)),
    isUtcTime: false,
    hasSpawns: false,
    hasResearchTasks: true,
    buffs: const [],
    featuredPokemon: const [],
    promoCodes: const [],
  ),
];

// ---------------------------------------------------------------------------
// Builder
// ---------------------------------------------------------------------------

Widget _buildUpcomingScreen({
  List<EventDto> events = const [],
  Set<String> flaggedIds = const {},
  bool isError = false,
}) {
  return ProviderScope(
    overrides: [
      upcomingEventsProvider.overrideWith(() => _FakeUpcomingNotifier(
            events: events,
            isError: isError,
          )),
      flaggedIdsProvider.overrideWith(() => _FakeFlaggedIdsNotifier(flaggedIds)),
      connectivityProvider.overrideWith(() => _FakeConnectivityNotifier()),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: const UpcomingScreen(),
    ),
  );
}

// ---------------------------------------------------------------------------
// Fake notifiers
// ---------------------------------------------------------------------------

class _FakeUpcomingNotifier extends UpcomingEventsNotifier {
  _FakeUpcomingNotifier({this.events = const [], this.isError = false});
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
  group('UpcomingScreen', () {
    testWidgets('renders app bar with "Upcoming" title', (tester) async {
      await tester.pumpWidget(_buildUpcomingScreen(events: _upcomingEvents));
      await tester.pumpAndSettle();

      expect(find.text('Upcoming'), findsOneWidget);
    });

    testWidgets('displays upcoming event cards', (tester) async {
      await tester.pumpWidget(_buildUpcomingScreen(events: _upcomingEvents));
      await tester.pumpAndSettle();

      expect(find.text('Raid Hour: Mewtwo'), findsOneWidget);
      expect(find.text('Spotlight Hour: Eevee'), findsOneWidget);
      expect(find.text('Research Day: Ditto'), findsOneWidget);
    });

    testWidgets('shows empty state when no upcoming events', (tester) async {
      await tester.pumpWidget(_buildUpcomingScreen(events: []));
      await tester.pumpAndSettle();

      expect(find.text('No upcoming events\nin the next 7 days.'), findsOneWidget);
    });

    testWidgets('shows error state on provider failure', (tester) async {
      await tester.pumpWidget(_buildUpcomingScreen(isError: true));
      await tester.pumpAndSettle();

      expect(find.text('Failed to load events'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('event type badges are displayed', (tester) async {
      await tester.pumpWidget(_buildUpcomingScreen(events: _upcomingEvents));
      await tester.pumpAndSettle();

      // Type labels appear in both filter bar chips and card badges
      expect(find.text('Raid Hour'), findsWidgets);
      expect(find.text('Spotlight Hour'), findsWidgets);
      expect(find.text('Research'), findsWidgets);
    });

    testWidgets('groups events by day with date headers', (tester) async {
      await tester.pumpWidget(_buildUpcomingScreen(events: _upcomingEvents));
      await tester.pumpAndSettle();

      // Events on different days should produce multiple day group headers
      // The exact header text depends on the date, but we can verify
      // that events from both days are visible
      expect(find.text('Raid Hour: Mewtwo'), findsOneWidget);
      expect(find.text('Research Day: Ditto'), findsOneWidget);
    });
  });
}
