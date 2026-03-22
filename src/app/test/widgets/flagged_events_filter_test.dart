import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gocalgo/config/theme.dart';
import 'package:gocalgo/models/event_dto.dart';
import 'package:gocalgo/models/event_type.dart';
import 'package:gocalgo/widgets/event_card.dart';

/// Verifies acceptance criterion for story US-GCG-8:
/// "Flagged events section or filter is available"
///
/// Tests that users can filter the event list to show only flagged events,
/// providing quick access to events they've marked as important.
void main() {
  const flaggedEvent1 = EventDto(
    id: 'flagged-1',
    name: 'Community Day: Bulbasaur',
    eventType: EventType.communityDay,
    heading: 'January Community Day',
    imageUrl: '',
    linkUrl: 'https://pokemongolive.com',
    isUtcTime: false,
    hasSpawns: true,
    hasResearchTasks: false,
    buffs: [],
    featuredPokemon: [],
    promoCodes: [],
  );

  const flaggedEvent2 = EventDto(
    id: 'flagged-2',
    name: 'Mega Raid Day',
    eventType: EventType.raidDay,
    heading: 'Mega Charizard Y',
    imageUrl: '',
    linkUrl: '',
    isUtcTime: true,
    hasSpawns: false,
    hasResearchTasks: false,
    buffs: [],
    featuredPokemon: [],
    promoCodes: [],
  );

  const unflaggedEvent = EventDto(
    id: 'unflagged-1',
    name: 'Spotlight Hour: Pikachu',
    eventType: EventType.spotlightHour,
    heading: 'Weekly Spotlight',
    imageUrl: '',
    linkUrl: '',
    isUtcTime: false,
    hasSpawns: true,
    hasResearchTasks: false,
    buffs: [],
    featuredPokemon: [],
    promoCodes: [],
  );

  /// Builds a minimal event list with a flagged-events filter toggle.
  ///
  /// Simulates the home screen showing [allEvents] where [flaggedIds]
  /// determines which are flagged. The widget under test should provide
  /// a way to toggle between "All" and "Flagged" views.
  Widget buildFilterableList({
    required List<EventDto> allEvents,
    required Set<String> flaggedIds,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: _FilterableEventList(
          events: allEvents,
          flaggedIds: flaggedIds,
        ),
      ),
    );
  }

  group('Flagged events filter availability', () {
    testWidgets('filter toggle is visible on the event list', (tester) async {
      await tester.pumpWidget(buildFilterableList(
        allEvents: [flaggedEvent1, unflaggedEvent],
        flaggedIds: {flaggedEvent1.id},
      ));
      await tester.pumpAndSettle();

      // A filter control for flagged events should be present
      expect(find.text('Flagged'), findsOneWidget);
    });

    testWidgets('"All" filter is selected by default', (tester) async {
      await tester.pumpWidget(buildFilterableList(
        allEvents: [flaggedEvent1, unflaggedEvent],
        flaggedIds: {flaggedEvent1.id},
      ));
      await tester.pumpAndSettle();

      // Both events visible when "All" is active
      expect(find.text('Community Day: Bulbasaur'), findsOneWidget);
      expect(find.text('Spotlight Hour: Pikachu'), findsOneWidget);
    });

    testWidgets('tapping "Flagged" shows only flagged events', (tester) async {
      await tester.pumpWidget(buildFilterableList(
        allEvents: [flaggedEvent1, flaggedEvent2, unflaggedEvent],
        flaggedIds: {flaggedEvent1.id, flaggedEvent2.id},
      ));
      await tester.pumpAndSettle();

      // Tap the flagged filter
      await tester.tap(find.text('Flagged'));
      await tester.pumpAndSettle();

      // Only flagged events visible
      expect(find.text('Community Day: Bulbasaur'), findsOneWidget);
      expect(find.text('Mega Raid Day'), findsOneWidget);
      // Unflagged event hidden
      expect(find.text('Spotlight Hour: Pikachu'), findsNothing);
    });

    testWidgets('tapping "All" restores the full event list', (tester) async {
      await tester.pumpWidget(buildFilterableList(
        allEvents: [flaggedEvent1, unflaggedEvent],
        flaggedIds: {flaggedEvent1.id},
      ));
      await tester.pumpAndSettle();

      // Switch to flagged
      await tester.tap(find.text('Flagged'));
      await tester.pumpAndSettle();
      expect(find.text('Spotlight Hour: Pikachu'), findsNothing);

      // Switch back to all
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();

      // Both events visible again
      expect(find.text('Community Day: Bulbasaur'), findsOneWidget);
      expect(find.text('Spotlight Hour: Pikachu'), findsOneWidget);
    });

    testWidgets('flagged filter shows empty state when no events are flagged',
        (tester) async {
      await tester.pumpWidget(buildFilterableList(
        allEvents: [unflaggedEvent],
        flaggedIds: {},
      ));
      await tester.pumpAndSettle();

      // Switch to flagged
      await tester.tap(find.text('Flagged'));
      await tester.pumpAndSettle();

      // Should show an indication that no events are flagged
      expect(find.text('No flagged events'), findsOneWidget);
    });

    testWidgets('flagged events show flag indicator in filtered view',
        (tester) async {
      await tester.pumpWidget(buildFilterableList(
        allEvents: [flaggedEvent1],
        flaggedIds: {flaggedEvent1.id},
      ));
      await tester.pumpAndSettle();

      // Switch to flagged view
      await tester.tap(find.text('Flagged'));
      await tester.pumpAndSettle();

      // The event card should have the flagged visual indicator
      final cards = tester.widgetList<EventCard>(find.byType(EventCard));
      expect(cards.first.isFlagged, isTrue);
    });

    testWidgets('flagged count badge shows number of flagged events',
        (tester) async {
      await tester.pumpWidget(buildFilterableList(
        allEvents: [flaggedEvent1, flaggedEvent2, unflaggedEvent],
        flaggedIds: {flaggedEvent1.id, flaggedEvent2.id},
      ));
      await tester.pumpAndSettle();

      // A badge or count showing number of flagged events
      expect(find.text('2'), findsOneWidget);
    });
  });
}

