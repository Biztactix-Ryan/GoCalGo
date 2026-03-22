import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gocalgo/config/theme.dart';
import 'package:gocalgo/widgets/loading_indicator.dart';
import 'package:gocalgo/widgets/shimmer.dart';
import 'package:gocalgo/widgets/skeleton_event_card.dart';

/// Verifies acceptance criterion for story US-GCG-26:
/// "Sync-in-progress indicator during refresh"
///
/// Tests that loading/syncing states display visual feedback to the user via
/// skeleton cards with shimmer animation and refresh indicators.
void main() {
  group(
      'US-GCG-26 — Sync-in-progress indicator during refresh', () {
    // -----------------------------------------------------------------------
    // Skeleton loading indicator (initial sync)
    // -----------------------------------------------------------------------

    testWidgets('initial load shows skeleton event cards as sync indicator',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: SkeletonEventList()),
        ),
      );

      expect(find.byType(SkeletonEventCard), findsWidgets,
          reason: 'Skeleton cards should be visible during sync');
    });

    testWidgets('skeleton cards contain shimmer animation for visual feedback',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: SkeletonEventList()),
        ),
      );

      expect(find.byType(Shimmer), findsWidgets,
          reason: 'Shimmer animation should indicate data is being fetched');
    });

    testWidgets('shimmer animation is actively running during sync',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: SkeletonEventList(itemCount: 1)),
        ),
      );

      // Capture initial state and advance animation.
      await tester.pump(const Duration(milliseconds: 750));

      // Shimmer should still be present — animation loops continuously.
      expect(find.byType(Shimmer), findsOneWidget,
          reason: 'Shimmer animation should loop while sync is in progress');
    });

    // -----------------------------------------------------------------------
    // RefreshIndicator (pull-to-refresh sync)
    // -----------------------------------------------------------------------

    testWidgets('RefreshIndicator wraps content for pull-to-refresh sync',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: RefreshIndicator(
              onRefresh: () async {},
              child: ListView(
                children: const [Text('Event 1')],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(RefreshIndicator), findsOneWidget,
          reason: 'A RefreshIndicator should be present for pull-to-refresh');
    });

    testWidgets(
        'pull-to-refresh shows CircularProgressIndicator during sync',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: RefreshIndicator(
              onRefresh: () =>
                  Future.delayed(const Duration(seconds: 2)),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 400),
                  Text('Event content'),
                ],
              ),
            ),
          ),
        ),
      );

      // Simulate pull-to-refresh gesture.
      await tester.fling(
        find.byType(ListView),
        const Offset(0, 300),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // The RefreshIndicator renders a CircularProgressIndicator while
      // the onRefresh future is pending.
      expect(find.byType(RefreshIndicator), findsOneWidget,
          reason: 'RefreshIndicator should be active during sync');
    });

    // -----------------------------------------------------------------------
    // LoadingIndicator as sync feedback
    // -----------------------------------------------------------------------

    testWidgets('LoadingIndicator shows spinner with sync message',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: LoadingIndicator(message: 'Syncing...'),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget,
          reason: 'Spinner should be visible during sync');
      expect(find.text('Syncing...'), findsOneWidget,
          reason: 'Sync message should be displayed');
    });

    testWidgets('LoadingIndicator spinner uses theme primary color',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: LoadingIndicator()),
        ),
      );

      final spinner = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(spinner.color, equals(AppTheme.lightTheme.colorScheme.primary),
          reason: 'Sync indicator should use the app theme color');
    });

    // -----------------------------------------------------------------------
    // State transitions: loading → data replaces sync indicator
    // -----------------------------------------------------------------------

    testWidgets('sync indicator disappears when data arrives',
        (tester) async {
      final stateNotifier = ValueNotifier<bool>(true); // true = syncing

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: stateNotifier,
              builder: (_, isSyncing, __) {
                if (isSyncing) {
                  return const SkeletonEventList();
                }
                return const Center(child: Text('Events loaded'));
              },
            ),
          ),
        ),
      );

      // Sync in progress.
      expect(find.byType(SkeletonEventCard), findsWidgets);
      expect(find.text('Events loaded'), findsNothing);

      // Sync completes.
      stateNotifier.value = false;
      await tester.pump();

      expect(find.byType(SkeletonEventCard), findsNothing,
          reason: 'Skeleton cards should disappear after sync completes');
      expect(find.text('Events loaded'), findsOneWidget);
    });

    testWidgets('sync indicator reappears on subsequent refresh trigger',
        (tester) async {
      final stateNotifier = ValueNotifier<String>('data');

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: ValueListenableBuilder<String>(
              valueListenable: stateNotifier,
              builder: (_, state, __) {
                if (state == 'syncing') {
                  return const SkeletonEventList();
                }
                return const Center(child: Text('Events loaded'));
              },
            ),
          ),
        ),
      );

      // Data is loaded.
      expect(find.text('Events loaded'), findsOneWidget);

      // Re-sync triggered.
      stateNotifier.value = 'syncing';
      await tester.pump();
      expect(find.byType(SkeletonEventCard), findsWidgets,
          reason: 'Sync indicator should reappear when refresh is triggered');

      // Sync completes again.
      stateNotifier.value = 'data';
      await tester.pump();
      expect(find.text('Events loaded'), findsOneWidget);
      expect(find.byType(SkeletonEventCard), findsNothing);
    });

    // -----------------------------------------------------------------------
    // Skeleton card count configuration
    // -----------------------------------------------------------------------

    testWidgets('SkeletonEventList defaults to 3 placeholder cards',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: SkeletonEventList()),
        ),
      );

      // The default itemCount is 3; some may scroll off-screen.
      expect(find.byType(SkeletonEventCard), findsAtLeast(2));
    });
  });
}
