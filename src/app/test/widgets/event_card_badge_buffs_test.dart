import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gocalgo/config/event_type_style.dart';
import 'package:gocalgo/config/theme.dart';
import 'package:gocalgo/models/buff.dart';
import 'package:gocalgo/models/buff_category.dart';
import 'package:gocalgo/models/event_dto.dart';
import 'package:gocalgo/models/event_type.dart';
import 'package:gocalgo/widgets/buff_chip.dart';
import 'package:gocalgo/widgets/event_card.dart';

/// Verifies acceptance criterion for story US-GCG-23:
/// "Each event card shows type badge and key buffs/bonuses"
///
/// Tests that the EventCard widget displays a type badge (icon + label) and
/// renders buff chips when buffs are present.
void main() {
  const sampleBuffs = [
    Buff(
      text: '2× Catch XP',
      category: BuffCategory.multiplier,
      multiplier: 2.0,
      resource: 'XP',
    ),
    Buff(
      text: 'Increased Shiny rate',
      category: BuffCategory.probability,
    ),
    Buff(
      text: '3-hour Lure Modules',
      category: BuffCategory.duration,
      resource: 'Lure Module',
    ),
  ];

  const eventWithBuffs = EventDto(
    id: 'test-cd-1',
    name: 'Community Day: Charmander',
    eventType: EventType.communityDay,
    heading: 'March Community Day',
    imageUrl: '',
    linkUrl: '',
    isUtcTime: false,
    hasSpawns: true,
    hasResearchTasks: true,
    buffs: sampleBuffs,
    featuredPokemon: [],
    promoCodes: [],
  );

  const eventNoBuffs = EventDto(
    id: 'test-sh-1',
    name: 'Spotlight Hour: Pikachu',
    eventType: EventType.spotlightHour,
    heading: '6 PM – 7 PM local time',
    imageUrl: '',
    linkUrl: '',
    isUtcTime: false,
    hasSpawns: true,
    hasResearchTasks: false,
    buffs: [],
    featuredPokemon: [],
    promoCodes: [],
  );

  Widget buildCard(EventDto event) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: SingleChildScrollView(child: EventCard(event: event)),
      ),
    );
  }

  group('Type badge display', () {
    testWidgets('card shows type badge label', (tester) async {
      await tester.pumpWidget(buildCard(eventWithBuffs));
      await tester.pump();

      final style = EventTypeStyle.of(EventType.communityDay);
      expect(find.text(style.label), findsOneWidget);
    });

    testWidgets('card shows type badge icon', (tester) async {
      await tester.pumpWidget(buildCard(eventWithBuffs));
      await tester.pump();

      final style = EventTypeStyle.of(EventType.communityDay);
      expect(find.byIcon(style.icon), findsOneWidget);
    });

    testWidgets('type badge uses event type color', (tester) async {
      await tester.pumpWidget(buildCard(eventWithBuffs));
      await tester.pump();

      final style = EventTypeStyle.of(EventType.communityDay);

      // Find the label text and verify its color
      final labelText = tester.widget<Text>(find.text(style.label));
      expect(labelText.style?.color, equals(style.color));

      // Find the badge icon and verify its color
      final icons = tester.widgetList<Icon>(find.byIcon(style.icon)).toList();
      final badgeIcon = icons.firstWhere((i) => i.size == 14);
      expect(badgeIcon.color, equals(style.color));
    });

    testWidgets('type badge appears for different event types', (tester) async {
      // Spotlight Hour event
      await tester.pumpWidget(buildCard(eventNoBuffs));
      await tester.pump();

      final style = EventTypeStyle.of(EventType.spotlightHour);
      expect(find.text(style.label), findsOneWidget);
      expect(find.byIcon(style.icon), findsOneWidget);
    });

    testWidgets('type badge works across all event types', (tester) async {
      for (final type in EventType.values) {
        final event = EventDto(
          id: 'test-${type.name}',
          name: 'Test ${type.name}',
          eventType: type,
          heading: '',
          imageUrl: '',
          linkUrl: '',
          isUtcTime: false,
          hasSpawns: false,
          hasResearchTasks: false,
          buffs: [],
          featuredPokemon: [],
          promoCodes: [],
        );

        await tester.pumpWidget(buildCard(event));
        await tester.pump();

        final style = EventTypeStyle.of(type);
        expect(
          find.text(style.label),
          findsOneWidget,
          reason: '${type.name} should show badge label "${style.label}"',
        );
      }
    });
  });

  group('Buff/bonus display on event card', () {
    testWidgets('card shows buff chips when event has buffs', (tester) async {
      await tester.pumpWidget(buildCard(eventWithBuffs));
      await tester.pump();

      expect(find.byType(BuffChipList), findsOneWidget);
      expect(find.byType(BuffChip), findsNWidgets(3));
    });

    testWidgets('each buff text is visible', (tester) async {
      await tester.pumpWidget(buildCard(eventWithBuffs));
      await tester.pump();

      expect(find.text('2× Catch XP'), findsOneWidget);
      expect(find.text('Increased Shiny rate'), findsOneWidget);
      expect(find.text('3-hour Lure Modules'), findsOneWidget);
    });

    testWidgets('card without buffs shows no buff chips', (tester) async {
      await tester.pumpWidget(buildCard(eventNoBuffs));
      await tester.pump();

      expect(find.byType(BuffChip), findsNothing);
    });

    testWidgets('buff chips have category-specific icons', (tester) async {
      await tester.pumpWidget(buildCard(eventWithBuffs));
      await tester.pump();

      // multiplier → trending_up, probability → auto_awesome, duration → timer
      expect(find.byIcon(Icons.trending_up), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
      expect(find.byIcon(Icons.timer), findsOneWidget);
    });

    testWidgets('both badge and buffs are visible together', (tester) async {
      await tester.pumpWidget(buildCard(eventWithBuffs));
      await tester.pump();

      final style = EventTypeStyle.of(EventType.communityDay);

      // Type badge is present
      expect(find.text(style.label), findsOneWidget);

      // Buffs are present
      expect(find.byType(BuffChip), findsNWidgets(3));
      expect(find.text('2× Catch XP'), findsOneWidget);
    });
  });
}