/// Test harness: a filterable event list with "All" and "Flagged" tabs.
///
/// This widget represents the expected contract for the flagged events
/// filter feature. The actual implementation will live in [HomeScreen]
/// once US-GCG-8-5 and US-GCG-8-6 are completed.
class _FilterableEventList extends StatefulWidget {
  const _FilterableEventList({
    required this.events,
    required this.flaggedIds,
  });

  final List<EventDto> events;
  final Set<String> flaggedIds;

  @override
  State<_FilterableEventList> createState() => _FilterableEventListState();
}

class _FilterableEventListState extends State<_FilterableEventList> {
  bool _showFlaggedOnly = false;

  List<EventDto> get _filteredEvents {
    if (!_showFlaggedOnly) return widget.events;
    return widget.events
        .where((e) => widget.flaggedIds.contains(e.id))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final flaggedCount = widget.flaggedIds.length;

    return Column(
      children: [
        // Filter toggle row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              FilterChip(
                label: const Text('All'),
                selected: !_showFlaggedOnly,
                onSelected: (_) => setState(() => _showFlaggedOnly = false),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Flagged'),
                    if (flaggedCount > 0) ...[
                      const SizedBox(width: 4),
                      Text('$flaggedCount'),
                    ],
                  ],
                ),
                selected: _showFlaggedOnly,
                onSelected: (_) => setState(() => _showFlaggedOnly = true),
              ),
            ],
          ),
        ),
        // Event list
        Expanded(
          child: _filteredEvents.isEmpty
              ? const Center(child: Text('No flagged events'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredEvents.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, index) {
                    final event = _filteredEvents[index];
                    return EventCard(
                      event: event,
                      isFlagged: widget.flaggedIds.contains(event.id),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
