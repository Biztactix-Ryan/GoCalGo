import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gocalgo/config/theme.dart';
import 'package:gocalgo/models/event_type.dart';
import 'package:gocalgo/providers/events_provider.dart';
import 'package:gocalgo/providers/onboarding_provider.dart';
import 'package:gocalgo/screens/home_screen.dart';
import 'package:gocalgo/screens/upcoming_screen.dart';
import 'package:gocalgo/services/flag_store.dart';

import '../helpers/in_memory_stores.dart';
import '../helpers/pump_app.dart';
import '../helpers/test_data.dart';

/// Verifies that scrolling and transitions are smooth (60fps proxy).
///
/// Acceptance criterion for US-GCG-14:
///   > Scrolling and transitions are smooth (60fps)
///
/// In a widget test environment we cannot measure real GPU frame times, but we
/// can verify:
///   1. Scrolling through a large list settles without excessive frames
///      (no layout thrash or rebuild storms).
///   2. Each scroll-driven pump completes within a reasonable budget.
///   3. Tab transitions between screens settle quickly.

/// Number of events to populate the list — large enough to exercise the
/// ListView builder and force off-screen items to be lazily built.
const _eventCount = 50;

void main() {
  group('Scrolling performance', () {
    testWidgets('home screen scrolls through many events without frame storm',
        (tester) async {
      final now = DateTime.now();
      final events = List.generate(_eventCount, (i) {
        return TestData.event(
          id: 'perf-$i',
          name: 'Performance Event $i',
          eventType: EventType.values[i % EventType.values.length],
          heading: 'Heading $i',
          start: now.subtract(const Duration(hours: 1)),
          end: now.add(const Duration(hours: 2)),
          hasSpawns: i.isEven,
          hasResearchTasks: i % 3 == 0,
        );
      });

      await tester.pumpScreen(
        const HomeScreen(),
        events: events,
      );
      await tester.pumpAndSettle();

      // Scroll down through the list in increments, counting frames at each step.
      var totalFrames = 0;
      const scrollSteps = 10;
      const scrollDistance = -300.0;

      for (var step = 0; step < scrollSteps; step++) {
        await tester.drag(
          find.byType(ListView).first,
          const Offset(0, scrollDistance),
        );

        // Count frames needed to settle after each scroll gesture.
        var frames = 0;
        while (tester.binding.hasScheduledFrame) {
          await tester.pump(const Duration(milliseconds: 16));
          frames++;
          if (frames > 120) break; // 2-second safety valve at 60fps
        }
        totalFrames += frames;
      }

      // Average frames per scroll gesture should be modest — smooth scrolling
      // settles within a few frames of the fling animation completing.
      final avgFrames = totalFrames / scrollSteps;

      expect(
        avgFrames,
        lessThan(60),
        reason: 'Scroll averaged $avgFrames frames per gesture to settle — '
            'possible jank or rebuild storm',
      );
    });

    testWidgets('upcoming screen scrolls through grouped days smoothly',
        (tester) async {
      final now = DateTime.now();
      // Create events spread across the next 7 days.
      final events = List.generate(_eventCount, (i) {
        final dayOffset = i % 7;
        return TestData.event(
          id: 'upcoming-perf-$i',
          name: 'Upcoming Event $i',
          eventType: EventType.values[i % EventType.values.length],
          heading: 'Heading $i',
          start: now.add(Duration(days: dayOffset, hours: 1)),
          end: now.add(Duration(days: dayOffset, hours: 4)),
        );
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            upcomingEventsProvider.overrideWith(
              () => FakeUpcomingEventsNotifier(events: events),
            ),
            flaggedIdsProvider.overrideWith(
              () => FakeFlaggedIdsNotifier({}),
            ),
            connectivityProvider.overrideWith(
              () => FakeConnectivityNotifier(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const UpcomingScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      var totalFrames = 0;
      const scrollSteps = 8;

      for (var step = 0; step < scrollSteps; step++) {
        await tester.drag(
          find.byType(ListView).first,
          const Offset(0, -300),
        );

        var frames = 0;
        while (tester.binding.hasScheduledFrame) {
          await tester.pump(const Duration(milliseconds: 16));
          frames++;
          if (frames > 120) break;
        }
        totalFrames += frames;
      }

      final avgFrames = totalFrames / scrollSteps;

      expect(
        avgFrames,
        lessThan(60),
        reason: 'Upcoming screen scroll averaged $avgFrames frames to settle — '
            'day group headers may be causing layout thrash',
      );
    });
  });

  group('Transition performance', () {
    testWidgets('tab switch settles within budget', (tester) async {
      final now = DateTime.now();
      final events = List.generate(10, (i) {
        return TestData.event(
          id: 'nav-$i',
          name: 'Nav Event $i',
          start: now.subtract(const Duration(hours: 1)),
          end: now.add(const Duration(hours: 2)),
        );
      });

      // Use a ValueNotifier to swap screens within a single ProviderScope,
      // avoiding the "cannot change number of overrides" Riverpod error.
      final screenNotifier = ValueNotifier<Widget>(const HomeScreen());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeEventsProvider.overrideWith(
              () => FakeEventsNotifier(events: events),
            ),
            upcomingEventsProvider.overrideWith(
              () => FakeUpcomingEventsNotifier(events: events),
            ),
            flaggedIdsProvider.overrideWith(
              () => FakeFlaggedIdsNotifier({}),
            ),
            connectivityProvider.overrideWith(
              () => FakeConnectivityNotifier(),
            ),
            hasCompletedOnboardingProvider.overrideWith((_) async => true),
            flagStoreProvider.overrideWithValue(InMemoryFlagStore()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: ValueListenableBuilder<Widget>(
              valueListenable: screenNotifier,
              builder: (_, screen, __) => screen,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Simulate switching to the Upcoming tab.
      final stopwatch = Stopwatch()..start();
      screenNotifier.value = const UpcomingScreen();

      var frames = 0;
      while (tester.binding.hasScheduledFrame) {
        await tester.pump(const Duration(milliseconds: 16));
        frames++;
        if (frames > 120) break;
      }

      stopwatch.stop();

      // Transition should settle within 500ms (30 frames at 60fps).
      expect(
        frames,
        lessThan(30),
        reason: 'Tab transition took $frames frames to settle — '
            'expected smooth transition under 500ms',
      );

      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(1000),
        reason: 'Tab transition took ${stopwatch.elapsedMilliseconds}ms — '
            'too slow for smooth UX',
      );
    });

    testWidgets('rapid scroll fling does not cause excessive rebuilds',
        (tester) async {
      final now = DateTime.now();
      final events = List.generate(_eventCount, (i) {
        return TestData.event(
          id: 'fling-$i',
          name: 'Fling Event $i',
          start: now.subtract(const Duration(hours: 1)),
          end: now.add(const Duration(hours: 2)),
        );
      });

      await tester.pumpScreen(
        const HomeScreen(),
        events: events,
      );
      await tester.pumpAndSettle();

      // Perform a fast fling gesture.
      await tester.fling(
        find.byType(ListView).first,
        const Offset(0, -2000),
        3000, // pixels per second — fast fling
      );

      // Count total frames until the fling animation completes.
      var frames = 0;
      while (tester.binding.hasScheduledFrame) {
        await tester.pump(const Duration(milliseconds: 16));
        frames++;
        if (frames > 300) break; // 5-second safety valve
      }

      // A smooth fling should complete within a reasonable frame count.
      // The fling animation itself takes time, but it shouldn't cause
      // layout thrash beyond the physics-driven animation frames.
      expect(
        frames,
        lessThan(200),
        reason: 'Fling took $frames frames to settle — possible jank. '
            'At 60fps this is ${(frames * 16.67).round()}ms',
      );
    });
  });
}
