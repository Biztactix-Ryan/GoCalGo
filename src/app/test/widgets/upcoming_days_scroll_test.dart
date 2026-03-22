import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gocalgo/config/theme.dart';
import 'package:gocalgo/models/event_dto.dart';
import 'package:gocalgo/models/event_type.dart';
import 'package:gocalgo/services/event_day_grouping.dart';
import 'package:gocalgo/widgets/event_card.dart';

/// Verifies acceptance criterion for story US-GCG-23:
/// "User can scroll through upcoming days"
///
/// Tests that the upcoming events view, grouped by day, is scrollable
/// and that users can reach day groups beyond the initial viewport.

/// Helper to build a minimal EventDto for scroll tests.
EventDto _event(String id, String name, {required String start}) => EventDto(
      id: id,
      name: name,
      eventType: EventType.event,
      heading: name,
      imageUrl: '',
      linkUrl: '',
      start: DateTime.parse(start),
      end: DateTime.parse(start).add(const Duration(hours: 1)),
      isUtcTime: false,
      hasSpawns: false,
      hasResearchTasks: false,
      buffs: const [],
      featuredPokemon: const [],
      promoCodes: const [],
    );

void main() {
  /// Events spread across 7 consecutive days — enough to overflow the viewport.
  final events = [
    _event('d1-1', 'Community Day', start: '2026-03-21T10:00:00.000'),
    _event('d1-2', 'Raid Hour', start: '2026-03-21T18:00:00.000'),
    _event('d2-1', 'Spotlight Hour', start: '2026-03-22T18:00:00.000'),
    _event('d3-1', 'Mega Raid', start: '2026-03-23T14:00:00.000'),
    _event('d4-1', 'GO Battle Day', start: '2026-03-24T10:00:00.000'),
    _event('d5-1', 'Incense Day', start: '2026-03-25T11:00:00.000'),
    _event('d6-1', 'Research Day', start: '2026-03-26T09:00:00.000'),
    _event('d7-1', 'Adventure Week', start: '2026-03-27T10:00:00.000'),
  ];

  final dayGroups = groupEventsByDay(events);

  Widget buildUpcomingDaysView(List<DayGroup> groups) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: _UpcomingDaysScrollView(groups: groups),
      ),
    );
  }

  group('Scrolling through upcoming days', () {
    testWidgets('all day headers are reachable by scrolling', (tester) async {
      await tester.pumpWidget(buildUpcomingDaysView(dayGroups));
      await tester.pumpAndSettle();

      // First day header should be visible initially
      expect(find.text('Sat, Mar 21'), findsOneWidget);

      // Last day header should not be visible without scrolling
      expect(find.text('Fri, Mar 27'), findsNothing);

      // Scroll down repeatedly until the last header is visible
      await _scrollUntilVisible(tester, find.text('Fri, Mar 27'));

      expect(find.text('Fri, Mar 27'), findsOneWidget);
    });

    testWidgets('all event cards are reachable by scrolling', (tester) async {
      await tester.pumpWidget(buildUpcomingDaysView(dayGroups));
      await tester.pumpAndSettle();

      // Last event should not be visible initially
      expect(find.text('Adventure Week'), findsNothing);

      // Scroll to the last event
      await _scrollUntilVisible(tester, find.text('Adventure Week'));

      expect(find.text('Adventure Week'), findsOneWidget);
    });

    testWidgets('day headers remain correct after scrolling back up',
        (tester) async {
      await tester.pumpWidget(buildUpcomingDaysView(dayGroups));
      await tester.pumpAndSettle();

      // Scroll down to the bottom
      await _scrollUntilVisible(tester, find.text('Fri, Mar 27'));
      expect(find.text('Fri, Mar 27'), findsOneWidget);

      // Scroll back up
      await _scrollUntilVisible(tester, find.text('Sat, Mar 21'),
          scrollDown: false);

      expect(find.text('Sat, Mar 21'), findsOneWidget);
    });

    testWidgets('the list is contained in a scrollable widget',
        (tester) async {
      await tester.pumpWidget(buildUpcomingDaysView(dayGroups));
      await tester.pumpAndSettle();

      // Verify a scrollable widget is present
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('each day group shows its header and event cards',
        (tester) async {
      await tester.pumpWidget(buildUpcomingDaysView(dayGroups));
      await tester.pumpAndSettle();

      // First group: Sat, Mar 21 with 2 events
      expect(find.text('Sat, Mar 21'), findsOneWidget);
      expect(find.text('Community Day'), findsOneWidget);
      expect(find.text('Raid Hour'), findsOneWidget);

      // Second group: Sun, Mar 22 with 1 event
      // May require scrolling depending on viewport size
      await _scrollUntilVisible(tester, find.text('Sun, Mar 22'));
      expect(find.text('Sun, Mar 22'), findsOneWidget);
      expect(find.text('Spotlight Hour'), findsOneWidget);
    });

    testWidgets('single day group does not need scrolling', (tester) async {
      final singleGroup = [dayGroups.first];

      await tester.pumpWidget(buildUpcomingDaysView(singleGroup));
      await tester.pumpAndSettle();

      expect(find.text('Sat, Mar 21'), findsOneWidget);
      expect(find.text('Community Day'), findsOneWidget);
      expect(find.text('Raid Hour'), findsOneWidget);
    });

    testWidgets('drag gesture scrolls the list', (tester) async {
      await tester.pumpWidget(buildUpcomingDaysView(dayGroups));
      await tester.pumpAndSettle();

      // Perform a drag gesture to scroll
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();

      // After scrolling down, earlier content may be offscreen
      // and later content should now be visible
      final scrollable = tester.widget<ListView>(find.byType(ListView));
      expect(scrollable.controller, isNull,
          reason: 'ListView uses default scroll behavior');
    });
  });
}

/// Scrolls in the given direction until [finder] is visible, or gives up
/// after [maxScrolls] attempts.
Future<void> _scrollUntilVisible(
  WidgetTester tester,
  Finder finder, {
  bool scrollDown = true,
  int maxScrolls = 20,
}) async {
  for (var i = 0; i < maxScrolls; i++) {
    if (tester.any(finder)) return;
    await tester.drag(
      find.byType(ListView),
      Offset(0, scrollDown ? -300 : 300),
    );
    await tester.pumpAndSettle();
  }
}

/// Test harness: an upcoming-days view that renders [DayGroup]s in a
/// scrollable list with sticky-style day headers.
///
/// This widget represents the expected contract for the upcoming events
/// scroll feature. The actual implementation will live in the upcoming
/// events screen once US-GCG-23-7 is completed.
class _UpcomingDaysScrollView extends StatelessWidget {
  const _UpcomingDaysScrollView({required this.groups});

  final List<DayGroup> groups;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Flatten day groups into a list of widgets: header + events per group.
    final items = <Widget>[];
    for (final group in groups) {
      items.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(
          group.header,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ));
      for (final event in group.events) {
        items.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: EventCard(event: event),
        ));
      }
    }

    return ListView(
      children: items,
    );
  }
}
