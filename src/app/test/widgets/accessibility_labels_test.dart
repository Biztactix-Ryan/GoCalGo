import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gocalgo/models/buff.dart';
import 'package:gocalgo/models/buff_category.dart';
import 'package:gocalgo/models/event_type.dart';
import 'package:gocalgo/models/pokemon.dart';
import 'package:gocalgo/models/pokemon_role.dart';
import 'package:gocalgo/screens/home_screen.dart';
import 'package:gocalgo/widgets/event_card.dart';
import 'package:gocalgo/widgets/buff_chip.dart';
import 'package:gocalgo/widgets/loading_indicator.dart';
import 'package:gocalgo/widgets/error_state.dart';
import 'package:gocalgo/widgets/empty_state.dart';
import 'package:gocalgo/widgets/skeleton_event_card.dart';
import 'package:gocalgo/widgets/freshness_indicator.dart';

import '../helpers/pump_app.dart';
import '../helpers/test_data.dart';

void main() {
  group('Accessibility labels on interactive elements', () {
    testWidgets('EventCard has semantic label for card tap', (tester) async {
      final event = TestData.event(name: 'Community Day: Bulbasaur');

      await tester.pumpApp(
        Scaffold(
          body: EventCard(
            event: event,
            isFlagged: false,
            onToggleFlag: () {},
          ),
        ),
      );

      // The outer Semantics wrapper should describe the event card as a button
      final semantics = tester.getSemantics(find.byType(EventCard));
      expect(
        semantics.label,
        contains('Community Day: Bulbasaur'),
        reason: 'EventCard should have a semantic label containing the event name',
      );
    });

    testWidgets('EventCard flag toggle has semantic label', (tester) async {
      final event = TestData.event(name: 'Test Event');

      await tester.pumpApp(
        Scaffold(
          body: EventCard(
            event: event,
            isFlagged: false,
            onToggleFlag: () {},
          ),
        ),
      );

      // Find the Semantics widget wrapping the flag toggle GestureDetector
      final semanticsWidgets = tester.widgetList<Semantics>(
        find.byType(Semantics),
      );
      final flagSemantics = semanticsWidgets.where(
        (s) => s.properties.label == 'Flag event',
      );
      expect(
        flagSemantics,
        isNotEmpty,
        reason: 'Unflagged event should have a Semantics with "Flag event" label',
      );
    });

    testWidgets('EventCard flagged toggle shows unflag label', (tester) async {
      final event = TestData.event(name: 'Test Event');

      await tester.pumpApp(
        Scaffold(
          body: EventCard(
            event: event,
            isFlagged: true,
            onToggleFlag: () {},
          ),
        ),
      );

      final semanticsWidgets = tester.widgetList<Semantics>(
        find.byType(Semantics),
      );
      final unflagSemantics = semanticsWidgets.where(
        (s) => s.properties.label == 'Unflag event',
      );
      expect(
        unflagSemantics,
        isNotEmpty,
        reason: 'Flagged event should have a Semantics with "Unflag event" label',
      );
    });

    testWidgets('HomeScreen flag filter button has tooltip', (tester) async {
      await tester.pumpScreen(
        const HomeScreen(),
        events: [TestData.event()],
      );
      await tester.pumpAndSettle();

      final iconButton = find.byType(IconButton);
      expect(iconButton, findsOneWidget);

      final widget = tester.widget<IconButton>(iconButton);
      expect(
        widget.tooltip,
        isNotNull,
        reason: 'Flag filter IconButton should have a tooltip',
      );
    });

    testWidgets('ErrorState retry button has text label', (tester) async {
      await tester.pumpApp(
        Scaffold(
          body: ErrorState(
            message: 'Failed to load',
            onRetry: () {},
          ),
        ),
      );

      expect(
        find.text('Retry'),
        findsOneWidget,
        reason: 'Retry button should have visible text label',
      );
    });

    testWidgets('LoadingIndicator has semantics label on spinner',
        (tester) async {
      await tester.pumpApp(
        const Scaffold(body: LoadingIndicator()),
      );

      final progressFinder = find.byType(CircularProgressIndicator);
      expect(progressFinder, findsOneWidget);

      final widget = tester.widget<CircularProgressIndicator>(progressFinder);
      expect(
        widget.semanticsLabel,
        isNotNull,
        reason: 'CircularProgressIndicator should have a semanticsLabel',
      );
    });

    testWidgets('EventCard event image has semantic label', (tester) async {
      final event = TestData.event(
        name: 'Raid Hour',
        imageUrl: 'https://example.com/img.png',
      );

      await tester.pumpApp(
        Scaffold(
          body: EventCard(
            event: event,
            isFlagged: false,
            onToggleFlag: () {},
          ),
        ),
      );

      // The Image.network should have a semanticLabel
      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);

      final image = tester.widget<Image>(imageFinder);
      expect(
        image.semanticLabel,
        contains('Raid Hour'),
        reason: 'Event image should have a semantic label with the event name',
      );
    });

    testWidgets('EventCard semantic label indicates flagged state',
        (tester) async {
      final event = TestData.event(name: 'Flagged Event');

      await tester.pumpApp(
        Scaffold(
          body: EventCard(
            event: event,
            isFlagged: true,
            onToggleFlag: () {},
          ),
        ),
      );

      final semantics = tester.getSemantics(find.byType(EventCard));
      expect(
        semantics.label,
        contains('Flagged'),
        reason: 'Flagged event card semantic label should mention flagged state',
      );
    });

    testWidgets('BuffChip has semantic label with category and text',
        (tester) async {
      final buff = Buff(
        text: '2× Catch Candy',
        category: BuffCategory.multiplier,
      );

      await tester.pumpApp(
        Scaffold(body: BuffChip(buff: buff)),
      );

      final semanticsWidgets = tester.widgetList<Semantics>(
        find.byType(Semantics),
      );
      final buffSemantics = semanticsWidgets.where(
        (s) =>
            s.properties.label != null &&
            s.properties.label!.contains('multiplier bonus') &&
            s.properties.label!.contains('2× Catch Candy'),
      );
      expect(
        buffSemantics,
        isNotEmpty,
        reason: 'BuffChip should have a semantic label with category and buff text',
      );
    });

    testWidgets('SkeletonEventCard has loading semantic label',
        (tester) async {
      await tester.pumpApp(
        const Scaffold(body: SkeletonEventCard()),
      );

      final semanticsWidgets = tester.widgetList<Semantics>(
        find.byType(Semantics),
      );
      final loadingSemantics = semanticsWidgets.where(
        (s) => s.properties.label == 'Loading event',
      );
      expect(
        loadingSemantics,
        isNotEmpty,
        reason: 'SkeletonEventCard should have a "Loading event" semantic label',
      );
    });

    testWidgets('EmptyState icon is excluded from semantics', (tester) async {
      await tester.pumpApp(
        const Scaffold(body: EmptyState(message: 'No events today')),
      );

      expect(
        find.byType(ExcludeSemantics),
        findsOneWidget,
        reason: 'EmptyState icon should be excluded from semantics tree',
      );
    });

    testWidgets('ErrorState icon is excluded from semantics', (tester) async {
      await tester.pumpApp(
        Scaffold(
          body: ErrorState(
            message: 'Something went wrong',
            onRetry: () {},
          ),
        ),
      );

      expect(
        find.byType(ExcludeSemantics),
        findsOneWidget,
        reason: 'ErrorState icon should be excluded from semantics tree',
      );
    });

    testWidgets('FreshnessIndicator has combined semantic label',
        (tester) async {
      await tester.pumpApp(
        Scaffold(
          body: FreshnessIndicator(
            lastUpdated: DateTime.now().subtract(const Duration(minutes: 5)),
          ),
        ),
      );

      final semanticsWidgets = tester.widgetList<Semantics>(
        find.byType(Semantics),
      );
      final freshnessSemantics = semanticsWidgets.where(
        (s) =>
            s.properties.label != null &&
            s.properties.label!.contains('Updated'),
      );
      expect(
        freshnessSemantics,
        isNotEmpty,
        reason: 'FreshnessIndicator should have a semantic label with update time',
      );
    });
  });
}
