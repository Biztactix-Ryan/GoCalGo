import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gocalgo/config/theme.dart';
import 'package:gocalgo/models/buff.dart';
import 'package:gocalgo/models/buff_category.dart';
import 'package:gocalgo/models/event_type.dart';
import 'package:gocalgo/widgets/event_card.dart';

import '../helpers/test_data.dart';

/// Golden tests for the [EventCard] widget.
///
/// These tests capture pixel-perfect snapshots of the event card in various
/// states (default, flagged, with buffs, different event types) and compare
/// them against stored reference images under `test/goldens/`.
///
/// To update goldens after intentional visual changes:
///   flutter test --update-goldens test/widgets/event_card_golden_test.dart

void main() {
  group('EventCard golden tests', () {
    Widget buildCard({
      required EventCard card,
      Size size = const Size(400, 300),
    }) {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: size.width,
              child: card,
            ),
          ),
        ),
      );
    }

    testWidgets('default event card', (tester) async {
      final event = TestData.event(
        imageUrl: '', // no network image for golden stability
        start: DateTime(2026, 3, 21, 14, 0),
        end: DateTime(2026, 3, 21, 17, 0),
      );

      await tester.pumpWidget(buildCard(
        card: EventCard(event: event),
      ));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(EventCard),
        matchesGoldenFile('goldens/event_card_default.png'),
      );
    });

    testWidgets('flagged event card', (tester) async {
      final event = TestData.event(
        imageUrl: '',
        start: DateTime(2026, 3, 21, 14, 0),
        end: DateTime(2026, 3, 21, 17, 0),
      );

      await tester.pumpWidget(buildCard(
        card: EventCard(
          event: event,
          isFlagged: true,
          onToggleFlag: () {},
        ),
      ));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(EventCard),
        matchesGoldenFile('goldens/event_card_flagged.png'),
      );
    });

    testWidgets('community day card with buffs', (tester) async {
      final event = TestData.event(
        id: 'cd-golden',
        name: 'Community Day: Bulbasaur',
        eventType: EventType.communityDay,
        heading: 'Community Day',
        imageUrl: '',
        start: DateTime(2026, 3, 21, 14, 0),
        end: DateTime(2026, 3, 21, 17, 0),
        buffs: [
          const Buff(
            text: '3× Catch Stardust',
            category: BuffCategory.multiplier,
            multiplier: 3.0,
            resource: 'Stardust',
          ),
        ],
      );

      await tester.pumpWidget(buildCard(
        card: EventCard(event: event),
        size: const Size(400, 350),
      ));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(EventCard),
        matchesGoldenFile('goldens/event_card_community_day.png'),
      );
    });

    testWidgets('spotlight hour card with buffs', (tester) async {
      final event = TestData.event(
        id: 'sh-golden',
        name: 'Spotlight Hour: Pikachu',
        eventType: EventType.spotlightHour,
        heading: 'Spotlight Hour',
        imageUrl: '',
        start: DateTime(2026, 3, 25, 18, 0),
        end: DateTime(2026, 3, 25, 19, 0),
        buffs: [
          const Buff(
            text: '2× Transfer Candy',
            category: BuffCategory.multiplier,
            multiplier: 2.0,
            resource: 'Candy',
          ),
        ],
      );

      await tester.pumpWidget(buildCard(
        card: EventCard(event: event),
        size: const Size(400, 350),
      ));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(EventCard),
        matchesGoldenFile('goldens/event_card_spotlight_hour.png'),
      );
    });

    testWidgets('raid hour card', (tester) async {
      final event = TestData.event(
        id: 'rh-golden',
        name: 'Raid Hour',
        eventType: EventType.raidHour,
        heading: 'Raid Hour',
        imageUrl: '',
        start: DateTime(2026, 3, 26, 18, 0),
        end: DateTime(2026, 3, 26, 19, 0),
      );

      await tester.pumpWidget(buildCard(
        card: EventCard(event: event),
      ));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(EventCard),
        matchesGoldenFile('goldens/event_card_raid_hour.png'),
      );
    });

    testWidgets('event card with multiple buffs', (tester) async {
      final event = TestData.event(
        name: 'Adventure Week',
        eventType: EventType.event,
        heading: 'Explore and earn bonus rewards!',
        imageUrl: '',
        start: DateTime(2026, 3, 21, 10, 0),
        end: DateTime(2026, 3, 28, 20, 0),
        buffs: [
          const Buff(
            text: '2× Buddy Candy',
            category: BuffCategory.multiplier,
            multiplier: 2.0,
            resource: 'Candy',
          ),
          const Buff(
            text: '4× Adventure Sync Hatch',
            category: BuffCategory.duration,
            multiplier: 4.0,
            resource: 'Hatch',
          ),
          const Buff(
            text: 'Increased wild spawns',
            category: BuffCategory.spawn,
          ),
        ],
      );

      await tester.pumpWidget(buildCard(
        card: EventCard(event: event),
        size: const Size(400, 400),
      ));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(EventCard),
        matchesGoldenFile('goldens/event_card_multiple_buffs.png'),
      );
    });
  });
}
