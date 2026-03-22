import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gocalgo/config/event_type_style.dart';
import 'package:gocalgo/config/theme.dart';
import 'package:gocalgo/models/event_dto.dart';
import 'package:gocalgo/models/event_type.dart';
import 'package:gocalgo/widgets/event_card.dart';

/// Verifies acceptance criterion for story US-GCG-8:
/// "Flagged events are visually distinct in the calendar view"
///
/// Tests that EventCard renders differently when isFlagged is true vs false,
/// so users can tell at a glance which events they've flagged.
void main() {
  const sampleEvent = EventDto(
    id: 'test-event-1',
    name: 'Community Day: Bulbasaur',
    eventType: EventType.communityDay,
    heading: 'January Community Day',
    imageUrl: 'https://example.com/image.png',
    linkUrl: 'https://pokemongolive.com',
    isUtcTime: false,
    hasSpawns: true,
    hasResearchTasks: false,
    buffs: [],
    featuredPokemon: [],
    promoCodes: [],
  );

  Widget buildCard({bool isFlagged = false, EventDto event = sampleEvent}) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: EventCard(event: event, isFlagged: isFlagged),
      ),
    );
  }

  group('Flagged event visual distinction', () {
    testWidgets('unflagged card does not show flag icon', (tester) async {
      await tester.pumpWidget(buildCard());
      await tester.pump();

      expect(find.byIcon(Icons.flag), findsNothing);
    });

    testWidgets('flagged card shows flag icon indicator', (tester) async {
      await tester.pumpWidget(buildCard(isFlagged: true));
      await tester.pump();

      expect(find.byIcon(Icons.flag), findsOneWidget);
    });

    testWidgets('flagged card has colored border', (tester) async {
      await tester.pumpWidget(buildCard(isFlagged: true));
      await tester.pump();

      final card = tester.widget<Card>(find.byType(Card));
      final shape = card.shape as RoundedRectangleBorder;
      final style = EventTypeStyle.of(sampleEvent.eventType);

      expect(shape.side.color, equals(style.color));
      expect(shape.side.width, equals(2.0));
    });

    testWidgets('unflagged card has no custom border', (tester) async {
      await tester.pumpWidget(buildCard());
      await tester.pump();

      final card = tester.widget<Card>(find.byType(Card));
      // shape is null (uses theme default) when not flagged
      expect(card.shape, isNull);
    });

    testWidgets('flag indicator uses event type color', (tester) async {
      await tester.pumpWidget(buildCard(isFlagged: true));
      await tester.pump();

      final style = EventTypeStyle.of(sampleEvent.eventType);
      final icon = tester.widget<Icon>(find.byIcon(Icons.flag));
      expect(icon.color, equals(style.color));
    });

    testWidgets('visual distinction works across event types', (tester) async {
      const raidEvent = EventDto(
        id: 'test-raid-1',
        name: 'Mega Raid Day',
        eventType: EventType.raidDay,
        heading: 'Mega Charizard Y',
        imageUrl: 'https://example.com/raid.png',
        linkUrl: '',
        isUtcTime: true,
        hasSpawns: false,
        hasResearchTasks: false,
        buffs: [],
        featuredPokemon: [],
        promoCodes: [],
      );

      await tester.pumpWidget(buildCard(isFlagged: true, event: raidEvent));
      await tester.pump();

      // Flag icon present
      expect(find.byIcon(Icons.flag), findsOneWidget);

      // Border matches raid event type color
      final card = tester.widget<Card>(find.byType(Card));
      final shape = card.shape as RoundedRectangleBorder;
      final style = EventTypeStyle.of(raidEvent.eventType);
      expect(shape.side.color, equals(style.color));
    });

    testWidgets('flagged and unflagged cards are visually different',
        (tester) async {
      // Render unflagged
      await tester.pumpWidget(buildCard());
      await tester.pump();
      final unflaggedCard = tester.widget<Card>(find.byType(Card));

      // Render flagged
      await tester.pumpWidget(buildCard(isFlagged: true));
      await tester.pump();
      final flaggedCard = tester.widget<Card>(find.byType(Card));

      // Cards must differ — flagged has a custom shape, unflagged doesn't
      expect(flaggedCard.shape, isNotNull);
      expect(unflaggedCard.shape, isNull);
    });
  });
}
