import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_app.dart';

/// End-to-end integration tests for four critical user journeys,
/// running against the local E2E backend (docker-compose.e2e.yml).
///
/// Prerequisites:
///   docker compose -f docker-compose.e2e.yml up --build -d
///   # Wait for all services to be healthy
///
/// Run:
///   cd src/app
///   flutter test integration_test/e2e_journeys_test.dart \
///     --dart-define=INTEGRATION_TEST_API_URL=http://localhost:5001
///
/// The WireMock backend serves these test events:
///   - Adventure Week 2026 (Mar 20–30) — active now
///   - GO Battle League: Interlude Season (Mar 1 – Apr 30) — active now
///   - Spotlight Hour: Magikarp (Mar 24) — upcoming
///   - Raid Hour: Mega Rayquaza (Mar 25) — upcoming
///   - Community Day: Beldum (Mar 28) — upcoming
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Build the app pointed at the E2E backend on port 5001.
  Widget e2eApp() => buildTestApp(
        apiBaseUrl: 'http://localhost:5001/api/v1',
      );

  // ── Journey 1: Launch app and see today's events ──────────────────────

  group('Journey 1: Launch app and see today\'s events', () {
    testWidgets('home screen shows currently active events', (tester) async {
      await tester.pumpWidget(e2eApp());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // App bar title is present.
      expect(find.text('GoCalGo'), findsOneWidget);

      // Active events from WireMock should be visible.
      // Adventure Week 2026 runs Mar 20–30, so it's active.
      expect(find.text('Adventure Week 2026'), findsOneWidget);

      // GO Battle League: Interlude Season runs Mar 1 – Apr 30, also active.
      expect(find.text('GO Battle League: Interlude Season'), findsOneWidget);

      // Upcoming-only events should NOT appear on the home screen.
      expect(find.text('Spotlight Hour: Magikarp'), findsNothing);
      expect(find.text('Community Day: Beldum'), findsNothing);
    });

    testWidgets('active event cards show type badges and time info',
        (tester) async {
      await tester.pumpWidget(e2eApp());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Type badges should be visible for active events.
      expect(find.text('Event'), findsWidgets);
      expect(find.text('GO Battle League'), findsWidgets);

      // Time-remaining indicator should be present for events with end dates.
      final timeRemainingFinder =
          find.textContaining(RegExp(r'\d+[dhm] left'));
      expect(timeRemainingFinder, findsWidgets);
    });
  });

  // ── Journey 2: Tap event and see detail ───────────────────────────────

  group('Journey 2: Tap event and see detail', () {
    testWidgets('tapping an event card navigates to the detail screen',
        (tester) async {
      await tester.pumpWidget(e2eApp());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Tap on the Adventure Week event card.
      await tester.tap(find.text('Adventure Week 2026'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Detail screen should show the event name as a headline.
      // The event name appears in the detail body (headlineSmall style).
      expect(find.text('Adventure Week 2026'), findsOneWidget);

      // Time section with schedule icon should be visible.
      expect(find.byIcon(Icons.schedule), findsOneWidget);

      // Buff/bonus section should be visible.
      expect(find.text('Active Bonuses'), findsOneWidget);
      expect(find.text('2x Buddy Candy'), findsOneWidget);
      expect(find.text('1/2 Egg Hatch Distance'), findsOneWidget);

      // Features section should show spawns and research.
      expect(find.text('Features'), findsOneWidget);
      expect(find.text('Special Spawns'), findsOneWidget);
      expect(find.text('Research Tasks'), findsOneWidget);
    });

    testWidgets('detail screen has a back button that returns to home',
        (tester) async {
      await tester.pumpWidget(e2eApp());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Navigate to detail.
      await tester.tap(find.text('Adventure Week 2026'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Tap the back button.
      final backButton = find.byType(BackButton);
      if (backButton.evaluate().isNotEmpty) {
        await tester.tap(backButton);
      } else {
        // SliverAppBar uses a leading icon button.
        await tester.tap(find.byTooltip('Back'));
      }
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Should be back on the home screen.
      expect(find.text('GoCalGo'), findsOneWidget);
      expect(find.text('Adventure Week 2026'), findsOneWidget);
    });

    testWidgets('detail screen shows flag toggle in app bar',
        (tester) async {
      await tester.pumpWidget(e2eApp());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Navigate to detail.
      await tester.tap(find.text('Adventure Week 2026'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Flag button should be in the app bar (unflagged initially).
      expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
      expect(find.byTooltip('Flag event'), findsOneWidget);
    });
  });

  // ── Journey 3: Flag an event and verify persistence ───────────────────

  group('Journey 3: Flag an event and verify persistence', () {
    testWidgets('flagging on home screen persists across tab navigation',
        (tester) async {
      await tester.pumpWidget(e2eApp());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // All flag icons should be outlined initially.
      final outlinedFlags = find.byIcon(Icons.flag_outlined);
      expect(outlinedFlags, findsWidgets);

      // Flag the first event.
      await tester.tap(outlinedFlags.first);
      await tester.pumpAndSettle();

      // A solid flag icon should appear.
      expect(find.byIcon(Icons.flag), findsWidgets);

      // Navigate to Upcoming and back to verify flag persists.
      await tester.tap(find.text('Upcoming'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Flag should still be solid after navigating back.
      expect(find.byIcon(Icons.flag), findsWidgets);
    });

    testWidgets('flagging on detail screen is reflected on home screen',
        (tester) async {
      await tester.pumpWidget(e2eApp());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Navigate to event detail.
      await tester.tap(find.text('Adventure Week 2026'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Flag the event on the detail screen.
      await tester.tap(find.byTooltip('Flag event'));
      await tester.pumpAndSettle();

      // Flag icon should now be solid.
      expect(find.byIcon(Icons.flag), findsOneWidget);
      expect(find.byTooltip('Unflag event'), findsOneWidget);

      // Go back to home.
      final backButton = find.byType(BackButton);
      if (backButton.evaluate().isNotEmpty) {
        await tester.tap(backButton);
      } else {
        await tester.tap(find.byTooltip('Back'));
      }
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // The event card on home should show the solid flag icon.
      expect(find.byIcon(Icons.flag), findsWidgets);
    });

    testWidgets('unflagging an event removes the flag', (tester) async {
      await tester.pumpWidget(e2eApp());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Flag the first event.
      final outlinedFlags = find.byIcon(Icons.flag_outlined);
      await tester.tap(outlinedFlags.first);
      await tester.pumpAndSettle();

      // Verify it's flagged.
      expect(find.byIcon(Icons.flag), findsWidgets);

      // Unflag it.
      final solidFlags = find.byIcon(Icons.flag);
      await tester.tap(solidFlags.first);
      await tester.pumpAndSettle();

      // All flags should be outlined again.
      expect(find.byIcon(Icons.flag_outlined), findsWidgets);
    });
  });

  // ── Journey 4: View upcoming events ───────────────────────────────────

  group('Journey 4: View upcoming events', () {
    testWidgets('upcoming tab shows future events from the E2E backend',
        (tester) async {
      await tester.pumpWidget(e2eApp());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Navigate to Upcoming tab.
      await tester.tap(find.text('Upcoming'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Upcoming events from WireMock should be visible.
      expect(find.text('Spotlight Hour: Magikarp'), findsOneWidget);
      expect(find.text('Raid Hour: Mega Rayquaza'), findsOneWidget);
      expect(find.text('Community Day: Beldum'), findsOneWidget);

      // Active-now events should NOT appear on the upcoming screen.
      expect(find.text('GO Battle League: Interlude Season'), findsNothing);
    });

    testWidgets('upcoming events are grouped by day with date headers',
        (tester) async {
      await tester.pumpWidget(e2eApp());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Navigate to Upcoming.
      await tester.tap(find.text('Upcoming'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Events on different days should produce separate day headers.
      // Magikarp (Mar 24), Rayquaza (Mar 25), Beldum (Mar 28) are on 3 different days.
      final dayHeaders =
          find.textContaining(RegExp(r'[A-Z][a-z]{2}, [A-Z][a-z]{2}'));
      expect(dayHeaders, findsAtLeast(3),
          reason:
              'Should have at least 3 day headers for events on different days');
    });

    testWidgets('tapping an upcoming event navigates to its detail',
        (tester) async {
      await tester.pumpWidget(e2eApp());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Navigate to Upcoming.
      await tester.tap(find.text('Upcoming'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Tap on the Community Day event.
      await tester.tap(find.text('Community Day: Beldum'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Detail screen should show the event.
      expect(find.text('Community Day: Beldum'), findsOneWidget);

      // Community Day has featured Pokemon and buffs.
      expect(find.text('Active Bonuses'), findsOneWidget);
      expect(find.text('3x Catch XP'), findsOneWidget);
    });

    testWidgets('can navigate between Today and Upcoming tabs',
        (tester) async {
      await tester.pumpWidget(e2eApp());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Start on Today.
      expect(find.text('Adventure Week 2026'), findsOneWidget);

      // Go to Upcoming.
      await tester.tap(find.text('Upcoming'));
      await tester.pumpAndSettle(const Duration(seconds: 10));
      expect(find.text('Community Day: Beldum'), findsOneWidget);

      // Go back to Today.
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(find.text('Adventure Week 2026'), findsOneWidget);
    });
  });
}
