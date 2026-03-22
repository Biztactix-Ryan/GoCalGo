import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_app.dart';

/// Full app integration tests that launch the GoCalGo Flutter app
/// connected to the local backend via Docker Compose.
///
/// Prerequisites:
///   docker compose up -d
///
/// Run:
///   cd src/app
///   flutter test integration_test/app_test.dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App launch against local backend', () {
    testWidgets('home screen loads and shows GoCalGo title', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // The app bar should display the app title.
      expect(find.text('GoCalGo'), findsOneWidget);
    });

    testWidgets('home screen fetches events from backend without crashing',
        (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // After settling, we should see either event cards or the empty state —
      // both indicate the API call completed successfully.
      final hasEvents = find.byType(Card).evaluate().isNotEmpty;
      final hasEmptyState =
          find.textContaining('No events').evaluate().isNotEmpty ||
              find.textContaining('no active').evaluate().isNotEmpty;
      final hasError =
          find.textContaining('Failed to load').evaluate().isNotEmpty;

      // The screen should have rendered data or an empty state, NOT an error.
      expect(hasEvents || hasEmptyState, isTrue,
          reason: hasError
              ? 'Screen shows an error — is the backend running?'
              : 'Screen did not render events or empty state');
    });

    testWidgets('bottom navigation bar is present with Today and Upcoming tabs',
        (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Upcoming'), findsOneWidget);
    });

    testWidgets('navigating to Upcoming tab fetches upcoming events',
        (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Tap the Upcoming tab.
      await tester.tap(find.text('Upcoming'));
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Should not show an error after navigating.
      final hasError =
          find.textContaining('Failed to load').evaluate().isNotEmpty;
      expect(hasError, isFalse,
          reason: 'Upcoming tab shows an error — is the backend running?');
    });
  });
}
