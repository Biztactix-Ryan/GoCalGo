import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gocalgo/config/theme.dart';
import 'package:gocalgo/providers/events_provider.dart';
import 'package:gocalgo/providers/onboarding_provider.dart';
import 'package:gocalgo/screens/home_screen.dart';
import 'package:gocalgo/services/flag_store.dart';

/// Verifies that app startup time is under 2 seconds.
///
/// Acceptance criterion for US-GCG-14:
///   > App startup time is under 2 seconds
///
/// This test measures the time from widget pump to the first fully settled
/// frame — the closest proxy for startup time in a widget test environment.
/// It uses lightweight provider overrides so we measure widget tree build and
/// layout performance, not network latency.

void main() {
  group('Startup performance', () {
    testWidgets('app renders first frame within 2 seconds', (tester) async {
      final stopwatch = Stopwatch()..start();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeEventsProvider
                .overrideWith(() => _FastEventsNotifier()),
            flaggedIdsProvider
                .overrideWith(() => _FastFlaggedIdsNotifier()),
            connectivityProvider
                .overrideWith(() => _FastConnectivityNotifier()),
            hasCompletedOnboardingProvider
                .overrideWith((_) async => true),
            flagStoreProvider.overrideWithValue(_InMemoryFlagStore()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      stopwatch.stop();

      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(2000),
        reason: 'App startup took ${stopwatch.elapsedMilliseconds}ms, '
            'exceeding the 2-second budget',
      );
    });

    testWidgets('widget tree settles without excessive rebuilds',
        (tester) async {
      var frameCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeEventsProvider
                .overrideWith(() => _FastEventsNotifier()),
            flaggedIdsProvider
                .overrideWith(() => _FastFlaggedIdsNotifier()),
            connectivityProvider
                .overrideWith(() => _FastConnectivityNotifier()),
            hasCompletedOnboardingProvider
                .overrideWith((_) async => true),
            flagStoreProvider.overrideWithValue(_InMemoryFlagStore()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const HomeScreen(),
          ),
        ),
      );

      // Pump frames one at a time to count how many are needed to settle.
      while (tester.binding.hasScheduledFrame) {
        await tester.pump();
        frameCount++;
        if (frameCount > 100) break; // safety valve
      }

      // Settling within a reasonable number of frames indicates no
      // infinite rebuild loops or expensive layout thrash.
      expect(
        frameCount,
        lessThan(100),
        reason: 'Widget tree took $frameCount frames to settle — '
            'possible rebuild loop',
      );
    });
  });
}

// ---------------------------------------------------------------------------
// Lightweight provider overrides — return data immediately so the test
// measures widget build/layout, not simulated network delay.
// ---------------------------------------------------------------------------

class _FastEventsNotifier extends EventsNotifier {
  @override
  Future<EventsState> build() async => EventsState(
        events: [],
        lastUpdated: DateTime.now(),
      );

  @override
  Future<void> refresh() async {
    state = AsyncData(EventsState(
      events: [],
      lastUpdated: DateTime.now(),
    ));
  }
}

class _FastFlaggedIdsNotifier extends FlaggedIdsNotifier {
  @override
  Future<Set<String>> build() async => {};

  @override
  Future<void> toggle(String id) async {}
}

class _FastConnectivityNotifier extends ConnectivityNotifier {
  @override
  Stream<bool> build() => Stream.value(true);
}

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
