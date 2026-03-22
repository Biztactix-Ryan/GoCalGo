import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gocalgo/config/theme.dart';
import 'package:gocalgo/models/event_dto.dart';
import 'package:gocalgo/models/event_type.dart';
import 'package:gocalgo/widgets/empty_state.dart';
import 'package:gocalgo/widgets/event_card.dart';

/// Verifies acceptance criterion for story US-GCG-24:
/// "Empty state shown when no events match the filter"
///
/// When a user applies an event type filter and no events match, the UI should
/// show a clear empty state message instead of a blank screen. This applies to
/// both event type filter chips and the flagged-events filter.
void main() {
  const communityDayEvent = EventDto(
    id: 'cd-1',
    name: 'Community Day: Bulbasaur',
    eventType: EventType.communityDay,
    heading: 'January Community Day',
    imageUrl: '',
    linkUrl: '',
    isUtcTime: false,
    hasSpawns: true,
    hasResearchTasks: false,
    buffs: [],
    featuredPokemon: [],
    promoCodes: [],
  );

  const spotlightEvent = EventDto(
    id: 'sh-1',
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

  /// Finds a FilterChip by its label text.
  Finder chipWithLabel(String label) => find.ancestor(
        of: find.text(label),
        matching: find.byType(FilterChip),
      );

  Widget buildEventTypeFilter({required List<EventDto> events}) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: _EventTypeFilterList(events: events),
      ),
    );
  }

  Widget buildFlaggedFilter({
    required List<EventDto> events,
    required Set<String> flaggedIds,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: _FlaggedFilterList(events: events, flaggedIds: flaggedIds),
      ),
    );
  }

  group('Empty state with event type filters', () {
    testWidgets('shows empty state when selecting a type with no matching events',
        (tester) async {
      // Only community day events in the list — no spotlight hour events
      await tester.pumpWidget(buildEventTypeFilter(events: [communityDayEvent]));
      await tester.pumpAndSettle();

      // All events visible initially
      expect(find.text('Community Day: Bulbasaur'), findsOneWidget);

      // Tap Spotlight Hour chip (exists because we show all known types,
      // but no events match)
      await tester.tap(chipWithLabel('Spotlight Hour'));
      await tester.pumpAndSettle();

      // Empty state should be displayed
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('No events match this filter'), findsOneWidget);
      expect(find.byIcon(Icons.filter_list_off), findsOneWidget);
    });

    testWidgets('empty state disappears when switching back to "All"',
        (tester) async {
      await tester.pumpWidget(buildEventTypeFilter(events: [communityDayEvent]));
      await tester.pumpAndSettle();

      // Apply a filter that yields no results
      await tester.tap(chipWithLabel('Spotlight Hour'));
      await tester.pumpAndSettle();
      expect(find.byType(EmptyState), findsOneWidget);

      // Switch back to All
      await tester.tap(chipWithLabel('All'));
      await tester.pumpAndSettle();

      // Empty state gone, events visible
      expect(find.byType(EmptyState), findsNothing);
      expect(find.text('Community Day: Bulbasaur'), findsOneWidget);
    });

    testWidgets('shows empty state when event list is completely empty',
        (tester) async {
      await tester.pumpWidget(buildEventTypeFilter(events: []));
      await tester.pumpAndSettle();

      // No events at all — should show empty state
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('No events match this filter'), findsOneWidget);
    });

    testWidgets('empty state is centered on screen', (tester) async {
      await tester.pumpWidget(buildEventTypeFilter(events: [communityDayEvent]));
      await tester.pumpAndSettle();

      await tester.tap(chipWithLabel('Spotlight Hour'));
      await tester.pumpAndSettle();

      // EmptyState internally uses Center — verify Center is a descendant
      expect(
        find.descendant(
          of: find.byType(EmptyState),
          matching: find.byType(Center),
        ),
        findsWidgets,
      );
    });
  });

  group('Empty state with flagged filter', () {
    testWidgets('shows empty state when filtering flagged with none flagged',
        (tester) async {
      await tester.pumpWidget(buildFlaggedFilter(
        events: [communityDayEvent, spotlightEvent],
        flaggedIds: {},
      ));
      await tester.pumpAndSettle();

      // Both events visible initially
      expect(find.text('Community Day: Bulbasaur'), findsOneWidget);
      expect(find.text('Spotlight Hour: Pikachu'), findsOneWidget);

      // Switch to flagged view
      await tester.tap(chipWithLabel('Flagged'));
      await tester.pumpAndSettle();

      // Empty state should appear
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('No flagged events'), findsOneWidget);
    });

    testWidgets('flagged empty state disappears when switching to "All"',
        (tester) async {
      await tester.pumpWidget(buildFlaggedFilter(
        events: [communityDayEvent],
        flaggedIds: {},
      ));
      await tester.pumpAndSettle();

      await tester.tap(chipWithLabel('Flagged'));
      await tester.pumpAndSettle();
      expect(find.byType(EmptyState), findsOneWidget);

      await tester.tap(chipWithLabel('All'));
      await tester.pumpAndSettle();

      expect(find.byType(EmptyState), findsNothing);
      expect(find.text('Community Day: Bulbasaur'), findsOneWidget);
    });
  });
}

