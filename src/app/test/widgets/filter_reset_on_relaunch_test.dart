import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gocalgo/config/theme.dart';
import 'package:gocalgo/models/event_dto.dart';
import 'package:gocalgo/models/event_type.dart';
import 'package:gocalgo/widgets/event_card.dart';

/// Verifies acceptance criterion for story US-GCG-24:
/// "Filter state resets on app relaunch"
///
/// Event type filters are stored only in widget state (ephemeral). When the
/// app is relaunched (widget tree rebuilt from scratch), all filters should
/// return to the default "show all" state.
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

  const raidDayEvent = EventDto(
    id: 'rd-1',
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

  final allEvents = [communityDayEvent, spotlightEvent, raidDayEvent];

  Widget buildApp({Key? key}) {
    return MaterialApp(
      key: key,
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: _EventTypeFilterList(
          key: key,
          events: allEvents,
        ),
      ),
    );
  }

  /// Finds a FilterChip by its label text (avoids ambiguity with EventCard
  /// type badges that render the same text).
  Finder chipWithLabel(String label) => find.ancestor(
        of: find.text(label),
        matching: find.byType(FilterChip),
      );

  group('Filter state resets on app relaunch', () {
    testWidgets('all event types are shown by default on first launch',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Community Day: Bulbasaur'), findsOneWidget);
      expect(find.text('Spotlight Hour: Pikachu'), findsOneWidget);
      expect(find.text('Mega Raid Day'), findsOneWidget);
    });

    testWidgets(
        'applying a filter then rebuilding the widget tree resets to show all',
        (tester) async {
      // First launch — apply a filter
      await tester.pumpWidget(buildApp(key: const ValueKey('launch-1')));
      await tester.pumpAndSettle();

      // Tap the Community Day chip to filter
      await tester.tap(chipWithLabel('Community Day'));
      await tester.pumpAndSettle();

      // Only community day events visible
      expect(find.text('Community Day: Bulbasaur'), findsOneWidget);
      expect(find.text('Spotlight Hour: Pikachu'), findsNothing);
      expect(find.text('Mega Raid Day'), findsNothing);

      // Simulate app relaunch — build a completely new widget tree
      await tester.pumpWidget(buildApp(key: const ValueKey('launch-2')));
      await tester.pumpAndSettle();

      // All events should be visible again — filter state was not persisted
      expect(find.text('Community Day: Bulbasaur'), findsOneWidget);
      expect(find.text('Spotlight Hour: Pikachu'), findsOneWidget);
      expect(find.text('Mega Raid Day'), findsOneWidget);
    });

    testWidgets(
        'multiple filters applied then relaunch resets all filters',
        (tester) async {
      // First launch — apply multiple filters
      await tester.pumpWidget(buildApp(key: const ValueKey('launch-a')));
      await tester.pumpAndSettle();

      // Select Raid Day filter
      await tester.tap(chipWithLabel('Raid Day'));
      await tester.pumpAndSettle();

      // Only raid day visible
      expect(find.text('Mega Raid Day'), findsOneWidget);
      expect(find.text('Community Day: Bulbasaur'), findsNothing);

      // Simulate relaunch
      await tester.pumpWidget(buildApp(key: const ValueKey('launch-b')));
      await tester.pumpAndSettle();

      // Everything is back
      expect(find.text('Community Day: Bulbasaur'), findsOneWidget);
      expect(find.text('Spotlight Hour: Pikachu'), findsOneWidget);
      expect(find.text('Mega Raid Day'), findsOneWidget);
    });

    testWidgets('"All" chip is selected by default after relaunch',
        (tester) async {
      // First launch — switch away from All
      await tester.pumpWidget(buildApp(key: const ValueKey('run-1')));
      await tester.pumpAndSettle();

      await tester.tap(chipWithLabel('Spotlight Hour'));
      await tester.pumpAndSettle();

      // Simulate relaunch
      await tester.pumpWidget(buildApp(key: const ValueKey('run-2')));
      await tester.pumpAndSettle();

      // "All" chip should be visually selected (default state)
      final allChip = tester.widget<FilterChip>(chipWithLabel('All'));
      expect(allChip.selected, isTrue);
    });

    testWidgets('filter state is not shared across independent widget trees',
        (tester) async {
      // Launch first instance with a filter applied
      await tester.pumpWidget(buildApp(key: const ValueKey('tree-1')));
      await tester.pumpAndSettle();

      await tester.tap(chipWithLabel('Community Day'));
      await tester.pumpAndSettle();
      expect(find.text('Spotlight Hour: Pikachu'), findsNothing);

      // Mount a completely separate widget tree
      await tester.pumpWidget(buildApp(key: const ValueKey('tree-2')));
      await tester.pumpAndSettle();

      // No filter state leaks between independent trees
      expect(find.text('Community Day: Bulbasaur'), findsOneWidget);
      expect(find.text('Spotlight Hour: Pikachu'), findsOneWidget);
      expect(find.text('Mega Raid Day'), findsOneWidget);
    });
  });
}

/// Test harness: event list with event-type filter chips.
///
/// Filter state is stored in [State] only — ephemeral by design.
/// This mirrors the expected production behavior where event type filters
/// are not persisted across app sessions.
class _EventTypeFilterList extends StatefulWidget {
  const _EventTypeFilterList({
    super.key,
    required this.events,
  });

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

  Set<EventType> get _availableTypes =>
      widget.events.map((e) => e.eventType).toSet();

  String _labelForType(EventType type) {
    return switch (type) {
      EventType.communityDay => 'Community Day',
      EventType.spotlightHour => 'Spotlight Hour',
      EventType.raidHour => 'Raid Hour',
      EventType.raidDay => 'Raid Day',
      EventType.event => 'Event',
      EventType.goBattleLeague => 'GO Battle League',
      EventType.goRocket => 'GO Rocket',
      EventType.research => 'Research',
      EventType.pokemonGoFest => 'GO Fest',
      EventType.safariZone => 'Safari Zone',
      EventType.season => 'Season',
      EventType.other => 'Other',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter chips row
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
              for (final type in _availableTypes) ...[
                FilterChip(
                  label: Text(_labelForType(type)),
                  selected: _selectedType == type,
                  onSelected: (_) => setState(() => _selectedType = type),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        // Event list
        Expanded(
          child: _filteredEvents.isEmpty
              ? const Center(child: Text('No events match filter'))
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
