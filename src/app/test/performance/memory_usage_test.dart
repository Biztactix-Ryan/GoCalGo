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

/// Verifies that memory usage is reasonable and no leaks are detected.
///
/// Acceptance criterion for US-GCG-14:
///   > Memory usage is reasonable and no leaks detected
///
/// In a widget test environment we cannot directly measure heap size, but we
/// can detect symptoms of memory leaks:
///   1. Repeatedly mounting/unmounting the widget tree should not accumulate
///      objects — providers use AutoDispose so state should be released.
///   2. Building large data sets and disposing them should allow the widget
///      tree to settle cleanly with no leftover frame scheduling.
///   3. Provider containers should not grow unbounded across repeated use.

/// Number of mount/unmount cycles to exercise disposal paths.
const _cycles = 20;

/// Number of events per cycle — large enough to surface leaks from list items.
const _eventCount = 100;

void main() {
  group('Memory usage', () {
    testWidgets(
        'repeated mount/unmount cycles do not accumulate pending frames',
        (tester) async {
      final now = DateTime.now();
      final events = List.generate(_eventCount, (i) {
        return TestData.event(
          id: 'mem-$i',
          name: 'Memory Event $i',
          eventType: EventType.values[i % EventType.values.length],
          heading: 'Heading $i',
          start: now.subtract(const Duration(hours: 1)),
          end: now.add(const Duration(hours: 2)),
          hasSpawns: i.isEven,
          hasResearchTasks: i % 3 == 0,
        );
      });

      // Track how many frames are needed to settle after each cycle.
      // A leak would cause this number to grow over time.
      final settleFrames = <int>[];

      for (var cycle = 0; cycle < _cycles; cycle++) {
        // Mount the full widget tree with a large event list.
        await tester.pumpScreen(
          const HomeScreen(),
          events: events,
        );
        await tester.pumpAndSettle();

        // Tear down by replacing with a minimal widget.
        await tester.pumpWidget(const SizedBox.shrink());

        // Count frames needed to fully settle after disposal.
        var frames = 0;
        while (tester.binding.hasScheduledFrame) {
          await tester.pump();
          frames++;
          if (frames > 100) break; // safety valve
        }
        settleFrames.add(frames);
      }

      // The settle frame count should not trend upward. Compare the average
      // of the last 5 cycles to the first 5 — a significant increase
      // indicates accumulated state preventing clean disposal.
      final firstAvg = settleFrames.take(5).reduce((a, b) => a + b) / 5;
      final lastAvg =
          settleFrames.skip(_cycles - 5).reduce((a, b) => a + b) / 5;

      expect(
        lastAvg,
        lessThanOrEqualTo(firstAvg + 3),
        reason: 'Settle frame count grew from $firstAvg to $lastAvg '
            'over $_cycles cycles — possible leak causing widget tree '
            'to retain state across mount/unmount',
      );

      // No individual cycle should require excessive frames to settle.
      for (var i = 0; i < settleFrames.length; i++) {
        expect(
          settleFrames[i],
          lessThan(50),
          reason: 'Cycle $i took ${settleFrames[i]} frames to settle — '
              'disposal may be blocked or leaking',
        );
      }
    });

    testWidgets('provider container disposes cleanly on unmount',
        (tester) async {
      // Create a ProviderContainer we can inspect for disposal.
      var disposeCount = 0;
      final container = ProviderContainer(
        overrides: [
          activeEventsProvider.overrideWith(() => FakeEventsNotifier()),
          flaggedIdsProvider.overrideWith(() => FakeFlaggedIdsNotifier({})),
          connectivityProvider.overrideWith(() => FakeConnectivityNotifier()),
          hasCompletedOnboardingProvider.overrideWith((_) async => true),
          flagStoreProvider.overrideWithValue(InMemoryFlagStore()),
        ],
      );

      // Listen to the main provider to force its creation.
      container.listen(activeEventsProvider, (_, __) {});

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Disposing the container should not throw — all providers should
      // release their resources cleanly.
      expect(
        () => container.dispose(),
        returnsNormally,
        reason: 'Provider container disposal threw — resource leak or '
            'dangling listener',
      );
    });

    testWidgets('screen transitions do not accumulate widget tree depth',
        (tester) async {
      final now = DateTime.now();
      final events = List.generate(20, (i) {
        return TestData.event(
          id: 'depth-$i',
          name: 'Depth Event $i',
          start: now.subtract(const Duration(hours: 1)),
          end: now.add(const Duration(hours: 2)),
        );
      });

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

      // Measure initial Element count as a baseline.
      final initialElementCount = _countElements(tester);

      // Rapidly switch between screens many times.
      const switchCycles = 20;
      for (var i = 0; i < switchCycles; i++) {
        screenNotifier.value = const UpcomingScreen();
        await tester.pumpAndSettle();

        screenNotifier.value = const HomeScreen();
        await tester.pumpAndSettle();
      }

      final finalElementCount = _countElements(tester);

      // Element count should remain stable — a growing count indicates
      // widgets being retained across screen transitions.
      // Allow a small tolerance for timing-related transient widgets.
      expect(
        finalElementCount,
        lessThanOrEqualTo(initialElementCount * 1.1),
        reason: 'Element count grew from $initialElementCount to '
            '$finalElementCount after $switchCycles screen transitions — '
            'possible widget retention leak',
      );
    });

    testWidgets('large event list does not cause excessive frame scheduling',
        (tester) async {
      final now = DateTime.now();

      // Build a very large event list to stress-test memory.
      final largeEvents = List.generate(500, (i) {
        return TestData.event(
          id: 'large-$i',
          name: 'Large List Event $i',
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
        events: largeEvents,
      );

      // Count frames needed to settle with a massive list.
      var frames = 0;
      while (tester.binding.hasScheduledFrame) {
        await tester.pump(const Duration(milliseconds: 16));
        frames++;
        if (frames > 300) break; // 5-second safety valve
      }

      // ListView.builder should lazily build only visible items, so even
      // 500 events should settle within a reasonable frame budget.
      expect(
        frames,
        lessThan(120),
        reason: 'Large event list took $frames frames to settle — '
            'ListView may not be lazily building items, causing '
            'excessive memory allocation',
      );

      // Verify the tree actually rendered (not a blank screen from OOM).
      expect(find.byType(ListView), findsWidgets);
    });
  });
}

/// Counts the total number of [Element]s in the current widget tree.
///
/// A growing element count across repeated operations indicates widgets
/// being retained when they should have been disposed.
int _countElements(WidgetTester tester) {
  var count = 0;
  void visitor(Element element) {
    count++;
    element.visitChildren(visitor);
  }

  tester.binding.rootElement!.visitChildren(visitor);
  return count;
}