/// Test harness: event list with event-type filter chips and empty state.
///
/// Shows filter chips for a fixed set of common event types. When no events
/// match the selected type, displays an [EmptyState] widget.
class _EventTypeFilterList extends StatefulWidget {
  const _EventTypeFilterList({required this.events});

  final List<EventDto> events;

  @override
  State<_EventTypeFilterList> createState() => _EventTypeFilterListState();
}

class _EventTypeFilterListState extends State<_EventTypeFilterList> {
  EventType? _selectedType;

  List<EventDto> get _filteredEvents {
    if (_selectedType == null) return widget.events;
    return widget.events.where((e) => e.eventType == _selectedType).toList();
  }

  /// Fixed set of filter chips shown regardless of which events are present.
  static const _filterTypes = [
    (EventType.communityDay, 'Community Day'),
    (EventType.spotlightHour, 'Spotlight Hour'),
    (EventType.raidDay, 'Raid Day'),
    (EventType.raidHour, 'Raid Hour'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              FilterChip(
                label: const Text('All'),
                selected: _selectedType == null,
                onSelected: (_) => setState(() => _selectedType = null),
              ),
              const SizedBox(width: 8),
              for (final (type, label) in _filterTypes) ...[
                FilterChip(
                  label: Text(label),
                  selected: _selectedType == type,
                  onSelected: (_) => setState(() => _selectedType = type),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        Expanded(
          child: _filteredEvents.isEmpty
              ? const EmptyState(
                  message: 'No events match this filter',
                  icon: Icons.filter_list_off,
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredEvents.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, index) {
                    final event = _filteredEvents[index];
                    return EventCard(event: event);
                  },
                ),
        ),
      ],
    );
  }
}

/// Test harness: event list with "All" / "Flagged" filter and empty state.
///
/// When no events match the flagged filter, displays an [EmptyState] widget.
class _FlaggedFilterList extends StatefulWidget {
  const _FlaggedFilterList({
    required this.events,
    required this.flaggedIds,
  });

  final List<EventDto> events;
  final Set<String> flaggedIds;

  @override
  State<_FlaggedFilterList> createState() => _FlaggedFilterListState();
}

class _FlaggedFilterListState extends State<_FlaggedFilterList> {
  bool _showFlaggedOnly = false;

  List<EventDto> get _filteredEvents {
    if (!_showFlaggedOnly) return widget.events;
    return widget.events
        .where((e) => widget.flaggedIds.contains(e.id))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
                label: const Text('Flagged'),
                selected: _showFlaggedOnly,
                onSelected: (_) => setState(() => _showFlaggedOnly = true),
              ),
            ],
          ),
        ),
        Expanded(
          child: _filteredEvents.isEmpty
              ? const EmptyState(message: 'No flagged events')
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
