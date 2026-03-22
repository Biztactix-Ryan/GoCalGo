import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gocalgo/config/theme.dart';
import 'package:gocalgo/models/event_dto.dart';
import 'package:gocalgo/models/event_type.dart';
import 'package:gocalgo/providers/events_provider.dart';
import 'package:gocalgo/screens/event_detail_screen.dart';
import 'package:gocalgo/services/flag_store.dart';

/// In-memory [FlagStore] for testing — no SQLite dependency.
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

/// Verifies acceptance criterion for story US-GCG-8:
/// "User can tap to flag/unflag any event"
///
/// Tests that the flag toggle button on the event detail screen allows users
/// to tap to flag an event, and tap again to unflag it.
void main() {
  const sampleEvent = EventDto(
    id: 'test-event-1',
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

  Widget buildScreen({Set<String> initialFlaggedIds = const {}}) {
    final store = _InMemoryFlagStore();
    for (final id in initialFlaggedIds) {
      store._ids.add(id);
    }

    return ProviderScope(
      overrides: [
        flagStoreProvider.overrideWithValue(store),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const EventDetailScreen(event: sampleEvent),
      ),
    );
  }

  group('Flag toggle', () {
    testWidgets('shows outlined flag icon when event is not flagged',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      final iconButton = find.byType(IconButton);
      expect(iconButton, findsOneWidget);

      final icon = tester.widget<Icon>(find.descendant(
        of: iconButton,
        matching: find.byType(Icon),
      ));
      expect(icon.icon, equals(Icons.flag_outlined));
    });

    testWidgets('shows filled flag icon when event is flagged',
        (tester) async {
      await tester
          .pumpWidget(buildScreen(initialFlaggedIds: {sampleEvent.id}));
      await tester.pumpAndSettle();

      final iconButton = find.byType(IconButton);
      final icon = tester.widget<Icon>(find.descendant(
        of: iconButton,
        matching: find.byType(Icon),
      ));
      expect(icon.icon, equals(Icons.flag));
    });

    testWidgets('tapping flag button toggles from unflagged to flagged',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      // Verify initially unflagged
      var icon = tester.widget<Icon>(find.descendant(
        of: find.byType(IconButton),
        matching: find.byType(Icon),
      ));
      expect(icon.icon, equals(Icons.flag_outlined));

      // Tap to flag
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      // Verify now flagged
      icon = tester.widget<Icon>(find.descendant(
        of: find.byType(IconButton),
        matching: find.byType(Icon),
      ));
      expect(icon.icon, equals(Icons.flag));
    });

    testWidgets('tapping flag button toggles from flagged to unflagged',
        (tester) async {
      await tester
          .pumpWidget(buildScreen(initialFlaggedIds: {sampleEvent.id}));
      await tester.pumpAndSettle();

      // Verify initially flagged
      var icon = tester.widget<Icon>(find.descendant(
        of: find.byType(IconButton),
        matching: find.byType(Icon),
      ));
      expect(icon.icon, equals(Icons.flag));

      // Tap to unflag
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      // Verify now unflagged
      icon = tester.widget<Icon>(find.descendant(
        of: find.byType(IconButton),
        matching: find.byType(Icon),
      ));
      expect(icon.icon, equals(Icons.flag_outlined));
    });

    testWidgets('flag toggle is reversible (flag → unflag → flag)',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      // Start unflagged
      var icon = tester.widget<Icon>(find.descendant(
        of: find.byType(IconButton),
        matching: find.byType(Icon),
      ));
      expect(icon.icon, equals(Icons.flag_outlined));

      // Tap to flag
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      icon = tester.widget<Icon>(find.descendant(
        of: find.byType(IconButton),
        matching: find.byType(Icon),
      ));
      expect(icon.icon, equals(Icons.flag));

      // Tap to unflag
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      icon = tester.widget<Icon>(find.descendant(
        of: find.byType(IconButton),
        matching: find.byType(Icon),
      ));
      expect(icon.icon, equals(Icons.flag_outlined));

      // Tap to flag again
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      icon = tester.widget<Icon>(find.descendant(
        of: find.byType(IconButton),
        matching: find.byType(Icon),
      ));
      expect(icon.icon, equals(Icons.flag));
    });

    testWidgets('tooltip updates when flag state changes', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      // Unflagged tooltip
      var button = tester.widget<IconButton>(find.byType(IconButton));
      expect(button.tooltip, equals('Flag event'));

      // Tap to flag
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      // Flagged tooltip
      button = tester.widget<IconButton>(find.byType(IconButton));
      expect(button.tooltip, equals('Unflag event'));
    });

    testWidgets('flag button works for different event types',
        (tester) async {
      // Test with a different event type to verify flagging works for "any event"
      const raidEvent = EventDto(
        id: 'test-raid-1',
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

      final store = _InMemoryFlagStore();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          flagStoreProvider.overrideWithValue(store),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const EventDetailScreen(event: raidEvent),
        ),
      ));
      await tester.pumpAndSettle();

      // Flag button is present and works
      expect(find.byType(IconButton), findsOneWidget);

      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      final icon = tester.widget<Icon>(find.descendant(
        of: find.byType(IconButton),
        matching: find.byType(Icon),
      ));
      expect(icon.icon, equals(Icons.flag));
    });
  });
}
